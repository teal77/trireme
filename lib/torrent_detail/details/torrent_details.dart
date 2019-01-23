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
import 'package:flutter/rendering.dart';

import 'package:trireme_client/deserialization.dart';

import 'package:trireme/common/bytesize.dart';
import 'package:trireme/common/common.dart';
import 'package:trireme/common/widgets/delete_button.dart';
import 'package:trireme/common/widgets/label_button.dart';
import 'package:trireme/torrent_list/torrent_item.dart';
import 'package:trireme/torrent_list/torrent_list_tile/torrent_list_tile.dart';

import 'move_storage.dart';
import 'torrent_details_controller.dart';

class TorrentDetailsPage extends StatefulWidget {
  final String torrentId;

  TorrentDetailsPage(this.torrentId);

  @override
  State<StatefulWidget> createState() {
    return TorrentDetailState();
  }
}

class TorrentDetailState extends State<TorrentDetailsPage>
    with TriremeProgressBarMixin {
  TorrentDetailsController controller = TorrentDetailsController();
  TriremeRepository repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TorrentDetail>(
      stream: repository.getTorrentDetails(widget.torrentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          hideProgressBar();
          if (snapshot.hasData) {
            return _TorrentDetailContent(widget.torrentId, snapshot.data);
          } else if (snapshot.hasError) {
            return ErrorPage(snapshot.error);
          }
        } else {
          showProgressBar();
        }
        return Container();
      },
    );
  }
}

class _TorrentDetailContent extends StatefulWidget {
  final String torrentId;
  final TorrentDetail torrentDetail;

  _TorrentDetailContent(this.torrentId, this.torrentDetail);

  @override
  State createState() {
    return _TorrentDetailContentState();
  }
}

class _TorrentDetailContentState extends State<_TorrentDetailContent>
    with TriremeProgressBarMixin {
  TriremeRepository repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _TorrentDetail(widget.torrentDetail),
        ),
        BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(
                icon: Icon(isPaused() ? Icons.play_arrow : Icons.pause),
                tooltip: isPaused()
                    ? Strings.detailResumeTorrentTooltip
                    : Strings.detailPauseTorrentTooltip,
                onPressed: () {
                  if (isPaused()) {
                    resumeTorrent();
                  } else {
                    pauseTorrent();
                  }
                },
              ),
              DeleteButton(
                  Strings.detailDeleteTorrentTooltip,
                  showDeleteConfirmationDialog,
                  showDeleteDataConfirmationDialog),
              LabelButton(
                  repository, Strings.detailLabelTorrentTooltip, setLabel),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: Strings.detailRecheckStorageTooltip,
                onPressed: () {
                  recheckTorrent();
                },
              ),
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: Strings.detailUpdateTrackersTooltip,
                onPressed: () {
                  updateTrackers();
                },
              ),
              IconButton(
                icon: const Icon(Icons.sd_storage),
                tooltip: Strings.detailMoveStorageTooltip,
                onPressed: () {
                  showMoveStorageDialog();
                },
              )
            ],
          ),
        )
      ],
    );
  }

  bool isPaused() {
    return getTorrentStateForStateString(
            widget.torrentDetail.state, widget.torrentDetail.isFinished) ==
        TorrentState.paused;
  }

  void resumeTorrent() async {
    showProgressBar();
    try {
      await repository.resumeTorrents([widget.torrentId]);
    } catch (e) {
      showErrorSnackBar(e);
    } finally {
      hideProgressBar();
    }
  }

  void pauseTorrent() async {
    showProgressBar();
    try {
      await repository.pauseTorrents([widget.torrentId]);
    } catch (e) {
      showErrorSnackBar(e);
    } finally {
      hideProgressBar();
    }
  }

  void setLabel(String label) async {
    showProgressBar();
    try {
      await repository.setTorrentLabel(widget.torrentId, label);
    } catch (e) {
      showErrorSnackBar(e);
    } finally {
      hideProgressBar();
    }
  }

  void recheckTorrent() async {
    showProgressBar();
    try {
      await repository.recheckTorrents([widget.torrentId]);
    } catch (e) {
      showErrorSnackBar(e);
    } finally {
      hideProgressBar();
    }
  }

  void updateTrackers() async {
    showProgressBar();
    try {
      await repository.reAnnounceTorrents([widget.torrentId]);
    } catch (e) {
      showErrorSnackBar(e);
    } finally {
      hideProgressBar();
    }
  }

  void showDeleteConfirmationDialog() {
    showConfirmationDialog(Strings.detailDeleteConfirmationText, () async {
      showProgressBar();
      try {
        await repository.removeTorrent(widget.torrentId, false);
      } catch (e) {
        showErrorSnackBar(e);
      } finally {
        hideProgressBar();
      }
    });
  }

  void showDeleteDataConfirmationDialog() {
    showConfirmationDialog(Strings.detailDeleteDataConfirmationText, () async {
      showProgressBar();
      try {
        await repository.removeTorrent(widget.torrentId, true);
      } catch (e) {
        showErrorSnackBar(e);
      } finally {
        hideProgressBar();
      }
    });
  }

  void showConfirmationDialog(String text, VoidCallback onConfirm) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              content: Text(text),
              actions: <Widget>[
                FlatButton(
                  child: Text(Strings.strcYes),
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
                FlatButton(
                  child: Text(Strings.strcNo),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )
              ],
            ));
  }

  void showMoveStorageDialog() async {
    Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            MoveStorageDialog(widget.torrentId, widget.torrentDetail.path)));
  }

  void showErrorSnackBar(Object error) {
    showSnackBar(prettifyError(error));
  }

  void showSnackBar(String text) {
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(text),
    ));
  }
}

