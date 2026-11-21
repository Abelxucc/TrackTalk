import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils, Icons;

import '../food/food_service.dart';
import '../history/food_history_order.dart';
import '../shared/food_style.dart';
import 'activity_record.dart';

class ActivityDiaryPage extends StatefulWidget {
  const ActivityDiaryPage({
    super.key,
    required this.service,
    required this.today,
    required this.active,
    required this.openHistory,
    required this.openRecord,
    required this.logActivity,
  });

  final FoodService service;
  final DateTime today;
  final bool active;
  final Future<void> Function(DateTime) openHistory;
  final Future<void> Function(ActivityRecord) openRecord;
  final VoidCallback logActivity;

  @override
  State<ActivityDiaryPage> createState() => _ActivityDiaryPageState();
}

class _ActivityDiaryPageState extends State<ActivityDiaryPage> {
  static const _forest = Color(0xFF185A46);
  static const _highlight = Color(0xFF91EEC0);
  static const _sage = Color(0xFFB8D6BC);
  static const _muted = Color(0xFF526854);
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool _showWeek = true;
  DateTime? _dailyDate;
  DateTime? _weeklyDate;
  Future<List<ActivityRecord>>? _records;

  DateTime get _today => DateUtils.dateOnly(widget.today);

  DateTime get _day {
    final selected = _showWeek ? _weeklyDate : _dailyDate;
    return selected == null || selected.isAfter(_today) ? _today : selected;
  }

  DateTime get _weekStart => _monday(_day);

