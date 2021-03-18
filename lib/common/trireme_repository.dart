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

  TriremeClient? _client;
  StreamController<bool> _readinessStream = StreamController.broadcast();
  StreamController<Object> _errorStream = StreamController.broadcast();

  late Stream<void> _clockStream;

  bool _isPaused = false;
  bool _isResumed = false;
  bool _isDisposed = false;

  StreamController<DelugeRpcEvent>? _eventsStream;
  StreamSubscription<DelugeRpcEvent>? _localEventSubscription;
  Stream<SessionStatus>? _sessionStatusStream;
  BehaviorSubject<List<SessionStatus>>? _sessionStatusHistory;
  StreamSubscription<List<SessionStatus>>? _localSessionStatusSubscription;

  final List<TorrentItem> _torrentsWhichNeedUpdates = [];

  TriremeRepository() {
    init();
  }

  set client(TriremeClient? client) {
    _readinessStream.add(client != null);
    if (client != null) {
      _client = client;
      _localEventSubscription?.cancel();
      _localEventSubscription =
          client.delugeRpcEvents().listen((e) => _eventsStream?.add(e));
    } else {
      _localEventSubscription?.cancel();
      _client?.dispose();
    }
  }

  TriremeClient get client => _client!;

  bool isReady() => _client != null;

  Future readiness() => _readinessStream.stream.firstWhere((b) => b);

  Stream<Object> errorStream() => _errorStream.stream;

  void init() {
    _readinessStream = StreamController.broadcast();
    _errorStream = StreamController.broadcast();

    _clockStream = Stream<void>.periodic(_refreshInterval)
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
    _eventsStream?.close();
    _sessionStatusHistory?.close();
    _isDisposed = true;
    _readinessStream.close();
    _errorStream.close();
  }

  Future<Response<SessionStatus>>? _getSessionStatus() {
    if (_client == null || _client!.isDisposed) {
      return null;
    } else {
      return _client!.getSessionStatus();
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
    var sessionStatus = _getSessionStatus();
    _sessionStatusStream ??= _clockStream
          .flatMap((_) => Stream.fromFutures([ if (sessionStatus != null) sessionStatus]))
          .retry()
          .syncWithClockStream(_clockStream)
          .doOnError((e, _) => _errorStream.add(e))
          .asBroadcastStream()
          .where(_isResponseValid)
          .map(_unpackResponse);
    return _sessionStatusStream!;
  }

  void startRecordingSpeedHistory() {
    _localSessionStatusSubscription = _getSessionStatusStream()
        .transform(_BootlegTakeLastTransformer(_speedHistorySize))
        .listen((s) => _sessionStatusHistory?.add(s));
  }

  void stopRecordingSpeedHistory() {
    _localSessionStatusSubscription?.cancel();
  }

  Stream<int> _downloadSpeedStream() {
    return _getSessionStatusStream().map((s) => s.payloadDownloadRate.toInt());
  }

  Stream<int> _uploadSpeedStream() {
    return _getSessionStatusStream().map((s) => s.payloadUploadRate.toInt());
  }

  Stream<DelugeRpcEvent> getDelugeRpcEvents() {
    return _eventsStream!.stream;
  }

  Future<String> getDaemonInfo() {
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

  Stream<List<SessionStatus?>> getSessionStatusHistory() {
    return _sessionStatusHistory!.stream
        .map((l) => _leftpadNull(l, _speedHistorySize));
  }

  List<T?> _leftpadNull<T>(List<T> input, int totalLength) {
    if (input.length >= totalLength) return input;
    var padding =
        List<T?>.filled(totalLength - input.length, null, growable: true);
    return padding..addAll(input);
  }

  Future<int> getDownloadSpeedLimit() async {
    var result = (await client.getConfigValue("max_download_speed")) as num;
    return result.toInt();
  }

  Future setDownloadSpeedLimit(int kibps) {
    return client.setConfig({"max_download_speed": kibps.toString()});
  }

  Future<int> getUploadSpeedLimit() async {
    var result = (await client.getConfigValue("max_upload_speed")) as num;
    return result.toInt();
  }

  Future setUploadSpeedLimit(int kibps) {
    return client.setConfig({"max_upload_speed": kibps.toString()});
  }

  Future<AddTorrentDefaultOptions> getAddTorrentDefaultOptions() {
    return client.getAddTorrentDefaultOptions();
  }

  Future addTorrentUrl(String url, Map<String, Object> options) {
    if (url.startsWith("magnet")) {
      return client.addTorrentMagnet(url, options);
    } else {
      return client.addTorrentUrl(url, options);
    }
  }

  Future addTorrentFile(
      String fileName, String fileDump, Map<String, Object> options) {
    return client.addTorrentFile(fileName, fileDump, options);
  }

  Future<FilterTree> getFilterTree() {
    return client.getFilterTree();
  }

  Future<List<TorrentItem>> getTorrentList(
      Map<String, Object> filterDict) async {
    var torrentList = await _getTorrentList(filterDict);
    return torrentList.response.entries
        .map((e) => TorrentItem(e.key, e.value))
        .toList();
  }

  Future<Response<Map<String, TorrentListItem>>> _getTorrentList(
      Map<String, Object> filterDict) async {
    return await client.getTorrentsList(filterDict);
  }

  void subscribeForTorrentListUpdates(TorrentItem item) {
    _torrentsWhichNeedUpdates.add(item);
  }

  void unsubscribeFromTorrentListUpdates(TorrentItem item) {
    _torrentsWhichNeedUpdates.remove(item);
  }

  Future<Response<List<TorrentItem>>> _getTorrentUpdate() async {
    if (_torrentsWhichNeedUpdates.isEmpty) {
      return Future.value(Response("", 0, <TorrentItem>[]));
    }
    var torrentIdsForUpdate =
        _torrentsWhichNeedUpdates.map((t) => t.id).toList();
    var r = await _getTorrentList({"id": torrentIdsForUpdate});
    return Response(r.apiName, r.requestId,
        r.response.entries.map((e) => TorrentItem(e.key, e.value)).toList());
  }

  Stream<List<TorrentItem>> getTorrentListUpdates() {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_getTorrentUpdate()))
        .retry()
        .syncWithClockStream(_clockStream)
        .mergeWith([Stream.fromFuture(_getTorrentUpdate())])
        .doOnError((e, _) => _errorStream.add(e))
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  void unsubscribeFromAllTorrentUpdates() {
    _torrentsWhichNeedUpdates.clear();
  }

  Stream<TorrentDetail> getTorrentDetails(String torrentId) {
    if (client.isDisposed || torrentId.isEmpty) return Stream.empty();
    return _clockStream
        .flatMap((_) => Stream.fromFuture(client.getTorrentDetails(torrentId)))
        .retry()
        .syncWithClockStream(_clockStream)
        .mergeWith([Stream.fromFuture(client.getTorrentDetails(torrentId))])
        .doOnError((e, _) => _errorStream.add(e))
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  void _invalidateOldResponses() {
    _invalidateEverythingBefore(client.latestRequestId);
  }

  Future pauseTorrents(List<String> torrentIds) {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("Error");
    _invalidateOldResponses();
    return client.pauseTorrents(torrentIds);
  }

  Future resumeTorrents(List<String> torrentIds) {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("Error");
    _invalidateOldResponses();
    return client.resumeTorrents(torrentIds);
  }

  Future recheckTorrents(List<String> torrentIds) {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.forceRecheck(torrentIds);
  }

  Future reAnnounceTorrents(List<String> torrentIds) {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.forceReAnnounce(torrentIds);
  }

  Future<bool> removeTorrent(String torrentId, bool removeData) {
    if (client.isDisposed || torrentId.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.removeTorrent(torrentId, removeData);
  }

  Future<List<Object>> removeTorrents(
      List<String> torrentIds, bool removeData) {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.removeTorrents(torrentIds, removeData);
  }

  Future<bool> moveStorage(String torrentId, String path) {
    if (client.isDisposed || torrentId.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.moveStorage([torrentId], path);
  }

  Future<List<String>> getLabels() {
    if (client.isDisposed) return Future.error("error");
    return client.getLabels();
  }

  Future setTorrentLabel(String torrentId, String label) {
    if (client.isDisposed || torrentId.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentLabel(torrentId, label);
  }

  Future<Response<TorrentFiles>> _getTorrentFiles(String torrentId) async {
    if (torrentId.isEmpty) return Future.error("error");
    return await client.getTorrentFileList(torrentId);
  }

  Stream<TorrentFiles> getTorrentFilesUpdate(String torrentId) {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_getTorrentFiles(torrentId)))
        .retry()
        .syncWithClockStream(_clockStream)
        .mergeWith([Stream.fromFuture(_getTorrentFiles(torrentId))])
        .doOnError((e, _) => _errorStream.add(e))
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  Future renameFile(String torrentId, int index, String newName) {
    if (torrentId.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.renameTorrentFiles(torrentId, [
      <Object>[index, newName]
    ]);
  }

  Future renameFolder(String torrentId, String oldName, String newName) {
    if (torrentId.isEmpty) return Future.error("error");
    _invalidateOldResponses();
    return client.renameTorrentFolder(torrentId, oldName, newName);
  }

  Stream<Peers> getTorrentPeers(String torrentId) {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(client.getTorrentPeers(torrentId)))
        .retry()
        .syncWithClockStream(_clockStream)
        .mergeWith([Stream.fromFuture(client.getTorrentPeers(torrentId))])
        .doOnError((e, _) => _errorStream.add(e))
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  Future setTorrentFilePriorities(String torrentId, List<int> priorities) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{'file_priorities': priorities});
  }

  Future<Response<TorrentOptions>> _getTorrentOptions(String torrentId) {
    if (client.isDisposed || torrentId.isEmpty) return Future.error("error");
    return client.getTorrentOptions(torrentId);
  }

  Stream<TorrentOptions> getTorrentOptionsUpdates(String torrentId) {
    return _clockStream
        .flatMap((_) => Stream.fromFuture(_getTorrentOptions(torrentId)))
        .retry()
        .syncWithClockStream(_clockStream)
        .mergeWith([Stream.fromFuture(_getTorrentOptions(torrentId))])
        .doOnError((e, _) => _errorStream.add(e))
        .where(_isResponseValid)
        .map(_unpackResponse);
  }

  Future setTorrentPrioritiseFirstLast(
      String torrentId, bool prioritiseFirstLast) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions([torrentId],
        <String, Object>{"prioritize_first_last_pieces": prioritiseFirstLast});
  }

  Future setTorrentMoveCompletedPath(
      String torrentId, String moveCompletedPath) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions([torrentId],
        <String, Object>{"move_completed_path": moveCompletedPath});
  }

  Future setTorrentMoveCompleted(String torrentId, bool moveCompleted) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"move_completed": moveCompleted});
  }

  Future setTorrentRemoveAtRatio(String torrentId, bool removeAtRatio) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"remove_at_ratio": removeAtRatio});
  }

  Future setTorrentStopRatio(String torrentId, double stopRatio) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"stop_ratio": stopRatio});
  }

  Future setTorrentStopAtRatio(String torrentId, bool stopAtRatio) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"stop_at_ratio": stopAtRatio});
  }

  Future setTorrentAutoManaged(String torrentId, bool autoManaged) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"auto_managed": autoManaged});
  }

  Future setTorrentMaxUploadSlots(String torrentId, int maxUploadSlots) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"max_upload_slots": maxUploadSlots});
  }

  Future setTorrentMaxConnections(String torrentId, int maxConnections) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"max_connections": maxConnections});
  }

  Future setTorrentMaxUploadSpeed(String torrentId, int maxSpeed) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"max_upload_speed": maxSpeed});
  }

  Future setTorrentMaxDownloadSpeed(String torrentId, int maxSpeed) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentOptions(
        [torrentId], <String, Object>{"max_download_speed": maxSpeed});
  }

  Future setTorrentTrackers(String torrentId, List<Map> trackers) {
    if (client.isDisposed) return Future.error("error");
    _invalidateOldResponses();
    return client.setTorrentTrackers(torrentId, trackers);
  }
}

extension _StreamExtensions<T> on Stream<T> {
  Stream<T> retry() {
    return Rx.retry(() => this);
  }

  Stream<T> syncWithClockStream(Stream<void> clockStream) {
    return clockStream.withLatestFrom(this, (_, T e) => e);
  }
}

class _BootlegTakeLastTransformer<T> extends StreamTransformerBase<T, List<T>> {
  final int count;

  _BootlegTakeLastTransformer(this.count);

  @override
  Stream<List<T>> bind(Stream<T> stream) =>
      _buildTransformer<T>(count).bind(stream);

  static StreamTransformer<T, List<T>> _buildTransformer<T>(int count) {
    return StreamTransformer<T, List<T>>((Stream<T> input, bool cancelOnError) {
      late StreamController<List<T>> controller;
      late StreamSubscription<T> subscription;
      var buffer = ListQueue<T>();

      void onDone() {
        if (controller.isClosed) return;

        if (buffer.isNotEmpty) controller.add(List<T>.unmodifiable(buffer));

        controller.close();
      }

      controller = StreamController<List<T>>(
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
          onPause: () => subscription.pause(),
          onResume: () => subscription.resume(),
          onCancel: () => subscription.cancel());

      return controller.stream.listen(null);
    });
  }
}
