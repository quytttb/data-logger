#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QFontDatabase>
#include <QSemaphore>
#include <QTimer>
#include <QtDebug>

#include "utils/system/AppPaths.h"
#include "utils/system/LogSetup.h"
#include "utils/system/DeviceId.h"
#include "utils/system/DeviceLock.h"
#include "data/db/Database.h"
#include "network/modbus/ModbusTcpServerService.h"
#include "network/rest/RestApiService.h"
#include "network/workers/FtpWorker.h"
#include "network/workers/RetentionWorker.h"
#include "core/MonitorModel.h"
#include "core/SensorListModel.h"
#include "core/SettingsController.h"
#include "core/MonitorController.h"
#include "core/history/HistoryViewModel.h"
#include "core/TesterController.h"
#include "core/ReportController.h"
#include "core/tt10/SensorSymbols.h"

namespace {
constexpr int kThreadJoinMs = 5000;  // graceful FTP thread join on quit

// H-1: mọi chờ I/O phải bounded — dừng worker kiểu queued + semaphore timeout
// thay vì BlockingQueuedConnection (treo quit nếu worker thread kẹt).
void stopWorkerOnQuit(QObject *worker, QThread *thread) {
    QSemaphore sem;
    QMetaObject::invokeMethod(worker, "stop", Qt::QueuedConnection);
    QMetaObject::invokeMethod(worker, [&sem]() { sem.release(); }, Qt::QueuedConnection);
    if (!sem.tryAcquire(1, kThreadJoinMs))
        qWarning() << "Worker slot 'stop' did not complete during shutdown";
    thread->quit();
    if (!thread->wait(kThreadJoinMs)) // thread object lives until application teardown
        qWarning() << "Worker thread did not finish during shutdown (leaked until process exit)";
}
}

