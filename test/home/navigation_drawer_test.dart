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
import 'package:flutter/services.dart';
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

  testWidgets('both bundled SVG assets load and parse', (tester) async {
    // assets/icons/highest.svg is used by the file-priority toolbar, which
    // needs a live repository to build, so its asset is covered here instead.
    //
    // Loading the bytes is the load-bearing part. SvgPicture.asset does NOT
    // throw for a missing asset -- the widget is still built and
    // takeException() stays null -- so a test that only pumps it passes with
    // a nonsense path and proves nothing. Verified: pointing this at
    // 'NOT-THERE.svg' passed until rootBundle.loadString was added.
    for (final asset in const [
      'assets/icons/trireme.svg',
      'assets/icons/highest.svg',
    ]) {
      final source = await rootBundle.loadString(asset);
      expect(source, contains('<svg'), reason: '$asset should be SVG source');

      // And it must still be parseable by whichever flutter_svg is resolved.
      final picture = await vg.loadPicture(SvgStringLoader(source), null);
      addTearDown(picture.picture.dispose);
      expect(picture.size.width, greaterThan(0), reason: 'parsing $asset');
      expect(picture.size.height, greaterThan(0), reason: 'parsing $asset');

      await tester.pumpWidget(MaterialApp(
        home: Center(child: SvgPicture.asset(asset, width: 24.0, height: 24.0)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'rendering $asset');
    }
  });
}
