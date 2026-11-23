import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/services.dart';

import '../history/food_history_order.dart';
import '../shared/diary_header.dart';
import '../shared/food_style.dart';
import 'food_allergies_page.dart';
import 'food_service.dart';

class FoodDiaryPage extends StatefulWidget {
  const FoodDiaryPage({
    super.key,
    required this.service,
    required this.today,
    required this.active,
    required this.openHistory,
    required this.addFood,
  });

  final FoodService service;
  final DateTime today;
  final bool active;
  final Future<void> Function(DateTime) openHistory;
  final VoidCallback addFood;

  @override
  State<FoodDiaryPage> createState() => _FoodDiaryPageState();
}

class _FoodDiaryPageState extends State<FoodDiaryPage> {
  static const _deep = Color(0xFF155A46);
  static const _muted = Color(0xFF526854);
  static const _tipFill = Color(0xFFE4EEE1);
  static const _section = TextStyle(fontSize: 19, fontWeight: FontWeight.w700);
  static const _guideUrl =
      'https://www.gov.uk/government/publications/the-eatwell-guide';

  DateTime? _selectedDay;
  DateTime? _selectedWeek;
  bool _showWeek = false;
  Future<List<FoodRecord>?>? _records;
  Future<FoodWeek?>? _week;

  DateTime get _day => _selectedDay ?? widget.today;
  DateTime get _weekStart => _selectedWeek ?? _monday(widget.today);
  DateTime get _recommendationDate =>
      _selectedWeek == null ? widget.today : _offset(_weekStart, 6);

  static DateTime _offset(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime _monday(DateTime date) => _offset(date, 1 - date.weekday);

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(FoodDiaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dayChanged =
        _showWeek && _selectedWeek == null && widget.today != oldWidget.today;
    if (widget.active && (!oldWidget.active || dayChanged)) _load();
  }

  Future<T?> _tryLoad<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (_) {
      return null;
    }
  }

  void _load() {
    if (_showWeek) {
      _week = _tryLoad(() => widget.service.week(_recommendationDate));
    } else {
      _records = _tryLoad(widget.service.list);
    }
  }

  void _selectView(bool showWeek) {
    if (showWeek == _showWeek) return;
    setState(() {
      _showWeek = showWeek;
      _load();
    });
  }

  void _changeDate(int direction) {
    setState(() {
      if (_showWeek) {
        final start = _offset(_weekStart, direction * 7);
        _selectedWeek = start == _monday(widget.today) ? null : start;
        _load();
      } else {
        final day = _offset(_day, direction);
        _selectedDay = day == widget.today ? null : day;
      }
    });
  }

  Future<void> _history([DateTime? date]) async {
    await widget.openHistory(date ?? (_showWeek ? _weekStart : _day));
    if (mounted && widget.active) setState(_load);
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: widget.active,
    child: ListView(
      padding: DiaryHeader.pagePadding,
      children: [
        DiaryHeader(
          kind: DiaryKind.food,
          showWeek: _showWeek,
          date: _showWeek ? _weekStart : _day,
          today: widget.today,
          onSelectView: _selectView,
          onChangeDate: _changeDate,
          onHistory: _history,
        ),
        if (_showWeek) _weeklyView() else _dailyView(),
        const SizedBox(height: 12),
        _allergiesCard(),
        if (!_showWeek) ...[const SizedBox(height: 12), _reviewLink()],
      ],
    ),
  );

