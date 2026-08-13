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
            colorFilter: ColorFilter.mode(
                Theme.of(context).primaryColor.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                BlendMode.srcIn)),
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
  static const _tag = "_SelectedServerState";

  late TriremeRepository repository;
  int? freeSpace;

  // Null until the daemon tells us. Rendering a guess here used to make the
  // button send a command the daemon then ignored, which looked like a dead
  // button.
  bool? isPaused;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
    _fetchServerState();
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
                    icon: Icon(
                        isPaused == true ? Icons.play_arrow : Icons.pause),
                    onPressed:
                        isPaused == null ? null : _toggleSessionPause,
                  ),
                ),
              ],
            )));
  }

  void _fetchServerState() async {
    try {
      // Both calls go to the same daemon, so run them together rather than
      // waiting out two round trips before the button becomes usable.
      final results = await Future.wait(
          [repository.getFreeSpace(), repository.isSessionPaused()]);
      if (!mounted) return;
      setState(() {
        freeSpace = results[0] as int;
        isPaused = results[1] as bool;
      });
    } catch (e) {
      // The client is disposed while the app is in the background and during
      // a reconnect, so this fails routinely. Leave the button disabled.
      Log.e(_tag, e.toString());
    }
  }

  void _toggleSessionPause() async {
    final wasPaused = isPaused!;
    setState(() {
      isPaused = !wasPaused;
    });
    try {
      if (wasPaused) {
        await repository.resumeSession();
      } else {
        await repository.pauseSession();
      }
    } catch (e) {
      Log.e(_tag, e.toString());
      // The daemon never took the change, so stop showing it as applied.
      if (mounted) {
        setState(() {
          isPaused = wasPaused;
        });
      }
    }
  }
}
