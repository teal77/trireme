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
import 'dart:collection';

import 'package:meta/meta.dart';

import 'package:rxdart/rxdart.dart';

import 'package:trireme_client/events.dart';
import 'package:trireme_client/deserialization.dart';
import 'package:trireme_client/trireme_client.dart';

import 'package:trireme/common/bytesize.dart';
import 'package:trireme/common/log.dart';
import 'package:trireme/torrent_list/torrent_item.dart';

abstract class TriremeRepository {
  static const _tag = "TriremeRepository";

  TriremeClient _client;
  StreamController<bool> _readinessStream = StreamController.broadcast();
  StreamController<Object> _errorStream = StreamController.broadcast();

  factory TriremeRepository() {
    return _TriremeRepositoryImpl();
  }

  TriremeRepository._();

  set client(TriremeClient client) {
    _client = client;
    _readinessStream.add(client != null);
  }

  TriremeClient get client => _client;

  bool isReady() => _client != null;

  Future readiness() => _readinessStream.stream.firstWhere((b) => b);

  Stream<Object> errorStream() => _errorStream.stream;

  @mustCallSuper
  void init() {
    _readinessStream = StreamController.broadcast();
    _errorStream = StreamController.broadcast();
  }

  void pause();

  void resume();

  @mustCallSuper
  void dispose() {
    Log.d(_tag, "Disposed");
    _readinessStream.close();
    _errorStream.close();
  }

  Stream<DelugeRpcEvent> getDelugeRpcEvents();

  Future<String> getDaemonInfo();

  Stream<String> getSessionDownloadSpeed(ByteSizeStyle style);

  Stream<String> getSessionUploadSpeed(ByteSizeStyle style);

  Stream<List<SessionStatus>> getSessionStatusHistory();

  Future<int> getDownloadSpeedLimit();

  Future setDownloadSpeedLimit(int kibps);

  Future<int> getUploadSpeedLimit();

  Future setUploadSpeedLimit(int kibps);

  Future<AddTorrentDefaultOptions> getAddTorrentDefaultOptions();

  Future addTorrentUrl(String url, Map<String, Object> options);

  Future addTorrentFile(
      String fileName, String fileDump, Map<String, Object> options);

  Future<FilterTree> getFilterTree();

  Future<List<TorrentItem>> getTorrentList(Map<String, Object> filterDict);

  void subscribeForTorrentListUpdates(TorrentItem item);

  void unsubscribeFromTorrentListUpdates(TorrentItem item);

  Stream<List<TorrentItem>> getTorrentListUpdates();

  void unsubscribeFromAllTorrentUpdates();

  Stream<TorrentDetail> getTorrentDetails(String torrentId);

  Future pauseTorrents(List<String> torrentIds);

  Future resumeTorrents(List<String> torrentIds);

  Future recheckTorrents(List<String> torrentIds);

  Future reAnnounceTorrents(List<String> torrentIds);

  Future<bool> removeTorrent(String torrentId, bool removeData);

  Future<List> removeTorrents(List<String> torrentIds, bool removeData);

  Future<bool> moveStorage(String torrentId, String path);

  Future<List<String>> getLabels();

  Future setTorrentLabel(String torrentId, String label);

  Future<TorrentFiles> getTorrentFiles(String torrentId);

  Stream<TorrentFiles> getTorrentFilesUpdate(String torrentId);

  Future renameFile(String torrentId, int index, String newName);

  Future renameFolder(String torrentId, String oldName, String newName);

  Stream<Peers> getTorrentPeers(String torrentId);

  Future setTorrentFilePriorities(String torrentId, List<int> priorities);

  Future<TorrentOptions> getTorrentOptions(String torrentId);

  Stream<TorrentOptions> getTorrentOptionsUpdates(String torrentId);

  Future setTorrentMaxDownloadSpeed(String torrentId, int maxSpeed);

  Future setTorrentMaxUploadSpeed(String torrentId, int maxSpeed);

  Future setTorrentMaxConnections(String torrentId, int maxConnections);

  Future setTorrentMaxUploadSlots(String torrentId, int maxUploadSlots);

  Future setTorrentAutoManaged(String torrentId, bool autoManaged);

  Future setTorrentStopAtRatio(String torrentId, bool stopAtRatio);

  Future setTorrentStopRatio(String torrentId, double stopRatio);

  Future setTorrentRemoveAtRatio(String torrentId, bool removeAtRatio);

  Future setTorrentMoveCompleted(String torrentId, bool moveCompleted);

  Future setTorrentMoveCompletedPath(
      String torrentId, String moveCompletedPath);

