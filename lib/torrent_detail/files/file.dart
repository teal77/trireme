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

import 'package:flutter/foundation.dart';

import 'package:trireme_client/deserialization.dart';

class File {
  String name;
  String path = "";
  int size;
  int index;
  int priorityInt;
  Priority priority;
  double progress;
  File parent;
  List<File> children = [];

  File(this.name);

  bool get isFolder => children != null && children.isNotEmpty;

  bool get isFile => children == null || children.isEmpty;

  bool get isRoot => parent == null;

  File getChild(String name) {
    return children.firstWhere((f) => f.name == name, orElse: () => null);
  }

  File findChild(String path) {
    var pathSegments = path.split("/");
    if (path.startsWith("/")) pathSegments = pathSegments.skip(1).toList();

    if (pathSegments.length == 1) {
      return getChild(pathSegments.first);
    } else {
      var immediateChild = pathSegments.first;
      var restOfPath = pathSegments.skip(1).join("/");
      return getChild(immediateChild).findChild(restOfPath);
    }
  }

  void addChild(File file) {
    children.add(file);
    file.parent = this;
    file.path = "${this.path}/${file.name}";
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is File && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

enum Priority { dontDownload, normal, high, highest, mixed }

const priorities = {
  0: Priority.dontDownload,
  1: Priority.normal,
  2: Priority.normal,
  3: Priority.normal,
  4: Priority.normal,
  5: Priority.high,
  6: Priority.high,
  7: Priority.highest
};

File convertToFileTree(TorrentFiles torrentFiles) {
  File root = File("/");

  void addFile(TorrentFile f, int priority, double progress) {
    var parent = root;

    var splitResult = f.path.split("/");
    var fileName = splitResult.last;
    var pathSegments = splitResult..removeLast();

    for (var segment in pathSegments) {
      var child = parent.getChild(segment);
      if (child == null) {
        parent.addChild(File(segment));
        child = parent.getChild(segment);
      }
      parent = child;
    }

    var file = File(fileName);
    file.priorityInt = priority;
    file.priority = priorities[priority];
    file.progress = progress;
    file.size = f.size;
    file.index = f.index;
    parent.addChild(file);
  }

  for (int i = 0; i < torrentFiles.files.length; i++) {
    addFile(torrentFiles.files[i], torrentFiles.filePriorities[i],
        torrentFiles.fileProgress[i]);
  }

  void computeFolderMetadata(File file) {
    if (file.isFile) return;
    file.children.forEach((f) => computeFolderMetadata(f));

    file.size = file.children.fold(0, (t, f) => t + f.size);
    file.progress =
        (file.children.fold(0.0, (t, f) => t + (f.progress * f.size))) /
            file.size.toDouble(); //average progress

    var childrenPriorities = file.children.map((f) => f.priority);
    if (childrenPriorities.every((p) => p == childrenPriorities.first)) {
      file.priority = childrenPriorities.first;
    } else {
      file.priority = Priority.mixed;
    }
  }

  computeFolderMetadata(root);

  return root;
}

class TorrentFileData {
  TorrentFiles torrentFiles;
  File root;

  TorrentFileData(this.torrentFiles, this.root);

  static Future<TorrentFileData> createAsync(TorrentFiles torrentFiles) async {
    File file = await compute(convertToFileTree, torrentFiles);
    return TorrentFileData(torrentFiles, file);
  }

  static TorrentFileData create(TorrentFiles torrentFiles) {
    File file = convertToFileTree(torrentFiles);
    return TorrentFileData(torrentFiles, file);
  }
}
