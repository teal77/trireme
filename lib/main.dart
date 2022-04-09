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

import 'package:trireme/home/home.dart';
import 'package:trireme/common/common.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(child: PreferenceProvider(_MyApp()));
  }
}

class _MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Deluge",
      color: PreferenceProvider.of(context).appThemeColor,
      theme: ThemeData(
        primarySwatch: PreferenceProvider.of(context).appThemeColor,
      ),
      darkTheme: ThemeData(
        primarySwatch: PreferenceProvider.of(context).appThemeColor,
        brightness: Brightness.dark,
        accentColor: PreferenceProvider.of(context).appThemeColor.shade200,
        textSelectionHandleColor: PreferenceProvider.of(context).appThemeColor.shade400,
        toggleableActiveColor: PreferenceProvider.of(context).appThemeColor.shade200,
      ),
      themeMode: PreferenceProvider.of(context).brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: HomePage(),
    );
  }
}