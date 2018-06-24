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

import 'package:kilobyte/kilobyte.dart';

import 'package:trireme_client/deserialization.dart';

import 'package:trireme/common/strings.dart';

class TorrentOptionsController {
  TorrentOptions torrentOptions;

  String getCurrentDownloadSpeedLimit() {
    if (torrentOptions.maxDownloadSpeed < 0) {
      return Strings.detailOptionUnsetText;
    } else {
      return "${Size(kilobytes: torrentOptions.maxDownloadSpeed.toInt())}/s";
    }
  }

  String getCurrentUploadSpeedLimit() {
    if (torrentOptions.maxUploadSpeed < 0) {
      return Strings.detailOptionUnsetText;
    } else {
      return "${Size(kilobytes: torrentOptions.maxUploadSpeed.toInt())}/s";
    }
  }

  String getCurrentConnectionLimit() {
    if (torrentOptions.maxConnections < 1) {
      return Strings.detailOptionUnsetText;
    } else {
      return torrentOptions.maxConnections.toString();
    }
  }

  String getCurrentUploadSlotLimit() {
    if (torrentOptions.maxUploadSlots < 0) {
      return Strings.detailOptionUnsetText;
    } else {
      return torrentOptions.maxUploadSlots.toString();
    }
  }
}
