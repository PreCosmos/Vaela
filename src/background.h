// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QJsonObject>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

// What the Vaela wallpaper shows on one monitor: the current workspace's background and how to
// play it, from the KWin plugin's org.vaela.Controller, plus whether the computer is on battery.
// Without a Vaela session, or on a monitor Vaela does not cover, source is empty.
class VaelaBackground : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString screenName READ screenName WRITE setScreenName NOTIFY changed)
    Q_PROPERTY(QUrl source READ source NOTIFY changed)
    // The workspace the options belong to, so a background fading out keeps its own.
    Q_PROPERTY(QString workspace READ workspace NOTIFY changed)
    Q_PROPERTY(bool playing READ playing NOTIFY changed)
    Q_PROPERTY(qreal volume READ volume NOTIFY changed)
    Q_PROPERTY(QString fill READ fill NOTIFY changed)
    Q_PROPERTY(qreal speed READ speed NOTIFY changed)
    Q_PROPERTY(qreal dim READ dim NOTIFY changed)
    Q_PROPERTY(qreal blur READ blur NOTIFY changed)
    Q_PROPERTY(int transition READ transition NOTIFY changed)
public:
    explicit VaelaBackground(QObject *parent = nullptr);
    QString screenName() const {return m_screen;}
    void setScreenName(const QString &name);
    QUrl source() const;
    QString workspace() const {return m_data.value("workspace").toString();}
    bool playing() const;
    qreal volume() const;
    QString fill() const;
    qreal speed() const;
    qreal dim() const;
    qreal blur() const;
    int transition() const;
    void setOnBattery(bool onBattery);
    // "video", "animated" (GIF or WebP, which may move) or "image".
    Q_INVOKABLE static QString kind(const QUrl &url);
    static QUrl toUrl(const QString &text);
public Q_SLOTS:
    void apply(const QString &json);
Q_SIGNALS:
    void changed();
private Q_SLOTS:
    void powerChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);
private:
    void fetch();
    QJsonObject output() const;
    QString m_screen;
    QJsonObject m_data;
    bool m_onBattery = false;
};
