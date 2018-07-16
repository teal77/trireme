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

import 'package:flutter/material.dart';

import 'package:trireme_client/trireme_client.dart';

import 'package:trireme/add_server/add_server.dart';
import 'package:trireme/common/common.dart';
import 'package:trireme/common/widgets/label_button.dart';
import 'package:trireme/common/widgets/delete_button.dart';
import 'package:trireme/core/persistence.dart';
import 'package:trireme/torrent_list/torrent_list.dart';
import 'package:trireme/torrent_list/torrent_list_controller.dart';

import 'add_torrent.dart';
import 'filter.dart';
import 'home_app_bar.dart';
import 'home_controller.dart';
import 'network_speed_bottomsheet_content.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _HomePageContent();
  }
}

class _HomePageContent extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<_HomePageContent> {
  var controller = HomePageController();

  var scaffoldKey = GlobalKey<ScaffoldState>();
  var loadingContainerKey = GlobalKey<LoadingContainerState>();
  var torrentListKey = GlobalKey<TorrentListState>();

  var loading = false;
  List<ServerDBModel> servers = [];
  ServerDBModel selectedServer;
  var sortCriterion = SortCriteria.name;
  var reverseSort = false;
  var filterSpec = FilterSpec.all;
  var selectedItemCount = 0;

