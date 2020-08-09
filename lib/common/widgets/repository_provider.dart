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

import 'package:meta/meta.dart';

import 'package:trireme_client/trireme_client.dart';

import '../trireme_repository.dart';
import 'client_provider.dart';

class RepositoryProvider extends StatelessWidget {
  final Widget child;

  RepositoryProvider({Key key, @required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClientProvider(
      child: _RepositoryProviderInternal(
        child: child,
      ),
    );
  }

  static TriremeRepository repositoryOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RepositoryProviderInherited>()
        .state
        .repository;
  }

  static RepositoryProviderState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RepositoryProviderInherited>()
        .state;
  }
}

class _RepositoryProviderInternal extends StatefulWidget {
  final Widget child;

  _RepositoryProviderInternal({Key key, @required this.child})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return RepositoryProviderState();
  }
}

class RepositoryProviderState extends State<_RepositoryProviderInternal>
    with WidgetsBindingObserver {
  TriremeRepository repository;
  TriremeClient _client;

  void setRepository(TriremeRepository repository) {
    setState(() {
      this.repository = repository;
    });
  }

  @override
  void initState() {
    super.initState();
    repository ??= TriremeRepository();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = ClientProvider.of(context).client;
    repository.client = _client;
  }

  @override
  Widget build(BuildContext context) {
    return _RepositoryProviderInherited(
      state: this,
      child: widget.child,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      repository.pause();
    } else if (state == AppLifecycleState.resumed) {
      repository.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    repository.dispose();
    super.dispose();
  }
}

class _RepositoryProviderInherited extends InheritedWidget {
  final RepositoryProviderState state;

  _RepositoryProviderInherited({Key key, this.state, Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_RepositoryProviderInherited oldWidget) {
    return true;
  }
}
