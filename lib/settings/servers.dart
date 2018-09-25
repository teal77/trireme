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

import 'package:trireme/common/common.dart';
import 'package:trireme/core/persistence.dart';

import 'edit_server.dart';

class ServerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.settingsServers),
      ),
      body: LoadingContainer(
        child: _ServerList(),
      ),
    );
  }
}

class _ServerList extends StatefulWidget {
  @override
  _ServerListState createState() => _ServerListState();
}

class _ServerListState extends State<_ServerList> {
  List<ServerDBModel> servers = [];

  @override
  void initState() {
    super.initState();
    getServersAsync();
  }

  void getServersAsync() async {
    LoadingContainer.of(context).showProgress();
    try {
      var database = ServerDetailsDatabase();
      await database.open();
      servers = await database.getServers();
      await database.close();
      setState(() {});
    } catch (e) {
      Scaffold.of(context).showSnackBar(
        SnackBar(content: Text(prettifyError(e)))
      );
    } finally {
      LoadingContainer.of(context).hideProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: ListTile.divideTiles(
          context: context,
          tiles: servers.map((s) => _buildServerTile(s))
      ).toList(),
    );
  }

  Widget _buildServerTile(ServerDBModel s) {
    return ListTile(
      title: Text(s.toString()),
      onTap: () => launchServerDetails(s),
    );
  }

  void launchServerDetails(ServerDBModel s) async {
    var result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => EditServer(s))
    );
    if (result == null) return;
    if (result) {
      getServersAsync();
    }
  }
}
