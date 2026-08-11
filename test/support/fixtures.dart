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
