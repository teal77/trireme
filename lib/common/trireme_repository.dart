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

import 'package:rxdart/rxdart.dart';

import 'package:trireme_client/events.dart';
import 'package:trireme_client/deserialization.dart';
import 'package:trireme_client/trireme_client.dart';

import 'package:trireme/common/bytesize.dart';
import 'package:trireme/common/log.dart';
import 'package:trireme/torrent_list/torrent_item.dart';

class TriremeRepository {
  static const _tag = "_TriremeRepositoryImpl";
  static const Duration _refreshInterval = Duration(seconds: 2);
  static const _speedHistorySize = 60;

  TriremeClient _client;
  StreamController<bool> _readinessStream = StreamController.broadcast();
  StreamController<Object> _errorStream = StreamController.broadcast();

  Observable<void> _clockStream;

  bool _isPaused = false;
  bool _isResumed = false;
  bool _isDisposed = false;

  StreamController<DelugeRpcEvent> _eventsStream;
  StreamSubscription<DelugeRpcEvent> _localEventSubscription;
  Stream<SessionStatus> _sessionStatusStream;
  BehaviorSubject<List<SessionStatus>> _sessionStatusHistory;
  StreamSubscription<List<SessionStatus>> _localSessionStatusSubscription;

  List<TorrentItem> _torrentsWhichNeedUpdates = [];

  TriremeRepository() {
    init();
  }

  set client(TriremeClient client) {
    _client = client;
    _readinessStream.add(client != null);
    if (client != null) {
      _localEventSubscription?.cancel();
      _localEventSubscription =
          client.delugeRpcEvents().listen((e) => _eventsStream.add(e));
    } else {
      _localEventSubscription?.cancel();
    }
  }

  TriremeClient get client => _client;

  bool isReady() => _client != null;

  Future readiness() => _readinessStream.stream.firstWhere((b) => b);

  Stream<Object> errorStream() => _errorStream.stream;

  void init() {
    _readinessStream = StreamController.broadcast();
    _errorStream = StreamController.broadcast();

    _clockStream = Observable.periodic(_refreshInterval)
        .takeWhile((_) => !_isDisposed)
        .where((_) => _isResumed)
        .asBroadcastStream();

    _eventsStream = StreamController.broadcast();
    _sessionStatusHistory = BehaviorSubject<List<SessionStatus>>();

    resume();
  }

  void resume() {
    if (_isResumed) {
      throw "Resume called while already resumed";
    }
    Log.d(_tag, "Resumed");
    _isPaused = false;
    _isResumed = true;
    startRecordingSpeedHistory();
  }

  void pause() {
    if (_isPaused) {
      throw "Pause called while already paused";
    }
    Log.d(_tag, "Paused");
    _isResumed = false;
    _isPaused = true;
    stopRecordingSpeedHistory();
  }

  void dispose() {
    Log.d(_tag, "Disposed");
    pause();
    _eventsStream.close();
    _sessionStatusHistory.close();
    _isDisposed = true;
    _readinessStream.close();
    _errorStream.close();
  }

  Future<Response<SessionStatus>> _getSessionStatus() {
    if (_client == null || _client.isDisposed) {
      return null;
    } else {
      return _client.getSessionStatus();
    }
  }

  T _unpackResponse<T>(Response<T> response) {
    return response.response;
  }

  bool _isResponseValid<T>(Response<T> response) {
    return response.requestId > _staleRequestCode;
  }

  var _staleRequestCode = 0;

  void _invalidateEverythingBefore(int requestCode) {
    _staleRequestCode = requestCode;
  }

  Stream<SessionStatus> _getSessionStatusStream() {
    if (_sessionStatusStream == null) {
      _sessionStatusStream = _clockStream
          .flatMap((_) => Stream.fromFuture(_getSessionStatus()))
          .transform(_SyncWithClockStream(_clockStream))
          .doOnError((e) => _errorStream.add(e))
          .transform(_RetryTransformer())
          .asBroadcastStream()
          .where(_isResponseValid)
          .map(_unpackResponse);
    }
    return _sessionStatusStream;
  }

  void startRecordingSpeedHistory() {
    _localSessionStatusSubscription = _getSessionStatusStream()
        .transform(new _BootlegTakeLastTransformer(_speedHistorySize))
        .listen((s) => _sessionStatusHistory.add(s));
  }

  void stopRecordingSpeedHistory() {
    _localSessionStatusSubscription.cancel();
  }

  Stream<int> _downloadSpeedStream() {
    return _getSessionStatusStream().map((s) => s.payloadDownloadRate.toInt());
  }

  Stream<int> _uploadSpeedStream() {
    return _getSessionStatusStream().map((s) => s.payloadUploadRate.toInt());
  }

  Stream<DelugeRpcEvent> getDelugeRpcEvents() {
    return _eventsStream.stream;
  }

  Future<String> getDaemonInfo() {
    if (client == null) return null;
    return client.daemonInfo();
  }

