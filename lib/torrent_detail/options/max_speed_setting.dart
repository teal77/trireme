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

import 'package:flutter/material.dart';

import 'package:kilobyte/kilobyte.dart' as kb;

import 'package:trireme/common/common.dart';

class MaxSpeedSettingScreen extends StatelessWidget {
  final String torrentId;
  final int currentMaxSpeed;
  final bool isDownloadSpeed;

  MaxSpeedSettingScreen(
      this.torrentId, this.currentMaxSpeed, this.isDownloadSpeed);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isDownloadSpeed
            ? Strings.detailMaxDownloadSpeedTitle
            : Strings.detailMaxUploadSpeedTitle),
      ),
      body: LoadingContainer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _MaxSpeedSetting(
            torrentId: torrentId,
            currentMaxSpeed: currentMaxSpeed,
            isDownloadSpeed: isDownloadSpeed,
          ),
        ),
      ),
    );
  }
}

class _MaxSpeedSetting extends StatefulWidget {
  final String torrentId;
  final int currentMaxSpeed;
  final bool isDownloadSpeed;

  _MaxSpeedSetting(
      {Key key, this.torrentId, this.currentMaxSpeed, this.isDownloadSpeed})
      : super(key: key);

  @override
  State createState() {
    return _MaxSpeedSettingState();
  }
}

class _MaxSpeedSettingState extends State<_MaxSpeedSetting>
    with TriremeProgressBarMixin {
  SpeedUnit userSelectedUnit;

  TextEditingController textEditingController;
  TriremeRepository repository;

  @override
  void initState() {
    super.initState();
    int currentSpeed = widget.currentMaxSpeed;
    SpeedUnit currentSpeedUnit = SpeedUnit.kbps;
    if (currentSpeed > 0) {
      var kbSize = kb.Size(kilobytes: currentSpeed);
      if (kbSize.inMegabytes > 1) {
        currentSpeed = kbSize.inMegabytes.toInt();
        currentSpeedUnit = SpeedUnit.mbps;
      } else {
        currentSpeedUnit = SpeedUnit.kbps;
      }
    }
    userSelectedUnit = currentSpeedUnit;
    textEditingController = TextEditingController(text: currentSpeed.toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                keyboardType: new TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                controller: textEditingController,
              ),
            ),
            DropdownButton<SpeedUnit>(
              items: [
                DropdownMenuItem<SpeedUnit>(
                  value: SpeedUnit.kbps,
                  child: Text(Strings.detailOptionKbpsLabel),
                ),
                DropdownMenuItem<SpeedUnit>(
                  value: SpeedUnit.mbps,
                  child: Text(Strings.detailOptionMbpsLabel),
                ),
              ],
              value: userSelectedUnit,
              onChanged: (v) {
                setState(() {
                  userSelectedUnit = v;
                });
              },
            ),
          ],
        ),
        Container(
          height: 48.0,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            OutlineButton(
              onPressed: resetSpeed,
              child: Text(Strings.detailOptionsResetLabel),
            ),
            Container(
              width: 16.0,
            ),
            RaisedButton(
              onPressed: setSelectedSpeed,
              child: Text(Strings.strOk),
            )
          ],
        )
      ],
    );
  }

  int getSpeed() {
    int userEnteredSpeed;
    try {
      if (textEditingController.text.isNotEmpty) {
        userEnteredSpeed = int.parse(textEditingController.text);
      }
    } on FormatException {
      //nop
    }

    if (userEnteredSpeed == null) return null;

    if (userEnteredSpeed < 0) return -1;

    var speedMultipliers = {
      SpeedUnit.kbps: 1,
      SpeedUnit.mbps: 1000,
    };
    var speedInKbps = speedMultipliers[userSelectedUnit] * userEnteredSpeed;
    return speedInKbps;
  }

  void resetSpeed() {
    setSpeed(-1);
  }

  void setSelectedSpeed() {
    int newSpeed = getSpeed();
    if (newSpeed != null) {
      setSpeed(newSpeed);
    }
  }

  void setSpeed(int newSpeed) async {
    showProgressBar();
    try {
      if (widget.isDownloadSpeed) {
        await repository.setTorrentMaxDownloadSpeed(widget.torrentId, newSpeed);
      } else {
        await repository.setTorrentMaxUploadSpeed(widget.torrentId, newSpeed);
      }
      Navigator.pop(context);
    } catch (e) {
      showErrorSnackbar(e);
    } finally {
      hideProgressBar();
    }
  }

  void showErrorSnackbar(Object error) {
    Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(prettifyError(error)),
        ));
  }
}

enum SpeedUnit { kbps, mbps, }
