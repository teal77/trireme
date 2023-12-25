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

class LoadingContainer extends StatefulWidget {
  final Widget child;

  LoadingContainer({Key? key, required this.child}) : super(key: key);

  static LoadingContainerState of(BuildContext context) {
    var state =
    context.findAncestorStateOfType<LoadingContainerState>();
    if (state != null) {
      return state;
    }
    throw "Could not find a LoadingContainer in this widget tree";
  }

  @override
  State createState() => LoadingContainerState();
}

class LoadingContainerState extends State<LoadingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: Duration(milliseconds: 250), vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final animation =
    CurvedAnimation(parent: _controller, curve: Curves.ease);
    return Stack(
      children: <Widget>[
        widget.child,
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return TickerMode(
                enabled: animation.value > 0.0,
                child: Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  heightFactor: animation.value,
                  child: child,
                ));
          },
          child: const LinearProgressIndicator(),
        )
      ],
    );
  }

  void showProgress() {
    _controller.forward();
  }

  void hideProgress() {
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

mixin TriremeProgressBarMixin<T extends StatefulWidget> on State<T> {
  void showProgressBar() {
    if (!mounted) return;
    LoadingContainer.of(context).showProgress();
  }

  void hideProgressBar() {
    if (!mounted) return;
    LoadingContainer.of(context).hideProgress();
  }

  void showProgressBarIf(bool showProgress) {
    showProgress ? showProgressBar() : hideProgressBar();
  }
}
