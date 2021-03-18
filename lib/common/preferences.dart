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

import 'bytesize.dart';

class Preferences {
  static Preferences defaultPreferences = Preferences(
    ByteSizeStyle.iec,
    Colors.blue,
    Brightness.light,
  );

  ByteSizeStyle byteSizeStyle;
  MaterialColor appThemeColor;
  Brightness brightness;

  Preferences(this.byteSizeStyle, this.appThemeColor, this.brightness);

  Preferences apply(
      {ByteSizeStyle? byteSizeStyle,
      MaterialColor? appThemeColor,
      Brightness? brightness}) {

    return Preferences(
      byteSizeStyle ?? this.byteSizeStyle,
      appThemeColor ?? this.appThemeColor,
      brightness ?? this.brightness,
    );
  }
}
