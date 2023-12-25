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

import 'add_server_controller.dart';

class HostDetails extends StatefulWidget {
  @override
  _HostDetailsState createState() => _HostDetailsState();
}

class _HostDetailsState extends State<HostDetails> {
  var controller = AddServerController();

  String? host;
  String? port;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextFormField(
          decoration: InputDecoration(labelText: Strings.addServerHostLabel),
          keyboardType: TextInputType.url,
          onSaved: (s) => host = s,
          validator: controller.validateHost,
        ),
        SizedBox(
          height: 16.0,
        ),
        TextFormField(
          initialValue: "58846",
          decoration: InputDecoration(labelText: Strings.addServerPortLabel),
          keyboardType: TextInputType.number,
          onSaved: (s) => port = s,
          validator: controller.validatePort,
        ),
        SizedBox(
          height: 16.0,
        ),
      ],
    );
  }
}
