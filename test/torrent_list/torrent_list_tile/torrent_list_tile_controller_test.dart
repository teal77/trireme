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
import 'package:intl/intl.dart';
import 'package:trireme/common/bytesize.dart';
import 'package:trireme/torrent_list/torrent_list_tile/torrent_list_tile_controller.dart';

import '../../support/fixtures.dart';

void main() {
  // NumberFormat resolves its locale on first use. Dart initialises static
  // fields lazily, so setting this before the first access is what makes the
  // decimal separator deterministic across machines and CI.
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  TorrentListItemController controllerFor({
    double ratio = 0.0,
    int totalSize = 0,
    int totalDone = 0,
    int totalUploaded = 0,
    bool isFinished = false,
    double progress = 0.0,
    num eta = 0,
  }) {
    return TorrentListItemController()
      ..torrentItem = buildTorrentItem(
        ratio: ratio,
        totalSize: totalSize,
        totalDone: totalDone,
        totalUploaded: totalUploaded,
        isFinished: isFinished,
        progress: progress,
        eta: eta,
      );
  }

  group('getRatio', () {
    test('uses two decimals below a gibibyte', () {
      expect(controllerFor(ratio: 1.23456, totalSize: 1000).getRatio(),
          'Ratio: 1.23');
    });

    test('uses three decimals above a gibibyte', () {
      expect(
        controllerFor(ratio: 1.23456, totalSize: 2 * 1024 * 1024 * 1024)
            .getRatio(),
        'Ratio: 1.235',
      );
    });

    test('keeps at least one decimal place', () {
      expect(
          controllerFor(ratio: 2.0, totalSize: 1000).getRatio(), 'Ratio: 2.0');
    });
  });

  group('progress', () {
    test('renders one decimal place with a percent sign', () {
      expect(controllerFor(progress: 45.67).getProgressPercentage(), '45.7%');
    });

    test('converts percent to a 0..1 fraction', () {
      expect(controllerFor(progress: 45.0).getProgressFloat(),
          closeTo(0.45, 1e-9));
    });
  });

  group('size explanation', () {
    const iec = ByteSizeFormatter(ByteSizeStyle.iec);

    test('reports uploaded bytes when finished', () {
      final c = controllerFor(
        isFinished: true,
        totalUploaded: 2048,
        totalSize: 4096,
      );
      expect(c.getCurrentSizeExplanation(iec), '2.00 KiB uploaded');
    });

    test('reports done over total with a percentage when unfinished', () {
      final c = controllerFor(
        isFinished: false,
        totalDone: 1024,
        totalSize: 4096,
        progress: 25.0,
      );
      expect(c.getCurrentSizeExplanation(iec), '1.00 KiB/4.00 KiB (25.0%)');
    });
  });

  group('getEta tersity', () {
    // These assert format *shape*, not exact strings: prettyDuration's wording
    // belongs to package:duration and is not this codebase's contract. The
    // branch selection is.
    // Each duration below carries a non-zero remainder in the unit the
    // branch is supposed to DROP. That is what makes the negative
    // assertions discriminating: if the tersity were wrong, the dropped
    // unit would appear. A duration with a zero remainder would satisfy
    // the negative assertion no matter which tersity ran.
    test('under an hour, includes minutes and seconds', () {
      // 90s renders as 1m 30s: default tersity keeps seconds.
      final eta = controllerFor(eta: 90).getEta();
      expect(eta, matches(RegExp(r'\d+\s*m')));
      expect(eta, matches(RegExp(r'\d+\s*s')));
    });

    test('over an hour, truncates to minutes and drops seconds', () {
      // 3700s is 1h 1m 40s; DurationTersity.minute drops the seconds.
      final eta = controllerFor(eta: 3700).getEta();
      expect(eta, matches(RegExp(r'\d+\s*h')));
      expect(eta, matches(RegExp(r'\d+\s*m')));
      expect(eta, isNot(matches(RegExp(r'\d+\s*s(\b|$)'))));
    });

    test('over a day, truncates to hours and drops minutes', () {
      // 90090s is 1d 1h 1m 30s. DurationTersity.hour must drop the 1m 30s.
      // Do NOT use 90000 here: that is exactly 1d 1h 0m 0s, so the
      // "no minutes" assertion would pass under every tersity and the
      // test would prove nothing about the day branch.
      final eta = controllerFor(eta: 90090).getEta();
      expect(eta, matches(RegExp(r'\d+\s*d')));
      expect(eta, matches(RegExp(r'\d+\s*h')));
      expect(eta, isNot(matches(RegExp(r'\d+\s*m(in)?(\b|$)'))));
    });
  });
}
