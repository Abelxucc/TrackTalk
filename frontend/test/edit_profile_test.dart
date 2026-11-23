import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/app_shell.dart';
import 'package:tracktalk/food/food_service.dart';

const _saveError = 'Please try saving the profile again.';
const _app = MaterialApp(
  home: AppShell(service: FoodService('edit-profile-token')),
);

Finder _key(String value) => find.byKey(Key(value));

Finder _field(String name) => _key('profile-$name');

String _value(WidgetTester tester, String name) =>
    tester.widget<CupertinoTextField>(_field(name)).controller!.text;

Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _show(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String field, String text) async {
  final target = _field(field);
  await _show(tester, target);
  await tester.enterText(target, text);
  await tester.pump();
}

Future<void> _openProfile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app);
  await tester.pumpAndSettle();
  await _tap(tester, _key('nav-me'));
  await _tap(tester, find.text('Edit my profile'));
}

class _ProfileBackend {
  _ProfileBackend({this.failFirstSave = false});

  final bool failFirstSave;
  final values = <String, dynamic>{
    'gender': 'non_binary',
    'age': 24,
    'height_cm': '170.02',
    'weight_kg': '73.27',
    'phone_number': '+447700900123',
  };
  final patches = <Map<String, dynamic>>[];
  int reads = 0;

  MockClient client() => MockClient((request) async {
    expect(request.headers['Authorization'], 'Token edit-profile-token');
    switch ((request.method, request.url.path)) {
      case ('GET', '/api/food-records/' || '/api/activity-records/'):
        return http.Response('[]', 200);
      case ('GET', '/api/food-recommendations/'):
        return http.Response('', 503);
      case ('GET', '/api/auth/profile/'):
        reads++;
        return http.Response(jsonEncode(values), 200);
      case ('PATCH', '/api/auth/profile/'):
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        patches.add(body);
        if (failFirstSave && patches.length == 1) {
          return http.Response(jsonEncode({'detail': _saveError}), 400);
        }
        values.addAll(body);
        return http.Response(jsonEncode(values), 200);
      default:
        fail('Unexpected profile request ${request.method} ${request.url}');
    }
  });
}

void main() {
  testWidgets('Profile keeps metric values and retries a failed save', (
    tester,
  ) async {
    final backend = _ProfileBackend(failFirstSave: true);
    final client = backend.client();
    addTearDown(client.close);

    await http.runWithClient(() async {
      await _openProfile(tester);
      expect(backend.reads, 1);
      expect(find.text('Non-binary'), findsOneWidget);
      expect(_value(tester, 'age'), '24');
      expect(_value(tester, 'height'), '170.02');
      expect(_value(tester, 'weight'), '73.27');
      expect(_value(tester, 'phone'), '+447700900123');

      await _tap(tester, _field('height-ft'));
      await _tap(tester, _field('weight-lb'));
      expect(_value(tester, 'height-feet'), '5');
      expect(double.parse(_value(tester, 'height-inches')), closeTo(6.94, .01));
      expect(double.parse(_value(tester, 'weight')), closeTo(161.53, .01));
      await _show(tester, _field('save'));
      expect(tester.widget<CupertinoButton>(_field('save')).onPressed, isNull);

      await _enter(tester, 'age', '25');
      await _enter(tester, 'phone', '');
      await _tap(tester, _field('save'));
      const changes = {'age': 25, 'phone_number': ''};
      expect(backend.patches, [changes]);
      expect(find.text(_saveError), findsOneWidget);
      expect(_value(tester, 'age'), '25');
      expect(_value(tester, 'phone'), isEmpty);
      expect(_value(tester, 'height-feet'), '5');
      expect(_value(tester, 'height-inches'), '6.94');
      expect(double.parse(_value(tester, 'weight')), closeTo(161.53, .01));

      await _tap(tester, _field('save'));
      expect(backend.patches, [changes, changes]);
      expect(find.text('Sign out'), findsOneWidget);
      expect(_field('save'), findsNothing);
      await _tap(tester, find.text('Edit my profile'));
      expect(backend.reads, 2);
      expect(_value(tester, 'age'), '25');
      expect(_value(tester, 'phone'), isEmpty);
      expect(_value(tester, 'height'), '170.02');
      expect(_value(tester, 'weight'), '73.27');
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets(
    'Profile saves edits entered in imperial units as metric values',
    (tester) async {
      final backend = _ProfileBackend();
      final client = backend.client();
      addTearDown(client.close);

      await http.runWithClient(() async {
        await _openProfile(tester);
        await _tap(tester, _field('gender'));
        tester
            .widget<CupertinoPicker>(_field('gender-picker'))
            .scrollController!
            .jumpToItem(3);
        await tester.pumpAndSettle();
        await _tap(tester, _key('picker-done'));
        expect(find.text('Prefer not to say'), findsOneWidget);
        await _tap(tester, _field('height-ft'));
        await _enter(tester, 'height-feet', '6');
        await _enter(tester, 'height-inches', '1');
        await _tap(tester, _field('weight-lb'));
        await _enter(tester, 'weight', '200');
        await _tap(tester, _field('save'));

        expect(backend.patches, [
          {
            'gender': 'prefer_not_to_say',
            'height_cm': '185.42',
            'weight_kg': '90.72',
          },
        ]);
        expect(find.text('Sign out'), findsOneWidget);
        expect(_field('save'), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
