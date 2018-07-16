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

import 'package:trireme_client/trireme_client.dart';

import '../common.dart';

class ClientProvider extends StatefulWidget {
  final Widget child;
  final TriremeClient client;

  ClientProvider({Key key, this.child, this.client}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ClientProviderState();

  static ClientProviderState of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(_ClientProviderInherited)
    as _ClientProviderInherited)
        .state;
  }
}

class ClientProviderState extends State<ClientProvider>
    with WidgetsBindingObserver {
  static const _tag = "ClientProviderState";

  TriremeClient _client;

  TriremeClient get client => _client;

  void setClient(TriremeClient client) {
    setState(() {
      _client = client;
    });
  }

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return _ClientProviderInherited(
      state: this,
      child: widget.child,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _client?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_client != null) {
        reInitClient();
      }
    }
  }

  void reInitClient() async {
    TriremeClient client = _client;
    setClient(null);
    try {
      await client.init();
    } catch (e) {
      Log.e(_tag, e.toString());
    }
    setClient(client);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _client.dispose();
    super.dispose();
  }
}

class _ClientProviderInherited extends InheritedWidget {
  final ClientProviderState state;

  _ClientProviderInherited({Key key, this.state, Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_ClientProviderInherited oldWidget) {
    return true;
  }
}
