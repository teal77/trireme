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
import 'package:trireme/torrent_detail/options/trackers/trackers_list.dart';

import 'package:trireme_client/deserialization.dart';

import 'package:trireme/common/bytesize.dart';
import 'package:trireme/common/common.dart';

import 'max_speed_setting.dart';
import 'torrent_options_controller.dart';

class TorrentOptionsPage extends StatefulWidget {
  final String torrentId;

  TorrentOptionsPage(this.torrentId);

  @override
  State createState() {
    return TorrentOptionsPageState();
  }
}

class TorrentOptionsPageState extends State<TorrentOptionsPage>
    with TriremeProgressBarMixin {
  late TriremeRepository repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: repository.getTorrentOptionsUpdates(widget.torrentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            hideProgressBar();

            if (snapshot.hasData) {
              return _TorrentOptionsContent(widget.torrentId, snapshot.data as TorrentOptions);
            } else if (snapshot.hasError) {
              return ErrorPage(snapshot.error!);
            }
          } else {
            showProgressBar();
          }
          return Container();
        });
  }
}

class _TorrentOptionsContent extends StatefulWidget {
  final String torrentId;
  final TorrentOptions torrentOptions;

  _TorrentOptionsContent(this.torrentId, this.torrentOptions);

  @override
  State createState() {
    return _TorrentsOptionsState();
  }
}

