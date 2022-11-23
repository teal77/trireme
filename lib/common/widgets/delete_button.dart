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

import '../common.dart';

typedef DeleteCallback = void Function(bool b);

class DeleteButton extends StatelessWidget {
  final String toolTip;
  final DeleteCallback deleteCallback;

  DeleteButton(this.toolTip, this.deleteCallback);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.delete),
      tooltip: toolTip,
      onPressed: () => _showConfirmationDialog(context),
    );
  }

  void _showConfirmationDialog(BuildContext context) async {
    final deleteOption = await showConfirmationDialog(context);
    switch (deleteOption) {
      case DeleteOptions.delete:
        deleteCallback(false);
        break;
      case DeleteOptions.deleteWithData:
        deleteCallback(true);
        break;
      case DeleteOptions.dontDelete:
        break;
    }
  }
}

enum DeleteOptions { delete, deleteWithData, dontDelete }

Future<DeleteOptions?> showConfirmationDialog(BuildContext context) {
  final _key = GlobalKey<_DeleteConfirmationDialogContentState>();
  return showDialog<DeleteOptions>(
      context: context,
      builder: (context) => AlertDialog(
            content: _DeleteConfirmationDialogContent(_key),
            actions: <Widget>[
              TextButton(
                child: Text(Strings.strcNo),
                onPressed: () {
                  Navigator.pop(context, DeleteOptions.dontDelete);
                },
              ),
              TextButton(
                child: Text(Strings.strcYes),
                onPressed: () {
                  Navigator.pop(
                      context,
                      _key.currentState?.deleteData ?? false
                          ? DeleteOptions.deleteWithData
                          : DeleteOptions.delete);
                },
              )
            ],
          ));
}

class _DeleteConfirmationDialogContent extends StatefulWidget {
  _DeleteConfirmationDialogContent(Key key) : super(key: key);

  @override
  State createState() {
    return _DeleteConfirmationDialogContentState();
  }
}

class _DeleteConfirmationDialogContentState
    extends State<_DeleteConfirmationDialogContent> {
  var deleteData = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(Strings.detailDeleteConfirmationText),
        CheckboxListTile(
            title: Text(Strings.detailDeleteDeleteData),
            value: deleteData,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (b) {
              setState(() {
                deleteData = b ?? false;
              });
            })
      ],
    );
  }
}
