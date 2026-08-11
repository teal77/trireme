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
import 'package:trireme/common/bytesize.dart';

void main() {
  group('ByteSizeFormatter IEC (base 1024)', () {
    const f = ByteSizeFormatter(ByteSizeStyle.iec);

    test('renders raw bytes below the base without a unit prefix', () {
      expect(f.format(0), '0 B');
      expect(f.format(1023), '1023 B');
    });

    test('renders two decimals below 10', () {
      expect(f.format(1024), '1.00 KiB');
      expect(f.format(1536), '1.50 KiB');
    });

    test('renders one decimal between 10 and 99', () {
      expect(f.format(10240), '10.0 KiB');
    });

    test('rounds to whole numbers above 99', () {
      expect(f.format(102400), '100 KiB');
    });

    test('steps up to the next unit at each power of the base', () {
      expect(f.format(1048576), '1.00 MiB');
      expect(f.format(1073741824), '1.00 GiB');
    });
  });

  group('ByteSizeFormatter SI (base 1000)', () {
    const f = ByteSizeFormatter(ByteSizeStyle.si);

    test('uses decimal units', () {
      expect(f.format(999), '999 B');
      expect(f.format(1000), '1.00 kB');
      expect(f.format(1500), '1.50 kB');
      expect(f.format(1000000), '1.00 MB');
    });
  });

  group('ByteSizeFormatter negative values', () {
    const iec = ByteSizeFormatter(ByteSizeStyle.iec);

    test('prefixes a minus sign above the base', () {
      expect(iec.format(-1536), '-1.50 KiB');
    });

    // Characterization: the sub-base branch returns the absolute value and
    // drops the sign. See Findings F1.
    test('drops the minus sign below the base', () {
      expect(iec.format(-500), '500 B');
    });
  });

  group('ByteSizeFormatter.of', () {
    test('maps each style to its formatter', () {
      expect(ByteSizeFormatter.of(ByteSizeStyle.si).style, ByteSizeStyle.si);
      expect(ByteSizeFormatter.of(ByteSizeStyle.iec).style, ByteSizeStyle.iec);
    });
  });
}
