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

import 'package:trireme/common/common.dart';

class AddTorrentPage extends StatefulWidget {
  final AddTorrentKind addTorrentKind;

  AddTorrentPage(this.addTorrentKind);

  @override
  State createState() => AddTorrentState();
}

enum AddTorrentKind {
  url,
}

class AddTorrentState extends State<AddTorrentPage> {
  var key = GlobalKey<_AddTorrentState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.addTorrentTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              key.currentState.addTorrent();
            },
          )
        ],
      ),
      body: LoadingContainer(
        child: _AddTorrent(key, widget.addTorrentKind),
      ),
    );
  }
}

class _AddTorrent extends StatefulWidget {
  final AddTorrentKind addTorrentKind;

  _AddTorrent(
    Key key,
    this.addTorrentKind,
  ) : super(key: key);

  @override
  State createState() => _AddTorrentState();
}

class _AddTorrentState extends State<_AddTorrent> with TriremeProgressBarMixin {
  TriremeRepository repository;

  String torrentUrl = "";
  String downloadPath = "";
  bool moveCompleted = false;
  String moveCompletedPath = "";
  int downloadSpeedLimit = -1;
  int uploadSpeedLimit = -1;
  int connectionLimit = -1;
  int uploadSlotLimit = -1;
  bool addPaused = false;
  bool prioritiseFirstLast = false;

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  void initStateAsync() async {
    showProgressBar();
    var defaultConfigs = await repository.getAddTorrentDefaultOptions();
    setState(() {
      downloadPath = defaultConfigs.downloadPath;
      moveCompleted = defaultConfigs.moveCompleted;
      moveCompletedPath = defaultConfigs.moveCompletedPath;
      downloadSpeedLimit = defaultConfigs.downloadSpeedLimit.toInt();
      uploadSpeedLimit = defaultConfigs.uploadSpeedLimit.toInt();
      connectionLimit = defaultConfigs.connectionsLimit.toInt();
      uploadSlotLimit = defaultConfigs.uploadSlotsLimit.toInt();
      addPaused = defaultConfigs.addPaused;
      prioritiseFirstLast = defaultConfigs.prioritiseFirstLastPieces;
    });
    hideProgressBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    String speedString(int speed) => "${kb.Size(kilobytes: speed)}/s";

    String getDownloadSpeedLimit() => downloadSpeedLimit == -1
        ? Strings.detailOptionUnsetText
        : speedString(downloadSpeedLimit);

    String getUploadSpeedLimit() => uploadSpeedLimit == -1
        ? Strings.detailOptionUnsetText
        : speedString(uploadSpeedLimit);

    String getConnectionsLimit() => connectionLimit == -1
        ? Strings.detailOptionUnsetText
        : connectionLimit.toString();

    String getUploadSlotLimit() => uploadSlotLimit == -1
        ? Strings.detailOptionUnsetText
        : uploadSlotLimit.toString();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: <Widget>[
        ListTile(
          title: TextField(
            decoration: InputDecoration(
              hintText: Strings.addTorrentUrlHint,
            ),
            keyboardType: TextInputType.url,
            maxLines: 1,
            onChanged: (s) => torrentUrl = s,
          ),
        ),
        getDivider(),
        getSubHeader(Strings.addTorrentLocationSubHeader),
        ListTile(
          title: Text(Strings.addTorrentDownloadPath),
          subtitle: Text(downloadPath),
          onTap: () {
            showDownloadPathDialog();
          },
        ),
        SwitchListTile(
          title: Text(Strings.addTorrentMoveCompleted),
          value: moveCompleted,
          onChanged: (value) {
            setState(() {
              moveCompleted = value;
            });
          },
        ),
        ListTile(
          title: Text(Strings.addTorrentMoveCompletedPath),
          subtitle: Text(moveCompletedPath),
          enabled: moveCompleted,
          onTap: () {
            showMoveCompletedPathDialog();
          },
        ),
        getDivider(),
        getSubHeader(Strings.addTorrentBandwidthSubHeader),
        ListTile(
          title: Text(Strings.addTorrentMaxDownloadSpeed),
          subtitle: Text(getDownloadSpeedLimit()),
          onTap: () {
            showMaxDownloadSpeedDialog();
          },
        ),
        ListTile(
          title: Text(Strings.addTorrentMaxUploadSpeed),
          subtitle: Text(getUploadSpeedLimit()),
          onTap: () {
            showMaxUploadSpeedDialog();
          },
        ),
        ListTile(
          title: Text(Strings.addTorrentMaxConnections),
          subtitle: Text(getConnectionsLimit()),
          onTap: () {
            showMaxConnectionDialog();
          },
        ),
        ListTile(
          title: Text(Strings.addTorrentMaxUploadSlots),
          subtitle: Text(getUploadSlotLimit()),
          onTap: () {
            showMaxUploadSlotsDialog();
          },
        ),
        getDivider(),
        getSubHeader(Strings.addTorrentGeneralSubHeader),
        SwitchListTile(
          title: Text(Strings.addTorrentAddPaused),
          value: addPaused,
          onChanged: (value) {
            setState(() {
              addPaused = value;
            });
          },
        ),
        SwitchListTile(
          title: Text(Strings.addTorrentPrioritiseFirstLast),
          subtitle: Text(Strings.addTorrentPrioritiseFirstLastInfo),
          value: prioritiseFirstLast,
          onChanged: (value) {
            setState(() {
              prioritiseFirstLast = value;
            });
          },
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

  Future<String> showPathInputDialog(String title) async {
    String userInput;
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

  void showDownloadPathDialog() async {
    String path =
        await showPathInputDialog(Strings.addTorrentDownloadPathTitle);
    if (path != null) {
      setState(() {
        downloadPath = path;
      });
    }
  }

  void showMoveCompletedPathDialog() async {
    String path =
        await showPathInputDialog(Strings.addTorrentMoveCompletedPathTitle);
    if (path != null) {
      setState(() {
        moveCompletedPath = path;
      });
    }
  }

  Future<num> showNumberInputDialog(String title, {String hintText}) async {
    String userInput;
    num n = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                decoration: InputDecoration(hintText: hintText ?? ""),
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
                    num n;
                    try {
                      if (userInput != null && userInput.isNotEmpty) {
                        n = num.parse(userInput);
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
    return n;
  }

  void showMaxDownloadSpeedDialog() async {
    int i = (await showNumberInputDialog(
            Strings.addTorrentSelectDownloadSpeedTitle,
            hintText: Strings.addTorrentDownloadSpeedHint))
        ?.toInt();
    if (i != null) {
      if (i < 0) i = -1;
      setState(() {
        downloadSpeedLimit = i;
      });
    }
  }

  void showMaxUploadSpeedDialog() async {
    int i = (await showNumberInputDialog(
            Strings.addTorrentSelectUploadSpeedTitle,
            hintText: Strings.addTorrentUploadSpeedHint))
        ?.toInt();
    if (i != null) {
      if (i < 0) i = -1;
      setState(() {
        uploadSpeedLimit = i;
      });
    }
  }

  void showMaxConnectionDialog() async {
    int i = (await showNumberInputDialog(Strings.detailMaxConnectionTitle))
        ?.toInt();
    if (i != null) {
      if (i < 0) i = -1;
      setState(() {
        connectionLimit = i;
      });
    }
  }

  void showMaxUploadSlotsDialog() async {
    int i = (await showNumberInputDialog(Strings.detailMaxUploadSlotsTitle))
        ?.toInt();
    if (i != null) {
      if (i < 0) i = -1;
      setState(() {
        uploadSlotLimit = i;
      });
    }
  }

  void addTorrent() async {
    try {
      showProgressBar();
      await repository.addTorrentUrl(torrentUrl, getTorrentOptions());
      Navigator.pop(context);
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      hideProgressBar();
    }
  }

  Map<String, Object> getTorrentOptions() {
    return {
      "download_location" : downloadPath,
      "move_completed" : moveCompleted,
      "move_completed_path" : moveCompletedPath,
      "max_download_speed" : downloadSpeedLimit,
      "max_upload_speed" : uploadSpeedLimit,
      "max_connections" : connectionLimit,
      "max_upload_slots" : uploadSlotLimit,
      "add_paused" : addPaused,
      "prioritize_first_last_pieces" : prioritiseFirstLast,
      "owner" : repository.client.username
    };
  }

  void showSnackBar(String text) {
    Scaffold.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }
}