// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QQuickImageProvider>
#include <QIcon>
#include <QPainter>
#include <QUrl>
#include <QStandardPaths>
#include <QDir>
class MenuIcons : public QQuickImageProvider {
public:
    MenuIcons() : QQuickImageProvider(QQuickImageProvider::Pixmap) {
        if(QIcon::themeName().isEmpty()) QIcon::setThemeName("breeze");
        QIcon::setFallbackThemeName("breeze");
        auto paths=QIcon::themeSearchPaths();
        for(const auto &directory:QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)) {
            auto path=directory+"/icons";if(!paths.contains(path)) paths.append(path);
        }
        auto legacy=QDir::homePath()+"/.icons";if(!paths.contains(legacy)) paths.append(legacy);
        QIcon::setThemeSearchPaths(paths);
    }
    QPixmap requestPixmap(const QString &id,QSize *size,const QSize &requested) override {
        auto name=QUrl::fromPercentEncoding(id.toUtf8());
        QIcon icon=name.startsWith('/')?QIcon(name):QIcon::fromTheme(name);
        if(icon.isNull()) icon=QIcon::fromTheme("application-x-executable");
        auto dimensions=requested.isValid()?requested:QSize(48,48);
        QPixmap pixmap=icon.pixmap(dimensions);
        if(pixmap.isNull()) {
            pixmap=QPixmap(dimensions);pixmap.fill(Qt::transparent);
            QPainter painter(&pixmap);painter.setRenderHint(QPainter::Antialiasing);
            painter.setBrush(QColor("#d58b66"));painter.setPen(Qt::NoPen);painter.drawRoundedRect(pixmap.rect().adjusted(2,2,-2,-2),8,8);
            painter.setPen(Qt::white);painter.drawText(pixmap.rect(),Qt::AlignCenter,">_");
        }
        *size=pixmap.size();return pixmap;
    }
};