  TriremeRepository repository;

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  Future initStateAsync() async {
    loadingContainerKey.currentState.showProgress();

    var servers = await controller.getSavedServers();

    loadingContainerKey.currentState.hideProgress();

    if (servers.isEmpty) {
      scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text(Strings.homeAddServerSnackbarText),
          duration: Duration(days: 999),
          action: SnackBarAction(
              label: Strings.homeAddServerSnackbarAction,
              onPressed: onAddServerClicked)));
      return;
    } else {
      scaffoldKey.currentState.removeCurrentSnackBar();
    }

    loadingContainerKey.currentState.showProgress();

    var selectedServer = await controller.getSelectedServer();
    var savedSortMode = await getSavedSortMode();
    var savedReverseMode = await getSavedSortReverseMode();
    var savedFilterSpec = await getSavedFilterSpec();

    setState(() {
      this.servers = servers;
      this.selectedServer = selectedServer;
      this.sortCriterion = savedSortMode;
      this.reverseSort = savedReverseMode;
      this.filterSpec = savedFilterSpec;
    });

    List<int> certificate;
    if (selectedServer.certificate != null &&
        selectedServer.certificate.isNotEmpty) {
      certificate = selectedServer.certificate.codeUnits;
    }
    var client = TriremeClient(
        selectedServer.username, selectedServer.password, selectedServer.host,
        port: selectedServer.port, pinnedCertificate: certificate);

    try {
      await client.init();
    } catch (e) {
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text(prettifyError(e)),
        duration: const Duration(seconds: 3),
      ));
    }

    ClientProvider.of(context).setClient(client);
    loadingContainerKey.currentState.hideProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: getHomeAppBar(
          context,
          selectedItemCount,
          IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: Strings.homeFilterTooltip,
              onPressed: showFilters),
          _getSortingButton(onSortCriterionChanged),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: clearSelection,
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: Strings.homePauseTooltip,
            onPressed: pauseTorrents,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: Strings.homeResumeTooltip,
            onPressed: resumeTorrents,
          ),
          DeleteButton(Strings.homeDeleteTooltip, deleteTorrents,
              deleteTorrentsWithData),
          LabelButton(repository, Strings.homeLabelTooltip, setLabel),
          getOverflowButton()),
      body: LoadingContainer(
          key: loadingContainerKey,
          child: Column(
            children: <Widget>[
              FilterSpecContainer(
                filterSpec,
                setFilter,
              ),
              Expanded(
                child: TorrentList(
                    torrentListKey,
                    sortCriterion,
                    reverseSort,
                    filterSpec,
                    (selectedItemCount) => setState(
                        () => this.selectedItemCount = selectedItemCount)),
              )
            ],
          )),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              height: 160.0,
            ),
            DrawerUserSwitcher(
                servers, selectedServer, onAddServerClicked, changeServer),
          ],
          padding: EdgeInsets.zero,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
          color: Colors.white,
          hasNotch: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                SpeedIndicator(
                    Icons.arrow_downward, repository.getSessionDownloadSpeed(),
                    () {
                  _showNetworkSpeedBottomSheet(context, true, repository);
                }),
                SpeedIndicator(
                    Icons.arrow_upward, repository.getSessionUploadSpeed(), () {
                  _showNetworkSpeedBottomSheet(context, false, repository);
                })
              ],
            ),
          )),
      floatingActionButton: FloatingActionButton(
        onPressed: onAddTorrentClicked,
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  void onAddServerClicked() async {
    var didAddServer = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (context) => AddServerPage()));

    if (didAddServer == null || didAddServer == false) return;

    if (servers.isEmpty) {
      initStateAsync();
    } else {
      var servers = await controller.getSavedServers();
      setState(() {
        this.servers = servers;
      });
    }
  }

  Future changeServer(ServerDBModel newServer) async {
    await controller.setSelectedServer(newServer);
    filterSpec = FilterSpec.all;
    sortCriterion = SortCriteria.name;
    reverseSort = false;
    await persistFilter();
    await persistSortMode();
    repository.dispose(); //discard everything about the previous session
    repository.client.dispose();
    RepositoryProvider.of(context).setRepository(new TriremeRepository());
    await initStateAsync();
  }

  void onSortCriterionChanged(SortCriteria newCriterion) {
    setState(() {
      if (sortCriterion == newCriterion) {
        reverseSort = !reverseSort;
      } else {
        reverseSort = false;
      }
      sortCriterion = newCriterion;
    });
    persistSortMode();
  }

  FilterSpec _tempFilterSpec;

  void showFilters() async {
    _tempFilterSpec = filterSpec;
    await showFilterBottomSheet(
        context, repository.getFilterTree(), filterSpec, onFilterSelected);
    setFilter(_tempFilterSpec);
  }

  void setFilter(FilterSpec f) {
    setState(() {
      filterSpec = f;
    });
    persistFilter();
  }

  void onFilterSelected(FilterSpec f) {
    _tempFilterSpec = f;
  }

  void clearSelection() {
    torrentListKey.currentState.clearSelection();
  }

  void pauseTorrents() {
    torrentListKey.currentState.pauseTorrents();
  }

  void resumeTorrents() {
    torrentListKey.currentState.resumeTorrents();
  }

  void deleteTorrents() {
    showConfirmationDialog(Strings.homeDeleteTorrentConfirmationText, () {
      torrentListKey.currentState.deleteTorrents();
    });
  }

  void deleteTorrentsWithData() {
    showConfirmationDialog(Strings.homeDeleteTorrentAndDataConfirmationText,
        () {
      torrentListKey.currentState.deleteTorrentsWithData();
    });
  }

  void setLabel(String label) {
    torrentListKey.currentState.setTorrentsLabel(label);
  }

  Widget getOverflowButton() {
    return new PopupMenuButton<OverflowButtons>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
            PopupMenuItem<OverflowButtons>(
              value: OverflowButtons.selectAll,
              child: Text(Strings.homeSelectAll),
            ),
            PopupMenuItem<OverflowButtons>(
              value: OverflowButtons.invertSelection,
              child: Text(Strings.homeInvertSelection),
            )
          ],
      onSelected: onOverflowMenuClick,
    );
  }

  void onOverflowMenuClick(OverflowButtons overflowButton) {
    switch (overflowButton) {
      case OverflowButtons.selectAll:
        torrentListKey.currentState.selectAll();
        return;
      case OverflowButtons.invertSelection:
        torrentListKey.currentState.invertSelection();
        return;
    }
  }

  void showConfirmationDialog(String text, VoidCallback onAccept) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text(text),
            actions: <Widget>[
              FlatButton(
                onPressed: () {
                  Navigator.pop(context);
                  onAccept();
                },
                child: Text(Strings.strcYes),
              ),
              FlatButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(Strings.strcNo),
              )
            ],
          );
        });
  }

  void onAddTorrentClicked() async {
    Navigator.push(
        context,
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => AddTorrentPage(AddTorrentKind.url)));
  }

  Future persistFilter() async {
    await saveFilter(filterSpec);
  }

  Future persistSortMode() async {
    await saveSortMode(sortCriterion);
    await saveSortReverse(reverseSort);
  }

  void _showNetworkSpeedBottomSheet(BuildContext context,
      bool isDownloadSpeedGraph, TriremeRepository repository) {
    showModalBottomSheet(
        context: context,
        builder: (context) =>
            NetworkSpeedBottomSheet(isDownloadSpeedGraph, repository));
  }
}