  Widget _dailyView() => FutureBuilder<List<FoodRecord>?>(
    future: _records,
    builder: (context, snapshot) {
      final records = snapshot.data;
      if (records == null) {
        return _loadStatus(
          snapshot.connectionState,
          'Could not load food records.',
        );
      }
      final meals = sortFoodHistory(
        records.where((record) => DateUtils.isSameDay(record.eatenAt, _day)),
      );
      final snacks = meals
          .where(
            (meal) => meal.mealType == 'snack' || meal.mealType == 'elevenses',
          )
          .length;
      final mealCount = meals.length - snacks;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panel(
            color: _tipFill,
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meals.length} food ${meals.length == 1 ? 'record' : 'records'}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _deep,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$mealCount ${mealCount == 1 ? 'meal' : 'meals'} · $snacks ${snacks == 1 ? 'snack' : 'snacks'}',
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  color: _deep,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  onPressed: widget.addFood,
                  child: const Text(
                    '+ Add food',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Text('Meals & snacks', style: _section),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            _panel(
              child: const Text(
                'No food records for this day.',
                style: TextStyle(fontSize: 14, color: _muted),
              ),
            )
          else
            for (final meal in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: CupertinoButton(
                  key: ValueKey('diary-meal-${meal.id}'),
                  padding: EdgeInsets.zero,
                  color: FoodStyle.surface,
                  borderRadius: BorderRadius.circular(18),
                  onPressed: () => _history(meal.eatenAt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _labelPair(
                            FoodStyle.meals[meal.mealType] ?? 'Meal',
                            meal.items.map((item) => item.name).join(', '),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          meal.timeSpecified
                              ? FoodStyle.time(meal.eatenAt)
                              : 'No time',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );

  Widget _allergiesCard() => CupertinoButton(
    key: const Key('food-allergies'),
    padding: EdgeInsets.zero,
    onPressed: _showAllergies,
    child: _panel(
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _iconTile(
            CupertinoIcons.shield,
            const Color(0xFFF2EBD9),
            FoodStyle.forest,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _labelPair('Food allergies', 'Choose foods to avoid'),
          ),
          const Icon(CupertinoIcons.chevron_right, size: 14, color: _muted),
        ],
      ),
    ),
  );

  Future<void> _showAllergies() async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => FoodAllergiesPage(service: widget.service),
      ),
    );
    if (mounted && saved == true && _showWeek) setState(_load);
  }

  Widget _reviewLink() => _panel(
    color: _tipFill,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _recommendationTitle(),
        const SizedBox(height: 7),
        const Text(
          'Ideas based on your last 7 days of food logs.',
          style: TextStyle(fontSize: 13),
        ),
        _textButton(
          'View this week',
          () => _selectView(true),
          icon: CupertinoIcons.chevron_right,
        ),
      ],
    ),
  );

  Widget _weeklyView() => FutureBuilder<FoodWeek?>(
    future: _week,
    builder: (context, snapshot) {
      final week = snapshot.connectionState == ConnectionState.done
          ? snapshot.data
          : null;
      if (week == null) {
        return _loadStatus(
          snapshot.connectionState,
          'Could not load the weekly food review.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'What you ate this week',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'From ${week.daysLogged} ${week.daysLogged == 1 ? 'day' : 'days'} of food logs',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
              _textButton(
                'Eatwell Guide',
                () => _showGuide(week.tip?.sourceUrl ?? _guideUrl),
                icon: CupertinoIcons.arrow_up_right,
              ),
            ],
          ),
          _panel(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            child: Column(
              children: [
                for (final (index, group) in week.groups.entries.indexed) ...[
                  if (index != 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 43),
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: Color(0xFFE5EBE2)),
                      ),
                    ),
                  _groupRow(group.key, group.value),
                ],
              ],
            ),
          ),
          const SizedBox(height: 13),
          _recommendationCard(week.tip, week.recommendationMessage),
        ],
      );
    },
  );

  Widget _groupRow(String label, List<String> foods) {
    final (icon, background, foreground) = switch (label) {
      'Fruit & vegetables' => (
        CupertinoIcons.leaf_arrow_circlepath,
        const Color(0xFFE3EFD9),
        const Color(0xFF467343),
      ),
      'Starchy foods' => (
        CupertinoIcons.tree,
        const Color(0xFFF2EBD5),
        const Color(0xFF866A32),
      ),
      'Protein foods' => (
        CupertinoIcons.circle,
        const Color(0xFFF2E6E1),
        const Color(0xFF915E50),
      ),
      'Dairy & alternatives' => (
        CupertinoIcons.cube_box,
        const Color(0xFFE2ECF1),
        const Color(0xFF4B7086),
      ),
      'Oils & spreads' => (
        CupertinoIcons.drop,
        const Color(0xFFF2EEDC),
        const Color(0xFF84713D),
      ),
      _ => (
        CupertinoIcons.line_horizontal_3,
        const Color(0xFFEBEEE8),
        const Color(0xFF667465),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _iconTile(icon, background, foreground),
          const SizedBox(width: 11),
          Expanded(
            child: _labelPair(
              label,
              foods.isEmpty ? 'No entries yet' : foods.join(', '),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendationCard(FoodTip? tip, String? message) {
    final pulses = tip?.title == 'No pulses logged in the last 7 days';
    return _panel(
      color: _tipFill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _recommendationTitle(),
          const SizedBox(height: 4),
          Text(
            'Based on the 7 days ending ${FoodStyle.today(_recommendationDate)}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          if (tip != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pulses ? 'Pulses' : tip.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (pulses)
                  _panel(
                    radius: 9,
                    color: const Color(0xFFF4F8F0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: const Text(
                      'Not logged',
                      style: TextStyle(
                        fontSize: 12,
                        color: FoodStyle.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          Text(
            tip?.body ?? message ?? 'Log a meal to see a food idea.',
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }

  Future<void> _showGuide(String url) => showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Eatwell Guide'),
      content: Text(url),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
        CupertinoDialogAction(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Copy link'),
        ),
      ],
    ),
  );

  Widget _loadStatus(ConnectionState state, String error) => switch (state) {
    ConnectionState.none => const SizedBox.shrink(),
    ConnectionState.done => _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error),
          _textButton('Try again', () => setState(_load)),
        ],
      ),
    ),
    _ => const Padding(
      padding: EdgeInsets.all(10),
      child: CupertinoActivityIndicator(),
    ),
  };

  Widget _textButton(String label, VoidCallback onPressed, {IconData? icon}) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: const Size(0, 42),
        alignment: Alignment.centerLeft,
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: FoodStyle.forest,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 13, color: FoodStyle.forest),
            ],
          ],
        ),
      );

  Widget _labelPair(String label, String detail, {int? maxLines}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: FoodStyle.ink,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        detail,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: _muted),
      ),
    ],
  );

  Widget _recommendationTitle() => const Row(
    children: [
      Icon(CupertinoIcons.leaf_arrow_circlepath, color: _deep, size: 18),
      SizedBox(width: 7),
      Expanded(
        child: Text(
          'Food recommendations',
          style: TextStyle(
            color: _deep,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _iconTile(IconData icon, Color background, Color foreground) =>
      Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: foreground, size: 17),
      );

  Widget _panel({
    required Widget child,
    Color color = FoodStyle.surface,
    double radius = 21,
    EdgeInsets padding = const EdgeInsets.all(15),
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );
}
