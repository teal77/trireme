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
import 'dart:io';

import 'package:trireme_client/events.dart';
import 'package:trireme_client/trireme_client.dart';

import 'package:trireme/common/common.dart';

import 'torrent_item.dart';

typedef void OnStateUpdated();
typedef void OnSelectedItemsChanged(int selectedCount);

class TorrentListController {
  static const _tag = "TorrentListController";

  final OnStateUpdated stateUpdateCallback;
  final OnSelectedItemsChanged selectedItemsChangedCallback;

  TriremeRepository _repository;

  List<TorrentItem> _torrentItems;
  List<TorrentItem> _selectedTorrentItems = [];

  SortCriteria _sortCriterion = SortCriteria.name;
  bool _reverseSort = false;
  FilterSpec _filterSpec = FilterSpec.all;

  StreamSubscription<List<TorrentItem>> _torrentListUpdateStreamSubscription;
  StreamSubscription<DelugeRpcEvent> _eventsStreamSubscription;

  TorrentListController(
      this.stateUpdateCallback, this.selectedItemsChangedCallback);

  set repository(TriremeRepository repository) {
    _repository = repository;
    listenForTorrentListUpdates();
    listenForRpcEvents();
    getTorrentsWithFilter();
  }

  TriremeRepository get repository => _repository;

  String getEmptyText() {
    if (repository.client == null) {
      return "Loading...";
    }

    if (getItemCount() == 0) {
      return "No torrents";
    } else {
      return "";
    }
  }

  int getItemCount() => _torrentItems == null ? 0 : _torrentItems.length;

  TorrentItem getItemAt(int index) => _torrentItems[index];

  Future getTorrentsWithFilter() async {
    if (!repository.isReady()) {
      await repository.readiness();
    }
    try {
      _torrentItems = await repository.getTorrentList(_filterSpec.toFilterDict());
    } catch (e) {
      if (e is DelugeRpcError || e is SocketException) {
        Log.e(_tag, e.toString());
        await Future.delayed(const Duration(seconds: 1));
        getTorrentsWithFilter();
      } else {
        rethrow;
      }
    }

    if (_torrentItems == null) return;

    sort(_sortCriterion, _reverseSort);

    stateUpdateCallback();
  }

  void listenForTorrentListUpdates() async {
    _torrentListUpdateStreamSubscription?.cancel();
    _torrentListUpdateStreamSubscription =
        repository.getTorrentListUpdates().listen((data) {
      _updateTorrentList(data);
    });
  }

  void listenForRpcEvents() async {
    _eventsStreamSubscription?.cancel();
    _eventsStreamSubscription =
        repository.getDelugeRpcEvents().listen((data) {
          if (isListAlteringEvent(data)) {
            getTorrentsWithFilter();
          }
        });
  }

  bool isListAlteringEvent(DelugeRpcEvent event) {
    return event is TorrentAddedEvent ||
        event is TorrentRemovedEvent ||
        event is TorrentStateChangedEvent ||
        event is TorrentResumedEvent ||
        event is TorrentFinishedEvent ||
        event is SessionPausedEvent ||
        event is SessionResumedEvent;
  }

  Future updateTorrentsWithIds(List<String> ids) async {
    List updates = await repository.getTorrentList({'id': ids});
    _updateTorrentList(updates);
  }

  void subscribeForStatusUpdates(TorrentItem torrentItem) {
    repository.subscribeForTorrentListUpdates(torrentItem);
  }

  void unSubscribeFromUpdates(TorrentItem torrentItem) {
    repository.unsubscribeFromTorrentListUpdates(torrentItem);
  }

  void _updateTorrentList(List<TorrentItem> newTorrentItems) {
    if (newTorrentItems == null) return;

    for (var t in newTorrentItems) {
      _updateTorrent(t);
    }
    stateUpdateCallback();
  }

  void _updateTorrent(TorrentItem torrentItem) {
    var pos = _torrentItems.indexWhere((t) => t.id == torrentItem.id);
    if (pos >= 0) {
      _torrentItems[pos] = torrentItem;
    } else {
      repository.unsubscribeFromTorrentListUpdates(torrentItem);
    }
  }

  void sort(SortCriteria criterion, bool reverse) {
    _sortCriterion = criterion;
    _reverseSort = reverse;

    if (_torrentItems != null && _torrentItems.isNotEmpty) {
      _torrentItems.sort(_getComparator(criterion));
      if (reverse) {
        _torrentItems = _torrentItems.reversed.toList();
      }
    }
  }

  Comparator<TorrentItem> _getComparator(SortCriteria criterion) {
    return _comparators[criterion];
  }

  void filter(FilterSpec filterSpec) {
    _filterSpec = filterSpec;
    getTorrentsWithFilter();
  }