  Future setTorrentPrioritiseFirstLast(
      String torrentId, bool prioritiseFirstLast);
}

class _TriremeRepositoryImpl extends TriremeRepository {
  static const _tag = "_TriremeRepositoryImpl";
  static const Duration refreshInterval = Duration(seconds: 2);
  static const speedHistorySize = 60;

  Timer publishTimer;
  bool isPaused = false;
  bool isResumed = false;

  String torrentIdForDetails;

  StreamController<DelugeRpcEvent> eventsStream;
  StreamSubscription<DelugeRpcEvent> localEventSubscription;
  _Refresher<SessionStatus> sessionStatusRefresher;
  BehaviorSubject<List<SessionStatus>> sessionStatusHistory;
  StreamSubscription<List<SessionStatus>> localSessionStatusSubscription;
  _Refresher<FilterTree> filterTreeRefresher;
  _TorrentListRefresher torrentListRefresher;
  _TorrentDetailRefresher torrentDetailRefresher;
  _TorrentFileListRefresher torrentFileListRefresher;
  _TorrentPeerListRefresher torrentPeerListRefresher;
  _TorrentOptionsRefresher torrentOptionsRefresher;

  List<_Refresher> refreshers;

  _TriremeRepositoryImpl() : super._() {
    init();
  }

  @override
  void init() {
    super.init();

    eventsStream = StreamController.broadcast();
    sessionStatusRefresher = _SimpleRefresher<SessionStatus>(
        (repository) => repository.client.getSessionStatus());
    sessionStatusHistory = BehaviorSubject<List<SessionStatus>>();
    filterTreeRefresher =
        _SimpleRefresher((repository) => repository.client.getFilterTree());
    torrentListRefresher = _TorrentListRefresher();
    torrentDetailRefresher = _TorrentDetailRefresher();
    torrentFileListRefresher = _TorrentFileListRefresher();
    torrentPeerListRefresher = _TorrentPeerListRefresher();
    torrentOptionsRefresher = _TorrentOptionsRefresher();

    refreshers = [
      sessionStatusRefresher,
      filterTreeRefresher,
      torrentListRefresher,
      torrentDetailRefresher,
      torrentPeerListRefresher,
      torrentFileListRefresher,
      torrentOptionsRefresher,
    ];

    resume();
  }

  void initPublishTimer() {
    publishTimer = Timer.periodic(refreshInterval, (t) => publishData());
  }

  void publishData() {
    refreshers.forEach((r) => r.publish());
  }

  void startRefreshingData() async {
    while (isResumed) {
      await refreshData();
    }
  }

  Future refreshData() async {
    if (client == null || client.isDisposed) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    try {
      await Future.wait(refreshers.map((r) => r.refresh(this)).toList()
        ..add(Future.delayed(refreshInterval)));
    } catch (e) {
      Log.e(_tag, e.toString());
      _errorStream.add(e);
    }
  }

  void startRecordingSpeedHistory() {
    localSessionStatusSubscription = sessionStatusRefresher
        .updateStream()
        .transform(new _BootlegTakeLastTransformer(speedHistorySize))
        .listen((s) => sessionStatusHistory.add(s));
  }

  void stopRecordingSpeedHistory() {
    localSessionStatusSubscription.cancel();
  }

  @override
  void resume() {
    if (isResumed) {
      throw "Resume called while already resumed";
    }
    Log.d(_tag, "Resumed");
    isPaused = false;
    isResumed = true;
    startRefreshingData();
    initPublishTimer();
    startRecordingSpeedHistory();
  }

  @override
  void pause() {
    if (isPaused) {
      throw "Pause called while already paused";
    }
    Log.d(_tag, "Paused");
    isResumed = false;
    isPaused = true;
    publishTimer.cancel();
    stopRecordingSpeedHistory();
  }

  @override
  void dispose() {
    pause();
    refreshers.forEach((r) => r.dispose());
    eventsStream.close();
    sessionStatusHistory.close();
    super.dispose();
  }

  @override
  set client(TriremeClient client) {
    super.client = client;
    if (client != null) {
      localEventSubscription?.cancel();
      localEventSubscription =
          client.delugeRpcEvents().listen((e) => eventsStream.add(e));
    } else {
      localEventSubscription?.cancel();
    }
  }

  Stream<int> downloadSpeedStream() {
    return sessionStatusRefresher
        .updateStream()
        .map((s) => s.payloadDownloadRate.toInt());
  }

  Stream<int> uploadSpeedStream() {
    return sessionStatusRefresher
        .updateStream()
        .map((s) => s.payloadUploadRate.toInt());
  }

