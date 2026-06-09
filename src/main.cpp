#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QThread>

#include "core/AppPaths.h"
#include "core/LogSetup.h"
#include "core/Database.h"
#include "core/ModbusTcpServerService.h"
#include "core/RestApiService.h"
#include "models/MonitorModel.h"
#include "models/SensorListModel.h"
#include "controllers/SettingsController.h"
#include "controllers/MonitorController.h"
#include "controllers/HistoryController.h"
#include "controllers/TesterController.h"
#include "controllers/ReportController.h"

int main(int argc, char *argv[]) {
    // Qt quick controls style
    qputenv("QT_QUICK_CONTROLS_STYLE", "Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");

    QGuiApplication app(argc, argv);
    app.setApplicationName("DataLogger");
    app.setApplicationVersion("2.0.0");
    app.setOrganizationName("DATALOGGER");
    app.setOrganizationDomain("datalogger.local");
    app.setDesktopFileName("data-logger");

    // Paths & Logging
    AppPaths::ensureDirectories();
    setupLogging(AppPaths::logDir());

    QString dbPath = AppPaths::dataDir() + "/datalogger.db";
    if (!Database::init(dbPath)) {
        qCritical() << "Failed to initialise database at" << dbPath;
        return 1;
    }

    // App icon
    QString iconPath = AppPaths::appIconPath();
    if (!iconPath.isEmpty())
        app.setWindowIcon(QIcon(iconPath));

    // Core services
    auto *modbusTcp   = new ModbusTcpServerService(&app);
    auto *restApi     = new RestApiService(&app);

    // Models
    auto *monitorModel  = new MonitorModel(&app);
    auto *sensorList    = new SensorListModel(&app);

    // Controllers
    auto *settingsCtrl  = new SettingsController(&app);
    auto *monitorCtrl   = new MonitorController(monitorModel, modbusTcp, &app);
    auto *historyCtrl   = new HistoryController(&app);
    auto *testerCtrl    = new TesterController(&app);
    auto *reportCtrl    = new ReportController(&app);

    // Load initial config
    settingsCtrl->loadConfig();
    const AppConfig &cfg = settingsCtrl->config();

    // Wire REST API readings provider
    restApi->setReadingsProvider([monitorCtrl]() -> QVariantMap {
        return monitorCtrl->readingsSnapshot();
    });

    // Start optional services based on config
    if (cfg.modbusTcpEnabled)
        modbusTcp->start(cfg.modbusTcpBind, cfg.modbusTcpPort, cfg.modbusTcpUnitId);

    if (cfg.restApiEnabled)
        restApi->start(cfg.restApiBind, cfg.restApiPort, cfg.restApiToken);

    // Restart services when settings are saved
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

    // Graceful shutdown
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&]() {
        monitorCtrl->stopPollingSync();
        modbusTcp->stop();
        restApi->stop();
    });

    // QML engine
    QQmlApplicationEngine engine;

    // Expose C++ objects to QML
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("settingsController",  settingsCtrl);
    ctx->setContextProperty("monitorController",   monitorCtrl);
    ctx->setContextProperty("historyController",   historyCtrl);
    ctx->setContextProperty("testerController",    testerCtrl);
    ctx->setContextProperty("reportController",    reportCtrl);
    ctx->setContextProperty("monitorModel",        monitorModel);
    ctx->setContextProperty("sensorListModel",     sensorList);
    ctx->setContextProperty("modbusTcpService",    modbusTcp);
    ctx->setContextProperty("restApiService",      restApi);

    const QUrl url("qrc:/com/datalogger/app/src/qml/Main.qml");
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);

    engine.load(url);
    if (engine.rootObjects().isEmpty()) return -1;

    return app.exec();
}