  Stream<String> getSessionDownloadSpeed(ByteSizeStyle style) {
    var formatter = ByteSizeFormatter.of(style);
    return _downloadSpeedStream().map((s) => "${formatter.format(s)}/s");
  }

  Stream<String> getSessionUploadSpeed(ByteSizeStyle style) {
    var formatter = ByteSizeFormatter.of(style);
    return _uploadSpeedStream().map((s) => "${formatter.format(s)}/s");
  }

  Stream<List<SessionStatus>> getSessionStatusHistory() {
    return _sessionStatusHistory.stream
        .map((l) => _leftpadNull(l, _speedHistorySize));
  }

  List<T> _leftpadNull<T>(List<T> input, int totalLength) {
    if (input.length >= totalLength) return input;
    var padding =
        List<T>.filled(totalLength - input.length, null, growable: true);
    return padding..addAll(input);
  }

  Future<int> getDownloadSpeedLimit() async {
    if (client == null) return null;
    num result = (await client.getConfigValue("max_download_speed")) as num;
    return result.toInt();
  }

  Future setDownloadSpeedLimit(int kibps) {
    if (client == null) return null;
    return client.setConfig({"max_download_speed": kibps.toString()});
  }

  Future<int> getUploadSpeedLimit() async {
    if (client == null) return null;
    num result = (await client.getConfigValue("max_upload_speed")) as num;
    return result.toInt();
  }

  Future setUploadSpeedLimit(int kibps) {
    if (client == null) return null;
    return client.setConfig({"max_upload_speed": kibps.toString()});
  }

  Future<AddTorrentDefaultOptions> getAddTorrentDefaultOptions() {
    if (client == null) return null;
    return client.getAddTorrentDefaultOptions();
  }

  Future addTorrentUrl(String url, Map<String, Object> options) {
    if (client == null) return null;
    if (url.startsWith("magnet")) {
      return client.addTorrentMagnet(url, options);
    } else {
      return client.addTorrentUrl(url, options);
    }
  }

  Future addTorrentFile(
      String fileName, String fileDump, Map<String, Object> options) {
    if (client == null) return null;
    return client.addTorrentFile(fileName, fileDump, options);
  }

  Future<FilterTree> getFilterTree() {
    if (client == null) return null;
    return client.getFilterTree();
  }

  Future<List<TorrentItem>> getTorrentList(
      Map<String, Object> filterDict) async {
    if (client == null) return null;
    var torrentList = await _getTorrentList(filterDict);
    return torrentList.response.entries
        .map((e) => TorrentItem(e.key, e.value))
        .toList();
  }

  Future<Response<Map<String, TorrentListItem>>> _getTorrentList(
      Map<String, Object> filterDict) async {
    if (client == null) return null;
    return await client.getTorrentsList(filterDict);
  }

  void subscribeForTorrentListUpdates(TorrentItem item) {
    _torrentsWhichNeedUpdates.add(item);
  }

  void unsubscribeFromTorrentListUpdates(TorrentItem item) {
    _torrentsWhichNeedUpdates.remove(item);
  }

  Future<Response<List<TorrentItem>>> _getTorrentUpdate() async {
    if (_torrentsWhichNeedUpdates.isEmpty)
      return Future.value(Response("", 0, []));
    var torrentIdsForUpdate =
        _torrentsWhichNeedUpdates.map((t) => t.id).toList();
    var r = await _getTorrentList({"id": torrentIdsForUpdate});
    return Response(r.apiName, r.requestId,
        r.response.entries.map((e) => TorrentItem(e.key, e.value)).toList());
  }

