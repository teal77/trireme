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

import 'package:flutter/material.dart';

import 'package:trireme/common/common.dart';
import 'package:trireme_client/events.dart';

import '../common/widgets/banner.dart';

class SessionPausedBanner extends StatefulWidget {
  const SessionPausedBanner({super.key});

  @override
  _SessionPausedBannerState createState() => _SessionPausedBannerState();
}

class _SessionPausedBannerState extends State<SessionPausedBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late TriremeRepository repository;
  StreamSubscription? subscription;
  var isBannerShowing = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
    // didChangeDependencies runs more than once, and each run used to
    // leave the previous subscription live -- three of them were seen
    // on one screen, so every event fired the handler three times.
    subscription?.cancel();
    subscription = repository
        .getDelugeRpcEvents()
        .where((e) => e is SessionPausedEvent || e is SessionResumedEvent)
        .listen((e) async {
      if (mounted && e is SessionPausedEvent) {
        showBanner();
      } else if (mounted && e is SessionResumedEvent) {
        hideBanner();
      }
    });
    checkAndShowBanner();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(parent: controller, curve: Curves.ease);
    return CollapsibleBanner(
      animation: animation,
      child: TriremeBanner(Strings.homeSessionPaused, [
        TextButton(
          onPressed: onResumePressed,
          child: Text(Strings.homeResumeSession),
        )
      ]),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    subscription?.cancel();
    super.dispose();
  }

  void onResumePressed() async {
    await repository.resumeSession();
  }

  void checkAndShowBanner() async {
    if (!repository.isReady()) {
      await repository.readiness();
    }
    final isPaused = await repository.isSessionPaused();
    if (isPaused) {
      showBanner();
    } else {
      hideBanner();
    }
  }

  void showBanner() {
    isBannerShowing = true;
    controller.forward();
  }

  void hideBanner() async {
    isBannerShowing = false;
    controller.reverse();
  }
}
