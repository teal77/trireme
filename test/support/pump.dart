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

import 'package:trireme_client/trireme_client.dart';

import 'package:trireme/common/common.dart';

/// Helpers for pumping a screen with the provider chain main.dart installs,
/// driven against a real daemon.
///
/// The awkwardness here is all one problem: a widget test runs inside
/// FakeAsync, and these screens talk to a daemon over a real socket. Nothing
/// in a widget test's body ever returns to the real event loop, so an RPC
/// issued from a tap never gets an answer, no matter how much the fake clock is
/// advanced. [letDaemonAnswer] is the escape hatch, and [pumpUntil] is the
/// polling loop built on it.

/// Wraps [home] in a MaterialApp, for screens that build their own Scaffold.
Widget appWith(Widget home) {
  return MaterialApp(home: home);
}

/// Wraps [child] in the provider chain from main.dart, plus the Scaffold and
/// LoadingContainer that HomePage would otherwise supply.
///
/// The LoadingContainer is not decoration: TriremeProgressBarMixin finds it
/// with findAncestorStateOfType and throws a bare String if there is none, so a
/// screen that calls showProgressBar() dies without it.
Widget triremeApp(Widget child) {
  return RepositoryProvider(
    child: PreferenceProvider(
      MaterialApp(
        home: Scaffold(
          body: LoadingContainer(child: child),
        ),
      ),
    ),
  );
}

/// Pumps [child] under [triremeApp] and pushes [client] into the chain.
///
/// The client is installed on the second pump rather than the first, which is
/// the order the running app produces: ClientProvider starts with no client and
/// home.dart sets one once a server has been picked. It matters here because
/// TorrentListController.getFilteredTorrentList awaits repository.readiness()
/// when the repository has no client, and readiness() is a broadcast stream --
/// the controller has to be listening before the client lands or it waits
/// forever.
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget child, {
  required TriremeClient client,
}) async {
  await tester.pumpWidget(triremeApp(child));
  tester
      .state<ClientProviderState>(find.byType(ClientProvider))
      .setClient(client);
  await tester.pump();
}

/// Hands the isolate back to the real event loop for [duration], so sockets
/// can actually carry bytes, then rebuilds.
///
/// runAsync is the only thing in flutter_test that leaves FakeAsync. Without
/// it the daemon never sees the request.
Future<void> letDaemonAnswer(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 50),
]) async {
  await tester.runAsync(() => Future<void>.delayed(duration));
  await tester.pump();
}

/// Alternates [letDaemonAnswer] with a rebuild until [condition] holds.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  required String reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting: $reason');
    await letDaemonAnswer(tester, const Duration(milliseconds: 20));
  }
}

/// Convenience wrapper over [pumpUntil] for the usual case.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) {
  return pumpUntil(tester, () => finder.evaluate().isNotEmpty,
      timeout: timeout, reason: 'for $finder');
}

/// Tears the tree down and drains the timers the RPC layer leaves behind.
///
/// Every call DelugeClient makes registers a 15 second timeout Timer that is
/// never cancelled, even on a successful response -- it just finds the request
/// already gone and does nothing. Under FakeAsync those are fake timers, and
/// flutter_test fails a test that ends with any timer outstanding, so they have
/// to be run out. Unmounting first is what makes that safe: it disposes the
/// repository, whose 2 second polling clock would otherwise issue a fresh call,
/// and a fresh timer, on every one of those fake seconds.
Future<void> unmountAndDrainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}
