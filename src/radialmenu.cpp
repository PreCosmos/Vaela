// SPDX-License-Identifier: GPL-2.0-or-later
#include "radialmenu.h"
#include <KApplicationTrader>
#include <KConfigGroup>
#include <KService>
#include <KIO/ApplicationLauncherJob>
#include <QDir>
#include <QSet>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QStandardPaths>
#include <QUuid>
#include <QUrl>
#include <algorithm>

namespace {
QVariantList defaults() {
    QVariantList entries;
    const QList<QStringList> items={
        {"Terminal","terminal","utilities-terminal"}, {"Web","browser","internet-web-browser"},
        {"Files","files","system-file-manager"}, {"Layout","cycle-layout","view-grid"},
        {"Settings","settings","configure"}, {"Activities","activities","activities"},
        {"Screenshot","screenshot","spectacle"}, {"Commands","commands","system-search"}};
    for(const auto &item:items) entries.append(QVariantMap{{"id","builtin-"+item[1]},{"type","builtin"},{"label",item[0]},{"target",item[1]},{"icon",item[2]}});
    return entries;
}
bool valid(const QVariantMap &entry) {
    return !entry.value("id").toString().isEmpty() && !entry.value("label").toString().trimmed().isEmpty()
        && !entry.value("icon").toString().isEmpty() && !entry.value("target").toString().trimmed().isEmpty()
        && QStringList{"builtin","application","command"}.contains(entry.value("type").toString());
}
}
RadialMenu::RadialMenu(KSharedConfig::Ptr config,QObject *parent) : QObject(parent),m_config(config) {
    KConfigGroup group(m_config,"RadialMenu");
    if(!group.hasKey("Entries")) {m_entries=defaults();return;}
    QJsonParseError error;
    auto doc=QJsonDocument::fromJson(group.readEntry("Entries",QString()).toUtf8(),&error);
    if(error.error!=QJsonParseError::NoError || !doc.isArray()) {
        m_entries=defaults();fail("The saved radial menu could not be read. Default items are shown; your saved configuration has been kept.");return;
    }
    QSet<QString> ids;
    for(const auto &value:doc.array().toVariantList()) {
        auto entry=value.toMap();auto id=entry.value("id").toString();
        if(!valid(entry) || ids.contains(id)) {
            m_entries=defaults();fail("The saved radial menu contains an invalid item. Default items are shown; your saved configuration has been kept.");return;
        }
        ids.insert(id);m_entries.append(entry);
    }
}
bool RadialMenu::fail(const QString &message) {m_error=message;emit errorChanged();return false;}
void RadialMenu::clearError() {if(!m_error.isEmpty()){m_error.clear();emit errorChanged();}}
bool RadialMenu::save(const QVariantList &entries) {
    KConfigGroup(m_config,"RadialMenu").writeEntry("Entries",QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(entries)).toJson(QJsonDocument::Compact)));
    if(!m_config->sync()) return fail("Could not save the radial menu. Check that your configuration directory is writable.");
    m_entries=entries;clearError();emit entriesChanged();return true;
}
int RadialMenu::indexOf(const QString &id) const {
    for(int i=0;i<m_entries.size();++i) if(m_entries[i].toMap().value("id").toString()==id) return i;
    return -1;
}
QString RadialMenu::importIcon(const QString &value) {
    QString icon=value.trimmed();
    if(icon.isEmpty()) return "application-x-executable";
    if(icon.startsWith("file:")) icon=QUrl(icon).toLocalFile();
    if(!QFileInfo(icon).isAbsolute()) return icon;
    if(!QImageReader(icon).canRead()) {fail("Choose a readable PNG, JPEG, SVG or WebP image.");return {};}
    auto directory=QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)+"/radial-icons";
    if(QFileInfo(icon).absolutePath()==directory) return icon;
    QDir().mkpath(directory);
    QString destination=directory+"/"+QUuid::createUuid().toString(QUuid::WithoutBraces)+"."+QFileInfo(icon).suffix();
    if(!QFile::copy(icon,destination)) {fail("Could not copy the image into your Vela data directory.");return {};}
    return destination;
}
void RadialMenu::refreshApplications() {
    m_applications.clear();
    auto services=KApplicationTrader::query([](const KService::Ptr &service){return service->isApplication() && !service->noDisplay();});
    std::sort(services.begin(),services.end(),[](const auto &a,const auto &b){return QString::localeAwareCompare(a->name(),b->name())<0;});
    for(const auto &service:services) m_applications.append(QVariantMap{{"id",service->storageId()},{"label",service->name()},{"description",service->genericName()},{"icon",service->icon().isEmpty()?"application-x-executable":service->icon()}});
    emit applicationsChanged();
}
bool RadialMenu::addApplication(const QString &desktopId) {
    auto service=KService::serviceByStorageId(desktopId);
    if(!service || !service->isApplication() || service->noDisplay()) return fail("That application is no longer available. Refresh the application list and try again.");
    auto entries=m_entries;
    entries.append(QVariantMap{{"id",QUuid::createUuid().toString(QUuid::WithoutBraces)},{"type","application"},{"label",service->name()},{"target",service->storageId()},{"icon",service->icon().isEmpty()?"application-x-executable":service->icon()}});
    return save(entries);
}
bool RadialMenu::addCommand(const QString &name,const QString &command,const QString &image,bool terminal) {
    if(name.trimmed().isEmpty() || command.trimmed().isEmpty()) return fail("Enter a name and a command.");
    auto icon=importIcon(image);if(icon.isEmpty()) return false;
    auto entries=m_entries;
    entries.append(QVariantMap{{"id",QUuid::createUuid().toString(QUuid::WithoutBraces)},{"type","command"},{"label",name.trimmed()},{"target",command},{"icon",icon},{"terminal",terminal}});
    return save(entries);
}
bool RadialMenu::update(const QString &id,const QString &label,const QString &image,const QString &command,bool terminal) {
    int index=indexOf(id);if(index<0) return fail("That menu item no longer exists.");
    auto entry=m_entries[index].toMap();
    if(label.trimmed().isEmpty() || (entry["type"]=="command" && command.trimmed().isEmpty())) return fail("Enter a name and a command.");
    auto icon=importIcon(image);if(icon.isEmpty()) return false;
    entry["label"]=label.trimmed();entry["icon"]=icon;
    if(entry["type"]=="command") {entry["target"]=command;entry["terminal"]=terminal;}
    auto entries=m_entries;entries[index]=entry;return save(entries);
}
bool RadialMenu::remove(const QString &id) {
    int index=indexOf(id);if(index<0) return false;
    auto entries=m_entries;entries.removeAt(index);return save(entries);
}
void RadialMenu::move(const QString &id,int direction) {
    int index=indexOf(id),next=index+direction;
    if(index<0 || next<0 || next>=m_entries.size() || std::abs(direction)!=1) return;
    auto entries=m_entries;entries.swapItemsAt(index,next);save(entries);
}
void RadialMenu::launch(const QString &id) {
    int index=indexOf(id);if(index<0) {fail("That menu item no longer exists.");emit launchFailed();return;}
    auto entry=m_entries[index].toMap();
    if(entry["type"]=="application") {
        auto service=KService::serviceByStorageId(entry["target"].toString());
        if(!service) {fail("This application is no longer installed. Remove it or add it again from the application picker.");emit launchFailed();return;}
        auto job=new KIO::ApplicationLauncherJob(service,this);
        connect(job,&KJob::result,this,[this](KJob *job){if(job->error()){fail(job->errorString());emit launchFailed();}});
        job->start();
    } else if(entry["type"]=="command") {
        bool terminal=entry.value("terminal").toBool();
        QStringList args=terminal?QStringList{"-e","/bin/sh","-c",entry["target"].toString()}:QStringList{"-c",entry["target"].toString()};
        if(!QProcess::startDetached(terminal?"konsole":"/bin/sh",args,QDir::homePath())) {fail("The command could not be started.");emit launchFailed();}
    }
}