  Stream<List<TorrentItem>> getTorrentListUpdates() {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_getTorrentUpdate()))
        .transform(_SyncWithClockStream(_clockStream))
        .mergeWith([Stream.fromFuture(_getTorrentUpdate())])
        .doOnError((e) => _errorStream.add(e))
        .transform(_RetryTransformer())
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  void unsubscribeFromAllTorrentUpdates() {
    _torrentsWhichNeedUpdates.clear();
  }

  Stream<TorrentDetail> getTorrentDetails(String torrentId) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_client.getTorrentDetails(torrentId)))
        .transform(_SyncWithClockStream(_clockStream))
        .mergeWith([Stream.fromFuture(_client.getTorrentDetails(torrentId))])
        .doOnError((e) => _errorStream.add(e))
        .transform(_RetryTransformer())
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  void _invalidateOldResponses() {
    _invalidateEverythingBefore(client.latestRequestId);
  }

  Future pauseTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    _invalidateOldResponses();
    return client.pauseTorrents(torrentIds);
  }

  Future resumeTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    _invalidateOldResponses();
    return client.resumeTorrents(torrentIds);
  }

  Future recheckTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    _invalidateOldResponses();
    return client.forceRecheck(torrentIds);
  }

  Future reAnnounceTorrents(List<String> torrentIds) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    _invalidateOldResponses();
    return client.forceReAnnounce(torrentIds);
  }

  Future<bool> removeTorrent(String torrentId, bool removeData) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    _invalidateOldResponses();
    return client.removeTorrent(torrentId, removeData);
  }

  Future<List<Object>> removeTorrents(
      List<String> torrentIds, bool removeData) {
    if (client == null || client.isDisposed || torrentIds.isEmpty) return null;
    _invalidateOldResponses();
    return client.removeTorrents(torrentIds, removeData);
  }

  Future<bool> moveStorage(String torrentId, String path) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    _invalidateOldResponses();
    return client.moveStorage([torrentId], path);
  }

  Future<List<String>> getLabels() {
    if (client == null || client.isDisposed) return null;
    return client.getLabels();
  }

  Future setTorrentLabel(String torrentId, String label) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    _invalidateOldResponses();
    return client.setTorrentLabel(torrentId, label);
  }

  Future<Response<TorrentFiles>> _getTorrentFiles(String torrentId) async {
    if (client == null || torrentId == null || torrentId.isEmpty) return null;
    return await client.getTorrentFileList(torrentId);
  }

  Stream<TorrentFiles> getTorrentFilesUpdate(String torrentId) {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_getTorrentFiles(torrentId)))
        .transform(_SyncWithClockStream(_clockStream))
        .mergeWith([Stream.fromFuture(_getTorrentFiles(torrentId))])
        .doOnError((e) => _errorStream.add(e))
        .transform(_RetryTransformer())
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  Future renameFile(String torrentId, int index, String newName) {
    if (client == null || torrentId == null || torrentId.isEmpty) return null;
    _invalidateOldResponses();
    return client.renameTorrentFiles(torrentId, [
      [index, newName]
    ]);
  }

  Future renameFolder(String torrentId, String oldName, String newName) {
    if (client == null || torrentId == null || torrentId.isEmpty) return null;
    _invalidateOldResponses();
    return client.renameTorrentFolder(torrentId, oldName, newName);
  }

  Stream<Peers> getTorrentPeers(String torrentId) {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_client.getTorrentPeers(torrentId)))
        .transform(_SyncWithClockStream(_clockStream))
        .mergeWith([Stream.fromFuture(_client.getTorrentPeers(torrentId))])
        .doOnError((e) => _errorStream.add(e))
        .transform(_RetryTransformer())
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  Future setTorrentFilePriorities(String torrentId, List<int> priorities) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {'file_priorities': priorities});
  }

  Future<Response<TorrentOptions>> _getTorrentOptions(String torrentId) {
    if (client == null || client.isDisposed || torrentId.isEmpty) return null;
    return client.getTorrentOptions(torrentId);
  }

  Stream<TorrentOptions> getTorrentOptionsUpdates(String torrentId) {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_getTorrentOptions(torrentId)))
        .transform(_SyncWithClockStream(_clockStream))
        .mergeWith([Stream.fromFuture(_getTorrentOptions(torrentId))])
        .doOnError((e) => _errorStream.add(e))
        .transform(_RetryTransformer())
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  Future setTorrentPrioritiseFirstLast(
      String torrentId, bool prioritiseFirstLast) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], {"prioritize_first_last_pieces": prioritiseFirstLast});
  }

  Future setTorrentMoveCompletedPath(
      String torrentId, String moveCompletedPath) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], {"move_completed_path": moveCompletedPath});
  }

  Future setTorrentMoveCompleted(String torrentId, bool moveCompleted) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {"move_completed": moveCompleted});
  }

  Future setTorrentRemoveAtRatio(String torrentId, bool removeAtRatio) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {"remove_at_ratio": removeAtRatio});
  }

  Future setTorrentStopRatio(String torrentId, double stopRatio) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client.setTorrentOptions([torrentId], {"stop_ratio": stopRatio});
  }

  Future setTorrentStopAtRatio(String torrentId, bool stopAtRatio) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {"stop_at_ratio": stopAtRatio});
  }

  Future setTorrentAutoManaged(String torrentId, bool autoManaged) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client.setTorrentOptions([torrentId], {"auto_managed": autoManaged});
  }

  Future setTorrentMaxUploadSlots(String torrentId, int maxUploadSlots) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {"max_upload_slots": maxUploadSlots});
  }

  Future setTorrentMaxConnections(String torrentId, int maxConnections) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {"max_connections": maxConnections});
  }

  Future setTorrentMaxUploadSpeed(String torrentId, int maxSpeed) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {"max_upload_speed": maxSpeed});
  }

  Future setTorrentMaxDownloadSpeed(String torrentId, int maxSpeed) {
    if (client == null || client.isDisposed) return null;
    _invalidateOldResponses();
    return client
        .setTorrentOptions([torrentId], {"max_download_speed": maxSpeed});
  }
}

class _RetryTransformer<T> extends StreamTransformerBase<T, T> {
  @override
  Stream<T> bind(Stream<T> stream) {
    return Observable.retry(() => stream);
  }
}

class _SyncWithClockStream<T> extends StreamTransformerBase<T, T> {
  Stream<void> clockStream;

  _SyncWithClockStream(this.clockStream);

  @override
  Stream<T> bind(Stream<T> stream) {
    return clockStream
        .transform(WithLatestFromStreamTransformer(stream, (_, T e) => e));
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
