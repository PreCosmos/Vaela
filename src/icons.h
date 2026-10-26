// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QQuickImageProvider>
#include <QIcon>
#include <QPainter>
#include <QUrl>
#include <QStandardPaths>
#include <QDir>
class MenuIcons : public QQuickImageProvider {
    // Symbolic icons use one colour throughout; full-colour icons must keep their colours.
    static bool monochrome(const QImage &image) {
        QColor first;
        for(int y=0;y<image.height();++y) for(int x=0;x<image.width();++x) {
            const QColor c=image.pixelColor(x,y);
            if(c.alpha()<64) continue;
            if(!first.isValid()) {first=c;continue;}
            if(std::abs(c.red()-first.red())>48 || std::abs(c.green()-first.green())>48 || std::abs(c.blue()-first.blue())>48) return false;
        }
        return true;
    }
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
        // "tint/#rrggbb/name" draws a monochrome icon in one colour, for the shell's own controls.
        QColor tint;
        if(name.startsWith("tint/")) {
            const auto parts=name.split('/');
            if(parts.size()>=3) {tint=QColor(parts[1]);name=parts.mid(2).join('/');}
        }
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
        if(tint.isValid() && monochrome(pixmap.toImage())) {
            QPainter painter(&pixmap);painter.setCompositionMode(QPainter::CompositionMode_SourceIn);painter.fillRect(pixmap.rect(),tint);
        }
        *size=pixmap.size();return pixmap;
    }
};
