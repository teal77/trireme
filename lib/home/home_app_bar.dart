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
import 'package:flutter/services.dart';

import 'package:trireme/common/common.dart';

AppBar getHomeAppBar(
    BuildContext context,
    int selectedItemCount,
    Widget filterButton,
    Widget sortButton,
    Widget clearSelectionButton,
    Widget pauseTorrentsButton,
    Widget resumeTorrentsButton,
    Widget deleteTorrentsButton,
    Widget labelTorrentsButton,
    Widget overflowButton) {

  var isSelectionMode = selectedItemCount > 0;
  if (!isSelectionMode) {
    return AppBar(
      title: Text(Strings.homeTitle),
      actions: <Widget>[filterButton, sortButton],
    );
  } else {
    var isDark = Theme.of(context).brightness == Brightness.dark;
    var theme = isDark ? ThemeData.light() : ThemeData.dark();
    return AppBar(
      leading: clearSelectionButton,
      title: Text(selectedItemCount.toString()),
      actions: <Widget>[
        pauseTorrentsButton,
        resumeTorrentsButton,
        deleteTorrentsButton,
        labelTorrentsButton,
        overflowButton,
      ],
      backgroundColor: theme.primaryColor,
      iconTheme: theme.iconTheme,
      toolbarTextStyle: theme.textTheme.bodyMedium,
      titleTextStyle: theme.textTheme.titleLarge,
    );
  }
}
