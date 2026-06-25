class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? healthId;
  final String? dob;
  final String? gender;
  final String? bloodGroup;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.healthId,
    this.dob,
    this.gender,
    this.bloodGroup,
  });

  /// Factory constructor to create a UserModel from a JSON map.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      healthId: json['healthId'] as String?,
      dob: json['dob'] as String?,
      gender: json['gender'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
    );
  }

  /// Converts the UserModel instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'healthId': healthId,
      'dob': dob,
      'gender': gender,
      'bloodGroup': bloodGroup,
    };
  }
}

class AuthResponse {
  final String token;
  final UserModel user;

  AuthResponse({
    required this.token,
    required this.user,
  });

  /// Factory constructor to parse AuthResponse from API response JSON.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Converts the AuthResponse instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
    };
  }
}
