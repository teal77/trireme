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
import 'package:flutter_test/flutter_test.dart';
import 'package:trireme/common/strings.dart';
import 'package:trireme/home/navigation_drawer.dart';

import '../support/pump.dart';

/// The drawer and the file-priority toolbar are the app's only two users of
/// flutter_svg, and neither had a test. That is what kept the flutter_svg 2.x
/// upgrade deferred: 1.x to 2.x is a breaking rendering API change, and
/// nothing here could have caught it.
///
/// These render the real widgets and the real assets, so an upgrade that
/// breaks asset loading or the colour API fails here rather than on a device.
void main() {
  testWidgets('the drawer header renders its SVG logo', (tester) async {
    await tester.pumpWidget(appWith(
      Scaffold(
        drawer: NavDrawer(
          const [],
          null,
          () {},
          (_) {},
          () {},
        ),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The header is a NavDrawerHeader wrapping an SvgPicture built from
    // assets/icons/trireme.svg.
    expect(find.byType(NavDrawerHeader), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(NavDrawerHeader), matching: find.byType(SvgPicture)),
        findsOneWidget,
        reason: 'the drawer header renders its logo through flutter_svg');

    // With no server selected the drawer still offers its two fixed entries.
    expect(find.text(Strings.homeAddServerDrawerButtonText), findsOneWidget);
    expect(find.text(Strings.homeSettings), findsOneWidget);
  });

  testWidgets('the drawer survives a full render with no exceptions',
      (tester) async {
    // flutter_svg failures surface as exceptions during paint rather than as a
    // missing widget, so an explicit check that nothing was thrown is the
    // assertion that would actually catch a broken upgrade.
    await tester.pumpWidget(appWith(
      Scaffold(
        drawer: NavDrawer(const [], null, () {}, (_) {}, () {}),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('both bundled SVG assets decode and render', (tester) async {
    // assets/icons/highest.svg is used by the file-priority toolbar, which
    // needs a live repository to build. Rendering the asset directly still
    // covers what the flutter_svg upgrade puts at risk: that this asset loads
    // and paints with the parameters the app passes.
    for (final asset in const [
      'assets/icons/trireme.svg',
      'assets/icons/highest.svg',
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SvgPicture.asset(asset, width: 24.0, height: 24.0),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget, reason: 'rendering $asset');
      expect(tester.takeException(), isNull, reason: 'rendering $asset');
    }
  });
}
