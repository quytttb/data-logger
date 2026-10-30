#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

#include "utils/qml/QmlSingleton.h"

// Tra cứu audit_log cho màn Settings > Audit (chỉ người có quyền ViewAudit).
//
// Chỉ đọc: mọi thao tác ghi audit nằm trong transaction của nghiệp vụ tương ứng
// (SensorListModel, SettingsController, AuthService). Controller này không mở
// transaction và không bao giờ trả về secret — detail_json do nơi ghi quyết
// định theo whitelist.
class AuditController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList entries READ entries NOTIFY changed)
    Q_PROPERTY(int total READ total NOTIFY changed)
    Q_PROPERTY(int page READ page NOTIFY changed)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY changed)
    Q_PROPERTY(int pageSize READ pageSize CONSTANT)
    Q_PROPERTY(QString actionFilter READ actionFilter NOTIFY filtersChanged)
    Q_PROPERTY(QString entityFilter READ entityFilter NOTIFY filtersChanged)
    Q_PROPERTY(QString resultFilter READ resultFilter NOTIFY filtersChanged)
    Q_PROPERTY(int daysFilter READ daysFilter NOTIFY filtersChanged)

public:
    explicit AuditController(QObject *parent = nullptr);

    DECLARE_QML_SINGLETON(AuditController)

    QVariantList entries() const { return m_entries; }
    int total() const { return m_total; }
    int page() const { return m_page; }
    int pageCount() const;
    int pageSize() const { return kPageSize; }
    QString actionFilter() const { return m_action; }
    QString entityFilter() const { return m_entity; }
    QString resultFilter() const { return m_result; }
    int daysFilter() const { return m_days; }

    // Lọc theo tiền tố action ("sensor."), entity, result ("ok"/"denied"/
    // "failed", rỗng = tất cả) và số ngày gần nhất (0 = tất cả).
    Q_INVOKABLE void setFilters(const QString &action, const QString &entity,
                                const QString &result, int days);
    Q_INVOKABLE void setPage(int page);
    Q_INVOKABLE void nextPage();
    Q_INVOKABLE void previousPage();
    Q_INVOKABLE void refresh();

    Q_INVOKABLE QStringList actionOptions() const;
    Q_INVOKABLE QStringList entityOptions() const;

signals:
    void changed();
    void filtersChanged();

private:
    bool allowed() const;
    void reload();

    static constexpr int kPageSize = 50;

    QVariantList m_entries;
    int m_total = 0;
    int m_page = 0;
    QString m_action;
    QString m_entity;
    QString m_result;
    int m_days = 0;
};
