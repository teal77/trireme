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

import 'dart:io';

import 'package:kilobyte/kilobyte.dart';

import 'package:trireme_client/trireme_client.dart';

export 'client_provider.dart';
export 'error_page.dart';
export 'loading_container.dart';
export 'log.dart';
export 'repository_provider.dart';
export 'strings.dart';
export 'trireme_repository.dart';

String prettifyError(Object error) {
  if (error is DelugeRpcError) {
    return error.toString();
  } else if (error is SocketException) {
    if (error.osError != null) {
      if (error.osError.errorCode == 111) {
        return "Connection refused. Is the deluge server running and configured to accept remote connections?";
      } else if (error.osError.errorCode == 113) {
        return "No route to host";
      }
    }
    return "Network error. Could not connect to server.";
  }
  throw error;
}

String getByteSizeString(int size) {
  return Size(bytes: size).toString();
}
