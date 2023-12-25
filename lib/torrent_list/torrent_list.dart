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

import 'torrent_item.dart';
import 'torrent_list_controller.dart';
import 'torrent_list_tile/torrent_list_tile.dart';

class TorrentList extends StatefulWidget {
  final SortCriteria sortCriterion;
  final bool reverseSort;
  final FilterSpec filterSpec;
  final ValueChanged<int> selectionCountChangedCallback;

  TorrentList(Key key, this.sortCriterion, this.reverseSort, this.filterSpec,
      this.selectionCountChangedCallback)
      : super(key: key);

  @override
  TorrentListState createState() => TorrentListState();
}

class TorrentListState extends State<TorrentList> with TriremeProgressBarMixin {
  late TorrentListController controller;

  TorrentListState() {
    controller = TorrentListController(update, onSelectedItemsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  void didUpdateWidget(TorrentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterSpec != widget.filterSpec) {
      controller.filter(widget.filterSpec);
    }
    if (oldWidget.sortCriterion != widget.sortCriterion ||
        oldWidget.reverseSort != widget.reverseSort) {
      controller.sort(widget.sortCriterion, widget.reverseSort);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Scrollbar(
            child: ListView.builder(
                padding: EdgeInsets.only(bottom: 16.0),
                itemCount: controller.getItemCount(),
                itemBuilder: (context, index) {
                  TorrentItem t = controller.getItemAt(index);
                  return TorrentListItem(
                    t,
                    controller,
                  );
                })),
        Offstage(
          offstage: controller.getItemCount() != 0,
          child: Text(controller.getEmptyText()),
        )
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void update() {
    setState(() {
      //nop
    });
  }

  void onSelectedItemsChanged(int selectedCount) {
    widget.selectionCountChangedCallback(selectedCount);
  }

  void clearSelection() {
    controller.clearSelection();
  }

  void pauseTorrents() async {
    showProgressBar();
    try {
      await controller.pauseTorrents();
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      hideProgressBar();
    }
  }

  void resumeTorrents() async {
    showProgressBar();
    try {
      await controller.resumeTorrents();
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      hideProgressBar();
    }
  }

  void deleteTorrents() async {
    showProgressBar();
    try {
      await controller.deleteTorrents();
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      hideProgressBar();
    }
  }

  void deleteTorrentsWithData() async {
    showProgressBar();
    try {
      await controller.deleteTorrentsWithData();
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      hideProgressBar();
    }
  }

  void setTorrentsLabel(String label) async {
    showProgressBar();
    try {
      await controller.setTorrentsLabel(label);
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      hideProgressBar();
    }
  }

  void selectAll() {
    controller.selectAll();
  }

  void invertSelection() {
    controller.invertSelection();
  }

  void showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text),
        ));
  }
}
