import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../food/food_service.dart';
import '../registration/profile_details.dart';
import '../shared/food_style.dart';
import 'profile_avatar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.service, this.pickPhoto});

  final FoodService service;
  final Future<XFile?> Function()? pickPhoto;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _ink = Color(0xFF173328);
  static const _muted = Color(0xFF526854);
  static const _fieldFill = Color(0xFFE9F0E2);
  static const _labelStyle = TextStyle(
    color: _ink,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const _cmPerInch = 2.54;
  static const _kgPerPound = .45359237;
  static const _maxNameLength = 80;
  static const _maxPhotoBytes = 1024 * 1024;
  static final _decimalInput = RegExp(r'^\d{1,4}(\.\d{1,2})?$');
  static final _ageInput = RegExp(r'^\d{1,3}$');
  static final _phoneSeparators = RegExp(r'[ ()\-.]');
  static final _phoneInput = RegExp(r'^\+?[0-9]{7,15}$');
  static final _trailingZeroes = RegExp(r'\.?0+$');

  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _weight = TextEditingController();
  final _pounds = TextEditingController();
  final _phone = TextEditingController();

  AccountProfile? _profile;
  Uint8List? _pendingPhoto;
  ProfileGender? _gender;
  String? _loadError;
  String? _saveError;
  bool _saving = false;
  bool _pickingPhoto = false;
  bool _confirming = false;
  bool _showValidation = false;
  bool _heightInFeet = false;
  bool _weightInPounds = false;
  (int?, double?) _convertedHeight = (null, null);
  double? _convertedWeight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final field in [
      _name,
      _age,
      _height,
      _feet,
      _inches,
      _weight,
      _pounds,
      _phone,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  static String _format(double value) =>
      value.toStringAsFixed(2).replaceFirst(_trailingZeroes, '');

  static String _decimalText(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null ? '' : _format(number);
  }

  static double? _number(String text) {
    final value = text.trim().replaceAll(',', '.');
    return _decimalInput.hasMatch(value) ? double.tryParse(value) : null;
  }

  static String? _metricValue(String text) {
    if (text.trim().isEmpty) return '';
    final number = _number(text);
    return number == null ? null : _format(number);
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final profile = await widget.service.profile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _name.text = profile.name;
        _gender = profile.gender;
        _age.text = profile.age?.toString() ?? '';
        _height.text = _decimalText(profile.heightCm);
        _weight.text = _decimalText(profile.weightKg);
        _phone.text = profile.phoneNumber;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is FoodException
            ? error.message
            : 'Could not load your profile. Please try again.';
      });
    }
  }

  String? _heightValue() {
    if (!_heightInFeet) return _metricValue(_height.text);
    final feetText = _feet.text.trim();
    if (feetText.isEmpty && _inches.text.trim().isEmpty) return '';
    final feet = _ageInput.hasMatch(feetText) ? int.tryParse(feetText) : null;
    final inches = _number(_inches.text);
    if (feet == null || inches == null || inches >= 12) return null;
    // Showing a rounded conversion does not constitute an edit.
    if ((feet, inches) == _convertedHeight) return _metricValue(_height.text);
    if (feet > 9) return null;
    return _format((feet * 12 + inches) * _cmPerInch);
  }

  String? _weightValue() {
    if (!_weightInPounds) return _metricValue(_weight.text);
    if (_pounds.text.trim().isEmpty) return '';
    final pounds = _number(_pounds.text);
    if (pounds == null) return null;
    if (pounds == _convertedWeight) return _metricValue(_weight.text);
    return _format(pounds * _kgPerPound);
  }

  void _changeHeightUnit(bool useFeet) {
    if (_saving || useFeet == _heightInFeet) return;
    final value = _heightValue();
    if (value == null) {
      setState(() => _showValidation = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      if (useFeet) {
        final cm = double.tryParse(value);
        if (cm == null) {
          _feet.clear();
          _inches.clear();
          _convertedHeight = (null, null);
        } else {
          // Round total inches before splitting so 12 inches carries into feet.
          final total = double.parse(_format(cm / _cmPerInch));
          final feet = (total / 12).floor();
          final inches = _format(total - feet * 12);
          _feet.text = '$feet';
          _inches.text = inches;
          _convertedHeight = (feet, double.parse(inches));
        }
      } else {
        _height.text = value;
      }
      _heightInFeet = useFeet;
    });
  }

  void _changeWeightUnit(bool usePounds) {
    if (_saving || usePounds == _weightInPounds) return;
    final value = _weightValue();
    if (value == null) {
      setState(() => _showValidation = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      if (usePounds) {
        final kg = double.tryParse(value);
        _pounds.text = kg == null ? '' : _format(kg / _kgPerPound);
        _convertedWeight = double.tryParse(_pounds.text);
      } else {
        _weight.text = value;
      }
      _weightInPounds = usePounds;
    });
  }

  ({Map<String, Object?> changes, Map<String, String> errors}) _draft() {
    final changes = <String, Object?>{};
    final errors = <String, String>{};
    final profile = _profile;
    if (profile == null) return (changes: changes, errors: errors);

    final name = _name.text.trim();
    if (name.runes.length > _maxNameLength) {
      errors['name'] = 'Enter a name with $_maxNameLength characters or fewer.';
    } else if (name != profile.name) {
      changes['name'] = name;
    }
    if (_gender != profile.gender && _gender != null) {
      changes['gender'] = _gender!.value;
    }

    final ageText = _age.text.trim();
    final age = _ageInput.hasMatch(ageText) ? int.tryParse(ageText) : null;
    if (ageText.isNotEmpty || profile.age != null) {
      if (age == null || age < 1 || age > 120) {
        errors['age'] = 'Enter an age between 1 and 120.';
      } else if (age != profile.age) {
        changes['age'] = age;
      }
    }

    void measurement(
      String field,
      String? value,
      String? original,
      double min,
      double max,
      String error,
    ) {
      if (value == '' && original == null) return;
      final number = double.tryParse(value ?? '');
      if (number == null || number < min || number > max) {
        errors[field] = error;
      } else if (number != double.tryParse(original ?? '')) {
        changes[field] = value;
      }
    }

    measurement(
      'height_cm',
      _heightValue(),
      profile.heightCm,
      30,
      300,
      _heightInFeet
          ? 'Enter feet and inches for a height between 30 and 300 cm.'
          : 'Enter a height between 30 and 300 cm.',
    );
    measurement(
      'weight_kg',
      _weightValue(),
      profile.weightKg,
      1,
      500,
      _weightInPounds
          ? 'Enter a weight between 2.20 and 1102.32 lb.'
          : 'Enter a weight between 1 and 500 kg.',
    );

    final phone = _phone.text.trim();
    final number = phone.replaceAll(_phoneSeparators, '');
    if (phone.isNotEmpty &&
        (phone.length > 40 || !_phoneInput.hasMatch(number))) {
      errors['phone_number'] = 'Enter a valid phone number (7–15 digits).';
    } else if (number != profile.phoneNumber.replaceAll(_phoneSeparators, '')) {
      changes['phone_number'] = number;
    }
    return (changes: changes, errors: errors);
  }

  void _edited(String _) => setState(() => _saveError = null);

  Future<void> _pickPhoto() async {
    if (_saving || _pickingPhoto) return;
    FocusScope.of(context).unfocus();
    setState(() => _pickingPhoto = true);
    try {
      while (mounted) {
        try {
          final file =
              await (widget.pickPhoto?.call() ??
                  ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 85,
                    requestFullMetadata: false,
                  ));
          if (file == null || !mounted) return;
          if (await file.length() > _maxPhotoBytes) {
            throw const ProfilePhotoException('Choose a photo up to 1 MB.');
          }
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          if (bytes.isEmpty) {
            throw const ProfilePhotoException(
              'Choose a photo that can be opened.',
            );
          }
          setState(() {
            _pendingPhoto = bytes;
            _saveError = null;
          });
          return;
        } catch (error) {
          if (!mounted) return;
          final retry = await _photoAlert(
            title: 'Could not open photo',
            message: error is ProfilePhotoException
                ? error.message
                : 'Please choose another photo.',
          );
          if (!retry) return;
        }
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<bool> _photoAlert({
    required String title,
    required String message,
  }) async {
    return await showCupertinoDialog<bool>(
          context: context,
          barrierColor: const Color(0x66000000),
          builder: (context) => FoodStyle.theme(
            SafeArea(
              minimum: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SingleChildScrollView(
                    child: FoodStyle.card(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            namesRoute: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(message, textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: FoodStyle.secondary(
                                  label: 'Cancel',
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FoodStyle.primary(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Try again',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<void> _pickGender() async {
    FocusScope.of(context).unfocus();
    final options = ProfileGender.values;
    var selected = _gender ?? ProfileGender.preferNotToSay;
    final controller = FixedExtentScrollController(
      initialItem: options.indexOf(selected),
    );
    final confirmed = await FoodStyle.picker(
      context,
      title: 'Gender',
      child: CupertinoPicker(
        key: const Key('profile-gender-picker'),
        itemExtent: 44,
        scrollController: controller,
        onSelectedItemChanged: (index) => selected = options[index],
        children: [
          for (final gender in options) Center(child: Text(gender.label)),
        ],
      ),
    );
    controller.dispose();
    if (mounted && confirmed == true) {
      setState(() {
        _gender = selected;
        _saveError = null;
      });
    }
  }

  Future<void> _leave() async {
    if (_saving || _pickingPhoto || _confirming) return;
    FocusScope.of(context).unfocus();
    final draft = _draft();
    if (_pendingPhoto != null ||
        draft.changes.isNotEmpty ||
        draft.errors.isNotEmpty) {
      _confirming = true;
      final discarded = await FoodStyle.confirm(
        context,
        title: 'Discard changes?',
        message: 'Your profile changes haven’t been saved.',
        action: 'Discard',
        cancelLabel: 'Keep editing',
      );
      _confirming = false;
      if (!mounted || discarded != true) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving || _pickingPhoto) return;
    final draft = _draft();
    if (draft.errors.isNotEmpty) {
      setState(() {
        _showValidation = true;
        _saveError = null;
      });
      return;
    }
    final photo = _pendingPhoto;
    if (draft.changes.isEmpty && photo == null) return;
    FocusScope.of(context).unfocus();
    while (mounted) {
      setState(() {
        _saving = true;
        _saveError = null;
      });
      try {
        final profile = await widget.service.saveProfile(
          draft.changes,
          photo: photo,
        );
        if (mounted) Navigator.of(context).pop(profile);
        return;
      } catch (error) {
        if (!mounted) return;
        if (photo == null ||
            (error is FoodException && error.statusCode == 401)) {
          setState(() {
            _saving = false;
            _saveError = error is FoodException
                ? error.message
                : 'Could not save your profile. Please try again.';
          });
          return;
        }

        setState(() => _saving = false);
        final rejectedPhoto = error is ProfilePhotoException;
        final retry = await _photoAlert(
          title: 'Photo upload failed',
          message: rejectedPhoto
              ? error.message
              : 'Please try again to save your photo.',
        );
        if (!mounted) return;
        if (!retry || rejectedPhoto) {
          setState(() => _pendingPhoto = null);
          if (retry) await _pickPhoto();
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    final dirty =
        _pendingPhoto != null ||
        draft.changes.isNotEmpty ||
        draft.errors.isNotEmpty;
    final errors = _showValidation ? draft.errors : const <String, String>{};
    return FoodStyle.theme(
      PopScope<AccountProfile>(
        canPop: !_saving && !_pickingPhoto && !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: CupertinoPageScaffold(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    Expanded(
                      child: _profile == null ? _loadStatus() : _editor(errors),
                    ),
                    if (_profile != null) _footer(dirty),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      height: (MediaQuery.textScalerOf(context).scale(22) + 22).clamp(
        50,
        double.infinity,
      ),
      child: NavigationToolbar(
        leading: CupertinoButton(
          key: const Key('page-back'),
          padding: const EdgeInsets.only(right: 8),
          onPressed: _saving || _pickingPhoto ? null : _leave,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chevron_back, size: 23, color: _ink),
              SizedBox(width: 4),
              Text('Me', style: _labelStyle),
            ],
          ),
        ),
        middle: const Text(
          'Edit my profile',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );

  Widget _loadStatus() {
    if (_loadError == null) {
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
              _error(_loadError!),
              const SizedBox(height: 12),
              FoodStyle.secondary(label: 'Try again', onPressed: _load),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editor(Map<String, String> errors) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 19, 16, 14),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: [
      _section('Personal details'),
      const SizedBox(height: 12),
      _card([
        _photoRow(),
        _divider(vertical: 8),
        Row(
          children: [
            const Expanded(child: Text('Name', style: _labelStyle)),
            Expanded(
              flex: 2,
              child: _field(
                'profile-name',
                'Name',
                _name,
                TextInputType.name,
                hint: 'Add name',
              ),
            ),
          ],
        ),
        if (errors['name'] case final error?) _error(error),
        _divider(vertical: 8),
        CupertinoButton(
          key: const Key('profile-gender'),
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _pickGender,
          child: Row(
            children: [
              const Expanded(child: Text('Gender', style: _labelStyle)),
              Expanded(
                flex: 2,
                child: Text(
                  _gender?.label ?? 'Select',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: _ink, fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_down, color: _muted, size: 14),
            ],
          ),
        ),
        _divider(),
        Row(
          children: [
            const Expanded(child: Text('Age', style: _labelStyle)),
            Flexible(
              child: _field(
                'profile-age',
                'Age',
                _age,
                TextInputType.number,
                hint: '—',
              ),
            ),
            const SizedBox(width: 10),
            const Text('years', style: TextStyle(color: _muted, fontSize: 15)),
          ],
        ),
        if (errors['age'] case final error?) _error(error),
      ]),
      const SizedBox(height: 22),
      _section('Measurements'),
      const SizedBox(height: 12),
      _card([
        _measurement(
          'Height',
          _heightInFeet
              ? Row(
                  children: [
                    Expanded(
                      child: _field(
                        'profile-height-feet',
                        'Feet',
                        _feet,
                        TextInputType.number,
                        unit: 'ft',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _field(
                        'profile-height-inches',
                        'Inches',
                        _inches,
                        const TextInputType.numberWithOptions(decimal: true),
                        unit: 'in',
                      ),
                    ),
                  ],
                )
              : _field(
                  'profile-height',
                  'Height in cm',
                  _height,
                  const TextInputType.numberWithOptions(decimal: true),
                  hint: '—',
                ),
          _units(
            'height',
            'cm',
            'ft',
            'ft / in',
            _heightInFeet,
            _changeHeightUnit,
          ),
          error: errors['height_cm'],
          twoFields: _heightInFeet,
        ),
        _divider(),
        _measurement(
          'Weight',
          _field(
            'profile-weight',
            _weightInPounds ? 'Weight in lb' : 'Weight in kg',
            _weightInPounds ? _pounds : _weight,
            const TextInputType.numberWithOptions(decimal: true),
            hint: '—',
          ),
          _units(
            'weight',
            'kg',
            'lb',
            'lb',
            _weightInPounds,
            _changeWeightUnit,
          ),
          error: errors['weight_kg'],
        ),
      ]),
      const SizedBox(height: 20),
      _card([
        const Row(
          children: [
            Expanded(child: Text('Phone number', style: _labelStyle)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Optional',
                textAlign: TextAlign.end,
                style: TextStyle(color: _muted, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _field(
          'profile-phone',
          'Phone number',
          _phone,
          TextInputType.phone,
          hint: 'Add phone number',
        ),
        if (errors['phone_number'] case final error?) _error(error),
      ]),
    ],
  );

  Widget _photoRow() => Row(
    children: [
      ProfileAvatar(photo: _pendingPhoto ?? _profile?.photo),
      Expanded(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: CupertinoButton(
            key: const Key('profile-change-photo'),
            padding: const EdgeInsetsDirectional.only(start: 12),
            onPressed: _saving || _pickingPhoto ? null : _pickPhoto,
            child: _pickingPhoto
                ? const CupertinoActivityIndicator()
                : Text(
                    'Change photo',
                    textAlign: TextAlign.end,
                    style: _labelStyle.copyWith(color: FoodStyle.forest),
                  ),
          ),
        ),
      ),
    ],
  );

  Widget _section(String title) => Semantics(
    header: true,
    child: Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: FoodStyle.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D2C4431),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _divider({double vertical = 12}) => Padding(
    padding: EdgeInsets.symmetric(vertical: vertical),
    child: const SizedBox(
      height: 1,
      child: ColoredBox(color: Color(0xFFE2E8DF)),
    ),
  );

  Widget _measurement(
    String label,
    Widget field,
    Widget units, {
    required String? error,
    bool twoFields = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _labelStyle),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final scaled = MediaQuery.textScalerOf(context).scale(14);
          if (constraints.maxWidth < (twoFields ? 285 : 222) || scaled > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerEnd, child: units),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 9),
              SizedBox(width: scaled * 8.5, child: units),
            ],
          );
        },
      ),
      if (error != null) _error(error),
    ],
  );

  Widget _units(
    String field,
    String metric,
    String imperialKey,
    String imperialLabel,
    bool imperial,
    ValueChanged<bool> onChanged,
  ) => CupertinoSlidingSegmentedControl<bool>(
    groupValue: imperial,
    backgroundColor: FoodStyle.pale,
    thumbColor: FoodStyle.surface,
    disabledChildren: _saving ? const {false, true} : const {},
    onValueChanged: (value) {
      if (value != null) onChanged(value);
    },
    children: {
      for (final (choice, key, label) in [
        (false, metric, metric),
        (true, imperialKey, imperialLabel),
      ])
        choice: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            key: Key('profile-$field-$key'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: imperial == choice ? _ink : _muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    },
  );

  Widget _field(
    String key,
    String label,
    TextEditingController controller,
    TextInputType keyboard, {
    String? hint,
    String? unit,
  }) => Semantics(
    label: label,
    child: CupertinoTextField(
      key: Key(key),
      controller: controller,
      enabled: !_saving,
      keyboardType: keyboard,
      textCapitalization: keyboard == TextInputType.name
          ? TextCapitalization.words
          : TextCapitalization.none,
      onChanged: _edited,
      placeholder: hint,
      placeholderStyle: const TextStyle(color: _muted, fontSize: 15),
      style: const TextStyle(color: _ink, fontSize: 16),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(10),
      ),
      suffix: unit == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                unit,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
    ),
  );

  Widget _error(String message) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: const TextStyle(
          color: CupertinoColors.destructiveRed,
          fontSize: 13,
        ),
      ),
    ),
  );

  Widget _footer(bool dirty) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saveError case final error?) ...[
          _error(error),
          const SizedBox(height: 8),
        ],
        CupertinoButton.filled(
          key: const Key('profile-save'),
          onPressed: !_saving && !_pickingPhoto && dirty ? _save : null,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          borderRadius: BorderRadius.circular(18),
          disabledColor: FoodStyle.pale,
          child: _saving
              ? const CupertinoActivityIndicator()
              : Text(
                  'Save changes',
                  style: TextStyle(
                    color: dirty ? CupertinoColors.white : _muted,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    ),
  );
}
