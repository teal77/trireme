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
import 'package:trireme/common/bytesize.dart';
import 'package:trireme/core/persistence.dart';
import 'package:trireme/torrent_detail/files/torrent_files.dart';
import 'package:trireme/torrent_list/torrent_list_controller.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('filter spec', () {
    test('round-trips a state filter', () async {
      await saveFilter(const FilterSpec('Downloading', 'All', 'All'));
      expect(await getSavedFilterSpec(),
          const FilterSpec('Downloading', 'All', 'All'));
    });

    test('round-trips all three fields', () async {
      const spec = FilterSpec('Seeding', 'music', 'tracker.example');
      await saveFilter(spec);
      expect(await getSavedFilterSpec(), spec);
    });

    test('defaults to the all-filter when nothing is stored', () async {
      expect(await getSavedFilterSpec(), FilterSpec.all);
    });

    test('the all-filter round-trips back to itself', () async {
      await saveFilter(FilterSpec.all);
      expect(await getSavedFilterSpec(), FilterSpec.all);
    });
  });

  group('sort mode', () {
    test('round-trips each criterion', () async {
      for (final c in SortCriteria.values) {
        await saveSortMode(c);
        expect(await getSavedSortMode(), c);
      }
    });

    test('falls back to name when the stored value is unrecognised', () async {
      SharedPreferences.setMockInitialValues({'sortMode': 'not-a-criterion'});
      expect(await getSavedSortMode(), SortCriteria.name);
    });

    test('round-trips the reverse flag', () async {
      await saveSortReverse(true);
      expect(await getSavedSortReverseMode(), isTrue);
    });

    test('the reverse flag defaults to false', () async {
      expect(await getSavedSortReverseMode(), isFalse);
    });
  });

  group('file sort mode', () {
    test('round-trips each criterion', () async {
      for (final s in SortBy.values) {
        await saveFileSortMode(s);
        expect(await getSavedFileSortMode(), s);
      }
    });

    test('falls back to name when unrecognised', () async {
      SharedPreferences.setMockInitialValues({'fileSortMode': 'rubbish'});
      expect(await getSavedFileSortMode(), SortBy.name);
    });
  });

  group('byte size style', () {
    test('round-trips both styles', () async {
      await saveByteSizeStyle(ByteSizeStyle.si);
      expect(await getSavedByteSizeStyle(), ByteSizeStyle.si);
      await saveByteSizeStyle(ByteSizeStyle.iec);
      expect(await getSavedByteSizeStyle(), ByteSizeStyle.iec);
    });

    test('defaults to IEC', () async {
      expect(await getSavedByteSizeStyle(), ByteSizeStyle.iec);
    });
  });

  group('theme mode', () {
    test('round-trips each mode', () async {
      for (final m in ThemeMode.values) {
        await saveThemeMode(m);
        expect(await getSavedThemeMode(), m);
      }
    });

    test('falls back to the legacy brightness flag when unset', () async {
      SharedPreferences.setMockInitialValues({'isDark': true});
      expect(await getSavedThemeMode(), ThemeMode.dark);

      SharedPreferences.setMockInitialValues({'isDark': false});
      expect(await getSavedThemeMode(), ThemeMode.light);
    });
  });

  group('app colour', () {
    test('round-trips a known material colour', () async {
      await saveAppColor(Colors.teal);
      expect(await getSavedAppColor(), Colors.teal);
    });

    test('returns null when nothing is stored', () async {
      expect(await getSavedAppColor(), isNull);
    });

    test('rejects a colour outside the supported list', () async {
      const unsupported =
          MaterialColor(0xFF123456, <int, Color>{500: Color(0xFF123456)});
      await expectLater(
          saveAppColor(unsupported), throwsA('Unknown material color'));
    });
  });

  group('torrent destinations', () {
    test('round-trips a list and drops empty entries', () async {
      await saveTorrentDestList(['/downloads', '', '/media']);
      expect(await getSavedTorrentDestList(), ['/downloads', '/media']);
    });

    test('defaults to an empty list', () async {
      expect(await getSavedTorrentDestList(), isEmpty);
    });
  });
}
