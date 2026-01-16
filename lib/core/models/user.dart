import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? role;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.role,
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
    };
  }

  @override
  List<Object?> get props => [id, email, firstName, lastName, role];
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class TokenResponse {
  final String accessToken;
  final String? expiresIn;
  final String? tokenType;

  const TokenResponse({
    required this.accessToken,
    this.expiresIn,
    this.tokenType,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'] as String,
      expiresIn: json['expiresIn'] as String?,
      tokenType: json['tokenType'] as String?,
    );
  }
}
