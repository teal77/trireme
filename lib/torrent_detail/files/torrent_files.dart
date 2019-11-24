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
import 'package:flutter/foundation.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:trireme_client/deserialization.dart';

import 'package:trireme/common/common.dart';
import 'package:trireme/common/widgets/selectable.dart';

import 'file.dart';
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

  Stream<TorrentFileData> _dataStream() {
    return repository
        .getTorrentFilesUpdate(widget.torrentId)
//        .asyncMap((t) => TorrentFileData.createAsync(t));
        .map((t) => TorrentFileData.create(t));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TorrentFileData>(
      stream: _dataStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          hideProgressBar();
          if (snapshot.hasData) {
            return _TorrentFileList(
              torrentId: widget.torrentId,
              torrentFiles: snapshot.data.torrentFiles,
              root: snapshot.data.root,
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
  final TorrentFiles torrentFiles;
  final File root;

  _TorrentFileList({Key key, this.torrentId, this.torrentFiles, this.root})
      : super(key: key);

  @override
  State createState() {
    return _TorrentFileListState();
  }
}

class _TorrentFileListState extends State<_TorrentFileList>
    with TriremeProgressBarMixin {
  File currentDirectory;
  List<File> selectedFiles = [];
  bool disableButtons = false;

  TriremeRepository repository;
  TorrentFileListController controller = TorrentFileListController();

  @override
  void initState() {
    super.initState();
    currentDirectory = widget.root;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
    controller.repository = repository;
  }

  @override
  void didUpdateWidget(_TorrentFileList oldWidget) {
    super.didUpdateWidget(oldWidget);
    currentDirectory = currentDirectory.isRoot
        ? widget.root
        : widget.root.findChild(currentDirectory.path);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        alignment: Alignment.topLeft,
        child: Text(
          controller.getPath(currentDirectory),
          style: TextStyle(
            fontSize: 13.0,
            color: Colors.grey.shade700,
          ),
          textAlign: TextAlign.start,
        ),
      ),
      Expanded(
          child: ListView(
        children: getListChildren(),
      )),
      BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: selectedFiles.isEmpty ?
            <Widget> [] :
           <Widget>[
            IconButton(
              icon: Icon(Icons.select_all),
              tooltip: Strings.detailFileSelectAllTooltip,
              onPressed: disableButtons ? null : selectAll,
            ),
            IconButton(
              icon: Icon(Icons.block),
              tooltip: Strings.detailFileDoNotDownload,
              onPressed: disableButtons
                  ? null
                  : () => setPrioritiesForSelectedFiles(0),
            ),
            IconButton(
              icon: Icon(Icons.play_arrow),
              tooltip: Strings.detailFileNormal,
              onPressed: disableButtons
                  ? null
                  : () => setPrioritiesForSelectedFiles(1),
            ),
            IconButton(
              icon: Icon(Icons.fast_forward),
              tooltip: Strings.detailFileHigh,
              onPressed: disableButtons
                  ? null
                  : () => setPrioritiesForSelectedFiles(5),
            ),
            IconButton(
              icon: SvgPicture.asset(
                "assets/icons/highest.svg",
                width: 24.0,
                height: 24.0,
                color: IconTheme.of(context).color,
              ),
              tooltip: Strings.detailFileHighest,
              onPressed: disableButtons
                  ? null
                  : () => setPrioritiesForSelectedFiles(7),
            ),
            /*Offstage(
                offstage: selectedFiles.length != 1,
                child: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: disableButtons ? null : renameSelectedFile,
                ),
              )*/
          ],
        ),
      )
    ]);
  }

  List<Widget> getListChildren() {
    var children = <Widget>[];
    if (!currentDirectory.isRoot) {
      children.add(ListTile(
        leading: Icon(Icons.folder),
        title: Text(".."),
        onTap: onParentClicked,
      ));
    }
    currentDirectory.children.sort((f1, f2) => f2.size.compareTo(f1.size));
    for (var file in currentDirectory.children) {
      var isSelected = selectedFiles.contains(file);
      var isSelectionMode = selectedFiles.isNotEmpty;
      children.add(_TorrentFileListTile(
          file, isSelected, isSelectionMode, onFileClicked, onFileSelected));
    }
    return children;
  }

  void onParentClicked() {
    onFileClicked(currentDirectory.parent);
    setState(() {
      selectedFiles.clear();
    });
  }

  void onFileClicked(File file) {
    if (file.isFolder) {
      setState(() {
        currentDirectory = file;
      });
    }
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
      selectedFiles.addAll(currentDirectory.children);
    });
  }

  void setPrioritiesForSelectedFiles(int priority) async {
    setState(() {
      disableButtons = true;
    });
    showProgressBar();
    try {
      await controller.setPriorityForFiles(selectedFiles,
          widget.torrentFiles.filePriorities, widget.torrentId, priority);
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

  void renameSelectedFile() async {
    var fileForRename = selectedFiles.first;
    setState(() {
      selectedFiles.clear();
    });
    var newName = await showRenameDialog(fileForRename.name);

    if (newName == null || newName.isEmpty) return;

    showProgressBar();
    try {
      await controller.renameFile(widget.torrentId, fileForRename, newName);
    } catch (e) {
      Scaffold.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(prettifyError(e)),
        ));
    } finally {
      hideProgressBar();
    }
  }

  Future<String> showRenameDialog(String oldFileName) {
    return showDialog<String>(
        context: context,
        builder: (context) {
          String text = "";
          return AlertDialog(
            title: Text(Strings.detailRenameDialogTitle),
            content: TextField(
              controller: TextEditingController(text: oldFileName),
              onChanged: (s) => text = s,
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(Strings.strOk),
                onPressed: () {
                  Navigator.pop(context, text);
                },
              )
            ],
          );
        });
  }
}

typedef void _TorrentFileSelectedCallback(File file);
typedef void _TorrentFileClickedCallback(File file);

class _TorrentFileListTile extends StatelessWidget {
  final File file;
  final bool isSelected;
  final bool isSelectionMode;
  final _TorrentFileClickedCallback fileClickedCallback;
  final _TorrentFileSelectedCallback fileSelectedCallback;

  final TorrentFileListController controller = new TorrentFileListController();

  _TorrentFileListTile(this.file, this.isSelected, this.isSelectionMode,
      this.fileClickedCallback, this.fileSelectedCallback);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSelectionMode
          ? () => fileSelectedCallback(file)
          : () => fileClickedCallback(file),
      onLongPress: isSelectionMode ? null : () => fileSelectedCallback(file),
      child: Selectable(
          selected: isSelected,
          child: ListTile(
            leading:
                Icon(file.isFolder ? Icons.folder : Icons.insert_drive_file),
            title: Text(file.name),
            subtitle: Row(
              children: <Widget>[
                ByteSize(file.size),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ClipRect(
                      child: Align(
                        heightFactor: 0.5,
                        child: LinearProgressIndicator(
                          value: file.progress,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(controller.getFilePriority(file)),
              ],
            ),
            dense: true,
          )),
    );
  }
}
