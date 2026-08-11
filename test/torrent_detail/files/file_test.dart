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
import 'package:trireme/torrent_detail/files/file.dart';

import '../../support/fixtures.dart';

void main() {
  group('convertToFileTree', () {
    test('places a root-level file directly under the root', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [buildTorrentFile(index: 0, size: 100, path: 'a.txt')],
        priorities: [1],
        progress: [1.0],
      ));

      expect(tree.children.length, 1);
      expect(tree.children.single.name, 'a.txt');
      expect(tree.children.single.isFile, isTrue);
      expect(tree.children.single.path, '/a.txt');
    });

    test('creates intermediate folders once and nests files under them', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [
          buildTorrentFile(index: 0, size: 100, path: 'dir/a.txt'),
          buildTorrentFile(index: 1, size: 300, path: 'dir/b.txt'),
        ],
        priorities: [1, 1],
        progress: [1.0, 0.5],
      ));

      expect(tree.children.length, 1);
      final dir = tree.children.single;
      expect(dir.name, 'dir');
      expect(dir.isFolder, isTrue);
      expect(dir.children.length, 2);
      expect(dir.path, '/dir');
    });

    test('sums folder size from its children', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [
          buildTorrentFile(index: 0, size: 100, path: 'dir/a.txt'),
          buildTorrentFile(index: 1, size: 300, path: 'dir/b.txt'),
        ],
        priorities: [1, 1],
        progress: [1.0, 0.5],
      ));

      expect(tree.children.single.size, 400);
    });

    test('computes folder progress weighted by child size', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [
          buildTorrentFile(index: 0, size: 100, path: 'dir/a.txt'),
          buildTorrentFile(index: 1, size: 300, path: 'dir/b.txt'),
        ],
        priorities: [1, 1],
        progress: [1.0, 0.5],
      ));

      // (1.0*100 + 0.5*300) / 400
      expect(tree.children.single.progress, closeTo(0.625, 1e-9));
    });

    test('inherits a uniform child priority', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [
          buildTorrentFile(index: 0, size: 100, path: 'dir/a.txt'),
          buildTorrentFile(index: 1, size: 300, path: 'dir/b.txt'),
        ],
        priorities: [1, 1],
        progress: [1.0, 1.0],
      ));

      expect(tree.children.single.priority, Priority.normal);
    });

    test('marks a folder mixed when children disagree', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [
          buildTorrentFile(index: 0, size: 100, path: 'dir/a.txt'),
          buildTorrentFile(index: 1, size: 300, path: 'dir/b.txt'),
        ],
        priorities: [0, 7],
        progress: [1.0, 1.0],
      ));

      expect(tree.children.single.priority, Priority.mixed);
    });

    test('builds nested folder chains', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [
          buildTorrentFile(index: 0, size: 50, path: 'a/b/c.txt'),
        ],
        priorities: [1],
        progress: [1.0],
      ));

      final a = tree.children.single;
      final b = a.children.single;
      final c = b.children.single;
      expect([a.name, b.name, c.name], ['a', 'b', 'c.txt']);
      expect(c.path, '/a/b/c.txt');
      expect(c.index, 0);
      expect(c.size, 50);
    });
  });

  group('File.findChild', () {
    test('resolves a nested path with and without a leading slash', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [buildTorrentFile(index: 0, size: 50, path: 'a/b/c.txt')],
        priorities: [1],
        progress: [1.0],
      ));

      expect(tree.findChild('a/b/c.txt')?.name, 'c.txt');
      expect(tree.findChild('/a/b/c.txt')?.name, 'c.txt');
    });

    test('returns null for a path that does not exist', () {
      final tree = convertToFileTree(buildTorrentFiles(
        files: [buildTorrentFile(index: 0, size: 50, path: 'a/b/c.txt')],
        priorities: [1],
        progress: [1.0],
      ));

      expect(tree.findChild('a/nope.txt'), isNull);
    });
  });

  group('priorities map', () {
    test('maps each Deluge priority integer to a Priority', () {
      expect(priorities[0], Priority.dontDownload);
      expect(priorities[1], Priority.normal);
      expect(priorities[2], Priority.normal);
      expect(priorities[3], Priority.normal);
      expect(priorities[4], Priority.normal);
      expect(priorities[5], Priority.high);
      expect(priorities[6], Priority.high);
      expect(priorities[7], Priority.highest);
    });
  });
}
