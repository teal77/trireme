/*
 * Trireme for Deluge - A Deluge thin client for Android.
 * Copyright (C) 2018  Aashrava Holla
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:charts_flutter/flutter.dart';

import 'package:trireme/common/bytesize.dart';
import 'package:trireme/common/common.dart';

class NetworkSpeedGraph extends StatelessWidget {
  final Stream<NetworkSpeedData> speeds;

  NetworkSpeedGraph(this.speeds);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkSpeedData>(
        stream: speeds,
        builder: (context, snapshot) {
          return Container(
            height: 200.0,
            child: snapshot.hasData
                ? _NetworkSpeedGraph(snapshot.data)
                : Container(),
          );
        });
  }
}

class _NetworkSpeedGraph extends StatelessWidget {
  static const graphGranularity = 5000;
  final NetworkSpeedData speedData;

  _NetworkSpeedGraph(this.speedData);

  @override
  Widget build(BuildContext context) {
    return LineChart(
      getChartData(),
      animate: false,
      domainAxis: NumericAxisSpec(
        renderSpec: NoneRenderSpec(),
      ),
      primaryMeasureAxis: NumericAxisSpec(
          tickProviderSpec:
              StaticNumericTickProviderSpec(getSpeedLabels(context)),
          viewport: NumericExtents(getGraphLowerBound().toDouble(),
              getGraphUpperBound().toDouble())),
      defaultRenderer: LineRendererConfig(stacked: false, includeArea: true),
      behaviors: [
        SeriesLegend(
            position: BehaviorPosition.bottom,
            outsideJustification: OutsideJustification.start)
      ],
      defaultInteractions: false,
    );
  }

  List<Series<int, int>> getChartData() {
    return [
      Series<int, int>(
        id: speedData.speedLabel,
        data: speedData.speeds,
        domainFn: (_, index) => index,
        measureFn: (value, _) => value,
      ),
      Series<int, int>(
        id: speedData.protocolSpeedLabel,
        data: speedData.protocolSpeeds,
        domainFn: (_, index) => index,
        measureFn: (value, _) => value,
      )
    ];
  }

  List<TickSpec<int>> getSpeedLabels(BuildContext context) {
    var graphLowerBound = getGraphLowerBound();
    var graphUpperBound = getGraphUpperBound();
    return [
      TickSpec<int>(graphLowerBound,
          label: getSpeedString(context, graphLowerBound)),
      TickSpec<int>(graphUpperBound,
          label: getSpeedString(context, graphUpperBound)),
    ];
  }

  int getGraphLowerBound() {
    return 0;
  }

  int getGraphUpperBound() {
    var allSpeeds =
        [speedData.speeds, speedData.protocolSpeeds].expand((l) => l);
    var maxSpeed = allSpeeds.reduce(max);
    var graphUpperBound =
        maxSpeed + (graphGranularity - (maxSpeed % graphGranularity));
    return graphUpperBound;
  }

  String getSpeedString(BuildContext context, int speed) {
    var formatter =
        ByteSizeFormatter.of(PreferenceProvider.of(context).byteSizeStyle);
    return formatter.format(speed);
  }
}

class NetworkSpeedData {
  final List<int> speeds;
  final List<int> protocolSpeeds;
  final String speedLabel;
  final String protocolSpeedLabel;

  NetworkSpeedData(this.speeds, this.protocolSpeeds, this.speedLabel,
      this.protocolSpeedLabel);
}
