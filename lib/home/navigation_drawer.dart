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
  final ServerDBModel selectedServer;
  final VoidCallback onAddServerPressed;
  final ValueChanged<ServerDBModel> onServerChanged;

  NavDrawer(this.servers, this.selectedServer, this.onAddServerPressed,
      this.onServerChanged);

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            children: <Widget>[
              NavDrawerHeader(),
              buildSelectedServer(context),
            ]
              ..addAll(buildServerSwitchTiles())
              ..add(buildAddServerTile()),
            padding: EdgeInsets.zero,
          ),
        ),
        /*ListTile(
          leading: Icon(Icons.settings),
          title: Text(Strings.homeSettings),
        ),
        AboutListTile()*/
      ],
    ));
  }

  Widget buildSelectedServer(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: selectedServer == null
          ? Container()
          : ListTile(
              title: Text(selectedServer.toString()),
            ),
    );
  }

  List<Widget> buildServerSwitchTiles() {
    return servers
        .where((s) => s != selectedServer)
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
      trailing: Icon(Icons.add),
    );
  }
}

class NavDrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).primaryColor),
      height: 160.0,
      child: Align(
        alignment: AlignmentDirectional.center,
        child: SvgPicture.asset(
          "assets/icons/trireme.svg",
          height: 80.0,
          width: 80.0,
          color: Colors.white,
        ),
      ),
    );
  }
}
