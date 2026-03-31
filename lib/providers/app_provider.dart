import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dadaroo/config/app_config.dart';
import 'package:dadaroo/models/takeaway_type.dart';
import 'package:dadaroo/models/delivery.dart';
import 'package:dadaroo/models/delivery_stop.dart';
import 'package:dadaroo/models/rating.dart';
import 'package:dadaroo/models/badge.dart';
import 'package:dadaroo/models/parent_profile.dart';
import 'package:dadaroo/models/user_profile.dart';
import 'package:dadaroo/models/family_group.dart';
import 'package:dadaroo/services/auth_service.dart';
import 'package:dadaroo/services/firestore_service.dart';
import 'package:dadaroo/services/gps_tracking_service.dart';
import 'package:dadaroo/services/notification_service.dart';
import 'package:dadaroo/services/mock_gps_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  late final GpsTrackingService _gpsTrackingService;
  final MockGpsService _mockGpsService = MockGpsService();

  // Auth state
  UserProfile? _userProfile;
  FamilyGroup? _familyGroup;
  bool _isInitialized = false;
  bool _isAuthLoading = true;

  // Delivery state
  TakeawayType _selectedTakeaway = TakeawayType.pizza;
  String _customTakeawayName = '';
  Delivery? _activeDelivery;
  LatLng? _currentParentLocation;
  bool _parentIsClose = false;
  bool _showCelebration = false;
  bool _notifiedClose = false;

  // Family data
  List<ParentProfile> _parents = [];
  String _currentParentId = '';
  List<Delivery> _deliveryHistory = [];

  // Stream subscriptions
  StreamSubscription? _authSubscription;
  StreamSubscription? _profileSubscription;
  StreamSubscription? _familySubscription;
  StreamSubscription? _activeDeliverySubscription;
  StreamSubscription? _historySubscription;

  AppProvider() {
    _gpsTrackingService = GpsTrackingService(_firestoreService);
    _listenToAuth();
  }

  // ── Getters ──

  UserProfile? get userProfile => _userProfile;
  FamilyGroup? get familyGroup => _familyGroup;
  bool get isInitialized => _isInitialized;
  bool get isAuthLoading => _isAuthLoading;
  bool get isLoggedIn => _userProfile != null;
  bool get hasFamilyGroup => _userProfile?.familyGroupId != null;

  TakeawayType get selectedTakeaway => _selectedTakeaway;
  String get customTakeawayName => _customTakeawayName;
  Delivery? get activeDelivery => _activeDelivery;
  LatLng? get currentParentLocation => _currentParentLocation;
  bool get parentIsClose => _parentIsClose;
  bool get showCelebration => _showCelebration;
  bool get isDeliveryActive =>
      _activeDelivery != null && _activeDelivery!.isActive;
  List<Delivery> get deliveryHistory => List.unmodifiable(_deliveryHistory);
  List<ParentProfile> get parents => List.unmodifiable(_parents);
  ParentProfile get currentParent {
    if (_parents.isEmpty) {
      return ParentProfile(
        id: '',
        name: _userProfile?.name ?? appConfig.parentRole,
        badges: [],
        deliveries: [],
      );
    }
    return _parents.firstWhere(
      (d) => d.id == _currentParentId,
      orElse: () => _parents.first,
    );
  }

  MockGpsService get gpsService => _mockGpsService;

  Duration get etaRemaining {
    if (_activeDelivery != null &&
        _activeDelivery!.currentLatitude != null &&
        _activeDelivery!.currentLongitude != null) {
      return GpsTrackingService.calculateEtaFromPosition(
        latitude: _activeDelivery!.currentLatitude!,
        longitude: _activeDelivery!.currentLongitude!,
        homeLatitude: 51.5150,
        homeLongitude: -0.1100,
      );
    }
    return _mockGpsService.estimatedTimeRemaining;
  }

  double get deliveryProgress {
    if (_activeDelivery != null &&
        _activeDelivery!.currentLatitude != null) {
      final totalDistance = GpsTrackingService.distanceBetween(
        51.5074, -0.1278, 51.5150, -0.1100,
      );
      final remainingDistance = GpsTrackingService.distanceBetween(
        _activeDelivery!.currentLatitude!,
        _activeDelivery!.currentLongitude!,
        51.5150,
        -0.1100,
      );
      return ((totalDistance - remainingDistance) / totalDistance).clamp(0.0, 1.0);
    }
    return _mockGpsService.progress;
  }

  // ── Auth Methods ──

  void _listenToAuth() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        await _loadUserProfile(user.uid);
      } else {
        _clearUserData();
      }
      _isAuthLoading = false;
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile(String uid) async {
    _profileSubscription?.cancel();
    _profileSubscription = _authService.userProfileStream(uid).listen((profile) {
      _userProfile = profile;
      if (profile?.familyGroupId != null) {
        _loadFamilyGroup(profile!.familyGroupId!);
      }
      if (profile != null) {
        _currentParentId = profile.uid;
      }
      notifyListeners();
    });
  }

  Future<void> _loadFamilyGroup(String groupId) async {
    _familySubscription?.cancel();
    _familySubscription =
        _firestoreService.familyGroupStream(groupId).listen((group) async {
      _familyGroup = group;
      if (group != null) {
        await _loadFamilyParents(group);
        _listenToActiveDelivery(group.id);
        _listenToHistory(group.id);
      }
      notifyListeners();
    });
  }

  Future<void> _loadFamilyParents(FamilyGroup group) async {
    final members = await _firestoreService.getFamilyMembers(group.parentIds);
    final parentList = <ParentProfile>[];
    for (final member in members) {
      final badges = await _firestoreService.getUserBadges(member.uid);
      final deliveries = _deliveryHistory
          .where((d) => d.dadUid == member.uid)
          .toList();
      parentList.add(ParentProfile(
        id: member.uid,
        name: member.name,
        badges: badges,
        deliveries: deliveries,
      ));
    }
    _parents = parentList;
    if (_parents.isNotEmpty && !_parents.any((d) => d.id == _currentParentId)) {
      _currentParentId = _parents.first.id;
    }
  }

  void _listenToActiveDelivery(String groupId) {
    _activeDeliverySubscription?.cancel();
    _activeDeliverySubscription =
        _firestoreService.activeDeliveryStream(groupId).listen((delivery) {
      final wasActive = _activeDelivery?.isActive ?? false;
      _activeDelivery = delivery;

      if (delivery != null) {
        if (delivery.currentLatitude != null &&
            delivery.currentLongitude != null) {
          _currentParentLocation = LatLng(
            delivery.currentLatitude!,
            delivery.currentLongitude!,
          );

          final eta = etaRemaining;
          if (eta.inSeconds <= 120 && !_parentIsClose) {
            _parentIsClose = true;
            if (!_notifiedClose && _familyGroup != null) {
              _notifiedClose = true;
              _notificationService.notifyParentIsClose(
                familyGroupId: _familyGroup!.id,
                parentName: delivery.dadName,
              );
            }
          }
        }
      } else if (wasActive) {
        _showCelebration = true;
      }

      notifyListeners();
    });
  }

  void _listenToHistory(String groupId) {
    _historySubscription?.cancel();
    _historySubscription =
        _firestoreService.deliveryHistoryStream(groupId).listen((deliveries) {
      _deliveryHistory = deliveries;
      if (_familyGroup != null) {
        _loadFamilyParents(_familyGroup!);
      }
      notifyListeners();
    });
  }

  void _clearUserData() {
    _userProfile = null;
    _familyGroup = null;
    _activeDelivery = null;
    _currentParentLocation = null;
    _parentIsClose = false;
    _showCelebration = false;
    _parents = [];
    _deliveryHistory = [];
    _profileSubscription?.cancel();
    _familySubscription?.cancel();
    _activeDeliverySubscription?.cancel();
    _historySubscription?.cancel();
  }

  /// Register a parent (Dad/Mum) with full credentials and auto-create family group.
  Future<void> signUpParent({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String familyName,
  }) async {
    final profile = await _authService.signUp(
      email: email,
      password: password,
      name: name,
      role: UserRole.dad,
      phoneNumber: phoneNumber,
    );
    _userProfile = profile;
    await _notificationService.initialize(profile.uid);

    // Auto-create family group
    final group = await _firestoreService.createFamilyGroup(
      name: familyName,
      creatorUid: profile.uid,
    );
    await _notificationService.subscribeToFamily(group.id);

    notifyListeners();
  }

  /// Family member joins with just a name and invite code (anonymous auth).
  Future<FamilyGroup?> joinFamilyAsGuest({
    required String name,
    required String inviteCode,
  }) async {
    debugPrint('[JOIN] Step 1: Anonymous sign-in...');
    final profile = await _authService.signUpAnonymous(name: name)
        .timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Anonymous sign-in timed out. Check your internet connection.');
    });
    _userProfile = profile;
    debugPrint('[JOIN] Step 2: Signed in as ${profile.uid}');

    // Don't block join on notification setup
    _notificationService.initialize(profile.uid).catchError((_) {});

    debugPrint('[JOIN] Step 3: Looking up family code: $inviteCode');
    final group = await _firestoreService.joinFamilyByCode(
      inviteCode: inviteCode,
      uid: profile.uid,
      role: UserRole.familyMember,
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Family lookup timed out. Check your internet connection.');
    });
    debugPrint('[JOIN] Step 4: Result: ${group?.name ?? 'NOT FOUND'}');

    if (group != null) {
      _notificationService.subscribeToFamily(group.id).catchError((_) {});
    }
    notifyListeners();
    return group;
  }

  /// Legacy sign-up (kept for backward compat).
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final profile = await _authService.signUp(
      email: email,
      password: password,
      name: name,
      role: role,
    );
    _userProfile = profile;
    await _notificationService.initialize(profile.uid);
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final profile = await _authService.signIn(
      email: email,
      password: password,
    );
    _userProfile = profile;
    await _notificationService.initialize(profile.uid);
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    final profile = await _authService.signInWithGoogle();
    _userProfile = profile;
    await _notificationService.initialize(profile.uid);
    notifyListeners();
  }

  Future<void> signInWithApple() async {
    final profile = await _authService.signInWithApple();
    _userProfile = profile;
    await _notificationService.initialize(profile.uid);
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_familyGroup != null) {
      await _notificationService.unsubscribeFromFamily(_familyGroup!.id);
    }
    _gpsTrackingService.stopTracking();
    _mockGpsService.stopTracking();
    _clearUserData();
    await _authService.signOut();
    notifyListeners();
  }

  // ── Family Methods ──

  Future<FamilyGroup?> createFamilyGroup(String name) async {
    if (_userProfile == null) return null;
    final group = await _firestoreService.createFamilyGroup(
      name: name,
      creatorUid: _userProfile!.uid,
    );
    await _notificationService.subscribeToFamily(group.id);
    return group;
  }

  Future<FamilyGroup?> joinFamilyByCode(String code) async {
    if (_userProfile == null) return null;
    final group = await _firestoreService.joinFamilyByCode(
      inviteCode: code,
      uid: _userProfile!.uid,
      role: _userProfile!.role,
    );
    if (group != null) {
      await _notificationService.subscribeToFamily(group.id);
    }
    return group;
  }

  /// Get all family members (for manage members screen).
  Future<List<UserProfile>> getFamilyMembers() async {
    if (_familyGroup == null) return [];
    return _firestoreService.getFamilyMembers(_familyGroup!.memberIds);
  }

  /// Remove a family member (parent only).
  Future<void> removeFamilyMember(String memberUid) async {
    if (_familyGroup == null) return;
    if (_userProfile?.uid != _familyGroup!.createdBy) return;
    await _firestoreService.removeFamilyMember(
      groupId: _familyGroup!.id,
      memberUid: memberUid,
    );
  }

  // ── Delivery & Takeaway Methods ──

  void setSelectedTakeaway(TakeawayType type) {
    _selectedTakeaway = type;
    notifyListeners();
  }

  void setCustomTakeawayName(String name) {
    _customTakeawayName = name;
    notifyListeners();
  }

  void setCurrentParent(String parentId) {
    _currentParentId = parentId;
    notifyListeners();
  }

  /// Advance the delivery to a specific status.
  Future<void> updateDeliveryStatus(DeliveryStatus newStatus) async {
    if (_activeDelivery == null) return;

    _activeDelivery = _activeDelivery!.copyWith(status: newStatus);

    if (_familyGroup != null) {
      await _firestoreService.updateDeliveryStatus(
        deliveryId: _activeDelivery!.id,
        status: newStatus,
      );

      await _notificationService.notifyStatusUpdate(
        familyGroupId: _familyGroup!.id,
        parentName: _activeDelivery!.dadName,
        status: newStatus,
      );
    }

    // Start GPS tracking when moving to onRoute
    if (newStatus == DeliveryStatus.onRoute) {
      await _startGpsOrMock();
    }

    // Complete delivery when status is delivered
    if (newStatus == DeliveryStatus.delivered) {
      await _completeDelivery();
      return;
    }

    notifyListeners();
  }

  /// Advance to the next status in the flow.
  Future<void> advanceDeliveryStatus() async {
    if (_activeDelivery == null) return;
    final next = _activeDelivery!.status.next;
    if (next != null) {
      await updateDeliveryStatus(next);
    }
  }

  Future<void> _startGpsOrMock() async {
    if (_familyGroup != null) {
      final hasPermission = await _gpsTrackingService.ensurePermissions();
      if (hasPermission) {
        await _gpsTrackingService.startTracking(
          deliveryId: _activeDelivery!.id,
          homeLatitude: 51.5150,
          homeLongitude: -0.1100,
          onUpdate: (position, eta) {
            _currentParentLocation =
                LatLng(position.latitude, position.longitude);
            if (eta != null && eta.inSeconds <= 120 && !_parentIsClose) {
              _parentIsClose = true;
              if (_activeDelivery != null &&
                  _activeDelivery!.status == DeliveryStatus.onRoute) {
                updateDeliveryStatus(DeliveryStatus.nearlyThere);
              }
            }
            notifyListeners();
          },
        );
        return;
      }
    }
    _startMockTracking();
  }

  Future<void> startDelivery() async {
    final delivery = Delivery(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dadName: _userProfile?.name ?? currentParent.name,
      dadUid: _userProfile?.uid,
      familyGroupId: _familyGroup?.id,
      takeawayType: _selectedTakeaway,
      customTakeawayName:
          _selectedTakeaway == TakeawayType.custom ? _customTakeawayName : null,
      startTime: DateTime.now(),
      estimatedDuration: const Duration(minutes: 10),
      isActive: true,
      status: DeliveryStatus.arrivedAtRestaurant,
    );

    _activeDelivery = delivery;
    _parentIsClose = false;
    _showCelebration = false;
    _notifiedClose = false;

    if (_familyGroup != null) {
      await _firestoreService.createDelivery(delivery);

      await _notificationService.notifyDeliveryStarted(
        familyGroupId: _familyGroup!.id,
        parentName: delivery.dadName,
        takeawayName: delivery.takeawayDisplayName,
      );
    }

    notifyListeners();
  }

  Future<void> startMultiDropDelivery(List<DeliveryStop> stops) async {
    final stopsWithStatus = stops.isNotEmpty
        ? [
            stops.first.copyWith(status: StopStatus.delivering),
            ...stops.skip(1),
          ]
        : stops;

    final delivery = Delivery(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dadName: _userProfile?.name ?? currentParent.name,
      dadUid: _userProfile?.uid,
      familyGroupId: _familyGroup?.id,
      takeawayType: _selectedTakeaway,
      customTakeawayName:
          _selectedTakeaway == TakeawayType.custom ? _customTakeawayName : null,
      startTime: DateTime.now(),
      estimatedDuration: Duration(minutes: 10 * stops.length),
      isActive: true,
      status: DeliveryStatus.arrivedAtRestaurant,
      stops: stopsWithStatus,
      currentStopIndex: 0,
    );

    _activeDelivery = delivery;
    _parentIsClose = false;
    _showCelebration = false;
    _notifiedClose = false;

    if (_familyGroup != null) {
      await _firestoreService.createDelivery(delivery);

      final stopNames = stops.map((s) => s.name).join(', ');
      await _notificationService.notifyDeliveryStarted(
        familyGroupId: _familyGroup!.id,
        parentName: delivery.dadName,
        takeawayName:
            '${delivery.takeawayDisplayName} (${stops.length} stops: $stopNames)',
      );
    }

    notifyListeners();
  }

  Future<void> markCurrentStopDelivered() async {
    if (_activeDelivery == null || _activeDelivery!.stops.isEmpty) return;
    final idx = _activeDelivery!.currentStopIndex;
    if (idx >= _activeDelivery!.stops.length) return;

    final updatedStops = List<DeliveryStop>.from(_activeDelivery!.stops);
    updatedStops[idx] = updatedStops[idx].copyWith(
      status: StopStatus.delivered,
      deliveredAt: DateTime.now(),
    );

    final nextIdx = idx + 1;
    final allDone = nextIdx >= updatedStops.length;

    if (!allDone) {
      updatedStops[nextIdx] = updatedStops[nextIdx].copyWith(
        status: StopStatus.delivering,
      );
    }

    _activeDelivery = _activeDelivery!.copyWith(
      stops: updatedStops,
      currentStopIndex: allDone ? idx : nextIdx,
    );

    if (_familyGroup != null) {
      await _firestoreService.updateDeliveryStops(
        deliveryId: _activeDelivery!.id,
        stops: updatedStops,
        currentStopIndex: allDone ? idx : nextIdx,
      );
    }

    if (allDone) {
      await _completeDelivery();
    } else {
      notifyListeners();
    }
  }

  void _startMockTracking() {
    _mockGpsService.startTracking((location) {
      _currentParentLocation = location;
      final remaining = _mockGpsService.estimatedTimeRemaining;

      if (remaining.inSeconds <= 120 && !_parentIsClose) {
        _parentIsClose = true;
        if (_activeDelivery != null &&
            _activeDelivery!.status == DeliveryStatus.onRoute) {
          updateDeliveryStatus(DeliveryStatus.nearlyThere);
        }
      }

      if (_mockGpsService.hasArrived) {
        _completeDelivery();
      }

      notifyListeners();
    });
  }

  Future<void> _completeDelivery() async {
    if (_activeDelivery == null) return;

    _activeDelivery = _activeDelivery!.copyWith(
      arrivalTime: DateTime.now(),
      isActive: false,
      status: DeliveryStatus.delivered,
    );
    _showCelebration = true;

    if (_familyGroup != null) {
      await _firestoreService.completeDelivery(_activeDelivery!.id);
    }

    _gpsTrackingService.stopTracking();
    notifyListeners();
  }

  Future<void> rateDelivery(Rating rating) async {
    if (_activeDelivery == null) return;

    final ratedDelivery = _activeDelivery!.copyWith(rating: rating);

    if (_familyGroup != null) {
      await _firestoreService.rateDelivery(
        deliveryId: ratedDelivery.id,
        rating: rating,
      );

      if (ratedDelivery.dadUid != null) {
        await _notificationService.notifyRatingReceived(
          parentUid: ratedDelivery.dadUid!,
          averageRating: rating.average,
        );
      }

      if (ratedDelivery.dadUid != null) {
        final allDeliveries = _deliveryHistory
            .where((d) => d.dadUid == ratedDelivery.dadUid)
            .toList()
          ..add(ratedDelivery);
        final existingBadges =
            await _firestoreService.getUserBadges(ratedDelivery.dadUid!);
        final newBadges = _checkBadges(allDeliveries, existingBadges);
        for (final badge in newBadges) {
          if (!existingBadges.any((b) => b.type == badge.type)) {
            await _firestoreService.awardBadge(
              uid: ratedDelivery.dadUid!,
              badge: badge,
            );
          }
        }

        final ratedList =
            allDeliveries.where((d) => d.rating != null).toList();
        final avgRating = ratedList.isEmpty
            ? 0.0
            : ratedList.map((d) => d.rating!.average).reduce((a, b) => a + b) /
                ratedList.length;
        await _firestoreService.updateUserStats(
          uid: ratedDelivery.dadUid!,
          totalDeliveries: allDeliveries.length,
          averageRating: avgRating,
        );
      }
    } else {
      _deliveryHistory.insert(0, ratedDelivery);

      final parentIndex = _parents.indexWhere((d) => d.id == _currentParentId);
      if (parentIndex != -1) {
        final parent = _parents[parentIndex];
        final updatedDeliveries = [...parent.deliveries, ratedDelivery];
        final updatedBadges = _checkBadges(updatedDeliveries, parent.badges);
        _parents[parentIndex] = ParentProfile(
          id: parent.id,
          name: parent.name,
          badges: updatedBadges,
          deliveries: updatedDeliveries,
        );
      }
    }

    _activeDelivery = null;
    _currentParentLocation = null;
    _parentIsClose = false;
    _showCelebration = false;
    _mockGpsService.stopTracking();

    notifyListeners();
  }

  /// Dismiss the celebration screen without clearing the delivery,
  /// so the rating screen can still access it.
  void acknowledgeCelebration() {
    _showCelebration = false;
    notifyListeners();
  }

  void skipRating() {
    if (_activeDelivery != null) {
      final completed = _activeDelivery!.copyWith(isActive: false);
      if (_familyGroup == null) {
        _deliveryHistory.insert(0, completed);
      }
    }
    _activeDelivery = null;
    _currentParentLocation = null;
    _parentIsClose = false;
    _showCelebration = false;
    _mockGpsService.stopTracking();
    _gpsTrackingService.stopTracking();
    notifyListeners();
  }

  void cancelDelivery() {
    if (_activeDelivery != null && _familyGroup != null) {
      _firestoreService.completeDelivery(_activeDelivery!.id);
    }
    _activeDelivery = null;
    _currentParentLocation = null;
    _parentIsClose = false;
    _showCelebration = false;
    _mockGpsService.stopTracking();
    _gpsTrackingService.stopTracking();
    notifyListeners();
  }

  void simulateArrival() {
    if (_activeDelivery == null) return;
    _mockGpsService.stopTracking();
    _gpsTrackingService.stopTracking();
    _parentIsClose = true;
    _completeDelivery();
  }

  List<Badge> _checkBadges(List<Delivery> deliveries, List<Badge> existing) {
    final badges = List<Badge>.from(existing);
    final existingTypes = existing.map((b) => b.type).toSet();
    final now = DateTime.now();

    if (!existingTypes.contains(BadgeType.speedDemon)) {
      if (deliveries.any((d) =>
          d.actualDuration != null && d.actualDuration!.inMinutes < 15)) {
        badges.add(Badge(type: BadgeType.speedDemon, earnedAt: now));
      }
    }

    if (!existingTypes.contains(BadgeType.hundredDeliveries)) {
      if (deliveries.length >= 100) {
        badges.add(Badge(type: BadgeType.hundredDeliveries, earnedAt: now));
      }
    }

    if (!existingTypes.contains(BadgeType.fiveStarParent)) {
      if (deliveries
          .any((d) => d.rating != null && d.rating!.average == 5.0)) {
        badges.add(Badge(type: BadgeType.fiveStarParent, earnedAt: now));
      }
    }

    if (!existingTypes.contains(BadgeType.masterChefPicker)) {
      final rated = deliveries.where((d) => d.rating != null).toList();
      if (rated.length >= 3) {
        final avgFoodChoice =
            rated.map((d) => d.rating!.foodChoice).reduce((a, b) => a + b) /
                rated.length;
        if (avgFoodChoice >= 4.5) {
          badges.add(Badge(type: BadgeType.masterChefPicker, earnedAt: now));
        }
      }
    }

    if (!existingTypes.contains(BadgeType.varietyRoyalty)) {
      final types = deliveries.map((d) => d.takeawayType).toSet();
      final mainTypes = TakeawayType.values
          .where((t) => t != TakeawayType.other && t != TakeawayType.custom)
          .toSet();
      if (types.containsAll(mainTypes)) {
        badges.add(Badge(type: BadgeType.varietyRoyalty, earnedAt: now));
      }
    }

    return badges;
  }

  // ── Stats ──

  Map<TakeawayType, int> get takeawayStats {
    final stats = <TakeawayType, int>{};
    for (final d in _deliveryHistory) {
      stats[d.takeawayType] = (stats[d.takeawayType] ?? 0) + 1;
    }
    return stats;
  }

  TakeawayType? get favouriteTakeaway {
    final stats = takeawayStats;
    if (stats.isEmpty) return null;
    return stats.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Duration? get averageDeliveryTime {
    final completed =
        _deliveryHistory.where((d) => d.actualDuration != null).toList();
    if (completed.isEmpty) return null;
    final totalSeconds = completed
        .map((d) => d.actualDuration!.inSeconds)
        .reduce((a, b) => a + b);
    return Duration(seconds: totalSeconds ~/ completed.length);
  }

  double? get bestRating {
    final rated = _deliveryHistory.where((d) => d.rating != null).toList();
    if (rated.isEmpty) return null;
    return rated
        .map((d) => d.rating!.average)
        .reduce((a, b) => a > b ? a : b);
  }

  // Seed demo data for offline/no-auth mode
  void seedDemoData() {
    if (_deliveryHistory.isNotEmpty) return;

    _parents = [
      ParentProfile(id: '1', name: appConfig.parentRole, badges: [], deliveries: []),
      ParentProfile(id: '2', name: 'Uncle Bob', badges: [], deliveries: []),
      ParentProfile(id: '3', name: 'Grandad', badges: [], deliveries: []),
    ];
    _currentParentId = '1';

    final demoDeliveries = [
      Delivery(
        id: 'demo1',
        dadName: appConfig.parentRole,
        takeawayType: TakeawayType.pizza,
        startTime: DateTime.now().subtract(const Duration(days: 7)),
        arrivalTime: DateTime.now()
            .subtract(const Duration(days: 7))
            .add(const Duration(minutes: 18)),
        estimatedDuration: const Duration(minutes: 20),
        rating:
            Rating(speed: 4, foodChoice: 5, communication: 4, overallDadness: 5),
      ),
      Delivery(
        id: 'demo2',
        dadName: appConfig.parentRole,
        takeawayType: TakeawayType.chinese,
        startTime: DateTime.now().subtract(const Duration(days: 5)),
        arrivalTime: DateTime.now()
            .subtract(const Duration(days: 5))
            .add(const Duration(minutes: 12)),
        estimatedDuration: const Duration(minutes: 15),
        rating:
            Rating(speed: 5, foodChoice: 4, communication: 5, overallDadness: 5),
      ),
      Delivery(
        id: 'demo3',
        dadName: 'Uncle Bob',
        takeawayType: TakeawayType.burger,
        startTime: DateTime.now().subtract(const Duration(days: 3)),
        arrivalTime: DateTime.now()
            .subtract(const Duration(days: 3))
            .add(const Duration(minutes: 22)),
        estimatedDuration: const Duration(minutes: 25),
        rating:
            Rating(speed: 3, foodChoice: 4, communication: 3, overallDadness: 4),
      ),
      Delivery(
        id: 'demo4',
        dadName: appConfig.parentRole,
        takeawayType: TakeawayType.indian,
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        arrivalTime: DateTime.now()
            .subtract(const Duration(days: 1))
            .add(const Duration(minutes: 16)),
        estimatedDuration: const Duration(minutes: 20),
        rating:
            Rating(speed: 4, foodChoice: 5, communication: 4, overallDadness: 4),
      ),
    ];

    _deliveryHistory.addAll(demoDeliveries);

    final parentIndex = _parents.indexWhere((d) => d.id == '1');
    if (parentIndex != -1) {
      _parents[parentIndex] = ParentProfile(
        id: '1',
        name: appConfig.parentRole,
        badges: [
          Badge(
              type: BadgeType.speedDemon,
              earnedAt: DateTime.now().subtract(const Duration(days: 5))),
          Badge(
              type: BadgeType.fiveStarParent,
              earnedAt: DateTime.now().subtract(const Duration(days: 7))),
        ],
        deliveries: demoDeliveries.where((d) => d.dadName == appConfig.parentRole).toList(),
      );
    }

    final bobIndex = _parents.indexWhere((d) => d.id == '2');
    if (bobIndex != -1) {
      _parents[bobIndex] = ParentProfile(
        id: '2',
        name: 'Uncle Bob',
        badges: [],
        deliveries:
            demoDeliveries.where((d) => d.dadName == 'Uncle Bob').toList(),
      );
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _familySubscription?.cancel();
    _activeDeliverySubscription?.cancel();
    _historySubscription?.cancel();
    _gpsTrackingService.dispose();
    _mockGpsService.dispose();
    _notificationService.dispose();
    super.dispose();
  }
}
