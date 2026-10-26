// SPDX-License-Identifier: GPL-2.0-or-later
#include "radialmenu.h"
#include <QtTest>
#include <KConfigGroup>
#include <QTemporaryDir>
#include <QImage>
#include <QFile>
class RadialMenuTest : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void persistenceAndEmptyMenu() {
        QTemporaryDir directory;
        auto config=KSharedConfig::openConfig(directory.filePath("vaelarc"),KConfig::SimpleConfig);
        RadialMenu menu(config);
        QCOMPARE(menu.entries().size(),8);
        QVERIFY(!menu.addCommand("", "true", "utilities-terminal"));
        QVERIFY(!menu.error().isEmpty());
        QVERIFY(!menu.addApplication("vaela-no-such-application.desktop"));
        QVERIFY(menu.addCommand("My command","printf 'hello world' | cat","utilities-terminal"));
        QCOMPARE(menu.entries().size(),9);
        auto entry=menu.entries().last().toMap();auto id=entry["id"].toString();
        QCOMPARE(entry["target"].toString(),QString("printf 'hello world' | cat"));
        menu.move(id,-1);QCOMPARE(menu.entries()[7].toMap()["id"].toString(),id);
        QVERIFY(menu.update(id,"Renamed","folder","echo changed",true));
        RadialMenu reloaded(config);
        QCOMPARE(reloaded.entries().size(),9);
        QCOMPARE(reloaded.entries()[7].toMap()["label"].toString(),QString("Renamed"));
        QVERIFY(reloaded.entries()[7].toMap()["terminal"].toBool());
        for(const auto &value:reloaded.entries()) QVERIFY(reloaded.remove(value.toMap()["id"].toString()));
        RadialMenu empty(config);QVERIFY(empty.entries().isEmpty());
    }
    void applicationMetadata() {
        QTemporaryDir directory;
        RadialMenu menu(KSharedConfig::openConfig(directory.filePath("vaelarc"),KConfig::SimpleConfig));
        menu.refreshApplications();QVERIFY(!menu.applications().isEmpty());
        auto app=menu.applications().first().toMap();
        QVERIFY(menu.addApplication(app["id"].toString()));
        auto entry=menu.entries().last().toMap();
        QCOMPARE(entry["type"].toString(),QString("application"));
        QCOMPARE(entry["label"],app["label"]);QCOMPARE(entry["icon"],app["icon"]);QCOMPARE(entry["target"],app["id"]);
    }
    void importedImageSurvivesSourceRemoval() {
        QTemporaryDir directory;
        auto config=KSharedConfig::openConfig(directory.filePath("vaelarc"),KConfig::SimpleConfig);
        RadialMenu menu(config);
        auto source=directory.filePath("icon.png");QImage image(32,32,QImage::Format_ARGB32);image.fill(Qt::red);QVERIFY(image.save(source));
        QVERIFY(menu.addCommand("Image test","true",source));
        auto icon=menu.entries().last().toMap()["icon"].toString();
        QVERIFY(icon!=source);QVERIFY(QFile::exists(icon));QVERIFY(QFile::remove(source));
        RadialMenu reloaded(config);QVERIFY(QFile::exists(reloaded.entries().last().toMap()["icon"].toString()));
        QVERIFY(!menu.addCommand("Bad image","true",directory.filePath("missing.png")));
        QCOMPARE(menu.entries().size(),9);
        QFile::remove(icon);
    }
    void commandLaunchPreservesShellSyntax() {
        QTemporaryDir directory;
        RadialMenu menu(KSharedConfig::openConfig(directory.filePath("vaelarc"),KConfig::SimpleConfig));
        QString marker=directory.filePath("result");
        QVERIFY(menu.addCommand("Write marker","printf '%s' 'hello world' | cat > '"+marker+"'","utilities-terminal"));
        menu.launch(menu.entries().last().toMap()["id"].toString());
        QTRY_VERIFY(QFile::exists(marker));
        QFile file(marker);QVERIFY(file.open(QIODevice::ReadOnly));QCOMPARE(file.readAll(),QByteArray("hello world"));
    }
    void malformedConfigurationIsNotOverwritten() {
        QTemporaryDir directory;
        auto config=KSharedConfig::openConfig(directory.filePath("vaelarc"),KConfig::SimpleConfig);
        KConfigGroup(config,"RadialMenu").writeEntry("Entries","broken json");config->sync();
        RadialMenu menu(config);QCOMPARE(menu.entries().size(),8);QVERIFY(!menu.error().isEmpty());
        QCOMPARE(KConfigGroup(config,"RadialMenu").readEntry("Entries",QString()),QString("broken json"));
    }
};
QTEST_GUILESS_MAIN(RadialMenuTest)
#include "radialmenu.moc"
