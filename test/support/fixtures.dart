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

import 'package:trireme/torrent_list/torrent_item.dart';
import 'package:trireme_client/deserialization.dart';

/// Builds a TorrentListItem with every late field populated, so tests only
/// need to name the fields they care about.
TorrentListItem buildTorrentListItem({
  String name = 'torrent',
  String state = 'Downloading',
  double progress = 0.0,
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  num eta = 0,
  int totalSize = 0,
  int totalDone = 0,
  int totalUploaded = 0,
  bool isFinished = false,
  double ratio = 0.0,
  num timeAdded = 0,
  num? timeCompleted,
  int timeSeeding = 0,
  String? label,
  String trackerHost = 'tracker.example',
}) {
  return TorrentListItem()
    ..name = name
    ..state = state
    ..progress = progress
    ..downloadSpeed = downloadSpeed
    ..uploadSpeed = uploadSpeed
    ..eta = eta
    ..totalSize = totalSize
    ..totalDone = totalDone
    ..totalUploaded = totalUploaded
    ..isFinished = isFinished
    ..ratio = ratio
    ..timeAdded = timeAdded
    ..timeCompleted = timeCompleted
    ..timeSeeding = timeSeeding
    ..label = label
    ..trackerHost = trackerHost;
}

TorrentItem buildTorrentItem({
  String id = 'id',
  String name = 'torrent',
  String state = 'Downloading',
  double progress = 0.0,
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  num eta = 0,
  int totalSize = 0,
  int totalDone = 0,
  int totalUploaded = 0,
  bool isFinished = false,
  double ratio = 0.0,
  num timeAdded = 0,
  num? timeCompleted,
  int timeSeeding = 0,
  String? label,
  String trackerHost = 'tracker.example',
}) {
  return TorrentItem(
    id,
    buildTorrentListItem(
      name: name,
      state: state,
      progress: progress,
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      eta: eta,
      totalSize: totalSize,
      totalDone: totalDone,
      totalUploaded: totalUploaded,
      isFinished: isFinished,
      ratio: ratio,
      timeAdded: timeAdded,
      timeCompleted: timeCompleted,
      timeSeeding: timeSeeding,
      label: label,
      trackerHost: trackerHost,
    ),
  );
}

/// Builds the map `core.get_torrents_status` answers with for one torrent.
///
/// This is the wire shape, not the model: every key in `torrentListItemKeys`
/// has to be present and of the right type, because the generated deserializer
/// casts hard, with no fallback. A missing key, or an int where a double is
/// declared, fails the whole response rather than the one field.
Map<String, Object?> buildTorrentStatus({
  String name = 'torrent',
  String state = 'Downloading',
  double progress = 0.0,
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  num eta = 0,
  int totalSize = 0,
  int totalDone = 0,
  int totalUploaded = 0,
  bool isFinished = false,
  double ratio = 0.0,
  num timeAdded = 1500000000,
  num timeCompleted = 0,
  int timeSeeding = 0,
  String? label,
  String trackerHost = 'tracker.example',
}) {
  return <String, Object?>{
    'name': name,
    'state': state,
    'progress': progress,
    'download_payload_rate': downloadSpeed,
    'upload_payload_rate': uploadSpeed,
    'eta': eta,
    'total_wanted': totalSize,
    'total_done': totalDone,
    'total_uploaded': totalUploaded,
    'is_finished': isFinished,
    'ratio': ratio,
    'time_added': timeAdded,
    'completed_time': timeCompleted,
    'seeding_time': timeSeeding,
    'label': label,
    'tracker_host': trackerHost,
  };
}

TorrentFile buildTorrentFile({
  int index = 0,
  int size = 0,
  int offset = 0,
  required String path,
}) {
  return TorrentFile()
    ..index = index
    ..size = size
    ..offset = offset
    ..path = path;
}

TorrentFiles buildTorrentFiles({
  required List<TorrentFile> files,
  required List<int> priorities,
  required List<double> progress,
}) {
  return TorrentFiles()
    ..files = files
    ..filePriorities = priorities
    ..fileProgress = progress;
}
