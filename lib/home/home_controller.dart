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

import 'package:shared_preferences/shared_preferences.dart';

import 'package:trireme/core/persistence.dart';

class HomePageController {
  static const _currentSelectedServerPrefKey = "_currentSelectedServerPrefKey";

  List<ServerDBModel> servers = [];

  HomePageController();

  Future<List<ServerDBModel>> getSavedServers() async {
    var database = ServerDetailsDatabase();
    await database.open();
    servers = await database.getServers();
    await database.close();
    return servers;
  }

  Future<ServerDBModel> getSelectedServer() async {
    var prefs = await SharedPreferences.getInstance();
    var id = prefs.getInt(_currentSelectedServerPrefKey);
    if (id == null) {
      return servers.first;
    } else {
      return servers.firstWhere((s) => s.id == id);
    }
  }

  Future setSelectedServer(ServerDBModel server) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentSelectedServerPrefKey, server.id!);
  }
}