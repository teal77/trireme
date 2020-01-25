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

import 'dart:math';

enum ByteSizeStyle {
  si, iec
}

const _siUnits = ["B", "kB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
const _iecUnits = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"];

class ByteSizeFormatter {
  static final kiloByte = ByteSizeFormatter(ByteSizeStyle.si);
  static final kibiByte = ByteSizeFormatter(ByteSizeStyle.iec);

  static ByteSizeFormatter of(ByteSizeStyle style) {
    if (style == ByteSizeStyle.si) {
      return kiloByte;
    } else {
      return kibiByte;
    }
  }

  final ByteSizeStyle style;

  const ByteSizeFormatter(this.style);

  String format(int bytes) {
    final bytesAbs = bytes.abs();
    final base = style == ByteSizeStyle.si ? 1000 : 1024;

    if (bytesAbs < base) return "$bytesAbs B";

    var i = (log(bytesAbs) / log(base)).floor();
    var result = bytesAbs / pow(base, i);
    var resultStr = _prettyDouble(result);
    var prefix = bytes.isNegative ? '-' : '';
    var unit = style == ByteSizeStyle.si ? _siUnits[i] : _iecUnits[i];

    return "$prefix$resultStr $unit";
  }

  String _prettyDouble(double input) {
    if (input > 99) {
      return input.round().toString();
    } else if (input > 9) {
      return input.toStringAsFixed(1);
    } else {
      return input.toStringAsFixed(2);
    }
  }
}

