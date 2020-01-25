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

import 'package:trireme_client/deserialization.dart';

class TorrentItem {
  final String name;
  final TorrentState state;
  final String stateString;
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final int eta;
  final int totalSize;
  final int currentSize;
  final double ratio;

  //Not for display
  final String id;
  final bool isFinished;
  final DateTime dateAdded;
  final Duration seedingTime;
  final String label;
  final String trackerHost;

  const TorrentItem._(
      this.name,
      this.state,
      this.stateString,
      this.progress,
      this.downloadSpeed,
      this.uploadSpeed,
      this.eta,
      this.totalSize,
      this.currentSize,
      this.ratio,
      this.id,
      this.isFinished,
      this.dateAdded,
      this.seedingTime,
      this.label,
      this.trackerHost);

  factory TorrentItem(String id, TorrentListItem torrentListItem) {
    String name = torrentListItem.name;

    TorrentState state = getTorrentStateForStateString(
        torrentListItem.state, torrentListItem.isFinished);

    int currentSize = torrentListItem.isFinished
        ? torrentListItem.totalUploaded
        : torrentListItem.totalDone;

    var dateAdded = DateTime
        .fromMillisecondsSinceEpoch(torrentListItem.timeAdded.toInt() * 1000);
    var seedingTime = Duration(seconds: torrentListItem.timeSeeding);

    return TorrentItem._(
        name,
        state,
        torrentListItem.state,
        torrentListItem.progress,
        torrentListItem.downloadSpeed,
        torrentListItem.uploadSpeed,
        torrentListItem.eta.toInt(),
        torrentListItem.totalSize,
        currentSize,
        torrentListItem.ratio,
        id,
        torrentListItem.isFinished,
        dateAdded,
        seedingTime,
        torrentListItem.label,
        torrentListItem.trackerHost);
  }

  @override
  String toString() {
    return 'TorrentItem{name: $name, state: $state, progress: $progress, downloadSpeed: $downloadSpeed,'
        ' uploadSpeed: $uploadSpeed, totalSize: $totalSize, currentSize: $currentSize, '
        'ratio: $ratio, id: $id, dateAdded: $dateAdded, seedingTime: $seedingTime}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TorrentItem &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

TorrentState getTorrentStateForStateString(String stateStr, bool isFinished) {
  TorrentState state = torrentStatusMap[stateStr];
  if (state == null) {
    if (stateStr == "Queued") {
      if (isFinished) {
        state = TorrentState.queuedForUpload;
      } else {
        state = TorrentState.queuedForDownload;
      }
    } else {
      state = TorrentState.inactive;
    }
  }
  return state;
}

//IMPORTANT: Order of these constants matter for sorting by TorrentState
//Highest priority is first
enum TorrentState {
  downloading,
  queuedForDownload,
  seeding,
  paused,
  checking,
  queuedForUpload,
  inactive,
}

const torrentStatusMap = {
  "Checking": TorrentState.checking,
  "Downloading": TorrentState.downloading,
  "Seeding": TorrentState.seeding,
  "Paused": TorrentState.paused,
};
