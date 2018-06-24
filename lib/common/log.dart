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

class Log {
  static const none = 10;
  static const error = 8;
  static const warn = 6;
  static const info = 4;
  static const debug = 2;
  static const verbose = 0;

  static int level = none;

  static void v(String tag, String msg) {
    _log(tag, msg, verbose);
  }

  static void d(String tag, String msg) {
    _log(tag, msg, debug);
  }

  static void i(String tag, String msg) {
    _log(tag, msg, info);
  }

  static void w(String tag, String msg) {
    _log(tag, msg, warn);
  }

  static void e(String tag, String msg) {
    _log(tag, msg, error);
  }

  static void _log(String tag, String msg, int level) {
    if (level >= Log.level) {
      print("$tag : $msg");
    }
  }
}