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

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:trireme_client/trireme_client.dart';

import '../common.dart';

class ClientProvider extends StatefulWidget {
  final Widget? child;
  final TriremeClient? client;

  const ClientProvider({Key? key, this.child, this.client}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ClientProviderState();

  static ClientProviderState of(BuildContext context) {
    var state = context.dependOnInheritedWidgetOfExactType<_ClientProviderInherited>()?.state;
    if (state != null) {
      return state;
    } else {
      throw "Client provider was null";
    }
  }
}

class ClientProviderState extends State<ClientProvider>
    with WidgetsBindingObserver {
  static const _tag = "ClientProviderState";

  TriremeClient? _client;
  Future<bool>? _connecting;
  Timer? _retryTimer;
  bool _isActive = true;
  final _connectionLost = ValueNotifier<bool>(false);

  ValueListenable<bool> get connectionLost => _connectionLost;

  TriremeClient? get client => _client;

  void setClient(TriremeClient? client) {
    _retryTimer?.cancel();
    setState(() {
      _client = client;
    });
    _connectionLost.value = client?.isDisposed ?? false;
    if (_connectionLost.value) _scheduleRetry();
  }

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    WidgetsBinding.instance.addObserver(this);
    if (_client?.isDisposed ?? false) {
      _connectionLost.value = true;
      _scheduleRetry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ClientProviderInherited(
      state: this,
      child: widget.child!,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isActive = false;
      _retryTimer?.cancel();
      _client?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _isActive = true;
      ensureConnected();
    }
  }

  Future<bool> ensureConnected() {
    return _connecting ??= _ensureConnected().whenComplete(() {
      _connecting = null;
    });
  }

  Future<bool> _ensureConnected() async {
    final currentClient = _client;
    if (!mounted || !_isActive || currentClient == null) return false;

    var reinitialized = false;
    try {
      if (currentClient.isDisposed || _connectionLost.value) {
        await currentClient.init();
        reinitialized = true;
      }
      await currentClient.daemonInfo();
      if (!mounted || !_isActive || !identical(_client, currentClient)) {
        if (reinitialized) currentClient.dispose();
        return false;
      }
      if (reinitialized) setClient(currentClient);
      _connectionLost.value = false;
      _retryTimer?.cancel();
      return true;
    } catch (e) {
      Log.e(_tag, e.toString());
      if (mounted && _isActive && identical(_client, currentClient)) {
        _connectionLost.value = true;
        _scheduleRetry();
      }
      return false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (mounted && _isActive && _client != null) {
      _retryTimer = Timer(const Duration(seconds: 2), () {
        ensureConnected();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _connectionLost.dispose();
    _client?.dispose();
    super.dispose();
  }
}

class _ClientProviderInherited extends InheritedWidget {
  final ClientProviderState? state;

  const _ClientProviderInherited({Key? key, this.state, required Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_ClientProviderInherited oldWidget) {
    return true;
  }
}
