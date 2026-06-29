/// User roles in the CNIC Health Card System.
enum UserRole { patient, doctor, labWorker, receptionist, admin, unknown }

UserRole roleFromString(String? value) {
  switch (value) {
    case 'patient':
      return UserRole.patient;
    case 'doctor':
      return UserRole.doctor;
    case 'lab_worker':
      return UserRole.labWorker;
    case 'receptionist':
      return UserRole.receptionist;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.unknown;
  }
}

String roleToString(UserRole role) {
  switch (role) {
    case UserRole.patient:
      return 'patient';
    case UserRole.doctor:
      return 'doctor';
    case UserRole.labWorker:
      return 'lab_worker';
    case UserRole.receptionist:
      return 'receptionist';
    case UserRole.admin:
      return 'admin';
    case UserRole.unknown:
      return 'unknown';
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? cnic;
  final UserRole role;
  final String? status;
  final String? healthId;
  final String? dob;
  final String? gender;
  final String? bloodGroup;

  /// Role-extended profile fields from the API (clinic_id, specialization, etc.).
  final Map<String, dynamic> extended;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.cnic,
    this.role = UserRole.patient,
    this.status,
    this.healthId,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.extended = const {},
  });

  /// Parses both the new API shape (full_name / phone_primary / role / extended)
  /// and the original demo shape (name / phone / healthId) for compatibility.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final ext = (json['extended'] as Map?)?.cast<String, dynamic>() ?? const {};
    return UserModel(
      id: json['id'] as String,
      name: (json['full_name'] ?? json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: (json['phone_primary'] ?? json['phone']) as String?,
      cnic: json['cnic'] as String?,
      role: roleFromString(json['role'] as String?),
      status: json['status'] as String?,
      healthId: (json['healthId'] ?? ext['health_card_number']) as String?,
      dob: (json['date_of_birth'] ?? json['dob']) as String?,
      gender: json['gender'] as String?,
      bloodGroup: (json['bloodGroup'] ?? ext['blood_group']) as String?,
      extended: ext,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': name,
        'email': email,
        'phone_primary': phone,
        'cnic': cnic,
        'role': roleToString(role),
        'status': status,
        'healthId': healthId,
        'date_of_birth': dob,
        'gender': gender,
        'bloodGroup': bloodGroup,
        'extended': extended,
      };
}

class AuthResponse {
  final String token;
  final UserModel user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}
