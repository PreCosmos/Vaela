// SPDX-License-Identifier: GPL-2.0-or-later
#include "background.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QFileInfo>
#include <QJsonDocument>
#include <QMimeDatabase>
#include <algorithm>

static const QString controller = QStringLiteral("org.vaela.Controller");

VaelaBackground::VaelaBackground(QObject *parent) : QObject(parent) {
    auto bus=QDBusConnection::sessionBus();
    bus.connect(controller,"/Controller",controller,"backgroundsChanged",this,SLOT(apply(QString)));
    // KWin's plugin may start after plasmashell, or the session may not be Vaela's at all.
    auto watcher=new QDBusServiceWatcher(controller,bus,QDBusServiceWatcher::WatchForOwnerChange,this);
    connect(watcher,&QDBusServiceWatcher::serviceRegistered,this,&VaelaBackground::fetch);
    connect(watcher,&QDBusServiceWatcher::serviceUnregistered,this,[this]{apply({});});
    fetch();

    auto system=QDBusConnection::systemBus();
    system.connect("org.freedesktop.UPower","/org/freedesktop/UPower","org.freedesktop.DBus.Properties","PropertiesChanged",
                   this,SLOT(powerChanged(QString,QVariantMap,QStringList)));
    auto get=QDBusMessage::createMethodCall("org.freedesktop.UPower","/org/freedesktop/UPower","org.freedesktop.DBus.Properties","Get");
    get << QStringLiteral("org.freedesktop.UPower") << QStringLiteral("OnBattery");
    auto pending=new QDBusPendingCallWatcher(system.asyncCall(get),this);
    connect(pending,&QDBusPendingCallWatcher::finished,this,[this,pending]{
        QDBusPendingReply<QDBusVariant> reply=*pending;
        if(!reply.isError()) setOnBattery(reply.value().variant().toBool());
        pending->deleteLater();
    });
}

void VaelaBackground::fetch() {
    auto call=QDBusMessage::createMethodCall(controller,"/Controller",controller,"backgrounds");
    auto pending=new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(call),this);
    connect(pending,&QDBusPendingCallWatcher::finished,this,[this,pending]{
        QDBusPendingReply<QString> reply=*pending;
        apply(reply.isError() ? QString() : reply.value());
        pending->deleteLater();
    });
}

void VaelaBackground::apply(const QString &json) {
    const auto next=QJsonDocument::fromJson(json.toUtf8()).object();
    if(next!=m_data) {m_data=next;Q_EMIT changed();}
}

void VaelaBackground::powerChanged(const QString &interface, const QVariantMap &changed, const QStringList &) {
    if(interface=="org.freedesktop.UPower" && changed.contains("OnBattery")) setOnBattery(changed.value("OnBattery").toBool());
}

void VaelaBackground::setOnBattery(bool onBattery) {
    if(onBattery!=m_onBattery) {m_onBattery=onBattery;Q_EMIT changed();}
}

void VaelaBackground::setScreenName(const QString &name) {
    if(name!=m_screen) {m_screen=name;Q_EMIT changed();}
}

QJsonObject VaelaBackground::output() const {return m_data.value("outputs").toObject().value(m_screen).toObject();}

QUrl VaelaBackground::toUrl(const QString &text) {
    if(text.isEmpty()) return {};
    const QUrl url(text);
    return url.scheme().isEmpty() ? QUrl::fromLocalFile(text) : url;
}

QUrl VaelaBackground::source() const {return toUrl(output().value("source").toString());}

qreal VaelaBackground::volume() const {
    if(!output().value("audio").toBool() || m_data.value("muted").toBool(true)) return 0;
    return std::clamp(m_data.value("volume").toInt(50),0,100)/100.;
}

// Videos pause under the lock screen, on battery and behind windows as the settings ask, except that
// a video with its sound on keeps playing behind windows unless told otherwise.
bool VaelaBackground::playing() const {
    if(source().isEmpty() || m_data.value("locked").toBool()) return false;
    if(m_onBattery && m_data.value("pauseOnBattery").toBool(true)) return false;
    if(volume()>0 && m_data.value("keepAudible").toBool(true)) return true;
    if(output().value("occluded").toBool() && m_data.value("pauseCovered").toBool(true)) return false;
    return !(output().value("windows").toBool() && m_data.value("pauseWindows").toBool(false));
}

QString VaelaBackground::fill() const {
    const auto fill=m_data.value("fill").toString();
    return fill=="fit" || fill=="stretch" ? fill : QStringLiteral("fill");
}
qreal VaelaBackground::speed() const {return std::clamp(m_data.value("speed").toInt(100),25,200)/100.;}
qreal VaelaBackground::dim() const {return std::clamp(m_data.value("dim").toInt(0),0,80)/100.;}
qreal VaelaBackground::blur() const {return std::clamp(m_data.value("blur").toInt(0),0,100)/100.;}
int VaelaBackground::transition() const {return std::clamp(m_data.value("transition").toInt(600),0,3000);}

QString VaelaBackground::kind(const QUrl &url) {
    if(url.isEmpty()) return {};
    static const QMimeDatabase mimes;
    const auto mime=url.isLocalFile() && QFileInfo::exists(url.toLocalFile()) ? mimes.mimeTypeForFile(url.toLocalFile()) : mimes.mimeTypeForUrl(url);
    if(mime.name().startsWith("video/") || mime.inherits("video/x-matroska")) return QStringLiteral("video");
    if(mime.name()=="image/gif" || mime.name()=="image/webp") return QStringLiteral("animated");
    return QStringLiteral("image");
}
