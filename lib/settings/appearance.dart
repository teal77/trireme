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
  const AppearanceSettingsScreen({super.key});

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
  const AppearanceSettings({super.key});

  @override
  _AppearanceSettingsState createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  late MaterialColor appThemeColor;
  late ByteSizeStyle byteSizeStyle;
  late ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    appThemeColor = PreferenceProvider.of(context).appThemeColor;
    byteSizeStyle = PreferenceProvider.of(context).byteSizeStyle;
    themeMode = PreferenceProvider.of(context).themeMode;

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
        getSubHeader(Strings.settingsDarkMode),
        RadioGroup<ThemeMode>(
          groupValue: themeMode,
          onChanged: setThemeMode,
          child: Column(
            children: <Widget>[
              RadioListTile(
                  value: ThemeMode.system,
                  title: Text(Strings.settingsDarkModeSystem)),
              RadioListTile(
                  value: ThemeMode.light,
                  title: Text(Strings.settingsDarkModeAlwaysLight)),
              RadioListTile(
                  value: ThemeMode.dark,
                  title: Text(Strings.settingsDarkModeAlwaysDark)),
            ],
          ),
        ),
        getDivider(),
        getSubHeader(Strings.settingsByteSizeStyle),
        RadioGroup<ByteSizeStyle>(
          groupValue: byteSizeStyle,
          onChanged: setByteSizeStyle,
          child: Column(
            children: <Widget>[
              RadioListTile(
                  value: ByteSizeStyle.iec,
                  title: Text(Strings.settingsKibibytes),
                  subtitle: Text(Strings.settingsKibibytesInfo)),
              RadioListTile(
                  value: ByteSizeStyle.si,
                  title: Text(Strings.settingsKilobytes),
                  subtitle: Text(Strings.settingsKilobytesInfo)),
            ],
          ),
        ),
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

  Widget getSubHeader(String text) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
        child: Text(
          text,
          style: TextStyle(fontSize: 13.0, color: Theme.of(context).hintColor),
        ));
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
      if (!mounted) return;
      var newPreference =
          PreferenceProvider.of(context).apply(appThemeColor: color);
      PreferenceProvider.updatePreference(context, newPreference);
    }
  }

  void setThemeMode(ThemeMode? themeMode) async {
    if (themeMode == null) return;
    await saveThemeMode(themeMode);
    if (!mounted) return;
    var newPreference =
        PreferenceProvider.of(context).apply(themeMode: themeMode);
    PreferenceProvider.updatePreference(context, newPreference);
  }

  void setByteSizeStyle(ByteSizeStyle? b) async {
    if (b == null) return;
    await saveByteSizeStyle(b);
    if (!mounted) return;
    var newPreference = PreferenceProvider.of(context).apply(byteSizeStyle: b);
    PreferenceProvider.updatePreference(context, newPreference);
  }
}

class MaterialColorPicker extends StatelessWidget {
  final MaterialColor selectedColor;
  final ValueChanged<MaterialColor> onColorChanged;

  const MaterialColorPicker(this.selectedColor, this.onColorChanged,
      {super.key});

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
          padding: const EdgeInsets.all(4.0),
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
