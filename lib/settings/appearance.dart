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

class AppearanceSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.settingsAppearance),
      ),
      body: AppearanceSettings(),
    );
  }
}

class AppearanceSettings extends StatefulWidget {
  @override
  _AppearanceSettingsState createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  MaterialColor appThemeColor;
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    appThemeColor = PreferenceProvider.of(context).appThemeColor;
    isDark = PreferenceProvider.of(context).brightness == Brightness.dark;
    return ListView(
      children: <Widget>[
        ListTile(
          title: Text(Strings.settingsAppThemeColor),
          trailing: CircleAvatar(
            backgroundColor: appThemeColor.shade500,
          ),
          onTap: () {
            showColorPickerDialog();
          },
        ),
        getDivider(),
        SwitchListTile(
          title: Text(Strings.settingsDarkMode),
          value: isDark,
          onChanged: ((value) => {toggleDarkMode(value)}),
        )
      ],
    );
  }

  Widget getDivider() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        height: 1.0,
        color: Theme.of(context).dividerColor,
      ),
    );
  }

  void showColorPickerDialog() async {
    var color = await showDialog<MaterialColor>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            children: <Widget>[
              MaterialColorPicker(appThemeColor, (c) {
                Navigator.pop(context, c);
              })
            ],
          );
        });
    if (color != null) {
      await saveAppColor(color);
      var newPreference =
          PreferenceProvider.of(context).apply(appThemeColor: color);
      PreferenceProvider.updatePreference(context, newPreference);
    }
  }

  void toggleDarkMode(bool isDark) async {
    await saveBrightness(isDark);
    var newPreference = PreferenceProvider.of(context)
        .apply(brightness: isDark ? Brightness.dark : Brightness.light);
    PreferenceProvider.updatePreference(context, newPreference);
  }
}

class MaterialColorPicker extends StatelessWidget {
  final MaterialColor selectedColor;
  final ValueChanged<MaterialColor> onColorChanged;

  MaterialColorPicker(this.selectedColor, this.onColorChanged);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: _getColorCircles(),
    );
  }

  List<Widget> _getColorCircles() {
    var colorList = <MaterialColor>[
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey
    ];

    Widget _getColorButton(MaterialColor c) {
      return Padding(
          padding: EdgeInsets.all(4.0),
          child: GestureDetector(
            onTap: () => onColorChanged(c),
            child: CircleAvatar(
              backgroundColor: c.shade500,
            ),
          ));
    }

    return colorList.map((c) => _getColorButton(c)).toList();
  }
}
