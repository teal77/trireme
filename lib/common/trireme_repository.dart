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

import 'package:collection/collection.dart';
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

  Future<Response<SessionStatus>> _getSessionStatus() {
    if (_client == null || _client!.isDisposed) {
      return Future.error("Client not initialized");
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
    _sessionStatusStream ??= _clockStream
          .flatMap((_) => Stream.fromFuture(_getSessionStatus()))
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
    if (filterDict.isNotEmpty) {
      return await client.getTorrentsList(filterDict);
    }

    var allIds = await client.getSessionState();
    if (allIds.length <= 500) {
      return await client.getTorrentsList(filterDict);
    }

    return await Stream.fromIterable(allIds.slices(500))
        .flatMap(
          (chunk) => Stream.fromFuture(
              client.getTorrentsList({'id': chunk})),
          maxConcurrent: 2,
        )
        .fold(
          Response('', 0, <String, TorrentListItem>{}),
          (acc, r) => Response(
            r.apiName,
            r.requestId,
            {...acc.response, ...r.response},
          ),
        );
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

  Future pauseTorrents(List<String> torrentIds) async {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("Error");
    var result = await client.pauseTorrents(torrentIds);
    _invalidateOldResponses();
    return result;
  }

  Future resumeTorrents(List<String> torrentIds) async {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("Error");
    var result = await client.resumeTorrents(torrentIds);
    _invalidateOldResponses();
    return result;
  }

  Future recheckTorrents(List<String> torrentIds) async {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("error");
    var result = await client.forceRecheck(torrentIds);
    _invalidateOldResponses();
    return result;
  }

  Future reAnnounceTorrents(List<String> torrentIds) async {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("error");
    var result = await client.forceReAnnounce(torrentIds);
    _invalidateOldResponses();
    return result;
  }

  Future<bool> removeTorrent(String torrentId, bool removeData) async {
    if (client.isDisposed || torrentId.isEmpty) return Future.error("error");
    var result = await client.removeTorrent(torrentId, removeData);
    _invalidateOldResponses();
    return result;
  }

  Future<List<Object>> removeTorrents(
      List<String> torrentIds, bool removeData) async {
    if (client.isDisposed || torrentIds.isEmpty) return Future.error("error");
    var result = await client.removeTorrents(torrentIds, removeData);
    _invalidateOldResponses();
    return result;
  }

  Future<bool> moveStorage(String torrentId, String path) async {
    if (client.isDisposed || torrentId.isEmpty) return Future.error("error");
    var result = await client.moveStorage([torrentId], path);
    _invalidateOldResponses();
    return result;
  }

  Future<List<String>> getLabels() {
    if (client.isDisposed) return Future.error("error");
    return client.getLabels();
  }

  Future setTorrentLabel(String torrentId, String label) async {
    if (client.isDisposed || torrentId.isEmpty) return Future.error("error");
    var result = await client.setTorrentLabel(torrentId, label);
    _invalidateOldResponses();
    return result;
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

  Future renameFile(String torrentId, int index, String newName) async {
    if (torrentId.isEmpty) return Future.error("error");
    var result = await client.renameTorrentFiles(torrentId, [
      <Object>[index, newName]
    ]);
    _invalidateOldResponses();
    return result;
  }

  Future renameFolder(String torrentId, String oldName, String newName) async {
    if (torrentId.isEmpty) return Future.error("error");
    var result = await client.renameTorrentFolder(torrentId, oldName, newName);
    _invalidateOldResponses();
    return result;
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

  Future setTorrentFilePriorities(String torrentId, List<int> priorities) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{'file_priorities': priorities});
    _invalidateOldResponses();
    return result;
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
      String torrentId, bool prioritiseFirstLast) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions([torrentId],
        <String, Object>{"prioritize_first_last_pieces": prioritiseFirstLast});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentMoveCompletedPath(
      String torrentId, String moveCompletedPath) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions([torrentId],
        <String, Object>{"move_completed_path": moveCompletedPath});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentMoveCompleted(String torrentId, bool moveCompleted) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"move_completed": moveCompleted});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentRemoveAtRatio(String torrentId, bool removeAtRatio) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"remove_at_ratio": removeAtRatio});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentStopRatio(String torrentId, double stopRatio) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"stop_ratio": stopRatio});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentStopAtRatio(String torrentId, bool stopAtRatio) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"stop_at_ratio": stopAtRatio});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentAutoManaged(String torrentId, bool autoManaged) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"auto_managed": autoManaged});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentMaxUploadSlots(String torrentId, int maxUploadSlots) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"max_upload_slots": maxUploadSlots});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentMaxConnections(String torrentId, int maxConnections) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"max_connections": maxConnections});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentMaxUploadSpeed(String torrentId, int maxSpeed) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"max_upload_speed": maxSpeed});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentMaxDownloadSpeed(String torrentId, int maxSpeed) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentOptions(
        [torrentId], <String, Object>{"max_download_speed": maxSpeed});
    _invalidateOldResponses();
    return result;
  }

  Future setTorrentTrackers(String torrentId, List<Map> trackers) async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.setTorrentTrackers(torrentId, trackers);
    _invalidateOldResponses();
    return result;
  }

  Future getFreeSpace() async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.getFreeSpace("");
    _invalidateOldResponses();
    return result;
  }

  Future<bool> isSessionPaused() async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.isSessionPaused();
    _invalidateOldResponses();
    return result;
  }

  Future pauseSession() async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.pauseSession();
    _invalidateOldResponses();
    return result;
  }

  Future resumeSession() async {
    if (client.isDisposed) return Future.error("error");
    var result = await client.resumeSession();
    _invalidateOldResponses();
    return result;
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
