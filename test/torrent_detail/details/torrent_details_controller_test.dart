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
import 'package:trireme/torrent_detail/details/torrent_details_controller.dart';
import 'package:trireme_client/deserialization.dart';

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  // Fixed reference instant used as "now" for every case below.
  final now = DateTime(2026, 6, 15, 12, 0, 0);
  int epochSecondsFor(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  TorrentDetailsController controllerWith({
    num? addedTime,
    num? timeCompleted,
    int? lastSeenComplete,
  }) {
    final detail = TorrentDetail();
    if (addedTime != null) detail.addedTime = addedTime;
    detail.timeCompleted = timeCompleted;
    if (lastSeenComplete != null) detail.lastSeenComplete = lastSeenComplete;

    return TorrentDetailsController(now: () => now)..torrentDetail = detail;
  }

  // These assert format *shape*, not exact strings. DateFormat output depends
  // on the machine's timezone, which differs between a developer box and CI.
  // The branch selection is what this codebase controls, so that is what is
  // pinned here.
  //
  // The space right before AM/PM is matched with \s rather than a literal
  // ' ': the intl package's CLDR data renders that particular separator as
  // a narrow no-break space (U+202F) rather than a regular space, and \s
  // matches both.
  final yearFormat = RegExp(r'^\w{3} \d{1,2}, \d{4} \d{1,2}:\d{2}\s[AP]M$');
  final monthFormat = RegExp(r'^\w{3} \d{1,2} \d{1,2}:\d{2}\s[AP]M$');
  // DateFormat("EEEEE, ...") renders a narrow (one-letter) weekday, e.g.
  // "F, Jun 12 ...". That narrowness is what this pins: a CLDR change to a
  // wide weekday in a future intl bump is a real behavior change worth
  // noticing, so the weekday group is bounded rather than left as `\S+`.
  final dayFormat = RegExp(r'^\w{1,3}, \w{3} \d{1,2} \d{1,2}:\d{2}\s[AP]M$');
  final timeFormat = RegExp(r'^\d{1,2}:\d{2}:\d{2}\s[AP]M$');

  group('getAddedDate branch selection', () {
    test('older than a year includes the year', () {
      final c = controllerWith(
          addedTime: epochSecondsFor(now.subtract(const Duration(days: 400))));
      expect(c.getAddedDate(), matches(yearFormat));
    });

    test('older than a month omits the year', () {
      final c = controllerWith(
          addedTime: epochSecondsFor(now.subtract(const Duration(days: 45))));
      expect(c.getAddedDate(), matches(monthFormat));
    });

    test('older than a day includes the weekday', () {
      final c = controllerWith(
          addedTime: epochSecondsFor(now.subtract(const Duration(days: 3))));
      expect(c.getAddedDate(), matches(dayFormat));
    });

    test('within a day shows only the time', () {
      final c = controllerWith(
          addedTime: epochSecondsFor(now.subtract(const Duration(hours: 2))));
      expect(c.getAddedDate(), matches(timeFormat));
    });
  });

  group('getCompletedDate', () {
    test('returns an empty string when never completed', () {
      expect(controllerWith(timeCompleted: null).getCompletedDate(), '');
    });

    test('formats a recent completion as a time', () {
      final c = controllerWith(
          timeCompleted:
              epochSecondsFor(now.subtract(const Duration(hours: 2))));
      expect(c.getCompletedDate(), matches(timeFormat));
    });

    test('formats an old completion with the year', () {
      final c = controllerWith(
          timeCompleted:
              epochSecondsFor(now.subtract(const Duration(days: 400))));
      expect(c.getCompletedDate(), matches(yearFormat));
    });
  });

  group('getLastSeenComplete', () {
    test('formats a recent sighting as a time', () {
      final c = controllerWith(
          lastSeenComplete:
              epochSecondsFor(now.subtract(const Duration(hours: 2))));
      expect(c.getLastSeenComplete(), matches(timeFormat));
    });
  });

  group('getRatio', () {
    TorrentDetailsController ratioController(double ratio) {
      final detail = TorrentDetail()..ratio = ratio;
      return TorrentDetailsController(now: () => now)..torrentDetail = detail;
    }

    test('keeps five significant digits for small ratios', () {
      expect(ratioController(1.23456789).getRatio(), '1.2346');
    });

    test('sheds decimals as the integer part grows', () {
      expect(ratioController(123.456789).getRatio(), '123.46');
    });

    test('never goes below zero decimals', () {
      expect(ratioController(123456.789).getRatio(), '123457');
    });
  });

  group('getProgressPercentage', () {
    test('renders one decimal with a percent sign', () {
      final detail = TorrentDetail()..progress = 45.67;
      final c = TorrentDetailsController(now: () => now)
        ..torrentDetail = detail;
      expect(c.getProgressPercentage(), '45.7%');
    });
  });
}
