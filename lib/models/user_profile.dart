enum UserRole { dad, familyMember }

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? familyGroupId;
  final int totalDeliveries;
  final double averageRating;
  final String? fcmToken;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.familyGroupId,
    this.totalDeliveries = 0,
    this.averageRating = 0.0,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.name,
      'familyGroupId': familyGroupId,
      'totalDeliveries': totalDeliveries,
      'averageRating': averageRating,
      'fcmToken': fcmToken,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.familyMember,
      ),
      familyGroupId: map['familyGroupId'],
      totalDeliveries: map['totalDeliveries'] ?? 0,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      fcmToken: map['fcmToken'],
    );
  }

  UserProfile copyWith({
    String? name,
    String? email,
    UserRole? role,
    String? familyGroupId,
    int? totalDeliveries,
    double? averageRating,
    String? fcmToken,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      averageRating: averageRating ?? this.averageRating,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
