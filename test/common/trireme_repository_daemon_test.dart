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

import 'package:flutter_test/flutter_test.dart';
import 'package:trireme_client/testing.dart';
import 'package:trireme_client/trireme_client.dart';

import 'package:trireme/common/trireme_repository.dart';
import 'package:trireme/torrent_list/torrent_item.dart';

import '../support/fixtures.dart';

// The repository driven over a real socket against an in-process daemon.
// trireme_repository_test.dart covers the client-less error paths; everything
// here needs a daemon that answers, because what is under test is the
// interaction between the 2 second polling clock and the calls the user makes
// while a poll is already outstanding.
void main() {
  const torrentId = '0123456789abcdef0123456789abcdef01234567';

  late FakeDelugeDaemon daemon;
  late TriremeClient client;
  late TriremeRepository repository;

  // The daemon answers core.get_torrents_status with this. Every key in
  // torrentListItemKeys has to be present and of the right type: the generated
  // deserializer casts hard, with no fallback, so a missing or int-where-double
  // value fails the whole response rather than the one field.
  Map<String, Object?> torrentStatus(String state, {int totalDone = 1000}) {
    return <String, Object?>{
      'name': 'ubuntu.iso',
      'state': state,
      'progress': 50.0,
      'download_payload_rate': 1000,
      'upload_payload_rate': 500,
      'eta': 60,
      'total_wanted': 2000,
      'total_done': totalDone,
      'total_uploaded': 250,
      'is_finished': false,
      'ratio': 0.5,
      'time_added': 1500000000,
      'completed_time': 0,
      'seeding_time': 0,
      'label': 'linux',
      'tracker_host': 'tracker.example',
    };
  }

  // The session status poll starts with the repository and runs on the same
  // clock as everything else. Answering it keeps it out of the way of the
  // tests that assert on the error stream -- with no handler the daemon
  // reports "no handler for core.get_session_status" every 2 seconds, and an
  // error test would pass on that alone without ever exercising its own call.
  Map<String, Object?> sessionStatus() {
    return <String, Object?>{
      'upload_rate': 0,
      'download_rate': 0,
      'payload_upload_rate': 0,
      'payload_download_rate': 0,
    };
  }

  int callsTo(String method) =>
      daemon.receivedMethods.where((m) => m == method).length;

  Future<void> waitFor(bool Function() condition,
      {Duration timeout = const Duration(seconds: 10),
      required String reason}) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Timed out: $reason');
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  void subscribeOneTorrent() {
    repository.subscribeForTorrentListUpdates(
        TorrentItem(torrentId, buildTorrentListItem()));
  }

  setUp(() async {
    daemon = await FakeDelugeDaemon.start();
    daemon.handle('core.get_session_status', (_) => sessionStatus());
    client = TriremeClient('user', 'password', '127.0.0.1',
        port: daemon.port, pinnedCertificate: fakeDaemonCertificateBytes);
    await client.init();
    // The constructor calls init(), which starts the 2 second clock.
    repository = TriremeRepository()..client = client;
  });

  tearDown(() async {
    // dispose() calls pause(), which throws if the repository is already
    // paused, so this must happen exactly once.
    repository.dispose();
    client.dispose();
    await daemon.stop();
  });

  test('a poll in flight when a mutation lands is discarded', () async {
    var state = 'Downloading';
    var pausedTorrents = <Object?>[];
    daemon.handle('core.get_torrents_status',
        (_) => <String, Object?>{torrentId: torrentStatus(state)});
    daemon.handle('core.pause_torrent', (args) {
      pausedTorrents = args;
      state = 'Paused';
      return null;
    });

    subscribeOneTorrent();

    final emitted = <List<TorrentItem>>[];
    var recording = false;
    final subscription = repository.getTorrentListUpdates().listen((items) {
      if (recording) emitted.add(items);
    }, onError: (Object _) {});
    addTearDown(subscription.cancel);

    // Wait for the clock to issue a poll of its own -- the first call is the
    // merged seed, the second is the first tick. Its answer lands within
    // milliseconds, but the pipeline does not release it until the *next*
    // tick, because syncWithClockStream is a withLatestFrom on the clock. So
    // from here until that tick there is a real, answered poll sitting in
    // flight, which is exactly the window the guard exists for.
    await waitFor(() => callsTo('core.get_torrents_status') >= 2,
        reason: 'the clock never issued a torrent list poll');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    recording = true;
    await repository.pauseTorrents([torrentId]);
    expect(pausedTorrents, [
      [torrentId]
    ]);

    // Past the tick that would have released the held response.
    await Future<void>.delayed(const Duration(milliseconds: 2300));

    expect(emitted, isEmpty,
        reason: 'the poll was issued before the mutation, so its response is '
            'stale and must not reach the UI -- it still says Downloading, and '
            'letting it through is what visually reverts a pause');

    // ...and the pipeline is not simply dead: the poll issued after the
    // mutation does get through, carrying the new state.
    await waitFor(() => emitted.isNotEmpty,
        reason: 'a poll issued after the mutation must still be delivered');
    expect(emitted.first.single.stateString, 'Paused');
  });

  test('a subscribed stream seeds at once and keeps updating', () async {
    var totalDone = 1000;
    daemon.handle(
        'core.get_torrents_status',
        (_) => <String, Object?>{
              torrentId: torrentStatus('Downloading', totalDone: totalDone)
            });

    subscribeOneTorrent();

    final emitted = <List<TorrentItem>>[];
    final subscription = repository
        .getTorrentListUpdates()
        .listen(emitted.add, onError: (Object _) {});
    addTearDown(subscription.cancel);

    // The pipelines mergeWith a seed precisely so the first value does not
    // wait out a clock tick. Without it nothing reaches a StreamBuilder for up
    // to four seconds and the screen sits on its progress bar.
    await waitFor(() => emitted.isNotEmpty,
        timeout: const Duration(seconds: 1),
        reason: 'the seeded first value must not wait for a clock tick');
    expect(emitted.single.single.currentSize, 1000);

    totalDone = 4000;

    await waitFor(() => emitted.length >= 2,
        timeout: const Duration(seconds: 6),
        reason: 'the clock must keep polling after the seed');
    expect(emitted.last.single.currentSize, 4000);
  });

  test('a failing poll reaches the error stream', () async {
    daemon.fail(
        'core.get_torrents_status', 'WrappedException', 'no such torrent');

    subscribeOneTorrent();

    final errors = <Object>[];
    final errorSubscription = repository.errorStream().listen(errors.add);
    addTearDown(errorSubscription.cancel);

    final subscription = repository
        .getTorrentListUpdates()
        .listen((_) {}, onError: (Object _) {});
    addTearDown(subscription.cancel);

    // retry() is unbounded and never forwards an error downstream, so the
    // report has to come off the failing call itself. Nothing else fails here
    // -- the session status poll has a working handler -- so an error on this
    // stream can only have come from the torrent list poll.
    await waitFor(() => errors.isNotEmpty,
        timeout: const Duration(seconds: 5),
        reason: 'a failing poll must be reported on the error stream');
    expect(
        errors.first,
        isA<DelugeRpcError>()
            .having((e) => e.type, 'type', 'WrappedException')
            .having((e) => e.msg, 'msg', 'no such torrent'));
  });

  test('an event still arrives after the client is reinitialised mid-flight',
      () async {
    // Reproduces ClientProviderState.reInitClient's exact sequence on app
    // resume: it calls setClient(null) -- which only *schedules* the widget
    // rebuild that eventually reaches this repository's client setter -- and
    // then, in the same synchronous stretch, calls client.init() again on the
    // same instance. init() replaces the client's internal event stream
    // controller before that scheduled null-branch call ever runs, so the
    // null branch reacts *after* the swap. Disposing the client there closed
    // the brand-new controller instead of the one that was actually meant to
    // be torn down, permanently losing every event for the rest of the app
    // session after the very first background/foreground cycle.
    final events = <DelugeRpcEvent>[];
    final subscription = repository.getDelugeRpcEvents().listen(events.add);
    addTearDown(subscription.cancel);

    await client.init();
    repository.client = null;
    repository.client = client;

    Timer.run(() => daemon.emitEvent('TorrentAddedEvent', [torrentId]));

    await waitFor(
      () => events.isNotEmpty,
      reason: 'an event on a client reinitialised mid-flight never arrived',
    );
    expect(
        events.single,
        isA<TorrentAddedEvent>()
            .having((e) => e.torrentId, 'torrentId', torrentId));
  });
}
