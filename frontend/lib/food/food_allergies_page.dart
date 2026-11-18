import 'package:flutter/cupertino.dart';

import '../shared/food_style.dart';
import '../shared/page_back_button.dart';
import 'food_service.dart';

class FoodAllergiesPage extends StatefulWidget {
  const FoodAllergiesPage({super.key, required this.service});

  final FoodService service;

  @override
  State<FoodAllergiesPage> createState() => _FoodAllergiesPageState();
}

class _FoodAllergiesPageState extends State<FoodAllergiesPage> {
  static const _section = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const _muted = Color(0xFF526854);
  static const _divider = Color(0xFFE3EADF);
  static const _selectedFill = Color(0xFFEAF2E5);
  final _food = TextEditingController();
  final _allergenIds = <String>{};
  final _otherFoods = <String>[];
  Map<String, String>? _options;
  String? _loadError;
  String? _inputError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _food.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final settings = await widget.service.allergies();
      if (!mounted) return;
      setState(() {
        _options = settings.options;
        _allergenIds
          ..clear()
          ..addAll(settings.allergenIds);
        _otherFoods
          ..clear()
          ..addAll(settings.otherFoods);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is FoodException
            ? error.message
            : 'Could not load your allergies. Please try again.';
      });
    }
  }

  void _toggleAllergen(String id) => setState(() {
    if (!_allergenIds.remove(id)) _allergenIds.add(id);
  });

  bool _addFood() {
    final name = _food.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(name)) {
      setState(() => _inputError = 'Enter a food name.');
      return false;
    }
    if (_otherFoods.any((food) => food.toLowerCase() == name.toLowerCase())) {
      setState(() => _inputError = 'This food is already listed.');
      return false;
    }
    setState(() {
      _otherFoods.add(name);
      _inputError = null;
    });
    _food.clear();
    return true;
  }

  Future<void> _save() async {
    if (_saving || (_food.text.trim().isNotEmpty && !_addFood())) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.service.saveAllergies(
        allergenIds: _allergenIds.toList(),
        otherFoods: _otherFoods,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = error is FoodException
            ? error.message
            : 'Could not save your allergies. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => FoodStyle.theme(
    PopScope(
      canPop: !_saving,
      child: CupertinoPageScaffold(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  Expanded(child: _options == null ? _loadStatus() : _editor()),
                  if (_options != null)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: _divider)),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_saveError case final error?) ...[
                            _error(error),
                            const SizedBox(height: 8),
                          ],
                          FoodStyle.primary(
                            key: const Key('save-food-allergies'),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const CupertinoActivityIndicator()
                                : const Text(
                                    'Save allergies',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
    child: Column(
      children: [
        SizedBox(
          height: (MediaQuery.textScalerOf(context).scale(21) + 14).clamp(
            44.0,
            double.infinity,
          ),
          child: NavigationToolbar(
            leading: PageBackButton(enabled: !_saving, color: FoodStyle.forest),
            middle: const Text(
              'Food allergies',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose foods to leave out of recommendations.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _muted),
        ),
      ],
    ),
  );

  Widget _loadStatus() {
    final error = _loadError;
    if (error == null) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FoodStyle.card(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _error(error),
              const SizedBox(height: 12),
              FoodStyle.secondary(label: 'Try again', onPressed: _load),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editor() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: [
      Row(
        children: [
          const Expanded(child: Text('Common allergens', style: _section)),
          const SizedBox(width: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              '${_allergenIds.length} selected',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      _allergenList(),
      const SizedBox(height: 20),
      const Text('Other foods', style: _section),
      const SizedBox(height: 9),
      _otherFoodsCard(),
    ],
  );

  Widget _allergenList() {
    final options = _options!.entries.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 280 &&
                MediaQuery.textScalerOf(context).scale(15) <= 19.5
            ? 2
            : 1;
        return _card(
          Table(
            defaultVerticalAlignment:
                TableCellVerticalAlignment.intrinsicHeight,
            border: const TableBorder(
              horizontalInside: BorderSide(color: _divider),
              verticalInside: BorderSide(color: _divider),
            ),
            children: [
              for (var start = 0; start < options.length; start += columns)
                TableRow(
                  children: [
                    for (var index = start; index < start + columns; index++)
                      index < options.length
                          ? _allergenButton(options[index])
                          : const SizedBox.shrink(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _otherFoodsCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      key: const Key('other-allergen-name'),
                      controller: _food,
                      placeholder: 'e.g. Chickpeas',
                      maxLength: 80,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      padding: const EdgeInsets.all(12),
                      style: const TextStyle(
                        fontSize: 15,
                        color: FoodStyle.ink,
                      ),
                      placeholderStyle: const TextStyle(
                        fontSize: 15,
                        color: _muted,
                      ),
                      decoration: BoxDecoration(
                        color: FoodStyle.background,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      onChanged: (_) {
                        if (_inputError != null) {
                          setState(() => _inputError = null);
                        }
                      },
                      onSubmitted: (_) => _addFood(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    key: const Key('add-other-allergen'),
                    color: FoodStyle.pale,
                    borderRadius: BorderRadius.circular(11),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 44),
                    onPressed: _saving ? null : _addFood,
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: FoodStyle.forest,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (_inputError case final error?) ...[
                const SizedBox(height: 8),
                _error(error),
              ],
            ],
          ),
        ),
        for (final food in _otherFoods) ...[
          const SizedBox(height: 1, child: ColoredBox(color: _divider)),
          _otherFoodRow(food),
        ],
      ],
    ),
  );

  Widget _allergenButton(MapEntry<String, String> option) {
    final selected = _allergenIds.contains(option.key);
    final (label, example) = switch (option.key) {
      'tree_nuts' => (option.value, 'Almonds, cashews'),
      'gluten_cereals' => ('Gluten cereals', 'Wheat, oats'),
      'crustaceans' => ('Crustaceans', 'Prawns, crab'),
      'molluscs' => ('Molluscs', 'Mussels, oysters'),
      'sulphites' => ('Sulphites', 'Sulphur dioxide'),
      _ => (option.value, null),
    };
    return Semantics(
      checked: selected,
      child: CupertinoButton(
        key: Key('allergen-${option.key}'),
        color: selected ? _selectedFill : null,
        borderRadius: BorderRadius.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 54),
        onPressed: _saving ? null : () => _toggleAllergen(option.key),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  if (example != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      example,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 7),
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: selected ? FoodStyle.forest : const Color(0xFF879687),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: ColoredBox(color: FoodStyle.surface, child: child),
  );

  Widget _otherFoodRow(String food) => Padding(
    padding: const EdgeInsets.only(left: 14, right: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            food,
            style: const TextStyle(fontSize: 15, color: FoodStyle.ink),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          key: ValueKey('remove-allergen-$food'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: _saving
              ? null
              : () => setState(() => _otherFoods.remove(food)),
          child: Icon(
            CupertinoIcons.xmark,
            size: 15,
            color: FoodStyle.forest,
            semanticLabel: 'Remove $food',
          ),
        ),
      ],
    ),
  );

  Widget _error(String message) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: const TextStyle(fontSize: 14, color: CupertinoColors.systemRed),
    ),
  );
}
