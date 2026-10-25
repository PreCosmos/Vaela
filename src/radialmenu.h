// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QVariantList>
#include <KSharedConfig>

class RadialMenu : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QVariantList applications READ applications NOTIFY applicationsChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
public:
    explicit RadialMenu(KSharedConfig::Ptr config, QObject *parent = nullptr);
    QVariantList entries() const { return m_entries; }
    QVariantList applications() const { return m_applications; }
    QString error() const { return m_error; }
    Q_INVOKABLE void refreshApplications();
    Q_INVOKABLE bool addApplication(const QString &desktopId);
    Q_INVOKABLE bool addCommand(const QString &label, const QString &command, const QString &icon, bool terminal = false);
    Q_INVOKABLE bool update(const QString &id, const QString &label, const QString &icon, const QString &command, bool terminal);
    Q_INVOKABLE bool remove(const QString &id);
    Q_INVOKABLE void move(const QString &id, int direction);
    Q_INVOKABLE void launch(const QString &id);
    Q_INVOKABLE void clearError();
Q_SIGNALS:
    void entriesChanged();
    void applicationsChanged();
    void errorChanged();
    void launchFailed();
private:
    KSharedConfig::Ptr m_config;
    QVariantList m_entries, m_applications;
    QString m_error;
    bool fail(const QString &message);
    bool save(const QVariantList &entries);
    QString importIcon(const QString &icon);
    int indexOf(const QString &id) const;
};
