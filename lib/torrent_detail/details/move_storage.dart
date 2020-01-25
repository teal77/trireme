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

import 'package:trireme/common/common.dart';

class MoveStorageDialog extends StatefulWidget {
  final String torrentId;
  final String currentPath;

  MoveStorageDialog(this.torrentId, this.currentPath);

  @override
  State createState() => MoveStorageDialogState();
}

class MoveStorageDialogState extends State<MoveStorageDialog> {
  final GlobalKey<_MoveStorageState> key = new GlobalKey<_MoveStorageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.detailMoveStorageDialogTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              key.currentState.savePath();
            },
          )
        ],
      ),
      body: LoadingContainer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _MoveStorage(
              key: key,
              torrentId: widget.torrentId,
              currentPath: widget.currentPath),
        ),
      ),
    );
  }
}

class _MoveStorage extends StatefulWidget {
  final String torrentId;
  final String currentPath;

  _MoveStorage({Key key, this.torrentId, this.currentPath}) : super(key: key);

  @override
  State createState() => _MoveStorageState();
}

class _MoveStorageState extends State<_MoveStorage>
    with TriremeProgressBarMixin {

  TriremeRepository repository;
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.currentPath);
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
        TextField(
          keyboardType: TextInputType.url,
          autocorrect: false,
          controller: controller,
        )
      ],
    );
  }

  void savePath() {
    if (controller.text.isNotEmpty) {
      moveStorage(controller.text);
    }
  }

  Future moveStorage(String newPath) async {
    showProgressBar();
    try {
      bool result = await repository.moveStorage(widget.torrentId, newPath);
      if (result == null) {
        Navigator.pop(context);
        return;
      }
      if (result) {
        showSnackBar(Strings.strSuccess);
        await Future<void>.delayed(const Duration(seconds: 1));
        Navigator.pop(context);
      } else {
        showSnackBar(Strings.detailMoveStorageFailedText);
      }
    } catch (e) {
      showErrorSnackBar(e);
    } finally {
      hideProgressBar();
    }
  }

  void showErrorSnackBar(Object error) {
    showSnackBar(prettifyError(error));
  }

  void showSnackBar(String text) {
    Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(text),
        ));
  }
}
