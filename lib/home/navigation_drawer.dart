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

import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:trireme/common/common.dart';
import 'package:trireme/core/persistence.dart';

class NavDrawer extends StatelessWidget {
  final List<ServerDBModel> servers;
  final ServerDBModel? selectedServer;
  final VoidCallback onAddServerPressed;
  final ValueChanged<ServerDBModel> onServerChanged;
  final VoidCallback onSettingsPressed;

  const NavDrawer(this.servers, this.selectedServer, this.onAddServerPressed,
      this.onServerChanged, this.onSettingsPressed,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const NavDrawerHeader(),
              if (selectedServer != null) SelectedServer(selectedServer!),
              ...buildServerSwitchTiles(),
              buildAddServerTile(),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(Strings.homeSettings),
          onTap: onSettingsPressed,
        ),
//        AboutListTile()
      ],
    ));
  }

  List<Widget> buildServerSwitchTiles() {
    return servers
        .where((s) => s.id != selectedServer?.id)
        .map(
          (s) => buildServerTile(s),
        )
        .toList();
  }

  Widget buildServerTile(ServerDBModel server) {
    return ListTile(
      title: Text(server.toString()),
      onTap: () => onServerChanged(server),
    );
  }

  Widget buildAddServerTile() {
    return ListTile(
      title: Text(Strings.homeAddServerDrawerButtonText),
      onTap: onAddServerPressed,
      trailing: const Icon(Icons.add),
    );
  }
}

class NavDrawerHeader extends StatelessWidget {
  const NavDrawerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).primaryColor),
      height: 160.0,
      child: Align(
        alignment: AlignmentDirectional.center,
        child: SvgPicture.asset("assets/icons/trireme.svg",
            height: 80.0,
            width: 80.0,
            color: Theme.of(context).primaryColor.computeLuminance() > 0.5
                ? Colors.black
                : Colors.white),
      ),
    );
  }
}

class SelectedServer extends StatefulWidget {
  const SelectedServer(this.selectedServer, {super.key});

  final ServerDBModel selectedServer;

  @override
  State<StatefulWidget> createState() {
    return _SelectedServerState();
  }
}

class _SelectedServerState extends State<SelectedServer> {
  late TriremeRepository repository;
  int? freeSpace;
  bool isPaused = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
    if (Scaffold.of(context).isDrawerOpen) {
      _fetchFreeSpace();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Theme.of(context).primaryColor,
        child: Theme(
            data: Theme.of(context).copyWith(
                listTileTheme: Theme.of(context).listTileTheme.copyWith(
                    textColor:
                        Theme.of(context).primaryColor.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white)),
            child: Column(
              children: [
                ListTile(
                  title: Text(widget.selectedServer.toString()),
                  subtitle: Row(
                    children: [
                      if (freeSpace != null) ByteSize(freeSpace!),
                      if (freeSpace != null) const Text(" free")
                    ],
                  ),
                  trailing: IconButton(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    constraints: const BoxConstraints(),
                    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                    onPressed: _toggleSessionPause,
                  ),
                ),
              ],
            )));
  }

  _fetchFreeSpace() async {
    final fs = await repository.getFreeSpace();
    final paused = await repository.isSessionPaused();
    setState(() {
      freeSpace = fs;
      isPaused = paused;
    });
  }

  _toggleSessionPause() async {
    final oldIsPaused = isPaused;
    setState(() {
      isPaused = !oldIsPaused;
    });
    if (oldIsPaused) {
      await repository.resumeSession();
    } else {
      await repository.pauseSession();
    }
  }
}
