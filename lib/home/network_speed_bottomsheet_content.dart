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

import 'package:flutter/material.dart';

import 'package:kilobyte/kilobyte.dart' as kb;

import 'package:trireme_client/deserialization.dart';
import 'package:trireme_client/events.dart';

import 'package:trireme/common/common.dart';

import 'network_speed_graph.dart';

class NetworkSpeedBottomSheet extends StatelessWidget {
  final bool isDownload;
  final TriremeRepository repository;

  NetworkSpeedBottomSheet(this.isDownload, this.repository);

  @override
  Widget build(BuildContext context) {
    Stream<NetworkSpeedData> dataStream =
        repository.getSessionStatusHistory().map((l) => getSpeedData(l));

    var title = isDownload
        ? Strings.homeDownloadSpeedTitle
        : Strings.homeUploadSpeedTitle;

    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          _NetworkSpeed(title, dataStream),
          SpeedLimitSetter(isDownload, repository),
        ],
      ),
    );
  }

  NetworkSpeedData getSpeedData(List<SessionStatus> statusHistory) {
    List<int> getSpeeds() {
      if (isDownload) {
        return statusHistory
            .map((s) => s == null ? 0 : s.payloadDownloadRate.toInt())
            .toList();
      } else {
        return statusHistory
            .map((s) => s == null ? 0 : s.payloadUploadRate.toInt())
            .toList();
      }
    }

    List<int> getProtocolSpeeds() {
      if (isDownload) {
        return statusHistory
            .map((s) => s == null
                ? 0
                : s.totalDownloadRate.toInt() - s.payloadDownloadRate.toInt())
            .toList();
      } else {
        return statusHistory
            .map((s) => s == null
                ? 0
                : s.totalUploadRate.toInt() - s.payloadUploadRate.toInt())
            .toList();
      }
    }

    return NetworkSpeedData(getSpeeds(), getProtocolSpeeds(),
        Strings.homePayloadSpeedLabel, Strings.homeProtocolSpeedLabel);
  }
}

class _NetworkSpeed extends StatelessWidget {
  final String title;
  final Stream<NetworkSpeedData> dataStream;

  _NetworkSpeed(this.title, this.dataStream);

  @override
  Widget build(BuildContext context) {
    var currentSpeed =
        dataStream.map((n) => "${getByteSizeString(n.speeds.last)}/s");
    var currentProtocolSpeed =
        dataStream.map((n) => "${getByteSizeString(n.protocolSpeeds.last)}/s");

    return Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0),
            ),
            NetworkSpeedGraph(dataStream),
            Align(
              child: StreamBuilder<String>(
                stream: currentSpeed,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.hasData ? snapshot.data : "0",
                    style: const TextStyle(fontSize: 24.0),
                  );
                },
              ),
            ),
            Align(
              child: StreamBuilder<String>(
                stream: currentProtocolSpeed,
                builder: (context, snapshot) {
                  return Text(snapshot.hasData ? snapshot.data : "0");
                },
              ),
            ),
          ],
        ));
  }
}

class SpeedLimitSetter extends StatefulWidget {
  final bool isForDownloadSpeed;
  final TriremeRepository repository;

  SpeedLimitSetter(this.isForDownloadSpeed, this.repository);

  @override
  _SpeedLimitSliderState createState() => _SpeedLimitSliderState();
}

class _SpeedLimitSliderState extends State<SpeedLimitSetter> {
  static const keyDownloadSpeedLimit = "max_download_speed";
  static const keyUploadSpeedLimit = "max_upload_speed";

  SpeedLimitStep currentSpeedLimitSetting;
  String speedLimitLabel = "";
  StreamSubscription<DelugeRpcEvent> eventsStreamSubscription;

  @override
  void initState() {
    super.initState();
    eventsStreamSubscription = widget.repository
        .getDelugeRpcEvents()
        .where((e) => e is ConfigValueChangedEvent)
        .map((e) => e as ConfigValueChangedEvent)
        .where((e) =>
            e.key == keyDownloadSpeedLimit || e.key == keyUploadSpeedLimit)
        .listen((e) {
          setUiStateForSpeedSetting((e.value as num).toInt());
    });
    currentSpeedLimitSetting = speedLimitSteps.last;
    initStateAsync();
  }

  void initStateAsync() async {
    var currentSetting = widget.isForDownloadSpeed
        ? await widget.repository.getDownloadSpeedLimit()
        : await widget.repository.getUploadSpeedLimit();
    setUiStateForSpeedSetting(currentSetting);
  }

  void setUiStateForSpeedSetting(int setting) {
    var currentStep = getNearestSpeedStep(setting);
    var currentSpeed = currentStep.isUnlimited()
        ? currentStep.label
        : "${kb.Size(kilobytes: setting)}/s";
    setState(() {
      currentSpeedLimitSetting = currentStep;
      speedLimitLabel = currentSpeed;
    });
  }

  SpeedLimitStep getNearestSpeedStep(int currentSetting) {
    if (currentSetting == -1) return speedLimitSteps.last;
    var s = speedLimitSteps.first;
    for (var step in speedLimitSteps.skip(1)) {
      if (step.value == -1) break;
      if (currentSetting >= step.value) {
        s = step;
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            Strings.homeSpeedLimitTitle,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0),
          ),
          Container(
            height: 16.0,
          ),
          Row(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: Slider(
                  value: speedLimitSteps
                      .indexOf(currentSpeedLimitSetting)
                      .toDouble(),
                  onChanged: (d) {
                    setState(() {
                      currentSpeedLimitSetting = speedLimitSteps[d.toInt()];
                      speedLimitLabel = speedLimitSteps[d.toInt()].label;
                    });
                    setSpeedLimit(currentSpeedLimitSetting);
                  },
                  min: 0.0,
                  max: (speedLimitSteps.length - 1).toDouble(),
                  divisions: speedLimitSteps.length - 1,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  speedLimitLabel,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void setSpeedLimit(SpeedLimitStep speedLimit) {
    if (widget.isForDownloadSpeed) {
      widget.repository.setDownloadSpeedLimit(speedLimit.value);
    } else {
      widget.repository.setUploadSpeedLimit(speedLimit.value);
    }
  }

  @override
  void dispose() {
    eventsStreamSubscription.cancel();
    super.dispose();
  }
}

class SpeedLimitStep {
  final String label;
  final int value;

  const SpeedLimitStep(this.label, this.value);

  bool isUnlimited() => value == -1;
}

const speedLimitSteps = [
  SpeedLimitStep("5kB/s", 5),
  SpeedLimitStep("10kB/s", 10),
  SpeedLimitStep("30kB/s", 30),
  SpeedLimitStep("80kB/s", 80),
  SpeedLimitStep("300kB/s", 300),
  SpeedLimitStep("Unlimited", -1),
];
