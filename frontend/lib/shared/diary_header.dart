import 'package:flutter/cupertino.dart';

import 'food_style.dart';

enum DiaryKind {
  food('Food', 'Your food diary'),
  activity('Activity', 'Your activity diary');

  const DiaryKind(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class DiaryHeader extends StatelessWidget {
  const DiaryHeader({
    super.key,
    required this.kind,
    required this.showWeek,
    required this.date,
    required this.today,
    required this.onSelectView,
    required this.onChangeDate,
    required this.onHistory,
  });

  static const pagePadding = EdgeInsets.fromLTRB(16, 17, 16, 16);
  static const _selectedText = Color(0xFF155A46);
  static const _muted = Color(0xFF526854);

  final DiaryKind kind;
  final bool showWeek;
  // The displayed day, or the Monday of the displayed week.
  final DateTime date;
  final DateTime today;
  final ValueChanged<bool> onSelectView;
  final ValueChanged<int> onChangeDate;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                kind.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          CupertinoButton(
            key: Key('${kind.name}-diary-history'),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            minimumSize: const Size(0, 42),
            alignment: Alignment.centerLeft,
            onPressed: onHistory,
            child: const Text(
              'History',
              style: TextStyle(
                color: FoodStyle.forest,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      Text(kind.subtitle, style: const TextStyle(fontSize: 14, color: _muted)),
      const SizedBox(height: 16),
      _periodControl(),
      const SizedBox(height: 12),
      _dateControl(),
      const SizedBox(height: 12),
    ],
  );

  Widget _periodControl() => DecoratedBox(
    decoration: _controlDecoration,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (weekly, label, suffix) in [
            (false, 'Today', 'today'),
            (true, 'This week', 'week'),
          ])
            Expanded(
              child: Semantics(
                selected: weekly == showWeek,
                child: CupertinoButton(
                  key: Key('${kind.name}-diary-$suffix'),
                  color: weekly == showWeek ? CupertinoColors.white : null,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 4,
                  ),
                  minimumSize: const Size(0, 35),
                  onPressed: () => onSelectView(weekly),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: weekly == showWeek ? _selectedText : _muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  static const _controlDecoration = BoxDecoration(
    color: FoodStyle.pale,
    borderRadius: BorderRadius.all(Radius.circular(15)),
  );

  Widget _dateControl() {
    final currentPeriod = showWeek
        ? DateTime(today.year, today.month, today.day + 1 - today.weekday)
        : today;
    final period = showWeek ? 'week' : 'day';
    return DecoratedBox(
      decoration: _controlDecoration,
      child: Row(
        children: [
          _dateArrow(
            key: Key('${kind.name}-previous-period'),
            label: 'Previous $period',
            icon: CupertinoIcons.chevron_left,
            onPressed: () => onChangeDate(-1),
          ),
          Expanded(
            child: Text(
              _dateLabel(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          _dateArrow(
            key: Key('${kind.name}-next-period'),
            label: 'Next $period',
            icon: CupertinoIcons.chevron_right,
            onPressed: date.isBefore(currentPeriod)
                ? () => onChangeDate(1)
                : null,
          ),
        ],
      ),
    );
  }

  String _dateLabel() {
    if (!showWeek) {
      if (date == today) return 'Today, ${FoodStyle.today(date)}';
      return date.year == today.year
          ? FoodStyle.today(date)
          : FoodStyle.date(date);
    }

    final end = DateTime(date.year, date.month, date.day + 6);
    if (date.year != end.year) {
      return '${FoodStyle.date(date)} – ${FoodStyle.date(end)}';
    }
    final range = date.month == end.month
        ? '${date.day}–${FoodStyle.today(end)}'
        : '${FoodStyle.today(date)} – ${FoodStyle.today(end)}';
    return end.year == today.year ? range : '$range ${end.year}';
  }

  Widget _dateArrow({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => Semantics(
    label: label,
    child: CupertinoButton(
      key: key,
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 42),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: 17,
        color: onPressed == null ? FoodStyle.muted : FoodStyle.forest,
      ),
    ),
  );
}
