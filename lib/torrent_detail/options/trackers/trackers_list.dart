/*
 * Trireme for Deluge - A Deluge thin client for Android.
 * Copyright (C) 2020  Aashrava Holla
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
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:trireme/common/common.dart';
import 'package:trireme/common/widgets/selectable.dart';

import 'package:trireme_client/deserialization.dart';
import 'package:trireme_client/events.dart';

class TrackerList extends StatefulWidget {
  final String torrentId;

  TrackerList(this.torrentId);

  @override
  State createState() {
    return _TrackerListState();
  }
}

class _TrackerListState extends State<TrackerList>
    with TriremeProgressBarMixin {
  final _key = GlobalKey<_TrackersListPageState>();
  var selectedItemCount = 0;
  late TriremeRepository repository;
  StreamSubscription<DelugeRpcEvent>? eventsStreamSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
    eventsStreamSubscription?.cancel();
    eventsStreamSubscription = repository
        .getDelugeRpcEvents()
        .where((event) => event is TorrentTrackerStatusEvent)
        .map((event) => event as TorrentTrackerStatusEvent)
        .where((event) => event.torrentId == widget.torrentId)
        .listen((event) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    var isDark = Theme.of(context).brightness == Brightness.dark;
    var theme = isDark ? ThemeData.light() : ThemeData.dark();
    return Scaffold(
      appBar: selectedItemCount == 0
          ? AppBar(
              title: Text(Strings.trackerTitle),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: add,
                )
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: clearSelection,
              ),
              actions: <Widget>[
                if (selectedItemCount == 1) ...[
                  IconButton(
                      icon: const Icon(Icons.arrow_upward), onPressed: moveUp),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: moveDn,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: edit,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: delete,
                )
              ],
              title: Text(selectedItemCount.toString()),
              backgroundColor: theme.backgroundColor,
              toolbarTextStyle: theme.textTheme.bodyMedium,
              titleTextStyle: theme.textTheme.titleLarge,
              iconTheme: theme.iconTheme,
            ),
      body: FutureBuilder(
        future: repository.getTorrentOptionsUpdates(widget.torrentId).first,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            hideProgressBar();
            return TrackerListPage(_key, widget.torrentId,
                (snapshot.data as TorrentOptions).trackers, (s) {
              setState(() {
                selectedItemCount = s;
              });
            });
          } else if (snapshot.hasError) {
            hideProgressBar();
            return ErrorPage(snapshot.error!);
          } else {
            showProgressBar();
            return Container();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    eventsStreamSubscription?.cancel();
    super.dispose();
  }

  void clearSelection() {
    _key.currentState!.clearSelection();
  }

  void delete() {
    _key.currentState!.delete();
  }

  void edit() {
    _key.currentState!.edit();
  }

  void moveUp() {
    _key.currentState!.moveUp();
  }

  void moveDn() {
    _key.currentState!.moveDn();
  }

  void add() {
    _key.currentState!.add();
  }
}

class TrackerListPage extends StatefulWidget {
  final String torrentId;
  final List<Tracker> trackers;
  final ValueChanged<int> callback;

  TrackerListPage(Key key, this.torrentId, this.trackers, this.callback)
      : super(key: key);

  @override
  State createState() {
    return _TrackersListPageState();
  }
}

class _TrackersListPageState extends State<TrackerListPage> {
  final _key = GlobalKey<_TrackerListContentState>();
  late TriremeRepository repository;
  final selectedTrackers = <int>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return _TrackerListContent(_key, widget.torrentId, widget.trackers,
        selectedTrackers, widget.callback, toggleSelection);
  }

  void toggleSelection(Tracker t) {
    if (selectedTrackers.contains(t.tier)) {
      setState(() {
        selectedTrackers.removeWhere((e) => e == t.tier);
      });
    } else {
      setState(() {
        selectedTrackers.add(t.tier);
      });
    }
    widget.callback(selectedTrackers.length);
  }

  void clearSelection() {
    setState(() {
      selectedTrackers.clear();
      widget.callback(0);
    });
  }

  void delete() {
    _key.currentState!.delete();
    clearSelection();
  }

  void edit() {
    _key.currentState!.edit(
        widget.trackers.firstWhere((e) => e.tier == selectedTrackers.first));
    clearSelection();
  }

  void moveUp() {
    _key.currentState!.moveUp();
    clearSelection();
  }

  void moveDn() {
    _key.currentState!.moveDn();
    clearSelection();
  }

  void add() {
    _key.currentState!.add();
  }
}

typedef _ToggleTrackerCallback = void Function(Tracker t);

class _TrackerListContent extends StatefulWidget {
  final String torrentId;
  final List<Tracker> trackers;
  final List<int> selectedTrackers;
  final ValueChanged<int> selectedCallback;
  final _ToggleTrackerCallback toggleCallback;

  _TrackerListContent(Key key, this.torrentId, this.trackers,
      this.selectedTrackers, this.selectedCallback, this.toggleCallback)
      : super(key: key);

  @override
  State createState() {
    return _TrackerListContentState();
  }
}

class _TrackerListContentState extends State<_TrackerListContent> {
  late TriremeRepository repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: widget.trackers
          .map((e) => InkWell(
                onTap: isSelectMode()
                    ? () {
                        toggleSelection(e);
                      }
                    : null,
                onLongPress: isSelectMode()
                    ? null
                    : () {
                        toggleSelection(e);
                      },
                child: Selectable(
                  selected: widget.selectedTrackers.contains(e.tier),
                  child: ListTile(
                    title: Text(e.url),
                  ),
                ),
              ))
          .toList(),
    );
  }

  bool isSelectMode() {
    return widget.selectedTrackers.isNotEmpty;
  }

  void toggleSelection(Tracker tracker) {
    widget.toggleCallback(tracker);
  }

  void delete() {
    final trackers = widget.trackers
        .where((element) => !widget.selectedTrackers.contains(element.tier));
    setTracker(formTrackersApiRequest(trackers.toList()));
  }

  void edit(Tracker tracker) async {
    var url = await showUrlInputDialog(Strings.trackerEditUrlDialogTitle,
        initial: tracker.url);

    if (url != null && url.isNotEmpty) {
      editTracker(url, tracker);
    }
  }

  void moveUp() {
    final selected = widget.trackers
        .firstWhere((e) => e.tier == widget.selectedTrackers.first);
    final trackers = widget.trackers.where((e) => e != selected).toList()
      ..insert(max(selected.tier - 1, 0), selected);
    setTracker(formTrackersApiRequest(trackers));
  }

  void moveDn() {
    final selected = widget.trackers
        .firstWhere((e) => e.tier == widget.selectedTrackers.first);
    final trackers = widget.trackers.where((e) => e != selected).toList()
      ..insert(selected.tier + 1, selected);
    setTracker(formTrackersApiRequest(trackers));
  }

  void add() async {
    var url = await showUrlInputDialog(Strings.trackerUrlDialogTitle);
    if (url != null && url.isNotEmpty) {
      addTracker(url);
    }
  }

  Future<String?> showUrlInputDialog(String title, {String initial = ''}) async {
    final textController = TextEditingController(text: initial);
    return showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                keyboardType: TextInputType.url,
                autocorrect: false,
                controller: textController,
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(Strings.strOk),
                  onPressed: () {
                    Navigator.pop(context, textController.text);
                  },
                )
              ],
            ));
  }

  void addTracker(String url) {
    final newTracker = Tracker();
    newTracker.url = url;
    setTracker(formTrackersApiRequest([...widget.trackers, newTracker]));
  }

  void editTracker(String url, Tracker tracker) {
    final t = widget.trackers
        .cast<Tracker?>()
        .firstWhere((e) => e?.url == tracker.url, orElse: () => null);
    if (t != null) {
      t.url = url;
      setTracker(formTrackersApiRequest(widget.trackers));
    }
  }

  List<Map<String, dynamic>> formTrackersApiRequest(List<Tracker> trackers) {
    final unique = trackers.map((e) => e.url).toSet().toList();
    return trackers
        .asMap()
        .map((key, value) => MapEntry(key, {'url': value.url, 'tier': key}))
        .values
        .where((e) => unique.contains(e['url']))
        .toList();
  }

  void setTracker(List<Map<String, dynamic>> trackers) {
    repository.setTorrentTrackers(widget.torrentId, trackers);
  }
}
