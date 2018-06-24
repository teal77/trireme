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

import 'package:kilobyte/kilobyte.dart';

import 'torrent_file.dart';

class TorrentFileListController {
  static const priorities = {
    0: "Do not download",
    1: "Normal",
    2: "Normal",
    3: "Normal",
    4: "Normal",
    5: "High",
    6: "High",
    7: "Highest",
  };

  String getFileSize(File file) {
    return Size(bytes: file.size).toString();
  }

  String getFilePriority(File file) {
    return priorities[file.priority];
  }
}