class _TorrentDetail extends StatelessWidget {
  final TorrentDetail torrentDetail;
  final TorrentDetailsController controller = TorrentDetailsController();

  _TorrentDetail(this.torrentDetail);

  @override
  Widget build(BuildContext context) {
    controller.torrentDetail = torrentDetail;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text("Added ${controller.getAddedDate()}"),
              ),
              Offstage(
                offstage:
                    torrentDetail.label == null || torrentDetail.label.isEmpty,
                child: Container(
                  decoration: BoxDecoration(color: Colors.black),
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    torrentDetail.label ?? "",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            ],
          ),
          Container(
            height: 16.0,
          ),
          _TorrentStatus(torrentDetail),
          Container(
            height: 16.0,
          ),
          Text(
            torrentDetail.name,
            softWrap: true,
          ),
          Container(
            height: 4.0,
          ),
          Text(torrentDetail.hash),
          Container(
            height: 4.0,
          ),
          Text(
            "${Strings.detailPathLabel} ${torrentDetail.path}",
            softWrap: true,
          ),
          Container(
            height: 4.0,
          ),
          Text("${Strings.detailFilesLabel} ${torrentDetail.files}"),
          Container(
            height: 4.0,
          ),
          Text(
              "${Strings.detailIsPrivateLabel} ${torrentDetail.private ? Strings.strYes : Strings.strNo}"),
          Offstage(
            offstage: torrentDetail.comment.isEmpty,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "${Strings.detailCommentLabel} ${torrentDetail.comment}",
                softWrap: true,
              ),
            ),
          ),
          Offstage(
            offstage: torrentDetail.timeCompleted == null ||
                !torrentDetail.isFinished,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "${Strings.detailCompletedLabel} ${controller.getCompletedDate()}",
                softWrap: true,
              ),
            ),
          ),
          Offstage(
            offstage: !torrentDetail.isFinished,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "${Strings.detailSeedingTime} ${controller.getSeedingTime()}",
                softWrap: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
            child: getSubHeader(Strings.detailTrackerSubHeader),
          ),
          Text(torrentDetail.trackerStatus),
        ],
      ),
    );
  }

  Widget getSubHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0),
    );
  }
}

class _TorrentStatus extends StatelessWidget {
  final TorrentDetail torrentDetail;
  final TorrentDetailsController controller = TorrentDetailsController();

  _TorrentStatus(this.torrentDetail);

  @override
  Widget build(BuildContext context) {
    controller.torrentDetail = torrentDetail;
    MaterialColor color = TorrentStateProperties(getTorrentStateForStateString(
            torrentDetail.state, torrentDetail.isFinished))
        .color;
    return Center(
        child: Container(
            width: 208.0,
            child: AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  children: <Widget>[
                    Container(
                      constraints: BoxConstraints.expand(),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: Colors.grey.shade200),
                      padding: const EdgeInsets.all(4.0),
                      child: CircularProgressIndicator(
                        value: torrentDetail.progress / 100.0,
                        backgroundColor: color.shade200,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color.shade500),
                        strokeWidth: 8.0,
                      ),
                    ),
                    Container(
                        constraints: BoxConstraints.expand(),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).scaffoldBackgroundColor),
                        margin: const EdgeInsets.all(8.0),
                        child: _buildTorrentStatusContent(context)),
                  ],
                ))));
  }

  Widget _buildTorrentStatusContent(BuildContext context) {
    var formatter =
        ByteSizeFormatter.of(PreferenceProvider.of(context).byteSizeStyle);
    return Column(children: <Widget>[
      Container(
        height: 16.0,
      ),
      Text(
        controller.getProgressPercentage(),
        style: TextStyle(fontSize: 24.0),
      ),
      Text(torrentDetail.state),
      Container(
        height: 8.0,
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.arrow_downward,
                        size: 14.0,
                      ),
                      Text(Strings.detailDown),
                    ],
                  ),
                  Text(
                    controller.getDoneSize(formatter),
                    style: TextStyle(fontSize: 22.0),
                  ),
                  Text("of ${controller.getWantedSize(formatter)}"),
                  Text(
                    controller.getDownloadSpeed(formatter),
                    style: TextStyle(fontSize: 16.0),
                  ),
                  Text(
                      "${Strings.detailSeeds} ${torrentDetail.connectedSeeds}"),
                  Text(
                    "of ${torrentDetail.totalSeeds}",
                    style: TextStyle(fontSize: 12.0),
                  )
                ]),
          ),
          Container(
            width: 4.0,
          ),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.arrow_upward,
                    size: 14.0,
                  ),
                  Text(Strings.detailUp),
                ],
              ),
              Text(
                controller.getUploadedSize(formatter),
                style: TextStyle(fontSize: 22.0),
              ),
              Text("${Strings.detailRatioLabel} ${controller.getRatio()}"),
              Text(
                controller.getUploadSpeed(formatter),
                style: TextStyle(fontSize: 16.0),
              ),
              Text("${Strings.detailPeers} ${torrentDetail.connectedPeers}"),
              Text(
                "of ${torrentDetail.totalPeers}",
                style: TextStyle(fontSize: 12.0),
              )
            ],
          ))
        ],
      ),
    ]);
  }
}