  bool isItemSelected(TorrentItem torrentItem) {
    return _selectedTorrentItems.contains(torrentItem);
  }

  bool isSelectionMode() {
    return _selectedTorrentItems.isNotEmpty;
  }

  void toggleTorrentItemSelection(TorrentItem torrentItem) {
    if (_selectedTorrentItems.contains(torrentItem)) {
      _selectedTorrentItems.remove(torrentItem);
    } else {
      _selectedTorrentItems.add(torrentItem);
    }
    selectedItemsChangedCallback(_selectedTorrentItems.length);
  }

  void clearSelection() {
    _selectedTorrentItems.clear();
    selectedItemsChangedCallback(_selectedTorrentItems.length);
    stateUpdateCallback();
  }

  Future pauseTorrents() {
    return repository.pauseTorrents(_getSelectedTorrentIds()).then((_) {
      var ids = _getSelectedTorrentIds();
      clearSelection();
      updateTorrentsWithIds(ids);
    });
  }

  List<String> _getSelectedTorrentIds() {
    return _selectedTorrentItems.map((t) => t.id).toList();
  }

  Future resumeTorrents() {
    return repository.resumeTorrents(_getSelectedTorrentIds()).then((_) {
      var ids = _getSelectedTorrentIds();
      clearSelection();
      updateTorrentsWithIds(ids);
    });
  }

  Future deleteTorrents() {
    return _deleteTorrents(false);
  }

  Future deleteTorrentsWithData() {
    return _deleteTorrents(true);
  }

  Future _deleteTorrents(bool removeData) {
    return Future
        .wait(_getSelectedTorrentIds()
            .map((t) => repository.removeTorrent(t, removeData)))
        .whenComplete(() {
      clearSelection();
      getTorrentsWithFilter();
    });
  }

  Future setTorrentsLabel(String label) {
    return Future
        .wait(_getSelectedTorrentIds()
            .map((t) => repository.setTorrentLabel(t, label)))
        .whenComplete(() {
      var ids = _getSelectedTorrentIds();
      clearSelection();
      updateTorrentsWithIds(ids);
    });
  }

  void selectAll() {
    _selectedTorrentItems.clear();
    _selectedTorrentItems.addAll(_torrentItems);
    selectedItemsChangedCallback(_selectedTorrentItems.length);
    stateUpdateCallback();
  }

  void invertSelection() {
    var invertedSelection =
        _torrentItems.where((t) => !isItemSelected(t)).toList();
    _selectedTorrentItems.clear();
    _selectedTorrentItems.addAll(invertedSelection);
    selectedItemsChangedCallback(_selectedTorrentItems.length);
    stateUpdateCallback();
  }

  void dispose() {
    _torrentListUpdateStreamSubscription?.cancel();
    _eventsStreamSubscription?.cancel();
  }
}

enum SortCriteria {
  name,
  status,
  dateAdded,
  downloadProgress,
  downloadSpeed,
  uploadSpeed,
  ratio,
  size
}

Map<SortCriteria, Comparator<TorrentItem>> _comparators = {
  SortCriteria.name: (a, b) => a.name.compareTo(b.name),
  SortCriteria.status: (a, b) => a.state.index.compareTo(b.state.index),
  SortCriteria.dateAdded: (a, b) => a.dateAdded.compareTo(b.dateAdded),
  SortCriteria.downloadProgress: (a, b) => a.progress.compareTo(b.progress),
  SortCriteria.downloadSpeed: (a, b) =>
      a.downloadSpeed.compareTo(b.downloadSpeed),
  SortCriteria.uploadSpeed: (a, b) => a.uploadSpeed.compareTo(b.uploadSpeed),
  SortCriteria.ratio: (a, b) => a.ratio.compareTo(b.ratio),
  SortCriteria.size: (a, b) => a.totalSize.compareTo(b.totalSize),
};

class FilterSpec {
  static const String strAll = "All";
  final String statusFilter;
  final String labelFilter;
  final String trackerFilter;

  static const all = const FilterSpec(strAll, strAll, strAll);

  const FilterSpec(this.statusFilter, this.labelFilter, this.trackerFilter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterSpec &&
          runtimeType == other.runtimeType &&
          statusFilter == other.statusFilter &&
          labelFilter == other.labelFilter &&
          trackerFilter == other.trackerFilter;

  @override
  int get hashCode =>
      statusFilter.hashCode ^ labelFilter.hashCode ^ trackerFilter.hashCode;

  Map<String, String> toFilterDict() {
    if (this == all) return {};

    var map = <String, String>{};
    if (statusFilter != strAll) {
      map["state"] = statusFilter;
    }
    if (labelFilter != strAll) {
      map["label"] = labelFilter;
    }
    if (trackerFilter != strAll) {
      map["tracker_host"] = trackerFilter;
    }
    return map;
  }
}
