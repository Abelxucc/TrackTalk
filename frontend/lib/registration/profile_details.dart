import 'dart:convert';
import 'dart:typed_data';

enum ProfileGender {
  male('male', 'Male'),
  female('female', 'Female'),
  nonBinary('non_binary', 'Non-binary'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  const ProfileGender(this.value, this.label);
  final String value;
  final String label;
}

class ProfileDetails {
  const ProfileDetails({
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.age,
  });

  final ProfileGender gender;
  final String heightCm;
  final String weightKg;
  final int age;

  Map<String, Object> toJson() => {
    'gender': gender.value,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'age': age,
  };
}

class AccountProfile {
  const AccountProfile({
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.phoneNumber,
    this.name = '',
    this.photo,
  });

  final ProfileGender? gender;
  final String? heightCm;
  final String? weightKg;
  final int? age;
  final String phoneNumber;
  final String name;
  final Uint8List? photo;

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final photo = json['photo'] as String?;
    return AccountProfile(
      gender: ProfileGender.values
          .where((gender) => gender.value == json['gender'])
          .firstOrNull,
      heightCm: json['height_cm']?.toString(),
      weightKg: json['weight_kg']?.toString(),
      age: json['age'] as int?,
      phoneNumber: json['phone_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      photo: photo == null ? null : base64Decode(photo),
    );
  }
}
