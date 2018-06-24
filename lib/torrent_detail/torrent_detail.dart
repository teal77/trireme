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

class TorrentDetailState extends State<TorrentDetailPage> with SingleTickerProviderStateMixin {
  final tabs = <Tab>[
    Tab(text: Strings.detailTabDetails),
    Tab(text: Strings.detailTabFiles),
    Tab(text: Strings.detailTabPeers),
    Tab(text: Strings.detailTabOptions),
  ];

  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(length: tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.torrentItem.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs,
        ),
      ),
      body: LoadingContainer(
        child: TabBarView(
          controller: _tabController,
          children: [
            TorrentDetailsPage(widget.torrentItem.id),
            TorrentFileListPage(widget.torrentItem.id),
            TorrentPeersPage(widget.torrentItem.id),
            TorrentOptionsPage(widget.torrentItem.id),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
