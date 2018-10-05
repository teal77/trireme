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

import 'package:duration/duration.dart';
import 'package:intl/intl.dart';

import 'package:trireme/common/bytesize.dart';
import '../torrent_item.dart';

class TorrentListItemController {
  static var ratioFormatter = NumberFormat("###0.0#");
  static var ratioFormatterPrecise = NumberFormat("###0.0##");

  TorrentItem torrentItem;

  String getTotalSize(ByteSizeFormatter formatter) {
    return formatter.format(torrentItem.totalSize);
  }

  String getCurrentSize(ByteSizeFormatter formatter) {
    return formatter.format(torrentItem.currentSize);
  }

  String getCurrentSizeExplanation(ByteSizeFormatter formatter) {
    if (torrentItem.isFinished) {
      return "${getCurrentSize(formatter)} uploaded";
    } else {
      return "${getCurrentSize(formatter)}/${getTotalSize(formatter)} (${getProgressPercentage()})";
    }
  }

  String getRatio() {
    var truncatedRatio = torrentItem.ratio.toStringAsFixed(4);
    if (truncatedRatio.contains("e")) {
      return "Ratio: $truncatedRatio";
    }
    var aGigabyte = 1024 * 1024 * 1024;
    if (torrentItem.totalSize > aGigabyte) {
      return "Ratio: ${ratioFormatterPrecise.format(torrentItem.ratio)}";
    }
    return "Ratio: ${ratioFormatter.format(torrentItem.ratio)}";
  }

  String getProgressPercentage() {
    return "${torrentItem.progress.toStringAsFixed(1)}%";
  }

  double getProgressFloat() {
    return torrentItem.progress / 100.0;
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
