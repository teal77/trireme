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
import 'package:trireme/add_server/add_server_controller.dart';
import 'package:trireme/home/home_controller.dart';

class EditServer extends StatefulWidget {
  final ServerDBModel server;

  const EditServer(this.server, {super.key});

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
            icon: const Icon(Icons.delete),
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

  const _EditServer(Key key, this.server) : super(key: key);

  @override
  _EditServerState createState() => _EditServerState();
}

class _EditServerState extends State<_EditServer> {
  late ServerDBModel server = widget.server;
  final controller = AddServerController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        sectionHeader(Strings.settingsServerConnection),
        ListTile(
          title: Text(Strings.addServerHostLabel),
          subtitle: Text(server.host),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 20,
            tooltip: 'Edit ${Strings.addServerHostLabel}',
            onPressed: () => editField('host', Strings.addServerHostLabel,
                server.host, controller.validateHost, keyboardType: TextInputType.url),
          ),
        ),
        ListTile(
          title: Text(Strings.addServerPortLabel),
          subtitle: Text(server.port.toString()),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 20,
            tooltip: 'Edit ${Strings.addServerPortLabel}',
            onPressed: () => editField('port', Strings.addServerPortLabel,
                server.port.toString(), controller.validatePort,
                keyboardType: TextInputType.number),
          ),
        ),
        const Divider(height: 24),
        sectionHeader(Strings.settingsServerCredentials),
        ListTile(
          title: Text(Strings.addServerUsernameLabel),
          subtitle: Text(server.username),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 20,
            tooltip: 'Edit ${Strings.addServerUsernameLabel}',
            onPressed: () => editField('username', Strings.addServerUsernameLabel,
                server.username, controller.validateUsername),
          ),
        ),
        ListTile(
          title: Text(Strings.addServerPasswordLabel),
          subtitle: const Text('********'),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 20,
            tooltip: 'Edit ${Strings.addServerPasswordLabel}',
            onPressed: () => editField('password', Strings.addServerPasswordLabel,
                server.password, controller.validatePassword, obscureText: true),
          ),
        ),
        const Divider(height: 24),
        ListTile(
          title: Text(Strings.settingsCertSaved),
          subtitle: Text(_isCertSaved() ? Strings.strYes : Strings.strNo),
        ),
      ],
    );
  }

  Widget sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
    );
  }

  Future<void> editField(String column, String title, String initialValue,
      FormFieldValidator<String> validator,
      {TextInputType? keyboardType, bool obscureText = false}) async {
    final formKey = GlobalKey<FormState>();
    var value = initialValue;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: initialValue,
            autofocus: true,
            keyboardType: keyboardType,
            obscureText: obscureText,
            autocorrect: !obscureText,
            enableSuggestions: !obscureText,
            validator: validator,
            onChanged: (text) => value = text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Strings.strcCancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, value);
            },
            child: Text(Strings.strcSave),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result == initialValue) return;

    final values = server.toMap();
    values[column] = column == 'port' ? int.parse(result) : result;
    final updated = ServerDBModel.fromMap(values);
    final database = ServerDetailsDatabase();
    final loading = LoadingContainer.of(context);
    loading.showProgress();
    try {
      await database.open();
      await database.updateServer(server, updated);
      if (mounted) setState(() => server = updated);
    } catch (e) {
      if (mounted) showSnackBar(e.toString());
    } finally {
      await database.close();
      if (mounted) loading.hideProgress();
    }
  }

  bool _isCertSaved() {
    var cert = server.certificate;
    return cert.isNotEmpty;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text))
    );
  }
}
