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

import 'package:rxdart/rxdart.dart';

import 'package:trireme/common/common.dart';

import 'banner.dart';

class DisconnectedBanner extends StatefulWidget {
  @override
  _DisconnectedBannerState createState() => _DisconnectedBannerState();
}

class _DisconnectedBannerState extends State<DisconnectedBanner>
    with SingleTickerProviderStateMixin {
  static const _tag = "_DisconnectedBannerState";

  AnimationController controller;
  TriremeRepository repository;
  StreamSubscription subscription;
  var isBannerShowing = false;
  var enableRetry = true;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    checkConnectionAndShowBanner();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = RepositoryProvider.repositoryOf(context);
    subscription = errorStreamDebounced().listen((e) async {
      if (!isBannerShowing) {
        await checkConnectionAndShowBanner();
        while (mounted && isBannerShowing) {
          await Future.delayed(const Duration(seconds: 2));
          await checkConnectionAndShowBanner();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(parent: controller, curve: Curves.ease);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => TickerMode(
          enabled: animation.value > 0.0,
          child: Align(
            alignment: AlignmentDirectional.bottomEnd,
            heightFactor: animation.value,
            child: child,
          )),
      child: TriremeBanner(Strings.homeDisconnectedInfo, [
        FlatButton(
          onPressed: enableRetry ? onRetryPressed : null,
          child: Text(Strings.strcRetry),
        )
      ]),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    subscription.cancel();
    super.dispose();
  }

  void onRetryPressed() async {
    setState(() {
      enableRetry = false;
    });
    await checkConnectionAndShowBanner();
    setState(() {
      enableRetry = true;
    });
  }

  Stream<Object> errorStreamDebounced() =>
      Observable(repository.errorStream()).debounce(const Duration(seconds: 1));

  var checking = false;
  Future checkConnectionAndShowBanner() async {
    if (checking) return;
    Log.v(_tag, "Checking connection to daemon");
    checking = true;
    try {
      await repository.getDaemonInfo();
      hideBanner();
    } catch (e) {
      Log.e(_tag, e.toString());
      showBanner();
    } finally {
      checking = false;
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
