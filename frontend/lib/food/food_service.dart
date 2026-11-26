import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../activity/activity_record.dart';
import '../registration/profile_details.dart';
import '../shared/api_config.dart';

class FoodException implements Exception {
  const FoodException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

class ProfilePhotoException extends FoodException {
  const ProfilePhotoException(super.message);
}

class FoodItem {
  const FoodItem({required this.name, this.quantity, this.unit = ''});
  final String name;
  final String? quantity;
  final String unit;

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    name: json['name'] as String,
    quantity: json['quantity']?.toString(),
    unit: json['unit'] as String? ?? '',
  );

  String get amount {
    if (quantity == null) return 'Amount not provided';
    final display = quantity!.contains('.')
        ? quantity!.replaceFirst(RegExp(r'\.?0+$'), '')
        : quantity!;
    return '$display $unit';
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };
}

class FoodDraft {
  const FoodDraft({
    required this.mealType,
    required this.eatenAt,
    required this.items,
    this.timeSpecified = true,
  });
  final String mealType;
  final DateTime eatenAt;
  final List<FoodItem> items;
  final bool timeSpecified;

  Map<String, Object?> toJson() => {
    'meal_type': mealType,
    'eaten_at':
        (timeSpecified
                ? eatenAt
                : DateTime(eatenAt.year, eatenAt.month, eatenAt.day))
            .toUtc()
            .toIso8601String(),
    'time_specified': timeSpecified,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class FoodRecord extends FoodDraft {
  const FoodRecord({
    required this.id,
    required super.mealType,
    required super.eatenAt,
    required super.items,
    super.timeSpecified,
  });
  final int id;

  factory FoodRecord.fromJson(Map<String, dynamic> json) => FoodRecord(
    id: json['id'] as int,
    mealType: json['meal_type'] as String,
    eatenAt: DateTime.parse(json['eaten_at'] as String).toLocal(),
    timeSpecified: json['time_specified'] as bool? ?? true,
    items: (json['items'] as List)
        .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

typedef FoodTip = ({String title, String body, String sourceUrl});
typedef FoodWeek = ({
  DateTime start,
  DateTime end,
  int daysLogged,
  Map<String, List<String>> groups,
  FoodTip? tip,
  String? recommendationMessage,
});
typedef FoodAllergies = ({
  Map<String, String> options,
  List<String> allergenIds,
  List<String> otherFoods,
});

class FoodService {
  const FoodService(this.token, {this.accountEmail});
  static const _allergiesPath = '/api/food-allergies/';
  static const _profilePath = '/api/auth/profile/';
  static const _parsePath = '/api/food-records/parse/';
  static const _transcribePath = '/api/food-records/transcribe/';
  final String token;
  final String? accountEmail;

  static Future<String> signIn(String email, String password) async {
    final data = await _request(
      'POST',
      '/api/auth/login/',
      data: {'email': email.trim(), 'password': password},
    );
    return (data as Map<String, dynamic>)['token'] as String;
  }

  Future<List<FoodRecord>> list() async {
    final data = await _request('GET', '/api/food-records/', token: token);
    return (data as List)
        .map((record) => FoodRecord.fromJson(record as Map<String, dynamic>))
        .toList();
  }

  Future<({FoodDraft? food, ActivityDraft? activity})> parseRecord(
    String text,
    DateTime referenceDate, {
    required bool activityMode,
  }) async {
    final data = await _request(
      'POST',
      _parsePath,
      token: token,
      data: {
        'text': text,
        'reference_date': _dateOnly(referenceDate),
        'mode': activityMode ? 'activity' : 'food',
      },
    ) as Map<String, dynamic>;
    final date = DateTime.parse(data['date'] as String);
    final time = data['time'] as String?;
    final specified = time == null
        ? null
        : DateTime.parse("${data['date']}T$time:00");
    if (data['kind'] == 'activity') {
      return (
        food: null,
        activity: ActivityDraft(
          name: data['activity_name'] as String,
          durationMinutes: data['duration_minutes'] as int?,
          occurredAt: specified ?? date,
          timeSpecified: specified != null,
        ),
      );
    }
    return (
      activity: null,
      food: FoodDraft(
        mealType: data['meal_type'] as String? ?? '',
        eatenAt:
            specified ??
            DateTime(
              date.year,
              date.month,
              date.day,
              referenceDate.hour,
              referenceDate.minute,
            ),
        items: (data['items'] as List)
            .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  Future<String> transcribeRecord(Uint8List audio) async {
    final data = await _request(
      'POST',
      _transcribePath,
      token: token,
      audio: audio,
    );
    final text = data is Map<String, dynamic> ? data['text'] : null;
    if (text is String && text.trim().isNotEmpty) return text.trim();
    throw const FoodException(
      'No speech detected. Hold to speak and try again.',
    );
  }

  Future<FoodWeek> week(DateTime date) async {
    final data = await _request(
      'GET',
      '/api/food-recommendations/?date=${_dateOnly(date)}',
      token: token,
    ) as Map<String, dynamic>;
    final groups = (data['groups'] as List).cast<Map<String, dynamic>>();
    final recommendation = data['recommendation'] as Map<String, dynamic>?;
    return (
      start: DateTime.parse(data['week_start'] as String),
      end: DateTime.parse(data['week_end'] as String),
      daysLogged: data['days_logged'] as int,
      groups: {
        for (final group in groups)
          group['label'] as String: (group['foods'] as List).cast<String>(),
      },
      tip: recommendation == null
          ? null
          : (
              title: recommendation['title'] as String,
              body: recommendation['body'] as String,
              sourceUrl: recommendation['source_url'] as String,
            ),
      recommendationMessage: data['recommendation_message'] as String?,
    );
  }

  Future<FoodAllergies> allergies() async {
    final data = await _request(
      'GET',
      _allergiesPath,
      token: token,
    ) as Map<String, dynamic>;
    final options = (data['options'] as List).cast<Map<String, dynamic>>();
    return (
      options: {
        for (final option in options)
          option['id'] as String: option['label'] as String,
      },
      allergenIds: (data['allergen_ids'] as List).cast<String>(),
      otherFoods: (data['other_foods'] as List).cast<String>(),
    );
  }

  Future<void> saveAllergies({
    required List<String> allergenIds,
    required List<String> otherFoods,
  }) async {
    await _request(
      'PUT',
      _allergiesPath,
      token: token,
      data: {'allergen_ids': allergenIds, 'other_foods': otherFoods},
    );
  }

  Future<AccountProfile> profile() async {
    final data = await _request('GET', _profilePath, token: token);
    return AccountProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<AccountProfile> saveProfile(
    Map<String, Object?> changes, {
    Uint8List? photo,
  }) async {
    final data = await _request(
      'PATCH',
      _profilePath,
      token: token,
      data: {...changes, if (photo != null) 'photo': base64Encode(photo)},
    );
    return AccountProfile.fromJson(data as Map<String, dynamic>);
  }

  static String _dateOnly(DateTime value) =>
      value.toIso8601String().split('T').first;

  Future<void> signOut() async {
    try {
      await _request('POST', '/api/auth/logout/', token: token);
    } on FoodException catch (error) {
      // An expired or already-revoked login can still be cleared locally.
      if (error.statusCode != 401) rethrow;
    }
  }

  Future<FoodRecord> save(FoodDraft draft, {int? id}) async {
    final data = await _request(
      id == null ? 'POST' : 'PUT',
      '/api/food-records/${id == null ? '' : '$id/'}',
      token: token,
      data: draft.toJson(),
    );
    return FoodRecord.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _request('DELETE', '/api/food-records/$id/', token: token);
  }

  Future<List<ActivityRecord>> listActivities() async {
    final data = await _request('GET', '/api/activity-records/', token: token);
    return (data as List)
        .map(
          (record) => ActivityRecord.fromJson(record as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ActivityRecord> saveActivity(ActivityDraft draft, {int? id}) async {
    final data = await _request(
      id == null ? 'POST' : 'PUT',
      '/api/activity-records/${id == null ? '' : '$id/'}',
      token: token,
      data: draft.toJson(),
    );
    return ActivityRecord.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteActivity(int id) async {
    await _request('DELETE', '/api/activity-records/$id/', token: token);
  }

  static Future<Object?> _request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? data,
    Uint8List? audio,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        if (audio == null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      };
      final Future<http.Response> future;
      if (audio != null) {
        final request = http.MultipartRequest(method, uri)
          ..headers.addAll(headers)
          ..files.add(
            http.MultipartFile.fromBytes(
              'audio',
              audio,
              filename: 'recording.wav',
            ),
          );
        future = request.send().then(http.Response.fromStream);
      } else {
        future = switch (method) {
          'GET' => http.get(uri, headers: headers),
          'POST' => http.post(uri, headers: headers, body: jsonEncode(data)),
          'PUT' => http.put(uri, headers: headers, body: jsonEncode(data)),
          'PATCH' => http.patch(uri, headers: headers, body: jsonEncode(data)),
          'DELETE' => http.delete(uri, headers: headers),
          _ => throw ArgumentError.value(method),
        };
      }
      final response = await future.timeout(
        Duration(seconds: audio == null ? 15 : 35),
      );
      if (response.statusCode == 204) return null;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      if (response.statusCode == 401) {
        throw const FoodException(
          'Please sign out and log in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode == 404) {
        throw FoodException(switch (path) {
          _allergiesPath => 'Could not load allergy settings. Check that the backend is up to date.',
          _profilePath =>
            'Profile editing requires the latest TrackTalk backend.',
          _transcribePath =>
            'Voice input requires the latest TrackTalk backend.',
          _ => 'This record could not be found. Refresh your history.',
        });
      }
      if (response.statusCode == 429) {
        throw const FoodException(
          'Too many attempts. Please wait a minute and try again.',
        );
      }
      if (response.statusCode == 400 ||
          (response.statusCode == 409 && path == _profilePath) ||
          (response.statusCode == 503 &&
              (path == _parsePath || path == _transcribePath))) {
        final body = jsonDecode(response.body);
        if (path == _profilePath && body is Map && body.containsKey('photo')) {
          throw ProfilePhotoException(
            _messages(body['photo']).firstOrNull ?? 'Choose another photo.',
          );
        }
        final messages = _messages(body).toList();
        throw FoodException(
          messages.isEmpty ? 'Please check your details.' : messages.join('\n'),
        );
      }
      throw FoodException(switch (path) {
        _allergiesPath =>
          'Could not save or load your allergies. Please try again.',
        _profilePath =>
          'Could not ${method == 'GET' ? 'load' : 'save'} your profile. Please try again.',
        _transcribePath =>
          'Could not transcribe your recording. Please try again.',
        _ => 'Could not save or load your record. Please try again.',
      });
    } on TimeoutException {
      throw FoodException(switch (path) {
        _parsePath =>
          'Could not read that record in time. Try again or add it manually.',
        _transcribePath =>
          'Transcription timed out. Try again or switch to typing.',
        _allergiesPath => 'Connection timed out. Please try again.',
        _profilePath => 'Connection timed out. Please try again.',
        _ => 'Connection timed out. Check history before saving again.',
      });
    } on http.ClientException {
      throw const FoodException(
        'Could not connect. Check that the backend is running.',
      );
    } on FormatException {
      throw const FoodException('Unexpected response. Please try again.');
    }
  }

  static Iterable<String> _messages(Object? value) sync* {
    if (value is String) {
      yield value;
    } else if (value is List) {
      for (final item in value) {
        yield* _messages(item);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        yield* _messages(item);
      }
    }
  }
}
