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
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:trireme_client/trireme_client.dart';

import 'package:trireme/common/common.dart';
import 'package:trireme/torrent_list/torrent_item.dart';

import 'details/torrent_details.dart';
import 'files/torrent_files.dart';
import 'peers/torrent_peers.dart';
import 'options/torrent_options.dart';

class TorrentDetailPage extends StatefulWidget {
  final TorrentItem torrentItem;

  TorrentDetailPage(this.torrentItem);

  @override
  State<StatefulWidget> createState() {
    return TorrentDetailState();
  }
}

class TorrentDetailState extends State<TorrentDetailPage> {
  final tabs = <Tab>[
    Tab(text: Strings.detailTabDetails),
    Tab(text: Strings.detailTabFiles),
    Tab(text: Strings.detailTabPeers),
    Tab(text: Strings.detailTabOptions),
  ];

  StreamSubscription<DelugeRpcEvent> _eventSubscription;

  @override
  Widget build(BuildContext context) {
    _eventSubscription = RepositoryProvider.repositoryOf(context)
        .getDelugeRpcEvents()
        .where((e) => e is TorrentRemovedEvent)
        .map((e) => e as TorrentRemovedEvent)
        .where((e) => e.torrentId == widget.torrentItem.id)
        .listen((e) {
      Navigator.pop(context);
    });

    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.torrentItem.name),
            bottom: TabBar(
              tabs: tabs,
            ),
          ),
          body: LoadingContainer(
            child: TabBarView(
              children: [
                TorrentDetailsPage(widget.torrentItem.id),
                TorrentFileListPage(widget.torrentItem.id),
                TorrentPeersPage(widget.torrentItem.id),
                TorrentOptionsPage(widget.torrentItem.id),
              ],
            ),
          ),
        ));
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }
}

mixin TabControllerAnimationProviderMixin<T extends StatefulWidget> on State<T>
    implements SingleTickerProviderStateMixin<T> {
  Animation<double> tabControllerAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tabControllerAnimation?.removeListener(_onAnimationChanged);
    tabControllerAnimation = DefaultTabController.of(context).animation;
    tabControllerAnimation.addListener(_onAnimationChanged);
  }

  void _onAnimationChanged() {
    onTabControllerValueChanged(tabControllerAnimation.value);
  }

  void onTabControllerValueChanged(double value) {

  }

  Animation<Offset> getOffsetAnimationOfTab(int tab) {
    return _CustomTween(tab).animate(tabControllerAnimation);
  }

  @override
  void dispose() {
    tabControllerAnimation?.removeListener(_onAnimationChanged);
    super.dispose();
  }
}

class _CustomTween extends Tween<Offset> {
  int tab;

  _CustomTween(this.tab);

  @override
  Offset lerp(double d) {
    double x = max(-1, min(d - tab, 1));
    double y = min((d - tab).abs(), 1);
    return Offset(x, 2*y);
  }

  @override
  Offset transform(double d) {
    return lerp(d);
  }
}