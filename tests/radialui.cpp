// SPDX-License-Identifier: GPL-2.0-or-later
#include "radialmenu.h"
#include "icons.h"
#include <QtTest>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlComponent>
#include <QQuickWindow>
#include <QQuickItem>
#include <QTemporaryDir>
class RadialUiTest : public QObject {
    Q_OBJECT
    QTemporaryDir directory;
    std::unique_ptr<RadialMenu> menu;
    std::unique_ptr<QQmlEngine> engine;
    std::unique_ptr<QQuickWindow> window;
    QQuickItem *editor=nullptr;
    QQuickItem *visual(QQuickItem *root,const QString &name) {
        if(root->objectName()==name) return root;
        for(auto item:root->childItems()) if(auto found=visual(item,name)) return found;
        return nullptr;
    }
    QQuickItem *find(const char *name) {return visual(editor,QString::fromUtf8(name));}
    void click(QQuickItem *item) {
        QVERIFY(item);QVERIFY(item->isVisible());QTest::qWait(50);
        QTest::mouseClick(window.get(),Qt::LeftButton,Qt::NoModifier,item->mapToScene(QPointF(item->width()/2,item->height()/2)).toPoint());
    }
private Q_SLOTS:
    void initTestCase() {
        menu=std::make_unique<RadialMenu>(KSharedConfig::openConfig(directory.filePath("velarc"),KConfig::SimpleConfig));
        engine=std::make_unique<QQmlEngine>();engine->rootContext()->setContextProperty("radial",menu.get());engine->addImageProvider("menuicons",new MenuIcons);
        QQmlComponent component(engine.get(),QUrl::fromLocalFile(QStringLiteral(RADIAL_EDITOR_PATH)));
        QVERIFY2(component.isReady(),qPrintable(component.errorString()));
        QVERIFY(!QIcon::fromTheme("utilities-terminal").isNull());
        editor=qobject_cast<QQuickItem*>(component.create());QVERIFY(editor);
        window=std::make_unique<QQuickWindow>();window->resize(580,640);window->setColor(QColor("#242630"));
        editor->setParentItem(window->contentItem());editor->setSize(QSizeF(580,640));window->show();
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));
    }
    void addCommandThroughEditor() {
        click(find("addCommand"));QCOMPARE(editor->property("page").toString(),QString("command"));
        find("entryName")->setProperty("text","My launcher");find("command")->setProperty("text","printf hello");
        click(find("saveEntry"));QCOMPARE(menu->entries().size(),9);QCOMPARE(editor->property("page").toString(),QString("menu"));
        QCOMPARE(menu->entries().last().toMap()["label"].toString(),QString("My launcher"));
    }
    void applicationPicker() {
        click(find("addApplication"));QCOMPARE(editor->property("page").toString(),QString("apps"));
        QVERIFY(!menu->applications().isEmpty());
        auto id=menu->applications().first().toMap()["id"].toString();
        QTRY_VERIFY(visual(editor,"app-"+id));
        click(visual(editor,"app-"+id));
        QTRY_COMPARE(menu->entries().size(),10);QCOMPARE(editor->property("page").toString(),QString("menu"));
    }
    void renderedImagesAndPreview() {
        QTest::qWait(150);
        auto image=window->grabWindow();QVERIFY(!image.isNull());
        QVERIFY(image.save(QStringLiteral(RADIAL_PREVIEW_PATH)));
    }
    void cleanupTestCase() {window.reset();engine.reset();menu.reset();}
};
int main(int argc,char **argv) {
    qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");
    QGuiApplication app(argc,argv);app.setApplicationName("vela-radial-ui-test");
    RadialUiTest test;return QTest::qExec(&test,argc,argv);
}
#include "radialui.moc"
