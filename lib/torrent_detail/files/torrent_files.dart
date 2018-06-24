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

import 'package:trireme/common/common.dart';
import 'package:trireme/common/selectable.dart';

import 'torrent_file.dart';
import 'torrent_files_controller.dart';

class TorrentFileListPage extends StatefulWidget {
  final String torrentId;

  TorrentFileListPage(this.torrentId);

  @override
  State<StatefulWidget> createState() {
    return TorrentFileListPageState();
  }
}

class TorrentFileListPageState extends State<TorrentFileListPage>
    with TriremeProgressBarMixin {
  TriremeRepository repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<File>>(
      stream: repository.getTorrentFilesUpdates(widget.torrentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          hideProgressBar();
          if (snapshot.hasData) {
            return _TorrentFileList(
              torrentId: widget.torrentId,
              files: snapshot.data,
            );
          } else if (snapshot.hasError) {
            return ErrorPage(snapshot.error);
          }
        } else {
          showProgressBar();
        }
        return Container();
      },
    );
  }
}

class _TorrentFileList extends StatefulWidget {
  final String torrentId;
  final List<File> files;

  _TorrentFileList({Key key, this.torrentId, this.files}) : super(key: key);

  @override
  State createState() {
    return _TorrentFileListState();
  }
}

class _TorrentFileListState extends State<_TorrentFileList>
    with TriremeProgressBarMixin {
  List<File> selectedFiles = [];
  bool disableButtons = false;
  TriremeRepository repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    widget.files.sort((f1, f2) => f1.index.compareTo(f2.index));
    return Column(children: <Widget>[
      Expanded(
          child: ListView(
        children: widget.files.map((f) => getListTileForFile(f)).toList(),
      )),
      Offstage(
        offstage: selectedFiles.isEmpty,
        child: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.select_all),
                onPressed: disableButtons ? null : selectAll,
              ),
              IconButton(
                icon: Icon(Icons.block),
                onPressed: disableButtons
                    ? null
                    : () => setPrioritiesForSelectedFiles(0),
              ),
              IconButton(
                icon: Icon(Icons.play_arrow),
                onPressed: disableButtons
                    ? null
                    : () => setPrioritiesForSelectedFiles(1),
              ),
              IconButton(
                icon: Icon(Icons.fast_forward),
                onPressed: disableButtons
                    ? null
                    : () => setPrioritiesForSelectedFiles(5),
              ),
              IconButton(
                icon: Icon(Icons.priority_high),
                onPressed: disableButtons
                    ? null
                    : () => setPrioritiesForSelectedFiles(7),
              ),
            ],
          ),
        ),
      )
    ]);
  }

  Widget getListTileForFile(File file) {
    return _TorrentFileListTile(file, selectedFiles.contains(file),
        selectedFiles.isNotEmpty, onFileSelected);
  }

  void onFileSelected(File file) {
    if (selectedFiles.contains(file)) {
      selectedFiles.remove(file);
    } else {
      selectedFiles.add(file);
    }
    setState(() {});
  }

  void selectAll() {
    selectedFiles.clear();
    setState(() {
      selectedFiles.addAll(widget.files);
    });
  }

  void setPrioritiesForSelectedFiles(int priority) async {
    setState(() {
      disableButtons = true;
    });
    showProgressBar();
    List<int> priorities = List(widget.files.length);
    widget.files.forEach((f) => priorities[f.index] = f.priority);
    selectedFiles.forEach((f) => priorities[f.index] = priority);
    try {
      await repository.setTorrentFilePriorities(widget.torrentId, priorities);
      setState(() {
        selectedFiles.clear();
      });
    } catch (e) {
      Scaffold.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(prettifyError(e)),
        ));
    } finally {
      hideProgressBar();
      setState(() {
        disableButtons = false;
      });
    }
  }
}

typedef void _TorrentFileSelectedCallback(File file);

class _TorrentFileListTile extends StatelessWidget {
  final File file;
  final bool isSelected;
  final bool isSelectionMode;
  final _TorrentFileSelectedCallback callback;

  final TorrentFileListController controller = new TorrentFileListController();

  _TorrentFileListTile(
      this.file, this.isSelected, this.isSelectionMode, this.callback);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSelectionMode ? () => callback(file) : null,
      onLongPress: isSelectionMode ? null : () => callback(file),
      child: Selectable(
        selected: isSelected,
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.path,
                  style: const TextStyle(fontSize: 16.0),
                ),
                Container(
                  height: 8.0,
                ),
                ClipRect(
                    child: Align(
                  heightFactor: 0.5,
                  child: LinearProgressIndicator(
                    value: file.progress,
                  ),
                )),
                Container(
                  height: 8.0,
                ),
                DefaultTextStyle(
                    style: const TextStyle(
                        fontSize: 14.0, color: const Color(0x99000000)),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(controller.getFileSize(file)),
                        ),
                        Text(controller.getFilePriority(file)),
                      ],
                    )),
              ],
            )),
      ),
    );
  }
}
