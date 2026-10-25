// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QVector>
#include <algorithm>
#include <numeric>
namespace Layout {
inline QVector<double> sizes(QVector<double> weights, int count, double total) {
    if(weights.size()!=count) weights=QVector<double>(count,1.);
    const auto sum=std::accumulate(weights.begin(),weights.end(),0.);
    for(auto &w:weights) w=total*w/sum;
    return weights;
}
// Keep the resized track at its requested size; share the remaining space proportionally.
inline QVector<double> resize(QVector<double> tracks,int index,double requested,double minimum) {
    if(tracks.size()<2 || index<0 || index>=tracks.size()) return tracks;
    double total=std::accumulate(tracks.begin(),tracks.end(),0.);
    minimum=std::min(minimum,total/tracks.size());
    requested=std::clamp(requested,minimum,total-minimum*(tracks.size()-1));
    double remaining=total-requested, others=total-tracks[index];
    // Distribute a minimum first, then share the surplus by the old sizes.
    for(int i=0;i<tracks.size();++i) if(i!=index) tracks[i]=minimum+(remaining-minimum*(tracks.size()-1))*tracks[i]/others;
    tracks[index]=requested;
    return tracks;
}
}
