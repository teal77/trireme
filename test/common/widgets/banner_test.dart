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
import 'package:flutter_test/flutter_test.dart';
import 'package:trireme/common/widgets/banner.dart';

/// Two stacked banners, the first expanded and the second collapsed, which is
/// the arrangement on the home screen: the disconnected banner sits above the
/// session-paused one.
Widget _twoBanners(double firstFactor, double secondFactor) {
  Widget banner(double factor, String label, Color color) {
    return CollapsibleBanner(
      animation: AlwaysStoppedAnimation<double>(factor),
      child: Container(
        height: 100.0,
        color: color,
        alignment: Alignment.center,
        child: Text(label, textDirection: TextDirection.ltr),
      ),
    );
  }

  return Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      children: [
        banner(firstFactor, 'first', const Color(0xFFFF0000)),
        banner(secondFactor, 'second', const Color(0xFF00FF00)),
      ],
    ),
  );
}

void main() {
  testWidgets('a collapsed banner takes no height', (tester) async {
    await tester.pumpWidget(_twoBanners(0.0, 0.0));

    final banners = find.byType(CollapsibleBanner);
    expect(tester.getSize(banners.at(0)).height, 0.0);
    expect(tester.getSize(banners.at(1)).height, 0.0);
  });

  testWidgets('an expanded banner takes its full height', (tester) async {
    await tester.pumpWidget(_twoBanners(1.0, 0.0));

    expect(tester.getSize(find.byType(CollapsibleBanner).at(0)).height, 100.0);
  });

  testWidgets('a collapsed banner clips, so it cannot paint over its neighbour',
      (tester) async {
    // Align does not clip. Without a ClipRect the collapsed second banner
    // painted its child at minus its own height, landing exactly on top of the
    // expanded first banner -- so the wrong banner's text was on screen while
    // the other one was doing the work.
    await tester.pumpWidget(_twoBanners(1.0, 0.0));

    final collapsed = find.byType(CollapsibleBanner).at(1);
    expect(find.descendant(of: collapsed, matching: find.byType(ClipRect)),
        findsOneWidget,
        reason: 'the collapsed banner must clip its overflowing child');

    // The clip region is the zero-height box, so nothing of it can be drawn.
    final clipSize = tester.getSize(
        find.descendant(of: collapsed, matching: find.byType(ClipRect)));
    expect(clipSize.height, 0.0);
  });
}
