#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QFontDatabase>
#include <QTimer>
#include <QtDebug>

#include "utils/AppPaths.h"
#include "utils/LogSetup.h"
#include "data/db/Database.h"
#include "network/modbus/ModbusTcpServerService.h"
#include "network/rest/RestApiService.h"
#include "network/workers/FtpWorker.h"
#include "core/MonitorModel.h"
#include "core/SensorListModel.h"
#include "core/SettingsController.h"
#include "core/MonitorController.h"
#include "core/history/HistoryViewModel.h"
#include "core/TesterController.h"
#include "core/ReportController.h"

int main(int argc, char *argv[]) {
    qputenv("QT_QUICK_CONTROLS_STYLE", "Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");

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
    app.setApplicationVersion("2.0.0");
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

    auto *ftpWorker  = new FtpWorker();          // no parent — owned by ftpThread
    auto *ftpThread  = new QThread(&app);
    ftpWorker->moveToThread(ftpThread);
    QObject::connect(ftpThread, &QThread::finished, ftpWorker, &QObject::deleteLater);
    ftpThread->start();

    ModbusTcpServerService::setInstance(modbusTcp);
    RestApiService::setInstance(restApi);
    MonitorModel::setInstance(monitorModel);
    SensorListModel::setInstance(sensorList);
    SettingsController::setInstance(settingsCtrl);
    MonitorController::setInstance(monitorCtrl);
    HistoryViewModel::setInstance(historyVm);
    TesterController::setInstance(testerCtrl);
    ReportController::setInstance(reportCtrl);

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
        monitorCtrl->stopPollingSync();
        QMetaObject::invokeMethod(ftpWorker, "stop", Qt::BlockingQueuedConnection);
        ftpThread->quit();
        ftpThread->wait(5000);
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
