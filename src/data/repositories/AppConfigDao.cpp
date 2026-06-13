#include "AppConfigDao.h"
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlError>
#include <QUuid>
#include <QDebug>

AppConfigDao::AppConfigDao(QSqlDatabase db) : m_db(std::move(db)) {}

AppConfig AppConfigDao::rowToConfig(const QSqlRecord &r) {
    AppConfig c;
    c.id                = r.value("id").toInt();
    c.stationCode       = r.value("station_code").toString();
    c.stationName       = r.value("station_name").toString();
    c.timeFormat        = r.value("time_format").toString();
    c.dateFormat        = r.value("date_format").toString();
    c.timezone          = r.value("timezone").toString();
    c.autoSyncTime      = r.value("auto_sync_time").toBool();
    c.buzzerEnable      = r.value("buzzer_enable").toBool();
    c.ftpAddress        = r.value("ftp_address").toString();
    c.ftpPort           = r.value("ftp_port").toInt();
    c.ftpUsername       = r.value("ftp_username").toString();
    c.ftpPassword       = r.value("ftp_password").toString();
    c.ftpRemotePath     = r.value("ftp_remote_path").toString();
    c.ftpPrefix         = r.value("ftp_prefix").toString();
    c.pollInterval      = r.value("poll_interval").toInt();
    c.serialPort        = r.value("serial_port").toString();
    c.serialBaudrate    = r.value("serial_baudrate").toInt();
    c.serialBytesize    = r.value("serial_bytesize").toInt();
    c.serialParity      = r.value("serial_parity").toString();
    c.serialStopbits    = r.value("serial_stopbits").toInt();
    c.serverActive      = r.value("server_active").toBool();
    c.serverDeviceType  = r.value("server_device_type").toString();
    c.serverName        = r.value("server_name").toString();
    c.serverSendInterval= r.value("server_send_interval").toInt();
    c.serverStartTime   = r.value("server_start_time").toString();
    c.serverBaseFolder  = r.value("server_base_folder").toString();
    c.serverTimeFolder  = r.value("server_time_folder").toString();
    c.serverFileSuffix  = r.value("server_file_suffix").toString();
    c.modbusTcpEnabled  = r.value("modbus_tcp_enabled").toBool();
    c.modbusTcpPort     = r.value("modbus_tcp_port").toInt();
    c.modbusTcpBind     = r.value("modbus_tcp_bind").toString();
    c.modbusTcpUnitId   = r.value("modbus_tcp_unit_id").toInt();
    c.restApiEnabled    = r.value("rest_api_enabled").toBool();
    c.restApiPort       = r.value("rest_api_port").toInt();
    c.restApiBind       = r.value("rest_api_bind").toString();
    c.restApiToken      = r.value("rest_api_token").toString();
    c.configRevision    = r.value("config_revision").toInt();
    c.uiLocale          = r.value("ui_locale").toString();
    return c;
}

AppConfig AppConfigDao::load() {
    QSqlQuery q(m_db);
    q.exec("SELECT * FROM app_config LIMIT 1");
    if (q.next())
        return rowToConfig(q.record());

    // No row yet — insert defaults and return
    AppConfig def;
    save(def);
    q.exec("SELECT * FROM app_config LIMIT 1");
    if (q.next())
        return rowToConfig(q.record());
    return def;
}

