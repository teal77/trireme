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

import 'dart:math';

import 'package:intl/intl.dart';

import 'package:kilobyte/kilobyte.dart';
import 'package:duration/duration.dart';

import 'package:trireme_client/deserialization.dart';

import 'package:trireme/torrent_list/torrent_item.dart';

class TorrentDetailsController {
  final ratioFormatter = NumberFormat("####.###");

  TorrentItem torrentItem;
  TorrentDetail torrentDetail;

  String getAddedDate() {
    var addedDate = DateTime.fromMillisecondsSinceEpoch(
        torrentDetail.addedTime.toInt() * 1000);
    var since = DateTime.now().difference(addedDate);

    if (since.inDays > 365) {
      return "${DateFormat.yMMMd().add_jm().format(addedDate)}";
    } else if (since.inDays > 30) {
      return "${DateFormat("MMM d").add_jm().format(addedDate)}";
    } else if (since.inHours > 24) {
      return "${DateFormat("EEEEE, MMM d").add_jm().format(addedDate)}";
    } else {
      return "${DateFormat.jms().format(addedDate)}";
    }
  }

  String getTotalSize() {
    return Size(bytes: torrentDetail.totalSize).toString();
  }

  String getWantedSize() {
    return Size(bytes: torrentDetail.totalWanted).toString();
  }

  String getDoneSize() {
    return Size(bytes: torrentDetail.totalDone).toString();
  }

  String getUploadedSize() {
    return Size(bytes: torrentDetail.totalUploaded).toString();
  }

  String getRatio() {
    var ratio = torrentDetail.ratio;
    var decimalPlaces = 5 - "${ratio.toInt()}".length;
    decimalPlaces = max(decimalPlaces, 0);
    var truncatedRatio = ratio.toStringAsFixed(decimalPlaces);
    return truncatedRatio;
  }

  String getProgressPercentage() {
    return "${torrentDetail.progress.toStringAsFixed(1)}%";
  }

  double getProgressFloat() {
    return torrentDetail.progress / 100.0;
  }

  String getDownloadSpeed() {
    return "${Size(bytes: torrentDetail.downloadPayloadRate)}/s";
  }

  String getUploadSpeed() {
    return "${Size(bytes: torrentDetail.uploadPayloadRate)}/s";
  }

  String getEta() {
    var etaDuration = seconds(torrentItem.eta);
    if (etaDuration.inDays > 0) {
      return prettyDuration(etaDuration,
          tersity: DurationTersity.hour, abbreviated: true);
    } else if (etaDuration.inHours > 0) {
      return prettyDuration(etaDuration,
          tersity: DurationTersity.minute, abbreviated: true);
    } else {
      return prettyDuration(etaDuration, abbreviated: true);
    }
  }
}