int main(int argc, char *argv[]) {
    qputenv("QT_QUICK_CONTROLS_STYLE", "Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");

    // Touch kiosk: route text input through the on-screen Qt Virtual Keyboard
    // and hide the mouse pointer when rendering directly on DRM/KMS (eglfs).
    qputenv("QT_IM_MODULE", "qtvirtualkeyboard");
    qputenv("QT_QPA_EGLFS_HIDECURSOR", "1");

    QGuiApplication app(argc, argv);
    app.setApplicationName("DataLogger");

    const QString iconFontPath =
        QStringLiteral(":/qt/qml/DataLogger/Components/resources/fonts/MaterialSymbols/"
                       "MaterialSymbolsOutlined.ttf");
    const int fontId = QFontDatabase::addApplicationFont(iconFontPath);
    if (fontId < 0) {
        qWarning() << "[main] Failed to load icon font from" << iconFontPath
                   << "— icons will show as boxes";
    } else {
        const QStringList families = QFontDatabase::applicationFontFamilies(fontId);
        if (!families.isEmpty()) {
            qDebug() << "[main] Icon font loaded:" << families.constFirst();
        }
    }
    app.setApplicationVersion("2.1.0");
    app.setOrganizationName("DATALOGGER");
    app.setOrganizationDomain("datalogger.local");
    app.setDesktopFileName("data-logger");

    AppPaths::ensureDirectories();
    setupLogging(AppPaths::logDir());

    QString dbPath = AppPaths::dataDir() + "/datalogger.db";
    if (!Database::init(dbPath)) {
        qCritical() << "Failed to initialise database at" << dbPath;
        return 1;
    }

    DeviceLock::State lockState = DeviceLock::check();
    if (lockState == DeviceLock::State::Unbound) {
        if (!DeviceLock::bind()) {
            qCritical() << "Failed to bind device to hardware";
            return 1;
        }
    } else if (lockState == DeviceLock::State::Unauthorized) {
        QQmlApplicationEngine lockEngine;
        lockEngine.rootContext()->setContextProperty(
            QStringLiteral("deviceStationCode"), DeviceId::stationCode());
        QObject::connect(
            &lockEngine,
            &QQmlApplicationEngine::objectCreationFailed,
            &app,
            []() { QCoreApplication::exit(-1); },
            Qt::QueuedConnection);
        lockEngine.loadFromModule("DataLogger.App", "LockScreen");
        if (lockEngine.rootObjects().isEmpty())
            return -1;
        return app.exec();
    }

    QString iconPath = AppPaths::appIconPath();
    if (!iconPath.isEmpty())
        app.setWindowIcon(QIcon(iconPath));

    auto *modbusTcp   = new ModbusTcpServerService(&app);
    auto *restApi     = new RestApiService(&app);

    auto *monitorModel  = new MonitorModel(&app);
    auto *sensorList    = new SensorListModel(&app);

    auto *settingsCtrl  = new SettingsController(&app);
    auto *monitorCtrl   = new MonitorController(monitorModel, modbusTcp, &app);
    auto *historyVm      = new HistoryViewModel(&app);
    auto *testerCtrl    = new TesterController(&app);
    auto *reportCtrl    = new ReportController(&app);
    auto *sensorSymbols = new SensorSymbols(&app);

    auto *ftpWorker  = new FtpWorker();          // no parent — owned by ftpThread
    auto *ftpThread  = new QThread(&app);
    ftpWorker->moveToThread(ftpThread);
    QObject::connect(ftpThread, &QThread::finished, ftpWorker, &QObject::deleteLater);
    ftpThread->start();

    // Retention: purge old sensor_data / reports / logs on its own thread so
    // the 24/7 device never fills its SD card (audit C4/H7).
    auto *retentionWorker = new RetentionWorker(); // no parent — owned by retentionThread
    auto *retentionThread = new QThread(&app);
    retentionWorker->moveToThread(retentionThread);
    QObject::connect(retentionThread, &QThread::finished, retentionWorker, &QObject::deleteLater);
    QObject::connect(retentionThread, &QThread::started, retentionWorker, &RetentionWorker::start);
    retentionThread->start();

    ModbusTcpServerService::setInstance(modbusTcp);
    RestApiService::setInstance(restApi);
    MonitorModel::setInstance(monitorModel);
    SensorListModel::setInstance(sensorList);
    SettingsController::setInstance(settingsCtrl);
    MonitorController::setInstance(monitorCtrl);
    HistoryViewModel::setInstance(historyVm);
    TesterController::setInstance(testerCtrl);
    ReportController::setInstance(reportCtrl);
    SensorSymbols::setInstance(sensorSymbols);

    reportCtrl->setFtpWorker(ftpWorker);
    reportCtrl->setSettingsController(settingsCtrl);
    QObject::connect(ftpWorker, &FtpWorker::workerHeartbeat,
                     monitorCtrl, &MonitorController::registerHeartbeat);

    // Keep the Monitor dashboard in sync with sensor add/edit/delete.
    // modelReset is emitted automatically by endResetModel() on every save/delete.
    // Pass already-loaded data via activeMonitorMaps() — no extra DB round-trip.
    QObject::connect(sensorList, &QAbstractItemModel::modelReset,
                     monitorCtrl, [sensorList, monitorCtrl]() {
                         monitorCtrl->refreshSensorsFromList(sensorList->activeMonitorMaps());
                     });
    // DI/DO link add/update/remove doesn't touch sensor rows, so modelReset is
    // not emitted. refreshSensors() re-reads the DB to rebuild diLegend and
    // digitalIoMap — acceptable since link edits are infrequent.
    QObject::connect(sensorList, &SensorListModel::linksChanged,
                     monitorCtrl, &MonitorController::refreshSensors);
    // Keep History sensor filter list in sync — no extra DB read.
    QObject::connect(sensorList, &QAbstractItemModel::modelReset,
                     historyVm, [sensorList, historyVm]() {
                         historyVm->reloadFiltersFromMaps(sensorList->activeMonitorMaps());
                     });
    // Populate the dashboard with already-configured sensors at startup.
    monitorCtrl->refreshSensorsFromList(sensorList->activeMonitorMaps());
    historyVm->reloadFiltersFromMaps(sensorList->activeMonitorMaps());

    settingsCtrl->loadConfig();
    const AppConfig &cfg = settingsCtrl->config();

    restApi->setReadingsProvider([monitorCtrl]() -> QVariantMap {
        return monitorCtrl->readingsSnapshot();
    });

    if (cfg.modbusTcpEnabled)
        modbusTcp->start(cfg.modbusTcpBind, cfg.modbusTcpPort, cfg.modbusTcpUnitId);

    if (cfg.restApiEnabled)
        restApi->start(cfg.restApiBind, cfg.restApiPort, cfg.restApiToken);

    reportCtrl->applyServerConfig();

    // Reload config and restart affected services when saved from the UI.
    auto applyConfig = [&]() {
        const AppConfig &c = settingsCtrl->config();
        if (c.modbusTcpEnabled)
            modbusTcp->start(c.modbusTcpBind, c.modbusTcpPort, c.modbusTcpUnitId);
        else
            modbusTcp->stop();
        if (c.restApiEnabled)
            restApi->start(c.restApiBind, c.restApiPort, c.restApiToken);
        else
            restApi->stop();
        reportCtrl->applyServerConfig();
    };
    QObject::connect(settingsCtrl, &SettingsController::configSaved, &app, applyConfig);

    // Also react to config changes coming from the REST API so that the
    // in-memory SettingsController stays in sync with the DB.
    QObject::connect(restApi, &RestApiService::configApplied, &app, [&](int /*revision*/) {
        settingsCtrl->loadConfig();
        applyConfig();
    });

    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&]() {
        stopWorkerOnQuit(retentionWorker, retentionThread);
        monitorCtrl->stopPollingSync();
        stopWorkerOnQuit(ftpWorker, ftpThread);
        modbusTcp->stop();
        restApi->stop();
    });

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("DataLogger.App", "Main");

    if (engine.rootObjects().isEmpty()) return -1;

    // Auto-start monitoring once the event loop is running, so that the UI is
    // ready to reflect the polling state and receive any startup messages.
    QTimer::singleShot(0, monitorCtrl, [monitorCtrl]() {
        monitorCtrl->startPolling();
    });

    return app.exec();
}