bool AppConfigDao::save(const AppConfig &c) {
    QSqlQuery q(m_db);
    if (c.id == 0) {
        q.prepare(R"(INSERT INTO app_config (
            station_code, station_name, time_format, date_format, timezone,
            auto_sync_time, buzzer_enable, ftp_address, ftp_port, ftp_username,
            ftp_password, ftp_remote_path, ftp_prefix, poll_interval,
            serial_port, serial_baudrate, serial_bytesize, serial_parity, serial_stopbits,
            server_active, server_device_type, server_name, server_send_interval,
            server_start_time, server_base_folder, server_time_folder, server_file_suffix,
            modbus_tcp_enabled, modbus_tcp_port, modbus_tcp_bind, modbus_tcp_unit_id,
            rest_api_enabled, rest_api_port, rest_api_bind, rest_api_token,
            config_revision, ui_locale
        ) VALUES (
            :sc, :sn, :tf, :df, :tz,
            :ast, :be, :fa, :fp, :fu,
            :fpw, :frp, :fpfx, :pi,
            :sp, :sb, :sbs, :spar, :ssb,
            :sact, :sdt, :snm, :ssi,
            :sst, :sbf, :stf, :ssf,
            :mte, :mtp, :mtb, :mtui,
            :rae, :rap, :rab, :rat,
            :cr, :ul
        ))");
    } else {
        q.prepare(R"(UPDATE app_config SET
            station_code=:sc, station_name=:sn, time_format=:tf, date_format=:df,
            timezone=:tz, auto_sync_time=:ast, buzzer_enable=:be, ftp_address=:fa,
            ftp_port=:fp, ftp_username=:fu, ftp_password=:fpw, ftp_remote_path=:frp,
            ftp_prefix=:fpfx, poll_interval=:pi, serial_port=:sp, serial_baudrate=:sb,
            serial_bytesize=:sbs, serial_parity=:spar, serial_stopbits=:ssb,
            server_active=:sact, server_device_type=:sdt, server_name=:snm,
            server_send_interval=:ssi, server_start_time=:sst, server_base_folder=:sbf,
            server_time_folder=:stf, server_file_suffix=:ssf,
            modbus_tcp_enabled=:mte, modbus_tcp_port=:mtp, modbus_tcp_bind=:mtb,
            modbus_tcp_unit_id=:mtui, rest_api_enabled=:rae, rest_api_port=:rap,
            rest_api_bind=:rab, rest_api_token=:rat, config_revision=:cr, ui_locale=:ul
            WHERE id=:id)");
        q.bindValue(":id", c.id);
    }

    q.bindValue(":sc",   c.stationCode);
    q.bindValue(":sn",   c.stationName);
    q.bindValue(":tf",   c.timeFormat);
    q.bindValue(":df",   c.dateFormat);
    q.bindValue(":tz",   c.timezone);
    q.bindValue(":ast",  c.autoSyncTime ? 1 : 0);
    q.bindValue(":be",   c.buzzerEnable ? 1 : 0);
    q.bindValue(":fa",   c.ftpAddress);
    q.bindValue(":fp",   c.ftpPort);
    q.bindValue(":fu",   c.ftpUsername);
    q.bindValue(":fpw",  c.ftpPassword);
    q.bindValue(":frp",  c.ftpRemotePath);
    q.bindValue(":fpfx", c.ftpPrefix);
    q.bindValue(":pi",   c.pollInterval);
    q.bindValue(":sp",   c.serialPort);
    q.bindValue(":sb",   c.serialBaudrate);
    q.bindValue(":sbs",  c.serialBytesize);
    q.bindValue(":spar", c.serialParity);
    q.bindValue(":ssb",  c.serialStopbits);
    q.bindValue(":sact", c.serverActive ? 1 : 0);
    q.bindValue(":sdt",  c.serverDeviceType);
    q.bindValue(":snm",  c.serverName);
    q.bindValue(":ssi",  c.serverSendInterval);
    q.bindValue(":sst",  c.serverStartTime);
    q.bindValue(":sbf",  c.serverBaseFolder);
    q.bindValue(":stf",  c.serverTimeFolder);
    q.bindValue(":ssf",  c.serverFileSuffix);
    q.bindValue(":mte",  c.modbusTcpEnabled ? 1 : 0);
    q.bindValue(":mtp",  c.modbusTcpPort);
    q.bindValue(":mtb",  c.modbusTcpBind);
    q.bindValue(":mtui", c.modbusTcpUnitId);
    q.bindValue(":rae",  c.restApiEnabled ? 1 : 0);
    q.bindValue(":rap",  c.restApiPort);
    q.bindValue(":rab",  c.restApiBind);
    q.bindValue(":rat",  c.restApiToken);
    q.bindValue(":cr",   c.configRevision);
    q.bindValue(":ul",   c.uiLocale);

    if (!q.exec()) {
        qWarning() << "AppConfigDao::save error:" << q.lastError().text();
        return false;
    }
    return true;
}

int AppConfigDao::bumpRevision() {
    QSqlQuery q(m_db);
    q.exec("UPDATE app_config SET config_revision = config_revision + 1");
    q.exec("SELECT config_revision FROM app_config LIMIT 1");
    if (q.next()) return q.value(0).toInt();
    return 1;
}

QString AppConfigDao::generateAndSaveToken() {
    QString token = QUuid::createUuid().toString(QUuid::WithoutBraces).remove('-');
    QSqlQuery q(m_db);
    q.prepare("UPDATE app_config SET rest_api_token = :t");
    q.bindValue(":t", token);
    q.exec();
    return token;
}
