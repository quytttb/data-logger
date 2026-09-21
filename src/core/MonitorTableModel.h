#pragma once
#include <QAbstractItemModel>
#include <QAbstractTableModel>
#include <QHash>
#include <QList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

// AppTableView bridge cho MonitorModel (QAbstractListModel).
// Dựng 4 cột: Sensor | Value | Unit | Status — cùng colWeights/header với
// các bảng Sensors/Attach/History nên header/cell luôn thẳng hàng (1 nguồn
// colWidths từ AppTheme.distributeColumnWidths, không custom ListView nữa).
//
// Lọc DI/DO khi showDigitalIO=false (thay cho visible binding trong delegate
// cũ). Rebuild snapshot mỗi khi source đổi (reset semantics — chỉ vài dòng).
class MonitorTableModel : public QAbstractTableModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QAbstractItemModel* sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged)
    Q_PROPERTY(bool showDigitalIO READ showDigitalIO WRITE setShowDigitalIO NOTIFY showDigitalIOChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Col { ColSensor = 0, ColValue, ColUnit, ColStatus, ColCount };
    enum Roles {
        DisplayNameRole = Qt::UserRole + 1,
        ValueRole,
        UnitRole,
        SensorTypeRole,
        IsAlarmRole,
        AlarmTypeRole,
        DiStatesRole,
    };

    explicit MonitorTableModel(QObject *parent = nullptr);

    QAbstractItemModel *sourceModel() const { return m_source; }
    void setSourceModel(QAbstractItemModel *source);
    bool showDigitalIO() const { return m_showDigitalIO; }
    void setShowDigitalIO(bool v);

    int rowCount(const QModelIndex &parent = {}) const override;
    int columnCount(const QModelIndex &parent = {}) const override { Q_UNUSED(parent) return ColCount; }
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation,
                        int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void sourceModelChanged();
    void showDigitalIOChanged();
    void countChanged();

private slots:
    void rebuild();

private:
    QAbstractItemModel *m_source = nullptr;
    bool m_showDigitalIO = true;
    QList<QVariantMap> m_rows; // displayName/value/unit/sensorType/isAlarm/alarmType/diStates
};