  static DateTime _monday(DateTime date) =>
      DateUtils.addDaysToDate(date, DateTime.monday - date.weekday);

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(ActivityDiaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active ||
            oldWidget.service != widget.service ||
            !DateUtils.isSameDay(oldWidget.today, widget.today))) {
      _load();
    }
  }

  void _load() {
    _records = widget.service.listActivities();
  }

  void _selectDate(DateTime date) {
    final selected = date == _today ? null : date;
    setState(() {
      if (_showWeek) {
        _weeklyDate = selected;
      } else {
        _dailyDate = selected;
      }
    });
  }

  void _shiftPeriod(int direction) {
    final next = DateUtils.addDaysToDate(_day, direction * (_showWeek ? 7 : 1));
    final returningToCurrentWeek =
        _showWeek && direction > 0 && _monday(next) == _monday(_today);
    _selectDate(returningToCurrentWeek ? _today : next);
  }

  Future<void> _refreshAfter(Future<void> route) async {
    await route;
    if (mounted && widget.active) setState(_load);
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: widget.active,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  'Activity',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            CupertinoButton(
              key: const Key('activity-diary-history'),
              padding: const EdgeInsets.only(left: 12),
              onPressed: () => _refreshAfter(widget.openHistory(_day)),
              child: const Text(
                'History',
                style: TextStyle(color: _forest, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _periodControl(),
        const SizedBox(height: 5),
        _dateControl(),
        const SizedBox(height: 8),
        FutureBuilder<List<ActivityRecord>>(
          future: _records,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return FoodStyle.card(
                Semantics(
                  label: 'Loading activities',
                  child: const Center(child: CupertinoActivityIndicator()),
                ),
              );
            }
            if (snapshot.hasError) {
              return FoodStyle.card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Could not load your activities.',
                      style: TextStyle(fontSize: 15, color: _muted),
                    ),
                    const SizedBox(height: 10),
                    FoodStyle.secondary(
                      label: 'Try again',
                      onPressed: () => setState(_load),
                    ),
                  ],
                ),
              );
            }
            return _content(snapshot.requireData);
          },
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          key: const Key('log-activity'),
          color: FoodStyle.pale,
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onPressed: widget.logActivity,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.plus, size: 23, color: _forest),
              SizedBox(width: 9),
              Flexible(
                child: Text(
                  'Log activity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _forest,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _periodControl() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: FoodStyle.pale,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final (weekly, title, key) in [
          (false, 'Today', 'activity-diary-today'),
          (true, 'This week', 'activity-diary-week'),
        ])
          Expanded(
            child: Semantics(
              selected: weekly == _showWeek,
              child: CupertinoButton(
                key: Key(key),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                minimumSize: const Size(0, 38),
                borderRadius: BorderRadius.circular(12),
                color: weekly == _showWeek ? FoodStyle.surface : null,
                onPressed: () => setState(() => _showWeek = weekly),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: weekly == _showWeek ? _forest : _muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dateControl() {
    final end = DateUtils.addDaysToDate(_weekStart, 6);
    final canGoForward = _showWeek
        ? _weekStart.isBefore(_monday(_today))
        : _day.isBefore(_today);
    final period = _showWeek ? 'week' : 'day';
    return Row(
      children: [
        _dateArrow(
          const Key('activity-previous-period'),
          'Previous $period',
          CupertinoIcons.chevron_left,
          () => _shiftPeriod(-1),
        ),
        Expanded(
          child: Text(
            _periodTitle(end),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        _dateArrow(
          const Key('activity-next-period'),
          'Next $period',
          CupertinoIcons.chevron_right,
          canGoForward ? () => _shiftPeriod(1) : null,
        ),
      ],
    );
  }

  String _periodTitle(DateTime end) {
    if (!_showWeek) {
      if (_day == _today) return 'Today, ${FoodStyle.today(_day)}';
      return _day.year == _today.year
          ? FoodStyle.today(_day)
          : FoodStyle.date(_day);
    }
    final start = _weekStart;
    if (start.year != end.year) {
      return '${FoodStyle.date(start)} – ${FoodStyle.date(end)}';
    }
    final range = start.month == end.month
        ? '${start.day}–${FoodStyle.today(end)}'
        : '${FoodStyle.today(start)} – ${FoodStyle.today(end)}';
    return end.year == _today.year ? range : '$range ${end.year}';
  }

  Widget _dateArrow(
    Key key,
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) => Semantics(
    label: label,
    child: CupertinoButton(
      key: key,
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: 18,
        color: onPressed == null ? const Color(0xFFA9B6A5) : _forest,
      ),
    ),
  );

  Widget _content(List<ActivityRecord> records) {
    final day = _day;
    final start = _showWeek ? _weekStart : day;
    final dates = [
      for (var offset = 0; offset < (_showWeek ? 7 : 1); offset++)
        DateUtils.addDaysToDate(start, offset),
    ];
    final minutesByDate = {for (final date in dates) date: 0};
    final dailyRecords = <ActivityRecord>[];
    for (final record in records) {
      final date = DateUtils.dateOnly(record.occurredAt);
      final previous = minutesByDate[date];
      if (previous == null || date.isAfter(_today)) continue;
      minutesByDate[date] = previous + record.durationMinutes;
      if (date == day) dailyRecords.add(record);
    }
    final minutes = minutesByDate.values.fold(
      0,
      (total, value) => total + value,
    );
    final count = _showWeek
        ? minutesByDate.values.where((minutes) => minutes > 0).length
        : dailyRecords.length;
    final countLabel = _showWeek
        ? '$count active ${count == 1 ? 'day' : 'days'}'
        : '$count ${count == 1 ? 'activity' : 'activities'}';
    final orderedRecords = sortRecordHistory(
      const [],
      dailyRecords,
    ).cast<ActivityRecord>();
    final fullDate = FoodStyle.date(day);
    final shortDate = day.year == _today.year
        ? fullDate.substring(0, fullDate.lastIndexOf(' '))
        : fullDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summary(minutes, countLabel, minutesByDate),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            '${_weekdays[day.weekday - DateTime.monday]}, $shortDate',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 9),
        _activityRows(orderedRecords),
      ],
    );
  }

  Widget _summary(
    int minutes,
    String countLabel,
    Map<DateTime, int> minutesByDate,
  ) {
    final maxMinutes = minutesByDate.values.fold(1, math.max);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: _forest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _showWeek
                ? 'Logged this week'
                : _day == _today
                ? 'Logged today'
                : 'Logged this day',
            style: const TextStyle(color: CupertinoColors.white, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 3,
            children: [
              Text(
                '$minutes min',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  height: 1.1,
                ),
              ),
              Text(
                countLabel,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_showWeek) ...[
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (index, entry) in minutesByDate.entries.indexed)
                  Expanded(
                    child: _weekdayBar(
                      entry.key,
                      _weekdays[index],
                      entry.value,
                      maxMinutes,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekdayBar(
    DateTime date,
    String weekday,
    int minutes,
    int maxMinutes,
  ) {
    final future = date.isAfter(_today);
    final selected = date == _day;
    final color = selected ? _highlight : _sage;
    final dateKey = date.toIso8601String().split('T').first;
    return Semantics(
      label:
          '${FoodStyle.today(date)}, ${future ? 'upcoming' : '$minutes minutes'}',
      selected: selected,
      child: CupertinoButton(
        key: ValueKey('activity-chart-day-$dateKey'),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: future ? null : () => _selectDate(date),
        child: ExcludeSemantics(
          child: Column(
            children: [
              SizedBox(
                height: 83 + MediaQuery.textScalerOf(context).scale(13),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (minutes > 0) ...[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$minutes',
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: math.max(3.0, minutes / maxMinutes * 73),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: future
                              ? const Color(0xFF709787)
                              : (selected ? color : null),
                          border: future || selected
                              ? null
                              : Border.all(color: color),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(
                height: 1,
                width: double.infinity,
                child: ColoredBox(color: Color(0xFF82A99A)),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  weekday,
                  style: TextStyle(
                    color: future
                        ? const Color(0xFFA9C2B5)
                        : CupertinoColors.white,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityRows(List<ActivityRecord> records) {
    if (records.isEmpty) {
      return FoodStyle.card(
        const Text(
          'No activities recorded for this day.',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: FoodStyle.surface,
        child: Column(
          children: [
            for (final (index, record) in records.indexed) ...[
              if (index > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    height: 1,
                    width: double.infinity,
                    child: ColoredBox(color: Color(0xFFE3EAE0)),
                  ),
                ),
              _activityRow(record),
            ],
          ],
        ),
      ),
    );
  }

  Widget _activityRow(ActivityRecord record) => CupertinoButton(
    key: ValueKey('activity-diary-record-${record.id}'),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    onPressed: () => _refreshAfter(widget.openRecord(record)),
    child: Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: FoodStyle.pale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_activityIcon(record.name), color: _forest, size: 23),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.name,
                style: const TextStyle(
                  color: FoodStyle.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                record.timeSpecified
                    ? FoodStyle.time(record.occurredAt)
                    : 'No time',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            '${record.durationMinutes} min',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: FoodStyle.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 7),
        const Icon(CupertinoIcons.chevron_right, color: _muted, size: 14),
      ],
    ),
  );

  IconData _activityIcon(String name) => switch (name.toLowerCase()) {
    final text when text.contains('walk') => Icons.directions_walk_rounded,
    final text when text.contains('stretch') || text.contains('yoga') =>
      Icons.self_improvement_rounded,
    final text when text.contains('run') || text.contains('jog') =>
      Icons.directions_run_rounded,
    final text when text.contains('cycl') || text.contains('bike') =>
      Icons.directions_bike_rounded,
    _ => CupertinoIcons.timer,
  };
}