  @override
  Stream<DelugeRpcEvent> getDelugeRpcEvents() {
    return eventsStream.stream;
  }

  @override
  Future<String> getDaemonInfo() {
    if (client == null) return null;
    return client.daemonInfo();
  }

  @override
  Stream<String> getSessionDownloadSpeed(ByteSizeStyle style) {
    var formatter = ByteSizeFormatter.of(style);
    return downloadSpeedStream().map((s) => "${formatter.format(s)}/s");
  }

  @override
  Stream<String> getSessionUploadSpeed(ByteSizeStyle style) {
    var formatter = ByteSizeFormatter.of(style);
    return uploadSpeedStream().map((s) => "${formatter.format(s)}/s");
  }

  @override
  Stream<List<SessionStatus>> getSessionStatusHistory() {
    return sessionStatusHistory.stream
        .map((l) => leftpadNull(l, speedHistorySize));
  }

  List<T> leftpadNull<T>(List<T> input, int totalLength) {
    if (input.length >= totalLength) return input;
    var padding =
        List<T>.filled(totalLength - input.length, null, growable: true);
    return padding..addAll(input);
  }

  @override
  Future<int> getDownloadSpeedLimit() async {
    if (client == null) return null;
    num result = await client.getConfigValue("max_download_speed");
    return result.toInt();
  }

  @override
  Future setDownloadSpeedLimit(int kibps) {
    if (client == null) return null;
    return client.setConfig({"max_download_speed": kibps.toString()});
  }

  @override
  Future<int> getUploadSpeedLimit() async {
    if (client == null) return null;
    num result = await client.getConfigValue("max_upload_speed");
    return result.toInt();
  }

  @override
  Future setUploadSpeedLimit(int kibps) {
    if (client == null) return null;
    return client.setConfig({"max_upload_speed": kibps.toString()});
  }

  @override
  Future<AddTorrentDefaultOptions> getAddTorrentDefaultOptions() {
    if (client == null) return null;
    return client.getAddTorrentDefaultOptions();
  }

  @override
  Future addTorrentUrl(String url, Map<String, Object> options) {
    if (client == null) return null;
    if (url.startsWith("magnet")) {
      return client.addTorrentMagnet(url, options);
    } else {
      return client.addTorrentUrl(url, options);
    }
  }

  @override
  Future addTorrentFile(
      String fileName, String fileDump, Map<String, Object> options) {
    if (client == null) return null;
    return client.addTorrentFile(fileName, fileDump, options);
  }

  @override
  Future<FilterTree> getFilterTree() {
    if (client == null) return null;
    return filterTreeRefresher.updateStream().first;
  }

  @override
  Future<List<TorrentItem>> getTorrentList(
      Map<String, Object> filterDict) async {
    if (client == null) return null;

    Map<String, TorrentListItem> torrentList =
        await client.getTorrentsList(filterDict);

    return torrentList.entries.map((e) => TorrentItem(e.key, e.value)).toList();
  }

  @override
  void subscribeForTorrentListUpdates(TorrentItem item) {
    torrentListRefresher.torrentsWhichNeedUpdates.add(item);
  }

  @override
  void unsubscribeFromTorrentListUpdates(TorrentItem item) {
    torrentListRefresher.torrentsWhichNeedUpdates.remove(item);
  }

  @override
  Stream<List<TorrentItem>> getTorrentListUpdates() {
    return torrentListRefresher.updateStream();
  }

  @override
  void unsubscribeFromAllTorrentUpdates() {
    torrentListRefresher.torrentsWhichNeedUpdates.clear();
  }

