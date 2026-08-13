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

import 'package:trireme/add_server/add_server.dart';

import '../support/pump.dart';

// The add-server stepper's first step. It validates host and port before it
// will talk to anything, so none of this needs a daemon: a rejected field
// never leaves the widget, and an accepted one is recognisable without one.
void main() {
  // Stepper renders its continue button first and its cancel button second.
  final continueButton = find.byType(TextButton).first;

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  // Fills in host and port, which is all the first step asks for.
  Future<void> enterHostDetails(
      WidgetTester tester, String host, String port) async {
    await tester.enterText(field('Host'), host);
    await tester.enterText(field('Port'), port);
    await tester.pump();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(continueButton);
    await tester.pump();
  }

  // Whether the step accepted what was typed. On a passing validation the
  // screen sets loading, and Stepper's continue button is wired to
  // `loading ? null : onStepContinue` -- so a disabled button is reachable
  // only through a validation that passed. On a failing one nothing changes
  // and the button stays live.
  bool wasAccepted(WidgetTester tester) =>
      tester.widget<TextButton>(continueButton).onPressed == null;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('rejects', () {
    testWidgets('an empty host', (tester) async {
      await tester.pumpWidget(appWith(const AddServerPage()));

      // Nothing typed at all: the host field starts empty and the port field
      // is pre-filled with 58846, so only the host can fail here.
      await tapContinue(tester);

      expect(find.text('Host must not be empty'), findsOneWidget);
      expect(wasAccepted(tester), isFalse);
    });

    testWidgets('a host of nothing but whitespace', (tester) async {
      await tester.pumpWidget(appWith(const AddServerPage()));

      await enterHostDetails(tester, '   ', '58846');
      await tapContinue(tester);

      expect(find.text('Host must not be empty'), findsOneWidget);
      expect(wasAccepted(tester), isFalse);
    });

    testWidgets('an empty port', (tester) async {
      await tester.pumpWidget(appWith(const AddServerPage()));

      await enterHostDetails(tester, 'deluge.example', '');
      await tapContinue(tester);

      expect(find.text('Port must not be empty'), findsOneWidget);
      expect(find.text('Host must not be empty'), findsNothing,
          reason: 'the host was valid, so only the port may be flagged');
      expect(wasAccepted(tester), isFalse);
    });

    testWidgets('a non-numeric port', (tester) async {
      await tester.pumpWidget(appWith(const AddServerPage()));

      await enterHostDetails(tester, 'deluge.example', 'fifty-eight');
      await tapContinue(tester);

      expect(find.text('Port must be valid'), findsOneWidget);
      expect(wasAccepted(tester), isFalse);
    });

    testWidgets('a port above the TCP range', (tester) async {
      await tester.pumpWidget(appWith(const AddServerPage()));

      await enterHostDetails(tester, 'deluge.example', '70000');
      await tapContinue(tester);

      expect(find.text('Port not in range [0, 65535]'), findsOneWidget);
      expect(wasAccepted(tester), isFalse);
    });

    testWidgets('reports both fields at once', (tester) async {
      await tester.pumpWidget(appWith(const AddServerPage()));

      await enterHostDetails(tester, '', '70000');
      await tapContinue(tester);

      expect(find.text('Host must not be empty'), findsOneWidget);
      expect(find.text('Port not in range [0, 65535]'), findsOneWidget);
    });

    testWidgets('and clears a field\'s message once it is corrected',
        (tester) async {
      await tester.pumpWidget(appWith(const AddServerPage()));

      await enterHostDetails(tester, '', '70000');
      await tapContinue(tester);
      expect(find.text('Port not in range [0, 65535]'), findsOneWidget);

      // Correct only the port. The host is still empty, so the step is
      // rejected again -- which is what keeps this test off the network while
      // still proving the port message was re-evaluated rather than left over.
      await enterHostDetails(tester, '', '58846');
      await tapContinue(tester);

      expect(find.text('Port not in range [0, 65535]'), findsNothing);
      expect(find.text('Host must not be empty'), findsOneWidget);
      expect(wasAccepted(tester), isFalse);
    });
  });

  testWidgets('accepts a valid host and port, and starts detecting the daemon',
      (tester) async {
    await tester.pumpWidget(appWith(const AddServerPage()));

    await enterHostDetails(tester, 'deluge.example', '58846');
    await tapContinue(tester);

    expect(find.text('Host must not be empty'), findsNothing);
    expect(find.text('Port must not be empty'), findsNothing);
    expect(find.text('Port must be valid'), findsNothing);
    expect(find.text('Port not in range [0, 65535]'), findsNothing);
    expect(wasAccepted(tester), isTrue,
        reason: 'accepted input puts the step into its detecting state');

    // Detection is now in flight against a host that does not exist, and it
    // cannot finish: a widget test never returns to the real event loop, so
    // the sockets it opened stay unresolved. What does finish is
    // DaemonDetector's own 30 second timeout, which is a Timer the fake clock
    // owns -- running it out is what leaves no timer pending at the end of the
    // test, and it puts the screen back where the user could try again.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();

    expect(wasAccepted(tester), isFalse,
        reason: 'a failed detection must hand the step back to the user');
    expect(find.byType(SnackBar), findsOneWidget, reason: 'and tell them why');

    await tester.pump(const Duration(seconds: 10));
  });
}
