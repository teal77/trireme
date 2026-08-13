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
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trireme_client/testing.dart';
// `show` is not tidiness: package:trireme_client exports a model called
// TorrentListItem, and the app's list tile widget has the same name.
import 'package:trireme_client/trireme_client.dart' show TriremeClient;

import 'package:trireme/common/widgets/selectable.dart';
import 'package:trireme/torrent_list/torrent_list.dart';
import 'package:trireme/torrent_list/torrent_list_controller.dart';
import 'package:trireme/torrent_list/torrent_list_tile/torrent_list_tile.dart';

import '../support/fixtures.dart';
import '../support/pump.dart';

// The torrent list, rendered from data a real daemon served over a real
// socket, under the provider chain main.dart installs. Nothing here is
// stubbed: the rows on screen are what came back from core.get_torrents_status
// by way of TriremeRepository and TorrentListController.
void main() {
  const firstId = '0123456789abcdef0123456789abcdef01234567';
  const secondId = 'fedcba9876543210fedcba9876543210fedcba98';

  late FakeDelugeDaemon daemon;
  late TriremeClient client;

  // What the daemon serves. A test that wants different data reassigns this
  // before pumping.
  late Map<String, Object?> torrents;

  int selectionCount = -1;

  Widget torrentList() {
    return TorrentList(
      GlobalKey<TorrentListState>(),
      SortCriteria.name,
      false,
      FilterSpec.all,
      (count) => selectionCount = count,
    );
  }

  Finder tileFor(String name) => find.ancestor(
      of: find.text(name), matching: find.byType(TorrentListItem));

  bool isSelected(WidgetTester tester, String name) {
    return tester
        .widget<Selectable>(find.descendant(
            of: tileFor(name), matching: find.byType(Selectable)))
        .selected;
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // PreferenceProvider reads the saved byte size style on startup, and the
    // list tile formats sizes with it.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    selectionCount = -1;
    torrents = <String, Object?>{
      firstId: buildTorrentStatus(
          name: 'debian-13.iso',
          state: 'Downloading',
          progress: 40.0,
          totalSize: 5 * 1024 * 1024,
          totalDone: 2 * 1024 * 1024),
      secondId: buildTorrentStatus(
          name: 'ubuntu-24.04.iso',
          state: 'Seeding',
          progress: 100.0,
          isFinished: true,
          totalSize: 6 * 1024 * 1024,
          totalDone: 6 * 1024 * 1024,
          totalUploaded: 3 * 1024 * 1024),
    };

    daemon = await FakeDelugeDaemon.start();
    daemon.handle('core.get_session_state', (_) => torrents.keys.toList());
    daemon.handle('core.get_torrents_status', (_) => torrents);
    daemon.handle(
        'core.get_session_status',
        (_) => <String, Object?>{
              'upload_rate': 0,
              'download_rate': 0,
              'payload_upload_rate': 0,
              'payload_download_rate': 0,
            });

    // The connection has to exist before the widget test starts. A socket
    // opened from inside a widget test never finishes connecting -- FakeAsync
    // owns the timers dart:io's connect logic uses, and nothing advances them
    // -- but a socket that is already open carries bytes fine.
    client = TriremeClient('user', 'password', '127.0.0.1',
        port: daemon.port, pinnedCertificate: fakeDaemonCertificateBytes);
    await client.init();
  });

  tearDown(() async {
    client.dispose();
    await daemon.stop();
  });

  testWidgets('renders a row for every torrent the daemon serves',
      (tester) async {
    await pumpWithProviders(tester, torrentList(), client: client);

    await pumpUntilFound(tester, find.byType(TorrentListItem));

    expect(find.text('debian-13.iso'), findsOneWidget);
    expect(find.text('ubuntu-24.04.iso'), findsOneWidget);
    expect(find.byType(TorrentListItem), findsNWidgets(2));

    // Not just the names. Each row carries the state and the sizes the daemon
    // reported for that torrent, run through the tile's formatters and the
    // byte size style the preferences supplied. The two rows take different
    // branches: an unfinished torrent reports done-of-total, a finished one
    // reports how much it has uploaded.
    expect(
        find.text('Downloading • 2.00 MiB/5.00 MiB (40.0%)'), findsOneWidget);
    expect(find.text('6.00 MiB • Seeding • 3.00 MiB uploaded'), findsOneWidget);

    await unmountAndDrainTimers(tester);
  });

  testWidgets('sorts the rows by the criterion it was given', (tester) async {
    await pumpWithProviders(tester, torrentList(), client: client);

    await pumpUntilFound(tester, find.byType(TorrentListItem));

    // Sorted by name ascending, so debian comes before ubuntu -- which is not
    // the order the daemon's map put them in.
    final names = tester
        .widgetList<TorrentListItem>(find.byType(TorrentListItem))
        .map((tile) => tile.data.name)
        .toList();
    expect(names, ['debian-13.iso', 'ubuntu-24.04.iso']);

    await unmountAndDrainTimers(tester);
  });

  testWidgets('shows the empty text until the first response lands',
      (tester) async {
    await pumpWithProviders(tester, torrentList(), client: client);

    // Nothing has come back yet, and the repository has a client, so the list
    // is empty rather than loading.
    expect(find.byType(TorrentListItem), findsNothing);
    expect(find.text('No torrents'), findsOneWidget);

    await pumpUntilFound(tester, find.byType(TorrentListItem));

    expect(find.text('No torrents'), findsNothing,
        reason: 'the empty text goes away once there are rows');

    await unmountAndDrainTimers(tester);
  });

  testWidgets('long press selects a row, and a tap then selects another',
      (tester) async {
    await pumpWithProviders(tester, torrentList(), client: client);

    await pumpUntilFound(tester, find.byType(TorrentListItem));

    expect(isSelected(tester, 'debian-13.iso'), isFalse);
    expect(isSelected(tester, 'ubuntu-24.04.iso'), isFalse);

    // A plain tap outside selection mode opens the detail screen, so entering
    // selection mode is a long press. That is the only way in.
    //
    // warnIfMissed is off throughout because Selectable lays a full-bleed
    // Container over each row to tint it. The container is transparent when
    // the row is unselected but still takes the hit, so the gesture reaches
    // the InkWell -- which is what matters -- without landing on the widget
    // the finder named.
    await tester.longPress(tileFor('debian-13.iso'), warnIfMissed: false);
    await tester.pump();

    expect(selectionCount, 1,
        reason: 'the screen above the list is told how many are selected');
    expect(isSelected(tester, 'debian-13.iso'), isTrue);
    expect(isSelected(tester, 'ubuntu-24.04.iso'), isFalse);

    // Once selection mode is on, a tap toggles instead of navigating.
    await tester.tap(tileFor('ubuntu-24.04.iso'), warnIfMissed: false);
    await tester.pump();

    expect(selectionCount, 2);
    expect(isSelected(tester, 'ubuntu-24.04.iso'), isTrue);

    // ...and a tap on a selected row takes it back out.
    await tester.tap(tileFor('debian-13.iso'), warnIfMissed: false);
    await tester.pump();

    expect(selectionCount, 1);
    expect(isSelected(tester, 'debian-13.iso'), isFalse);
    expect(isSelected(tester, 'ubuntu-24.04.iso'), isTrue);

    await unmountAndDrainTimers(tester);
  });
}
