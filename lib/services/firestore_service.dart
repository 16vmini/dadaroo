import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadaroo/models/delivery.dart';
import 'package:dadaroo/models/rating.dart';
import 'package:dadaroo/models/badge.dart';
import 'package:dadaroo/models/family_group.dart';
import 'package:dadaroo/models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Family Groups ──

  Future<FamilyGroup> createFamilyGroup({
    required String name,
    required String creatorUid,
  }) async {
    final code = _generateInviteCode();
    final docRef = _firestore.collection('familyGroups').doc();

    final group = FamilyGroup(
      id: docRef.id,
      name: name,
      inviteCode: code,
      createdBy: creatorUid,
      memberIds: [creatorUid],
      dadIds: [creatorUid],
      createdAt: DateTime.now(),
    );

    await docRef.set(group.toMap());

    // Update user's familyGroupId
    await _firestore.collection('users').doc(creatorUid).update({
      'familyGroupId': docRef.id,
    });

    return group;
  }

  Future<FamilyGroup?> joinFamilyByCode({
    required String inviteCode,
    required String uid,
    required UserRole role,
  }) async {
    final query = await _firestore
        .collection('familyGroups')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final group = FamilyGroup.fromMap(doc.data());

    // Add member
    final updates = <String, dynamic>{
      'memberIds': FieldValue.arrayUnion([uid]),
    };
    if (role == UserRole.dad) {
      updates['dadIds'] = FieldValue.arrayUnion([uid]);
    }
    await doc.reference.update(updates);

    // Update user's familyGroupId
    await _firestore.collection('users').doc(uid).update({
      'familyGroupId': doc.id,
    });

    return FamilyGroup.fromMap({...doc.data(), ...updates});
  }

  Stream<FamilyGroup?> familyGroupStream(String groupId) {
    return _firestore
        .collection('familyGroups')
        .doc(groupId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return FamilyGroup.fromMap(doc.data()!);
    });
  }

  Future<FamilyGroup?> getFamilyGroup(String groupId) async {
    final doc =
        await _firestore.collection('familyGroups').doc(groupId).get();
    if (!doc.exists) return null;
    return FamilyGroup.fromMap(doc.data()!);
  }

  Future<List<UserProfile>> getFamilyMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    // Firestore 'in' queries limited to 30 items
    final profiles = <UserProfile>[];
    for (var i = 0; i < memberIds.length; i += 30) {
      final batch = memberIds.sublist(
        i,
        i + 30 > memberIds.length ? memberIds.length : i + 30,
      );
      final query = await _firestore
          .collection('users')
          .where('uid', whereIn: batch)
          .get();
      profiles.addAll(query.docs.map((d) => UserProfile.fromMap(d.data())));
    }
    return profiles;
  }

  // ── Deliveries ──

  Future<Delivery> createDelivery(Delivery delivery) async {
    final docRef = _firestore.collection('deliveries').doc(delivery.id);
    await docRef.set(delivery.toMap());
    return delivery;
  }

  Future<void> updateDelivery(Delivery delivery) async {
    await _firestore
        .collection('deliveries')
        .doc(delivery.id)
        .update(delivery.toMap());
  }

  Future<void> updateDeliveryLocation({
    required String deliveryId,
    required double latitude,
    required double longitude,
  }) async {
    await _firestore.collection('deliveries').doc(deliveryId).update({
      'currentLatitude': latitude,
      'currentLongitude': longitude,
      'gpsTrail': FieldValue.arrayUnion([
        GpsPoint(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
        ).toMap(),
      ]),
    });
  }

  Future<void> completeDelivery(String deliveryId) async {
    await _firestore.collection('deliveries').doc(deliveryId).update({
      'isActive': false,
      'arrivalTime': DateTime.now().toIso8601String(),
    });
  }

  Stream<Delivery?> activeDeliveryStream(String familyGroupId) {
    return _firestore
        .collection('deliveries')
        .where('familyGroupId', isEqualTo: familyGroupId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return Delivery.fromMap(snap.docs.first.data());
    });
  }

  Stream<List<Delivery>> deliveryHistoryStream(String familyGroupId) {
    return _firestore
        .collection('deliveries')
        .where('familyGroupId', isEqualTo: familyGroupId)
        .where('isActive', isEqualTo: false)
        .orderBy('startTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Delivery.fromMap(d.data())).toList());
  }

  // ── Ratings ──

  Future<void> rateDelivery({
    required String deliveryId,
    required Rating rating,
  }) async {
    await _firestore.collection('deliveries').doc(deliveryId).update({
      'rating': rating.toMap(),
    });

    // Also save to ratings collection for easy querying
    await _firestore.collection('ratings').doc(deliveryId).set({
      'deliveryId': deliveryId,
      'rating': rating.toMap(),
      'average': rating.average,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ── Badges ──

  Future<void> awardBadge({
    required String uid,
    required Badge badge,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'badges': FieldValue.arrayUnion([badge.toMap()]),
    });
  }

  Future<List<Badge>> getUserBadges(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    if (data['badges'] == null) return [];
    return (data['badges'] as List)
        .map((b) => Badge.fromMap(b))
        .toList();
  }

  // ── User Stats ──

  Future<void> updateUserStats({
    required String uid,
    required int totalDeliveries,
    required double averageRating,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'totalDeliveries': totalDeliveries,
      'averageRating': averageRating,
    });
  }

  // ── Helpers ──

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
