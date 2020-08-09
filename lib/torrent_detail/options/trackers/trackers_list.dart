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

import 'package:flutter/material.dart';

import 'package:trireme/common/common.dart';
import 'package:trireme/common/widgets/selectable.dart';

import 'package:trireme_client/deserialization.dart';

class TrackerList extends StatefulWidget {
  final String torrentId;

  TrackerList(this.torrentId);

  @override
  State createState() {
    return _TrackerListState();
  }
}

class _TrackerListState extends State<TrackerList> {
  final _key = GlobalKey<_TrackersListPageState>();
  var selectedItemCount = 0;

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
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: delete,
                )
              ],
              title: Text(selectedItemCount.toString()),
              backgroundColor: theme.backgroundColor,
              textTheme: theme.textTheme,
              iconTheme: theme.iconTheme,
              brightness: theme.brightness,
            ),
      body: LoadingContainer(
        child: TrackerListPage(_key, widget.torrentId, (s) {
          setState(() {
            selectedItemCount = s;
          });
        }),
      ),
    );
  }

  void clearSelection() {
    _key.currentState.clearSelection();
  }

  void delete() {
    _key.currentState.delete();
  }

  void add() {
    _key.currentState.add();
  }
}

class TrackerListPage extends StatefulWidget {
  final String torrentId;
  final ValueChanged<int> callback;

  TrackerListPage(Key key, this.torrentId, this.callback) : super(key: key);

  @override
  State createState() {
    return _TrackersListPageState();
  }
}

class _TrackersListPageState extends State<TrackerListPage>
    with TriremeProgressBarMixin {
  final _key = GlobalKey<_TrackerListContentState>();
  TriremeRepository repository;
  var selectedTrackers = <String>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: repository.getTorrentOptionsUpdates(widget.torrentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            hideProgressBar();

            if (snapshot.hasData) {
              return _TrackerListContent(
                  _key,
                  widget.torrentId,
                  (snapshot.data as TorrentOptions).trackers,
                  selectedTrackers,
                  widget.callback,
                  toggleSelection);
            } else if (snapshot.hasError) {
              return ErrorPage(snapshot.error);
            }
          } else {
            showProgressBar();
          }
          return Container();
        });
  }

  void toggleSelection(Tracker t) {
    if (selectedTrackers.contains(t.url)) {
      setState(() {
        selectedTrackers.removeWhere((e) => e == t.url);
      });
    } else {
      setState(() {
        selectedTrackers.add(t.url);
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
    _key.currentState.delete();
    clearSelection();
  }

  void add() {
    _key.currentState.add();
  }
}

typedef _ToggleTrackerCallback = void Function(Tracker t);

class _TrackerListContent extends StatefulWidget {
  final String torrentId;
  final List<Tracker> trackers;
  final List<String> selectedTrackers;
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
  TriremeRepository repository;

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
                  selected: widget.selectedTrackers.contains(e.url),
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
        .where((element) => !widget.selectedTrackers.contains(element.url));
    setTracker(getApiFormatTrackers(trackers.toList()));
  }

  void add() async {
    var url = await showUrlInputDialog(Strings.trackerUrlDialogTitle);
    if (url != null && url.isNotEmpty) {
      addTracker(url);
    }
  }

  Future<String> showUrlInputDialog(String title) async {
    String userInput;
    return showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (s) => userInput = s,
              ),
              actions: <Widget>[
                FlatButton(
                  child: Text(Strings.strOk),
                  onPressed: () {
                    Navigator.pop(context, userInput);
                  },
                )
              ],
            ));
  }

  void addTracker(String url) {
    final newTracker = Tracker();
    newTracker.url = url;
    setTracker(getApiFormatTrackers([...widget.trackers, newTracker]));
  }

  List<Map<String, dynamic>> getApiFormatTrackers(List<Tracker> trackers) {
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
