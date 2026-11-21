import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/app_shell.dart';
import 'package:tracktalk/food/food_service.dart';
import 'package:tracktalk/history/food_history_page.dart';

Finder _key(String value) => find.byKey(Key(value));

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openDiary(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402, 940);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AppShell(
        service: const FoodService('activity-diary-token'),
        now: () => DateTime(2026, 11, 18, 12, 17),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, _key('nav-activity'));
}

Map<String, Object> _activity(
  int id,
  String name,
  int minutes,
  DateTime date, {
  bool hasTime = true,
}) => {
  'id': id,
  'name': name,
  'duration_minutes': minutes,
  'occurred_at': date.toUtc().toIso8601String(),
  'time_specified': hasTime,
};

class _ActivityBackend {
  final records = {
    1: _activity(1, 'Cycling', 30, DateTime(2026, 11, 16, 9)),
    2: _activity(2, 'Swimming', 20, DateTime(2026, 11, 17), hasTime: false),
    3: _activity(3, 'Morning walk', 25, DateTime(2026, 11, 18, 8, 10)),
    4: _activity(4, 'Stretching', 20, DateTime(2026, 11, 18, 11, 40)),
    5: _activity(5, 'Football', 12, DateTime(2026, 11, 9, 13)),
  };
  final writes = <String>[];

  MockClient client() => MockClient((request) async {
    expect(request.headers['Authorization'], 'Token activity-diary-token');
    switch ((request.method, request.url.path)) {
      case ('GET', '/api/food-records/'):
        return http.Response('[]', 200);
      case ('GET', '/api/food-recommendations/'):
        return http.Response('', 503);
      case ('GET', '/api/activity-records/'):
        return http.Response(jsonEncode(records.values.toList()), 200);
      case ('PUT', '/api/activity-records/3/'):
        writes.add(request.method);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        records[3] = {...body.cast<String, Object>(), 'id': 3};
        return http.Response(jsonEncode(records[3]), 200);
      case ('POST', '/api/food-records/parse/'):
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['mode'], 'activity');
        expect(body['text'], 'I went dancing for 15 minutes');
        return http.Response(
          jsonEncode({
            'kind': 'activity',
            'activity_name': 'Dancing',
            'duration_minutes': 15,
            'date': '2026-11-18',
            'time': null,
          }),
          200,
        );
      case ('POST', '/api/activity-records/'):
        writes.add(request.method);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        records[6] = {...body.cast<String, Object>(), 'id': 6};
        return http.Response(jsonEncode(records[6]), 201);
      default:
        fail(
          'Unexpected activity diary request ${request.method} ${request.url}',
        );
    }
  });
}

void main() {
  testWidgets(
    'Activity selects dated records in both diary views and History',
    (tester) async {
      final backend = _ActivityBackend();
      final client = backend.client();
      addTearDown(client.close);

      await http.runWithClient(() async {
        await _openDiary(tester);

        expect(find.text('16–22 November'), findsOneWidget);
        expect(find.text('95 min'), findsOneWidget);
        expect(find.text('3 active days'), findsOneWidget);
        for (final day in ['16', '17', '18', '19', '20', '21', '22']) {
          expect(_key('activity-chart-day-2026-11-$day'), findsOneWidget);
        }
        for (final minutes in ['30', '20', '45']) {
          expect(find.text(minutes), findsOneWidget);
        }
        expect(find.text('Wed, 18 Nov'), findsOneWidget);
        expect(find.text('Morning walk'), findsOneWidget);
        expect(find.text('Stretching'), findsOneWidget);
        expect(find.text('Cycling'), findsNothing);

        await _tap(tester, _key('activity-chart-day-2026-11-17'));
        expect(find.text('Swimming'), findsOneWidget);
        expect(find.text('No time'), findsOneWidget);
        expect(find.text('Morning walk'), findsNothing);
        await _tap(tester, find.text('History'));
        final history = tester.widget<FoodHistoryPage>(
          find.byType(FoodHistoryPage),
        );
        expect(history.initialDate, DateTime(2026, 11, 17));
        expect(history.initialFilter, HistoryFilter.activity);
        expect(_key('activity-history-2'), findsOneWidget);
        await _tap(tester, _key('page-back'));

        await _tap(tester, _key('activity-previous-period'));
        expect(find.text('9–15 November'), findsOneWidget);
        expect(find.text('1 active day'), findsOneWidget);
        await _tap(tester, _key('activity-chart-day-2026-11-09'));
        expect(find.text('Football'), findsOneWidget);
        await _tap(tester, _key('activity-chart-day-2026-11-10'));
        expect(
          find.text('No activities recorded for this day.'),
          findsOneWidget,
        );
        await _tap(tester, _key('activity-next-period'));
        expect(find.text('95 min'), findsOneWidget);

        await _tap(tester, _key('activity-chart-day-2026-11-18'));
        await _tap(tester, _key('activity-diary-today'));
        expect(find.text('Today, 18 November'), findsOneWidget);
        expect(find.text('45 min'), findsOneWidget);
        expect(find.text('2 activities'), findsOneWidget);
        expect(find.text('Morning walk'), findsOneWidget);
        expect(_key('activity-chart-day-2026-11-18'), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets('Activity refreshes its weekly summary after edits and logging', (
    tester,
  ) async {
    final backend = _ActivityBackend();
    final client = backend.client();
    addTearDown(client.close);

    await http.runWithClient(() async {
      await _openDiary(tester);
      await _tap(tester, _key('activity-diary-record-3'));
      expect(find.text('Edit activity'), findsOneWidget);
      await tester.enterText(_key('activity-duration'), '35');
      await _tap(tester, _key('review-activity'));
      expect(backend.records[3]?['duration_minutes'], 35);
      expect(find.text('105 min'), findsOneWidget);

      await _tap(tester, _key('log-activity'));
      expect(find.text('Add record'), findsOneWidget);
      expect(_key('activity-description'), findsOneWidget);
      expect(_key('food-description'), findsNothing);
      await tester.enterText(
        _key('activity-description'),
        'I went dancing for 15 minutes',
      );
      await tester.pump();
      await tester.tap(_key('parse-activity'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await _tap(tester, _key('confirm-activity'));
      expect(backend.writes, ['PUT', 'POST']);

      await _tap(tester, _key('nav-activity'));
      expect(find.text('120 min'), findsOneWidget);
      expect(_key('activity-diary-record-6'), findsOneWidget);
      expect(find.text('Dancing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
