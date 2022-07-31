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

import 'package:flutter_svg/flutter_svg.dart';

import 'package:trireme_client/deserialization.dart';

import 'package:trireme/common/common.dart';

class TorrentPeersPage extends StatefulWidget {
  final String torrentId;

  TorrentPeersPage(this.torrentId);

  @override
  State<StatefulWidget> createState() {
    return TorrentPeersState();
  }
}

class TorrentPeersState extends State<TorrentPeersPage>
    with TriremeProgressBarMixin {
  late TriremeRepository repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Peers>(
      stream: repository.getTorrentPeers(widget.torrentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          hideProgressBar();

          if (snapshot.hasData) {
            return _TorrentPeersList(snapshot.data!);
          }
        } else {
          showProgressBar();
        }
        return Container();
      },
    );
  }
}

class _TorrentPeersList extends StatelessWidget {
  final Peers peers;

  _TorrentPeersList(this.peers);

  @override
  Widget build(BuildContext context) {
    return ListView(children: getChildren(context));
  }

  List<Widget> getChildren(BuildContext context) {
    peers.peers.sort((p1, p2) {
      var downSpeedCompare = p2.downSpeed.compareTo(p1.downSpeed);
      if (downSpeedCompare != 0) return downSpeedCompare;
      var upSpeedCompare = p2.upSpeed.compareTo(p1.upSpeed);
      if (upSpeedCompare != 0) return upSpeedCompare;
      return p1.country.compareTo(p2.country);
    });
    return peers.peers.map((p) => getListTileForPeer(context, p)).toList();
  }

  Widget getListTileForPeer(BuildContext context, Peer peer) {
    Widget placeholder = Container(
      color: Colors.transparent,
      height: 24.0,
      width: 24.0,
    );

    Widget getCountryFlag() {
      if (peer.country.trim().isEmpty) {
        return placeholder;
      } else {
        return SvgPicture.network(
          "https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/${peer.country.toLowerCase()}.svg",
          height: 18.0,
          width: 24.0,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          getCountryFlag(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          peer.ip,
                          style: const TextStyle(fontSize: 16.0),
                        ),
                      ),
                      Offstage(
                        offstage: peer.seed == 0,
                        child: const Text("Seed"),
                      )
                    ],
                  ),
                  Container(
                    height: 4.0,
                  ),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                        fontSize: 12.0,
                        color: Theme.of(context).textTheme.caption!.color),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(peer.client),
                        ),
                        Offstage(
                          offstage: peer.downSpeed == 0,
                          child: Icon(
                            Icons.arrow_downward,
                            size: 12.0,
                            color: Theme.of(context).textTheme.caption!.color,
                          ),
                        ),
                        Offstage(
                          offstage: peer.downSpeed == 0,
                          child: ByteSizePerSecond(peer.downSpeed),
                        ),
                        Offstage(
                          offstage: peer.upSpeed == 0,
                          child: Icon(
                            Icons.arrow_upward,
                            size: 12.0,
                            color: Theme.of(context).textTheme.caption!.color,
                          ),
                        ),
                        Offstage(
                          offstage: peer.upSpeed == 0,
                          child: ByteSizePerSecond(peer.upSpeed),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 8.0,
                  ),
                  ClipRect(
                      child: Align(
                    heightFactor: 0.5,
                    child: LinearProgressIndicator(
                      value: peer.progress,
                    ),
                  )),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
