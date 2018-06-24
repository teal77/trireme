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

import 'package:trireme_client/deserialization.dart';

class File {
  final int index;

  final int size;

  final String path;

  final int priority;

  final double progress;

  File._(this.index, this.size, this.path, this.priority, this.progress);

  factory File(TorrentFile torrentFile, int priority, double progress) {
    return new File._(torrentFile.index, torrentFile.size,
        torrentFile.path, priority, progress);
  }

  @override
  String toString() {
    return 'File{index: $index, size: $size, path: $path, priority: $priority, progress: $progress}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is File &&
              runtimeType == other.runtimeType &&
              index == other.index &&
              path == other.path;

  @override
  int get hashCode =>
      index.hashCode ^
      path.hashCode;
}