class _TorrentsOptionsState extends State<_TorrentOptionsContent>
    with TriremeProgressBarMixin {
  late TorrentOptions torrentOptions;
  TorrentOptionsController controller = TorrentOptionsController();
  late TriremeRepository repository;

  @override
  void initState() {
    super.initState();
    torrentOptions = widget.torrentOptions;
    controller.torrentOptions = torrentOptions;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  void didUpdateWidget(_TorrentOptionsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    torrentOptions = widget.torrentOptions;
    controller.torrentOptions = torrentOptions;
  }

  @override
  Widget build(BuildContext context) {
    var formatter =
        ByteSizeFormatter.of(PreferenceProvider.of(context).byteSizeStyle);
    return ListView(
      children: <Widget>[
        getSubHeader(Strings.detailBandwidthLabel),
        ListTile(
          title: Text(Strings.detailMaxDownloadSpeed),
          subtitle: Text(controller.getCurrentDownloadSpeedLimit(formatter)),
          onTap: () {
            Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (context) => MaxSpeedSettingScreen(
                        widget.torrentId,
                        torrentOptions.maxDownloadSpeed.toInt(),
                        true),
                    fullscreenDialog: true));
          },
        ),
        ListTile(
          title: Text(Strings.detailMaxUploadSpeed),
          subtitle: Text(controller.getCurrentUploadSpeedLimit(formatter)),
          onTap: () {
            Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (context) => MaxSpeedSettingScreen(
                        widget.torrentId,
                        torrentOptions.maxUploadSpeed.toInt(),
                        false),
                    fullscreenDialog: true));
          },
        ),
        ListTile(
          title: Text(Strings.detailMaxConnections),
          subtitle: Text(controller.getCurrentConnectionLimit()),
          onTap: () {
            showMaxConnectionDialog();
          },
        ),
        ListTile(
          title: Text(Strings.detailMaxUploadSlots),
          subtitle: Text(controller.getCurrentUploadSlotLimit()),
          onTap: () {
            showMaxUploadSlotsDialog();
          },
        ),
        getDivider(),
        getSubHeader(Strings.detailQueueLabel),
        SwitchListTile(
          title: Text(Strings.detailOptionsAutoManagedLabel),
          subtitle: Text(Strings.detailOptionsAutoManagedSubtitle),
          value: torrentOptions.isAutoManaged,
          onChanged: (value) {
            setState(() {
              torrentOptions.isAutoManaged = value;
            });
            setAutoManaged(value);
          },
        ),
        SwitchListTile(
          title: Text(Strings.detailOptionsStopAtRatio),
          value: torrentOptions.stopAtRatio,
          onChanged: (value) {
            setState(() {
              torrentOptions.stopAtRatio = value;
            });
            setStopAtRatio(value);
          },
        ),
        ListTile(
          title: Text(Strings.detailOptionsStopRatio),
          subtitle: Text(torrentOptions.stopRatio.toString()),
          enabled: torrentOptions.stopAtRatio,
          onTap: () {
            showStopRatioDialog();
          },
        ),
        SwitchListTile(
          title: Text(Strings.detailOptionsRemoveAtRatio),
          value: torrentOptions.removeAtRatio,
          onChanged: torrentOptions.stopAtRatio
              ? (value) {
                  setState(() {
                    torrentOptions.removeAtRatio = value;
                  });
                  setRemoveAtRatio(value);
                }
              : null,
        ),
        SwitchListTile(
          title: Text(Strings.detailOptionsMoveCompleted),
          value: torrentOptions.moveCompleted,
          onChanged: (value) {
            setState(() {
              torrentOptions.moveCompleted = value;
            });
            setMoveCompleted(value);
          },
        ),
        ListTile(
          title: Text(Strings.detailOptionsMoveCompletedPath),
          subtitle: Text(torrentOptions.moveCompletedPath),
          enabled: torrentOptions.moveCompleted,
          onTap: () {
            showMoveCompletedPathDialog();
          },
        ),
        getDivider(),
        getSubHeader(Strings.detailGeneralLabel),
        SwitchListTile(
          title: Text(Strings.detailOptionsPrioritiseFirstLast),
          value: torrentOptions.prioritizeFirstLast,
          onChanged: (value) {
            setState(() {
              torrentOptions.prioritizeFirstLast = value;
            });
            setPrioritizeFirstLast(value);
          },
        ),
        ListTile(
          title: Text(Strings.detailOptionsTrackers),
          subtitle: Text("${torrentOptions.trackers.length} trackers"),
          onTap: () => showTrackerListPage(),
        )
      ],
    );
  }

  Widget getSubHeader(String text) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
        child: Text(
          text,
          style: TextStyle(fontSize: 13.0, color: Theme.of(context).hintColor),
        ));
  }

  Widget getDivider() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        height: 1.0,
        color: Theme.of(context).dividerColor,
      ),
    );
  }

  void showErrorSnackbar(Object error) {
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(prettifyError(error)),
    ));
  }

  Future<String?> showPathInputDialog(String title) async {
    String? userInput;
    return showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (s) => userInput = s,
              ),
              actions: <Widget>[
                FlatButton(
                  child: Text(Strings.strOk),
                  onPressed: () {
                    Navigator.pop(context, userInput);
                  },
                )
              ],
            ));
  }

  Future<num?> showNumberInputDialog(String title) async {
    String? userInput;
    return await showDialog<num>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                keyboardType: TextInputType.number,
                onChanged: (s) => userInput = s,
              ),
              actions: <Widget>[
                FlatButton(
                  child: Text(Strings.detailOptionsResetLabel),
                  onPressed: () {
                    Navigator.pop(context, -1);
                  },
                ),
                FlatButton(
                  child: Text(Strings.strOk),
                  onPressed: () {
                    num? n;
                    try {
                      if (userInput != null && userInput!.isNotEmpty) {
                        n = num.parse(userInput!);
                      }
                    } on FormatException {
                      //nop
                    }
                    if (n != null) {
                      Navigator.pop(context, n);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                )
              ],
            ));
  }

  void showMaxConnectionDialog() async {
    var i = (await showNumberInputDialog(Strings.detailMaxConnectionTitle))
        ?.toInt();
    if (i != null) {
      setMaxConnection(i);
    }
  }

  void showMaxUploadSlotsDialog() async {
    var i = (await showNumberInputDialog(Strings.detailMaxUploadSlotsTitle))
        ?.toInt();
    if (i != null) {
      setMaxUploadSlots(i);
    }
  }

  void showStopRatioDialog() async {
    var stopRatio =
        (await showNumberInputDialog(Strings.detailStopRatioTitle))?.toDouble();
    if (stopRatio != null) {
      setStopRatio(stopRatio);
    }
  }

  void showMoveCompletedPathDialog() async {
    var path = await showPathInputDialog(Strings.detailMoveCompletedPath);
    if (path != null && path.isNotEmpty) {
      setMoveCompletedPath(path);
    }
  }

  void showTrackerListPage() {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (context) {
      return LoadingContainer(child: TrackerList(widget.torrentId));
    }));
  }

  void setOption(Future optionApiCall) async {
    showProgressBar();
    try {
      await optionApiCall;
    } catch (e) {
      showErrorSnackbar(e);
    } finally {
      hideProgressBar();
    }
  }

  void setMaxConnection(int maxConnection) {
    if (maxConnection < 0) maxConnection = -1;
    setOption(
        repository.setTorrentMaxConnections(widget.torrentId, maxConnection));
  }

  void setMaxUploadSlots(int maxSlots) {
    if (maxSlots < 0) maxSlots = -1;
    setOption(repository.setTorrentMaxUploadSlots(widget.torrentId, maxSlots));
  }

  void setAutoManaged(bool autoManaged) {
    setOption(repository.setTorrentAutoManaged(widget.torrentId, autoManaged));
  }

  void setStopAtRatio(bool stopAtRatio) {
    setOption(repository.setTorrentStopAtRatio(widget.torrentId, stopAtRatio));
  }

  void setStopRatio(double stopRatio) {
    if (stopRatio < 0) stopRatio = 2.0;
    setOption(repository.setTorrentStopRatio(widget.torrentId, stopRatio));
  }

  void setRemoveAtRatio(bool removeAtRatio) {
    setOption(
        repository.setTorrentRemoveAtRatio(widget.torrentId, removeAtRatio));
  }

  void setMoveCompleted(bool moveCompleted) {
    setOption(
        repository.setTorrentMoveCompleted(widget.torrentId, moveCompleted));
  }

  void setMoveCompletedPath(String moveCompletedPath) {
    setOption(repository.setTorrentMoveCompletedPath(
        widget.torrentId, moveCompletedPath));
  }

  void setPrioritizeFirstLast(bool prioritizeFirstLast) {
    setOption(repository.setTorrentPrioritiseFirstLast(
        widget.torrentId, prioritizeFirstLast));
  }
}
