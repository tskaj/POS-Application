// Models will be defined here

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? cellNo1;
  final String? cellNo2;
  final String? imgPath;
  final String roleId;
  final String? emailVerifiedAt;
  final String? twoFactorSecret;
  final String? twoFactorRecoveryCodes;
  final String? twoFactorConfirmedAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.cellNo1,
    this.cellNo2,
    this.imgPath,
    required this.roleId,
    this.emailVerifiedAt,
    this.twoFactorSecret,
    this.twoFactorRecoveryCodes,
    this.twoFactorConfirmedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      cellNo1: json['cell_no1']?.toString(),
      cellNo2: json['cell_no2']?.toString(),
      imgPath: json['img_path']?.toString(),
      roleId:
          json['role_id']?.toString() ??
          (json['role'] is Map ? json['role']['id']?.toString() : '') ??
          '',
      emailVerifiedAt: json['email_verified_at']?.toString(),
      twoFactorSecret: json['two_factor_secret']?.toString(),
      twoFactorRecoveryCodes: json['two_factor_recovery_codes']?.toString(),
      twoFactorConfirmedAt: json['two_factor_confirmed_at']?.toString(),
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'cell_no1': cellNo1,
      'cell_no2': cellNo2,
      'img_path': imgPath,
      'role_id': roleId,
      'email_verified_at': emailVerifiedAt,
      'two_factor_secret': twoFactorSecret,
      'two_factor_recovery_codes': twoFactorRecoveryCodes,
      'two_factor_confirmed_at': twoFactorConfirmedAt,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get fullName => '$firstName $lastName';
}

class UserProfile {
  final int id;
  final String userId;
  final User user;
  final String? phone;
  final String? address;
  final String? gender;
  final String? dob;
  String? profilePicture;
  final String createdAt;
  final String updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    required this.user,
    this.phone,
    this.address,
    this.gender,
    this.dob,
    this.profilePicture,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, {User? currentUser}) {
    return UserProfile(
      id: json['id'],
      userId: json['user_id'].toString(),
      user: currentUser ?? User.fromJson(json['user']),
      phone: json['phone'],
      address: json['address'],
      gender: json['gender'],
      dob: json['dob'],
      profilePicture:
          json['profile_picture'] != null &&
              !json['profile_picture'].startsWith('http')
          ? json['profile_picture']
          : null,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user': user.toJson(),
      'phone': phone,
      'address': address,
      'gender': gender,
      'dob': dob,
      'profile_picture': profilePicture,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // For updating profile
  Map<String, dynamic> toUpdateJson() {
    return {
      'user_id': userId,
      'phone': phone,
      'address': address,
      'gender': gender,
      'dob': dob,
      'profile_picture': profilePicture,
    };
  }
}
