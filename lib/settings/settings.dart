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

import 'appearance.dart';
import 'servers.dart';

class SettingsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.settingsTitle),
      ),
      body: ListView(
          children: ListTile.divideTiles(
        context: context,
        tiles: <Widget>[
          ListTile(
            title: Text(Strings.settingsServers),
            subtitle: Text(Strings.settingsServersInfo),
            onTap: () => launchServerListScreen(context),
          ),
          ListTile(
            title: Text(Strings.settingsAppearance),
            onTap: () => launchAppearanceSettingsScreen(context),
          ),
        ],
      ).toList()),
    );
  }

  void _launchScreen(BuildContext context, Widget screen) {
    Navigator.push<void>(context, MaterialPageRoute(builder: (context) => screen));
  }

  void launchServerListScreen(BuildContext context) {
    _launchScreen(context, ServerList());
  }

  void launchAppearanceSettingsScreen(BuildContext context) {
    _launchScreen(context, AppearanceSettingsScreen());
  }
}