  @override
  Stream<TorrentDetail> getTorrentDetails(String torrentId) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    torrentDetailRefresher.torrentId = torrentId;
    torrentDetailRefresher.clearData();
    return Observable.merge([
      Stream.fromFuture(client.getTorrentDetails(torrentId)),
      torrentDetailRefresher.updateStream()
    ]);
  }

  @override
  Future pauseTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.pauseTorrents(torrentIds);
  }

  @override
  Future resumeTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.resumeTorrents(torrentIds);
  }

  @override
  Future recheckTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.forceRecheck(torrentIds);
  }

  @override
  Future reAnnounceTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.forceReAnnounce(torrentIds);
  }

  @override
  Future<bool> removeTorrent(String torrentId, bool removeData) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.removeTorrent(torrentId, removeData);
  }

  @override
  Future<List<Object>> removeTorrents(
      List<String> torrentIds, bool removeData) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.removeTorrents(torrentIds, removeData);
  }

  @override
  Future<bool> moveStorage(String torrentId, String path) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.moveStorage([torrentId], path);
  }

  @override
  Future<List<String>> getLabels() {
    if (client == null || client.isDisposed) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.getLabels();
  }

  @override
  Future setTorrentLabel(String torrentId, String label) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    torrentListRefresher.clearData();
    torrentDetailRefresher.clearData();
    return client.setTorrentLabel(torrentId, label);
  }

  @override
  Future<TorrentFiles> getTorrentFiles(String torrentId) async {
    if (client == null || torrentId == null || torrentId.isEmpty) return null;
    return await client.getTorrentFileList(torrentId);
  }

  @override
  Stream<TorrentFiles> getTorrentFilesUpdate(String torrentId) {
    torrentFileListRefresher.torrentId = torrentId;
    torrentFileListRefresher.clearData();
    return Observable.merge([
      Stream.fromFuture(getTorrentFiles(torrentId)),
      torrentFileListRefresher.updateStream()
    ]);
  }

  @override
  Future renameFile(String torrentId, int index, String newName) {
    if (client == null || torrentId == null || torrentId.isEmpty) return null;
    return client.renameTorrentFiles(torrentId, [
      [index, newName]
    ]);
  }

  @override
  Future renameFolder(String torrentId, String oldName, String newName) {
    if (client == null || torrentId == null || torrentId.isEmpty) return null;
    return client.renameTorrentFolder(torrentId, oldName, newName);
  }

  @override
  Stream<Peers> getTorrentPeers(String torrentId) {
    torrentPeerListRefresher.torrentId = torrentId;
    torrentPeerListRefresher.clearData();
    return Observable.merge([
      Stream.fromFuture(client.getTorrentPeers(torrentId)),
      torrentPeerListRefresher.updateStream()
    ]);
  }

  @override
  Future setTorrentFilePriorities(String torrentId, List<int> priorities) {
    if (client == null || client.isDisposed) return null;
    return client
        .setTorrentOptions([torrentId], {'file_priorities': priorities});
  }

  @override
  Future<TorrentOptions> getTorrentOptions(String torrentId) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    return client.getTorrentOptions(torrentId);
  }

  @override
  Stream<TorrentOptions> getTorrentOptionsUpdates(String torrentId) {
    torrentOptionsRefresher.torrentId = torrentId;
    torrentOptionsRefresher.clearData();
    return Observable.merge([
      Stream.fromFuture(getTorrentOptions(torrentId)),
      torrentOptionsRefresher.updateStream()
    ]);
  }

  @override
  Future setTorrentPrioritiseFirstLast(
      String torrentId, bool prioritiseFirstLast) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client.setTorrentOptions(
        [torrentId], {"prioritize_first_last_pieces": prioritiseFirstLast});
  }

  @override
  Future setTorrentMoveCompletedPath(
      String torrentId, String moveCompletedPath) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client.setTorrentOptions(
        [torrentId], {"move_completed_path": moveCompletedPath});
  }

  @override
  Future setTorrentMoveCompleted(String torrentId, bool moveCompleted) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client
        .setTorrentOptions([torrentId], {"move_completed": moveCompleted});
  }

  @override
  Future setTorrentRemoveAtRatio(String torrentId, bool removeAtRatio) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client
        .setTorrentOptions([torrentId], {"remove_at_ratio": removeAtRatio});
  }

  @override
  Future setTorrentStopRatio(String torrentId, double stopRatio) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client.setTorrentOptions([torrentId], {"stop_ratio": stopRatio});
  }

  @override
  Future setTorrentStopAtRatio(String torrentId, bool stopAtRatio) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client
        .setTorrentOptions([torrentId], {"stop_at_ratio": stopAtRatio});
  }

  @override
  Future setTorrentAutoManaged(String torrentId, bool autoManaged) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client.setTorrentOptions([torrentId], {"auto_managed": autoManaged});
  }

  @override
  Future setTorrentMaxUploadSlots(String torrentId, int maxUploadSlots) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client
        .setTorrentOptions([torrentId], {"max_upload_slots": maxUploadSlots});
  }

  @override
  Future setTorrentMaxConnections(String torrentId, int maxConnections) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client
        .setTorrentOptions([torrentId], {"max_connections": maxConnections});
  }

  @override
  Future setTorrentMaxUploadSpeed(String torrentId, int maxSpeed) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client
        .setTorrentOptions([torrentId], {"max_upload_speed": maxSpeed});
  }

  @override
  Future setTorrentMaxDownloadSpeed(String torrentId, int maxSpeed) {
    if (client == null || client.isDisposed) return null;
    torrentOptionsRefresher.clearData();
    return client
        .setTorrentOptions([torrentId], {"max_download_speed": maxSpeed});
  }
}

