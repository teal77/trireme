import 'package:flutter_test/flutter_test.dart';
import 'package:trireme/common/common.dart';
import 'package:trireme/torrent_list/torrent_item.dart';
import 'package:trireme/torrent_list/torrent_list_controller.dart';

import '../support/fixtures.dart';

List<String> sortedIds(List<TorrentItem> items, Comparator<TorrentItem> c) {
  final copy = List<TorrentItem>.from(items)..sort(c);
  return copy.map((t) => t.id).toList();
}

void main() {
  group('sort comparators', () {
    test('name sorts lexicographically', () {
      final items = [
        buildTorrentItem(id: 'b', name: 'beta'),
        buildTorrentItem(id: 'a', name: 'alpha'),
      ];
      expect(sortedIds(items, comparators[SortCriteria.name]!), ['a', 'b']);
    });

    test('status sorts by TorrentState declaration order', () {
      final items = [
        buildTorrentItem(id: 'seed', state: 'Seeding'),
        buildTorrentItem(id: 'down', state: 'Downloading'),
      ];
      expect(sortedIds(items, comparators[SortCriteria.status]!),
          ['down', 'seed']);
    });

    test('dateAdded sorts oldest first', () {
      final items = [
        buildTorrentItem(id: 'new', timeAdded: 2000),
        buildTorrentItem(id: 'old', timeAdded: 1000),
      ];
      expect(sortedIds(items, comparators[SortCriteria.dateAdded]!),
          ['old', 'new']);
    });

    test('seedingTime sorts shortest first', () {
      final items = [
        buildTorrentItem(id: 'long', timeSeeding: 500),
        buildTorrentItem(id: 'short', timeSeeding: 5),
      ];
      expect(sortedIds(items, comparators[SortCriteria.seedingTime]!),
          ['short', 'long']);
    });

    test('downloadProgress sorts least complete first', () {
      final items = [
        buildTorrentItem(id: 'full', progress: 100.0),
        buildTorrentItem(id: 'half', progress: 50.0),
      ];
      expect(sortedIds(items, comparators[SortCriteria.downloadProgress]!),
          ['half', 'full']);
    });

    test('downloadSpeed sorts slowest first', () {
      final items = [
        buildTorrentItem(id: 'fast', downloadSpeed: 900),
        buildTorrentItem(id: 'slow', downloadSpeed: 100),
      ];
      expect(sortedIds(items, comparators[SortCriteria.downloadSpeed]!),
          ['slow', 'fast']);
    });

    test('uploadSpeed sorts slowest first', () {
      final items = [
        buildTorrentItem(id: 'fast', uploadSpeed: 900),
        buildTorrentItem(id: 'slow', uploadSpeed: 100),
      ];
      expect(sortedIds(items, comparators[SortCriteria.uploadSpeed]!),
          ['slow', 'fast']);
    });

    test('ratio sorts lowest first', () {
      final items = [
        buildTorrentItem(id: 'high', ratio: 2.5),
        buildTorrentItem(id: 'low', ratio: 0.5),
      ];
      expect(sortedIds(items, comparators[SortCriteria.ratio]!),
          ['low', 'high']);
    });

    test('size sorts smallest first', () {
      final items = [
        buildTorrentItem(id: 'big', totalSize: 900),
        buildTorrentItem(id: 'small', totalSize: 100),
      ];
      expect(sortedIds(items, comparators[SortCriteria.size]!),
          ['small', 'big']);
    });

    test('every criterion has a comparator', () {
      for (final c in SortCriteria.values) {
        expect(comparators[c], isNotNull, reason: 'missing comparator for $c');
      }
    });

    test('reversed() inverts the order', () {
      final items = [
        buildTorrentItem(id: 'a', name: 'alpha'),
        buildTorrentItem(id: 'b', name: 'beta'),
      ];
      expect(sortedIds(items, comparators[SortCriteria.name]!.reversed()),
          ['b', 'a']);
    });
  });

  group('TorrentState mapping', () {
    test('maps known state strings', () {
      expect(buildTorrentItem(state: 'Downloading').state,
          TorrentState.downloading);
      expect(buildTorrentItem(state: 'Seeding').state, TorrentState.seeding);
      expect(buildTorrentItem(state: 'Paused').state, TorrentState.paused);
      expect(buildTorrentItem(state: 'Checking').state, TorrentState.checking);
    });

    test('splits Queued by finished flag', () {
      expect(buildTorrentItem(state: 'Queued', isFinished: false).state,
          TorrentState.queuedForDownload);
      expect(buildTorrentItem(state: 'Queued', isFinished: true).state,
          TorrentState.queuedForUpload);
    });

    test('falls back to inactive for unknown states', () {
      expect(buildTorrentItem(state: 'Moon').state, TorrentState.inactive);
    });
  });

  group('FilterSpec.toFilterDict', () {
    test('the all-filter produces an empty dict', () {
      expect(FilterSpec.all.toFilterDict(), <String, String>{});
    });

    test('emits only the non-All fields', () {
      expect(const FilterSpec('Downloading', 'All', 'All').toFilterDict(),
          {'state': 'Downloading'});
      expect(const FilterSpec('All', 'music', 'All').toFilterDict(),
          {'label': 'music'});
      expect(const FilterSpec('All', 'All', 'tracker.example').toFilterDict(),
          {'tracker_host': 'tracker.example'});
    });

    test('emits all three when all are set', () {
      expect(
        const FilterSpec('Seeding', 'music', 'tracker.example').toFilterDict(),
        {
          'state': 'Seeding',
          'label': 'music',
          'tracker_host': 'tracker.example',
        },
      );
    });
  });

  group('FilterSpec equality', () {
    test('equal field values compare equal and hash equal', () {
      const a = FilterSpec('Seeding', 'music', 'tracker.example');
      const b = FilterSpec('Seeding', 'music', 'tracker.example');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing field values compare unequal', () {
      expect(const FilterSpec('Seeding', 'All', 'All'),
          isNot(const FilterSpec('Paused', 'All', 'All')));
    });
  });
}
