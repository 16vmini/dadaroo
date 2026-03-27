import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dadaroo/models/takeaway_type.dart';
import 'package:dadaroo/models/delivery.dart';
import 'package:dadaroo/models/rating.dart';
import 'package:dadaroo/models/badge.dart';
import 'package:dadaroo/models/dad.dart';
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
  LatLng? _currentDadLocation;
  bool _dadIsClose = false;
  bool _showCelebration = false;
  bool _notifiedClose = false;

  // Family data
  List<Dad> _dads = [];
  String _currentDadId = '';
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
  LatLng? get currentDadLocation => _currentDadLocation;
  bool get dadIsClose => _dadIsClose;
  bool get showCelebration => _showCelebration;
  bool get isDeliveryActive =>
      _activeDelivery != null && _activeDelivery!.isActive;
  List<Delivery> get deliveryHistory => List.unmodifiable(_deliveryHistory);
  List<Dad> get dads => List.unmodifiable(_dads);
  Dad get currentDad {
    if (_dads.isEmpty) {
      return Dad(id: '', name: _userProfile?.name ?? 'Dad', badges: [], deliveries: []);
    }
    return _dads.firstWhere(
      (d) => d.id == _currentDadId,
      orElse: () => _dads.first,
    );
  }

  MockGpsService get gpsService => _mockGpsService;

  Duration get etaRemaining {
    // If we have real GPS data from Firestore, calculate real ETA
    if (_activeDelivery != null &&
        _activeDelivery!.currentLatitude != null &&
        _activeDelivery!.currentLongitude != null) {
      // TODO: Use actual home coordinates from family group settings
      return GpsTrackingService.calculateEtaFromPosition(
        latitude: _activeDelivery!.currentLatitude!,
        longitude: _activeDelivery!.currentLongitude!,
        homeLatitude: 51.5150,
        homeLongitude: -0.1100,
      );
    }
    // Fallback to mock GPS
    return _mockGpsService.estimatedTimeRemaining;
  }

  double get deliveryProgress {
    if (_activeDelivery != null &&
        _activeDelivery!.currentLatitude != null) {
      // Calculate progress based on distance
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
        _currentDadId = profile.uid;
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
        await _loadFamilyDads(group);
        _listenToActiveDelivery(group.id);
        _listenToHistory(group.id);
      }
      notifyListeners();
    });
  }

  Future<void> _loadFamilyDads(FamilyGroup group) async {
    final members = await _firestoreService.getFamilyMembers(group.dadIds);
    final dadList = <Dad>[];
    for (final member in members) {
      final badges = await _firestoreService.getUserBadges(member.uid);
      final deliveries = _deliveryHistory
          .where((d) => d.dadUid == member.uid)
          .toList();
      dadList.add(Dad(
        id: member.uid,
        name: member.name,
        badges: badges,
        deliveries: deliveries,
      ));
    }
    _dads = dadList;
    if (_dads.isNotEmpty && !_dads.any((d) => d.id == _currentDadId)) {
      _currentDadId = _dads.first.id;
    }
  }

  void _listenToActiveDelivery(String groupId) {
    _activeDeliverySubscription?.cancel();
    _activeDeliverySubscription =
        _firestoreService.activeDeliveryStream(groupId).listen((delivery) {
      final wasActive = _activeDelivery?.isActive ?? false;
      _activeDelivery = delivery;

      if (delivery != null) {
        // Update dad location from Firestore
        if (delivery.currentLatitude != null &&
            delivery.currentLongitude != null) {
          _currentDadLocation = LatLng(
            delivery.currentLatitude!,
            delivery.currentLongitude!,
          );

          // Check if close
          final eta = etaRemaining;
          if (eta.inSeconds <= 120 && !_dadIsClose) {
            _dadIsClose = true;
            if (!_notifiedClose && _familyGroup != null) {
              _notifiedClose = true;
              _notificationService.notifyDadIsClose(
                familyGroupId: _familyGroup!.id,
                dadName: delivery.dadName,
              );
            }
          }
        }
      } else if (wasActive) {
        // Delivery just completed
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
      // Refresh dad profiles with updated deliveries
      if (_familyGroup != null) {
        _loadFamilyDads(_familyGroup!);
      }
      notifyListeners();
    });
  }

  void _clearUserData() {
    _userProfile = null;
    _familyGroup = null;
    _activeDelivery = null;
    _currentDadLocation = null;
    _dadIsClose = false;
    _showCelebration = false;
    _dads = [];
    _deliveryHistory = [];
    _profileSubscription?.cancel();
    _familySubscription?.cancel();
    _activeDeliverySubscription?.cancel();
    _historySubscription?.cancel();
  }

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

  // ── Delivery & Takeaway Methods ──

  void setSelectedTakeaway(TakeawayType type) {
    _selectedTakeaway = type;
    notifyListeners();
  }

  void setCustomTakeawayName(String name) {
    _customTakeawayName = name;
    notifyListeners();
  }

  void setCurrentDad(String dadId) {
    _currentDadId = dadId;
    notifyListeners();
  }

  Future<void> startDelivery() async {
    final delivery = Delivery(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dadName: _userProfile?.name ?? currentDad.name,
      dadUid: _userProfile?.uid,
      familyGroupId: _familyGroup?.id,
      takeawayType: _selectedTakeaway,
      customTakeawayName:
          _selectedTakeaway == TakeawayType.custom ? _customTakeawayName : null,
      startTime: DateTime.now(),
      estimatedDuration: const Duration(minutes: 10),
      isActive: true,
    );

    _activeDelivery = delivery;
    _dadIsClose = false;
    _showCelebration = false;
    _notifiedClose = false;

    // Save to Firestore if connected
    if (_familyGroup != null) {
      await _firestoreService.createDelivery(delivery);

      // Send notification
      await _notificationService.notifyDeliveryStarted(
        familyGroupId: _familyGroup!.id,
        dadName: delivery.dadName,
        takeawayName: delivery.takeawayDisplayName,
      );

      // Start real GPS tracking
      final hasPermission = await _gpsTrackingService.ensurePermissions();
      if (hasPermission) {
        await _gpsTrackingService.startTracking(
          deliveryId: delivery.id,
          homeLatitude: 51.5150, // TODO: Use actual home coordinates
          homeLongitude: -0.1100,
          onUpdate: (position, eta) {
            _currentDadLocation = LatLng(position.latitude, position.longitude);
            if (eta != null && eta.inSeconds <= 120 && !_dadIsClose) {
              _dadIsClose = true;
            }
            notifyListeners();
          },
        );
      } else {
        // Fall back to mock GPS
        _startMockTracking();
      }
    } else {
      // No family group - use mock GPS
      _startMockTracking();
    }

    notifyListeners();
  }

  void _startMockTracking() {
    _mockGpsService.startTracking((location) {
      _currentDadLocation = location;
      final remaining = _mockGpsService.estimatedTimeRemaining;

      if (remaining.inSeconds <= 120 && !_dadIsClose) {
        _dadIsClose = true;
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
    );
    _showCelebration = true;

    // Update Firestore
    if (_familyGroup != null) {
      await _firestoreService.completeDelivery(_activeDelivery!.id);
    }

    _gpsTrackingService.stopTracking();
    notifyListeners();
  }

  Future<void> rateDelivery(Rating rating) async {
    if (_activeDelivery == null) return;

    final ratedDelivery = _activeDelivery!.copyWith(rating: rating);

    // Save to Firestore
    if (_familyGroup != null) {
      await _firestoreService.rateDelivery(
        deliveryId: ratedDelivery.id,
        rating: rating,
      );

      // Notify Dad
      if (ratedDelivery.dadUid != null) {
        await _notificationService.notifyRatingReceived(
          dadUid: ratedDelivery.dadUid!,
          averageRating: rating.average,
        );
      }

      // Check badges
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

        // Update user stats
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
      // Offline mode - just add to local history
      _deliveryHistory.insert(0, ratedDelivery);

      final dadIndex = _dads.indexWhere((d) => d.id == _currentDadId);
      if (dadIndex != -1) {
        final dad = _dads[dadIndex];
        final updatedDeliveries = [...dad.deliveries, ratedDelivery];
        final updatedBadges = _checkBadges(updatedDeliveries, dad.badges);
        _dads[dadIndex] = Dad(
          id: dad.id,
          name: dad.name,
          badges: updatedBadges,
          deliveries: updatedDeliveries,
        );
      }
    }

    _activeDelivery = null;
    _currentDadLocation = null;
    _dadIsClose = false;
    _showCelebration = false;
    _mockGpsService.stopTracking();

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
    _currentDadLocation = null;
    _dadIsClose = false;
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
    _currentDadLocation = null;
    _dadIsClose = false;
    _showCelebration = false;
    _mockGpsService.stopTracking();
    _gpsTrackingService.stopTracking();
    notifyListeners();
  }

  void simulateArrival() {
    if (_activeDelivery == null) return;
    _mockGpsService.stopTracking();
    _gpsTrackingService.stopTracking();
    _dadIsClose = true;
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

    if (!existingTypes.contains(BadgeType.fiveStarDad)) {
      if (deliveries
          .any((d) => d.rating != null && d.rating!.average == 5.0)) {
        badges.add(Badge(type: BadgeType.fiveStarDad, earnedAt: now));
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

    if (!existingTypes.contains(BadgeType.varietyKing)) {
      final types = deliveries.map((d) => d.takeawayType).toSet();
      final mainTypes = TakeawayType.values
          .where((t) => t != TakeawayType.other && t != TakeawayType.custom)
          .toSet();
      if (types.containsAll(mainTypes)) {
        badges.add(Badge(type: BadgeType.varietyKing, earnedAt: now));
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

    _dads = [
      Dad(id: '1', name: 'Dad', badges: [], deliveries: []),
      Dad(id: '2', name: 'Uncle Bob', badges: [], deliveries: []),
      Dad(id: '3', name: 'Grandad', badges: [], deliveries: []),
    ];
    _currentDadId = '1';

    final demoDeliveries = [
      Delivery(
        id: 'demo1',
        dadName: 'Dad',
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
        dadName: 'Dad',
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
        dadName: 'Dad',
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

    final dadIndex = _dads.indexWhere((d) => d.id == '1');
    if (dadIndex != -1) {
      _dads[dadIndex] = Dad(
        id: '1',
        name: 'Dad',
        badges: [
          Badge(
              type: BadgeType.speedDemon,
              earnedAt: DateTime.now().subtract(const Duration(days: 5))),
          Badge(
              type: BadgeType.fiveStarDad,
              earnedAt: DateTime.now().subtract(const Duration(days: 7))),
        ],
        deliveries: demoDeliveries.where((d) => d.dadName == 'Dad').toList(),
      );
    }

    final bobIndex = _dads.indexWhere((d) => d.id == '2');
    if (bobIndex != -1) {
      _dads[bobIndex] = Dad(
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
