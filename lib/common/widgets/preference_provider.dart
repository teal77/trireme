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

import 'package:trireme/common/preferences.dart';
import 'package:trireme/core/persistence.dart';

class PreferenceProvider extends StatefulWidget {
  final Widget child;

  PreferenceProvider(this.child);

  @override
  _PreferenceProviderState createState() => _PreferenceProviderState();

  static Preferences of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_PreferenceProviderInherited>()
        !.state
        .preferences;
  }

  static void updatePreference(BuildContext context, Preferences preferences) {
    context.dependOnInheritedWidgetOfExactType<_PreferenceProviderInherited>()
        !.state
        .setPreference(preferences);
  }
}

class _PreferenceProviderState extends State<PreferenceProvider> {
  late Preferences _preferences;

  Preferences get preferences => _preferences;

  void setPreference(Preferences preferences) {
    setState(() {
      _preferences = preferences;
    });
  }

  @override
  void initState() {
    super.initState();
    _preferences = Preferences.defaultPreferences;
    readSavedPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return _PreferenceProviderInherited(this, widget.child);
  }

  void readSavedPreferences() async {
    var savedColor = await getSavedAppColor();
    var savedBrightness = await getSavedBrightness();
    var savedByteSizeStyle = await getSavedByteSizeStyle();
    setPreference(_preferences.apply(
        byteSizeStyle: savedByteSizeStyle,
        appThemeColor: savedColor,
        brightness: savedBrightness));
  }
}

class _PreferenceProviderInherited extends InheritedWidget {
  final _PreferenceProviderState state;

  _PreferenceProviderInherited(this.state, Widget child) : super(child: child);

  @override
  bool updateShouldNotify(_PreferenceProviderInherited oldWidget) {
    return true;
  }
}
