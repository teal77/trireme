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

import 'package:trireme/common/selectable.dart';
import 'package:trireme/torrent_list/torrent_list_tile/torrent_list_tile_controller.dart';
import 'package:trireme/torrent_detail/torrent_detail.dart';

import '../torrent_item.dart';
import '../torrent_list_controller.dart';

class TorrentListItem extends StatefulWidget {
  final TorrentItem data;
  final TorrentListController listController;

  TorrentListItem(this.data, this.listController);

  @override
  State<StatefulWidget> createState() => TorrentListItemState();
}

class TorrentListItemState extends State<TorrentListItem> {
  static const dotSeparator = "•";

  TorrentListItemController controller = TorrentListItemController();
  TorrentItem data;

  @override
  void initState() {
    super.initState();
    this.data = widget.data;
    controller.torrentItem = data;
    widget.listController.subscribeForStatusUpdates(data);
  }

  @override
  void didUpdateWidget(TorrentListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    this.data = widget.data;
    controller.torrentItem = data;
    widget.listController.unSubscribeFromUpdates(oldWidget.data);
    widget.listController.subscribeForStatusUpdates(data);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () {
          if (widget.listController.isSelectionMode()) {
            widget.listController.toggleTorrentItemSelection(data);
            setState(() {});
          } else {
            launchTorrentDetailScreen(context, data);
          }
        },
        onLongPress: widget.listController.isSelectionMode()
            ? null
            : () {
                widget.listController.toggleTorrentItemSelection(data);
                setState(() {});
              },
        child: Selectable(
          selected: widget.listController.isItemSelected(data),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                  width: 72.0,
                  padding: const EdgeInsets.all(16.0),
                  alignment: Alignment.center,
                  child: TorrentStateProperties(data.state).icon),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(
                      right: 16.0, top: 16.0, bottom: 18.0),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: Theme.of(context).dividerColor))),
                  constraints: const BoxConstraints(minHeight: 72.0),
                  child: _getTorrentDetails(),
                ),
              ),
            ],
          ),
        ));
  }

  @override
  void deactivate() {
    widget.listController.unSubscribeFromUpdates(data);
    super.deactivate();
  }

  @override
  void dispose() {
    widget.listController.unSubscribeFromUpdates(data);
    super.dispose();
  }

  Widget _getTorrentDetails() {
    List<Widget> torrentDetails = [
      Text(
        data.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600),
      ),
      Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Row(
          children: <Widget>[
            Expanded(
                child: Text(
              _getStateAndSize(),
            )),
            Text(
              controller.getRatio(),
            )
          ],
        ),
      ),
    ];

    if (data.downloadSpeed > 0 || data.uploadSpeed > 0) {
      torrentDetails.add(_getProgress());
      torrentDetails.add(_getSpeedAndEta());
    }

    return DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 11.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: torrentDetails,
        ));
  }

  String _getStateAndSize() {
    var totalSize = controller.getTotalSize();
    var state = data.stateString;
    var currentSizeExplanation = controller.getCurrentSizeExplanation();

    if (data.isFinished) {
      return "$totalSize $dotSeparator $state $dotSeparator $currentSizeExplanation";
    } else {
      return "$state $dotSeparator $currentSizeExplanation";
    }
  }

  Widget _getProgress() {
    var children = <Widget>[
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ClipRect(
            child: Align(
              heightFactor: 0.5,
              child: LinearProgressIndicator(
                value: data.progress / 100.0,
                backgroundColor:
                    TorrentStateProperties(data.state).color.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  TorrentStateProperties(data.state).color.shade500,
                ),
              ),
            ),
          ),
        ),
      )
    ];

    return Row(
      children: children,
    );
  }

  Widget _getSpeedAndEta() {
    var children = <Widget>[];

    if (data.downloadSpeed > 0) {
      children.add(const Icon(
        Icons.arrow_downward,
        size: 11.0,
      ));
      children.add(Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Text(controller.getDownloadSpeed()),
      ));
    }

    if (data.uploadSpeed > 0) {
      children.add(const Icon(
        Icons.arrow_upward,
        size: 11.0,
      ));
      children.add(Text(controller.getUploadSpeed()));
    }

    if (data.eta > 0) {
      var eta = controller.getEta();
      children.add(Expanded(
          child: Text(
        "$eta",
        textAlign: TextAlign.end,
      )));
    }

    return Row(
      children: children,
    );
  }
}

class TorrentStateProperties {
  static const iconSize = 40.0;

  static final downloadingColor = Colors.blue;
  static final queuedColor = Colors.lightBlue;
  static final seedingColor = Colors.lightGreen;
  static final inactiveColor = Colors.grey;
  static final pausedColor = Colors.pink;

  static final downloading = TorrentStateProperties._(
      downloadingColor,
      Icon(
        Icons.cloud_download,
        size: iconSize,
        color: downloadingColor,
      ));

  static final seeding = TorrentStateProperties._(
      seedingColor,
      Icon(
        Icons.cloud_upload,
        size: iconSize,
        color: seedingColor,
      ));

  static final inactive = TorrentStateProperties._(
      inactiveColor,
      Icon(
        Icons.cloud_off,
        size: iconSize,
        color: inactiveColor,
      ));

  static final paused = TorrentStateProperties._(
      pausedColor,
      Icon(
        Icons.cloud_off,
        size: iconSize,
        color: pausedColor,
      ));

  static final queuedForDownload = TorrentStateProperties._(
      queuedColor,
      Icon(
        Icons.cloud_queue,
        size: iconSize,
        color: queuedColor,
      ));

  static final queuedForUpload = TorrentStateProperties._(
      inactiveColor,
      Icon(
        Icons.cloud_done,
        size: iconSize,
        color: inactiveColor,
      ));

  static final checking = queuedForDownload;

  final MaterialColor color;
  final Icon icon;

  TorrentStateProperties._(this.color, this.icon);

  factory TorrentStateProperties(TorrentState t) {
    switch (t) {
      case TorrentState.downloading:
        return downloading;
      case TorrentState.seeding:
        return seeding;
      case TorrentState.inactive:
        return inactive;
      case TorrentState.paused:
        return paused;
      case TorrentState.checking:
        return checking;
      case TorrentState.queuedForDownload:
        return queuedForDownload;
      case TorrentState.queuedForUpload:
        return queuedForUpload;
    }
    throw "Unhandled state ${t.toString()}";
  }
}

void launchTorrentDetailScreen(BuildContext context, TorrentItem t) {
  Navigator.of(context).push(MaterialPageRoute(builder: (context) {
    return TorrentDetailPage(t);
  }));
}