class _BootlegTakeLastTransformer<T> extends StreamTransformerBase<T, List<T>> {
  final int count;

  _BootlegTakeLastTransformer(this.count);

  @override
  Stream<List<T>> bind(Stream<T> stream) =>
      _buildTransformer<T>(count).bind(stream);

  static StreamTransformer<T, List<T>> _buildTransformer<T>(int count) {
    return new StreamTransformer<T, List<T>>(
        (Stream<T> input, bool cancelOnError) {
      StreamController<List<T>> controller;
      StreamSubscription<T> subscription;
      ListQueue<T> buffer = new ListQueue();

      void onDone() {
        if (controller.isClosed) return;

        if (buffer.isNotEmpty) controller.add(new List<T>.unmodifiable(buffer));

        controller.close();
      }

      controller = new StreamController<List<T>>(
          sync: true,
          onListen: () {
            try {
              subscription = input.listen((data) {
                if (buffer.length == count) {
                  buffer.removeFirst();
                }
                buffer.add(data);
                controller.add(buffer.toList());
              },
                  onError: controller.addError,
                  onDone: onDone,
                  cancelOnError: cancelOnError);
            } catch (e, s) {
              controller.addError(e, s);
            }
          },
          onPause: ([Future<dynamic> resumeSignal]) =>
              subscription.pause(resumeSignal),
          onResume: () => subscription.resume(),
          onCancel: () => subscription.cancel());

      return controller.stream.listen(null);
    });
  }
}

abstract class _Refresher<T> {
  Stream<T> updateStream();

  Future refresh(TriremeRepository repository);

  void publish();

  void dispose();
}

abstract class _BasicRefresher<T> extends _Refresher<T> {
  StreamController<T> _streamController;
  T _data;

  _BasicRefresher() {
    _streamController = StreamController.broadcast();
  }

  @override
  Stream<T> updateStream() => _streamController.stream;

  @override
  void publish() {
    if (_streamController.hasListener && _data != null) {
      _streamController.add(_data);
    }
  }

  @override
  void dispose() {
    _streamController.close();
    clearData();
  }

  void clearData() {
    _data = null;
  }
}

typedef Future<T> _RefreshCallback<T>(TriremeRepository repository);

class _SimpleRefresher<T> extends _BasicRefresher<T> {
  _RefreshCallback<T> refreshCallback;

  _SimpleRefresher(this.refreshCallback) {
    _streamController = StreamController.broadcast();
  }

  @override
  Future refresh(TriremeRepository repository) async {
    if (_streamController.hasListener) {
      _data = await refreshCallback(repository);
    }
  }
}

class _TorrentListRefresher extends _BasicRefresher<List<TorrentItem>> {
  List<TorrentItem> torrentsWhichNeedUpdates = [];

  _TorrentListRefresher() {
    _data = [];
  }

  @override
  Future refresh(TriremeRepository repository) async {
    if (torrentsWhichNeedUpdates.isEmpty) return Future.value([]);

    var torrentIdsForUpdate =
        torrentsWhichNeedUpdates.map((t) => t.id).toList();
    _data = await repository.getTorrentList({"id": torrentIdsForUpdate});
  }
}

class _TorrentDetailRefresher extends _BasicRefresher<TorrentDetail> {
  String torrentId;

  @override
  Future refresh(TriremeRepository repository) async {
    if (torrentId != null && _streamController.hasListener) {
      _data = await repository.client.getTorrentDetails(torrentId);
    }
  }
}

class _TorrentPeerListRefresher extends _BasicRefresher<Peers> {
  String torrentId;

  @override
  Future refresh(TriremeRepository repository) async {
    if (torrentId != null && _streamController.hasListener) {
      _data = await repository.client.getTorrentPeers(torrentId);
    }
  }
}

class _TorrentFileListRefresher extends _BasicRefresher<TorrentFiles> {
  String torrentId;

  @override
  Future refresh(TriremeRepository repository) async {
    if (torrentId != null && _streamController.hasListener) {
      _data = await repository.getTorrentFiles(torrentId);
    }
  }
}

class _TorrentOptionsRefresher extends _BasicRefresher<TorrentOptions> {
  String torrentId;

  @override
  Future refresh(TriremeRepository repository) async {
    if (torrentId != null && _streamController.hasListener) {
      _data = await repository.getTorrentOptions(torrentId);
    }
  }
}
