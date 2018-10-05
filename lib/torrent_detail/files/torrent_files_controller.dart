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

import 'dart:async';

import 'package:trireme/common/common.dart';

import 'file.dart';

class TorrentFileListController {
  static final priorities = {
    Priority.dontDownload: Strings.detailFileDoNotDownload,
    Priority.normal: Strings.detailFileNormal,
    Priority.high: Strings.detailFileHigh,
    Priority.highest: Strings.detailFileHighest,
    Priority.mixed: Strings.detailFileMixed,
  };

  TriremeRepository repository;

  String getFilePriority(File file) {
    return priorities[file.priority];
  }

  Future setPriorityForFiles(List<File> files, List<int> currentPriorities,
      String torrentId, int newPriority) {
    var indices = <int>[];
    for (var file in files) {
      indices.addAll(getIndicesOfChildren(file));
    }

    var newPriorities = List.of(currentPriorities);
    for (var index in indices) {
      newPriorities[index] = newPriority;
    }

    return repository.setTorrentFilePriorities(torrentId, newPriorities);
  }

  List<int> getIndicesOfChildren(File file) {
    if (file.isFile) return [file.index];
    var indices = <int>[];
    for (var child in file.children) {
      indices.addAll(getIndicesOfChildren(child));
    }
    return indices;
  }

  String getPath(File file) {
    if (file.isRoot) return "/";

    var segments = <String>[];
    var currentDir = file;
    while (!currentDir.isRoot) {
      segments.add(currentDir.name);
      currentDir = currentDir.parent;
    }
    return "/${segments.reversed.join("/")}";
  }

  Future renameFile(String torrentId, File file, String newName) {
    var oldPath = file.path.substring(1); //we need to skip the first "/"
    var newPath = "${file.parent.path}/$newName".substring(1);
    if (file.isFolder) {
      return repository.renameFolder(torrentId, oldPath, newPath);
    } else {
      return repository.renameFile(torrentId, file.index, newPath);
    }
  }
}
