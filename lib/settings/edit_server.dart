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
import 'package:trireme/home/home_controller.dart';

class EditServer extends StatefulWidget {
  final ServerDBModel server;

  EditServer(this.server);

  @override
  EditServerState createState() => EditServerState();
}

class EditServerState extends State<EditServer> {
  var key = GlobalKey<_EditServerState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.settingsServerDetails),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: Strings.settingsDeleteServerTooltip,
            onPressed: () => key.currentState!.deleteServer(),
          )
        ],
      ),
      body: LoadingContainer(
        child: _EditServer(key, widget.server),
      ),
    );
  }
}

class _EditServer extends StatefulWidget {
  final ServerDBModel server;

  _EditServer(Key key, this.server) : super(key: key);

  @override
  _EditServerState createState() => _EditServerState();
}

class _EditServerState extends State<_EditServer> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ListTile(
          title: Text(Strings.addServerHostLabel),
          subtitle: Text(widget.server.host),
        ),
        ListTile(
          title: Text(Strings.addServerPortLabel),
          subtitle: Text(widget.server.port.toString()),
        ),
        ListTile(
          title: Text(Strings.settingsCertSaved),
          subtitle: Text(_isCertSaved() ? Strings.strYes : Strings.strNo),
        ),
        ListTile(
          title: Text(Strings.addServerUsernameLabel),
          subtitle: Text(widget.server.username),
        )
      ],
    );
  }

  bool _isCertSaved() {
    var cert = widget.server.certificate;
    return (cert != null && cert.isNotEmpty);
  }

  void deleteServer() async {
    var homeController = HomePageController();
    await homeController.getSavedServers();
    var currentServer = await homeController.getSelectedServer();
    if (currentServer.id == widget.server.id) {
      showSnackBar(Strings.settingsDeletingConnectedServer);
      return;
    }
    LoadingContainer.of(context).showProgress();
    try {
      var serversDB = ServerDetailsDatabase();
      await serversDB.open();
      await serversDB.deleteServer(widget.server);
      await serversDB.close();
      Navigator.pop(context, true);
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      LoadingContainer.of(context).hideProgress();
    }
  }

  void showSnackBar(String text) {
    Scaffold.of(context).showSnackBar(
      SnackBar(content: Text(text))
    );
  }
}
