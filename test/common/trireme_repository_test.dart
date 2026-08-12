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

import 'package:flutter_test/flutter_test.dart';
import 'package:trireme/common/trireme_repository.dart';

// A repository with no client fails every RPC it attempts, which is exactly
// the state these tests need: it exercises the polling pipelines end to end
// without a daemon or a fake client.
void main() {
  late TriremeRepository repository;

  setUp(() => repository = TriremeRepository());

  tearDown(() => repository.dispose());

  test('a failing poll is reported on the error stream', () async {
    // The polling pipelines wrap their RPC call in retry(), which is unbounded
    // and so never forwards an error downstream. Reporting therefore has to
    // happen on the call itself. When it did not, nothing observed a daemon
    // that went away mid-session and the disconnected banner never appeared.
    final errors = <Object>[];
    final subscription = repository.errorStream().listen(errors.add);

    // The clock ticks every 2s and the session status poll starts with the
    // repository, so one tick is enough.
    await Future<void>.delayed(const Duration(seconds: 3));
    await subscription.cancel();

    expect(errors, isNotEmpty,
        reason: 'a poll against a client-less repository must report an error');
  });

  test('the error stream keeps reporting, not just once', () async {
    final errors = <Object>[];
    final subscription = repository.errorStream().listen(errors.add);

    await Future<void>.delayed(const Duration(seconds: 5));
    await subscription.cancel();

    // retry() keeps the pipeline alive, so failures must keep arriving rather
    // than the stream going quiet after the first one.
    expect(errors.length, greaterThan(1));
  });

  test('torrent details for an empty id fails instead of hanging', () async {
    // This used to return an empty stream. An empty stream closes without ever
    // going active, which a StreamBuilder cannot tell apart from "still
    // loading" -- so the details screen sat on its progress bar forever.
    await expectLater(repository.getTorrentDetails(''), emitsError(anything));
  });
}
