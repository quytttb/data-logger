#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>

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
    auto *ftpWorker     = new FtpWorker(&app);

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

    QObject::connect(settingsCtrl, &SettingsController::configSaved, &app, [&]() {
        const AppConfig &c = settingsCtrl->config();
        if (c.modbusTcpEnabled)
            modbusTcp->start(c.modbusTcpBind, c.modbusTcpPort, c.modbusTcpUnitId);
        else
            modbusTcp->stop();
        if (c.restApiEnabled)
            restApi->start(c.restApiBind, c.restApiPort, c.restApiToken);
        else
            restApi->stop();
    });

    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&]() {
        monitorCtrl->stopPollingSync();
        ftpWorker->stop();
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

    return app.exec();
}