enum OverflowButtons { selectAll, invertSelection }

class DrawerUserSwitcher extends StatelessWidget {
  final List<ServerDBModel> servers;
  final ServerDBModel selectedServer;
  final VoidCallback onAddServerPressed;
  final ValueChanged<ServerDBModel> onServerChanged;

  DrawerUserSwitcher(this.servers, this.selectedServer, this.onAddServerPressed,
      this.onServerChanged);

  @override
  Widget build(BuildContext context) {
    Widget getAddServerListItem() {
      return ListTile(
        title: Text(Strings.homeAddServerDrawerButtonText),
        onTap: () {
          Navigator.pop(context);
          onAddServerPressed();
        },
        trailing: Icon(Icons.add),
      );
    }

    if (servers.isEmpty) {
      return getAddServerListItem();
    } else {
      return Container(
          color: Theme.of(context).primaryColor,
          child: ExpansionTile(
            title: Text(selectedServer.toString()),
            children: servers
                .where((s) => s != selectedServer)
                .map((s) => ListTile(
                      title: Text(s.toString()),
                      onTap: () => onServerTapped(context, s),
                    ))
                .toList()
                  ..add(getAddServerListItem()),
          ));
    }
  }

  void onServerTapped(BuildContext context, ServerDBModel newServer) {
    Navigator.pop(context);
    onServerChanged(newServer);
  }
}

class SpeedIndicator extends StatelessWidget {
  final IconData iconData;
  final Stream<String> dataStream;
  final VoidCallback onPressed;

  SpeedIndicator(this.iconData, this.dataStream, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
        stream: dataStream,
        builder: (context, snapshot) {
          return FlatButton.icon(
              onPressed: this.onPressed,
              icon: Icon(iconData),
              label: Text(snapshot.hasData ? snapshot.data : "0"));
        });
  }
}

typedef void OnSortModeSelected(SortCriteria newCriterion);

Widget _getSortingButton(OnSortModeSelected callback) {
  return PopupMenuButton<SortCriteria>(
      onSelected: callback,
      icon: const Icon(Icons.sort),
      tooltip: Strings.homeSortTooltip,
      itemBuilder: (context) => <PopupMenuEntry<SortCriteria>>[
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.name, child: Text(Strings.homeSortByName)),
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.status,
                child: Text(Strings.homeSortByStatus)),
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.dateAdded,
                child: Text(Strings.homeSortByDateAdded)),
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.downloadProgress,
                child: Text(Strings.homeSortByDownloadProgress)),
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.downloadSpeed,
                child: Text(Strings.homeSortByDownloadSpeed)),
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.uploadSpeed,
                child: Text(Strings.homeSortByUploadSpeed)),
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.ratio,
                child: Text(Strings.homeSortByRatio)),
            PopupMenuItem<SortCriteria>(
                value: SortCriteria.size, child: Text(Strings.homeSortBySize)),
          ]);
}
