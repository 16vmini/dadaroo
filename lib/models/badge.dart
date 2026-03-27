enum BadgeType {
  speedDemon,
  masterChefPicker,
  hundredDeliveries,
  nightOwl,
  weekendWarrior,
  consistentDad,
  fiveStarDad,
  varietyKing;

  String get title {
    switch (this) {
      case BadgeType.speedDemon:
        return 'Speed Demon';
      case BadgeType.masterChefPicker:
        return 'Master Chef Picker';
      case BadgeType.hundredDeliveries:
        return '100 Deliveries';
      case BadgeType.nightOwl:
        return 'Night Owl';
      case BadgeType.weekendWarrior:
        return 'Weekend Warrior';
      case BadgeType.consistentDad:
        return 'Consistent Dad';
      case BadgeType.fiveStarDad:
        return '5-Star Dad';
      case BadgeType.varietyKing:
        return 'Variety King';
    }
  }

  String get description {
    switch (this) {
      case BadgeType.speedDemon:
        return 'Delivered in under 15 minutes!';
      case BadgeType.masterChefPicker:
        return 'Always picks the best food';
      case BadgeType.hundredDeliveries:
        return 'Completed 100 food runs';
      case BadgeType.nightOwl:
        return 'Late night food hero';
      case BadgeType.weekendWarrior:
        return '10 weekend deliveries';
      case BadgeType.consistentDad:
        return '30-day delivery streak';
      case BadgeType.fiveStarDad:
        return 'Received a perfect 5-star rating';
      case BadgeType.varietyKing:
        return 'Tried every takeaway type';
    }
  }

  String get icon {
    switch (this) {
      case BadgeType.speedDemon:
        return '⚡';
      case BadgeType.masterChefPicker:
        return '👨‍🍳';
      case BadgeType.hundredDeliveries:
        return '💯';
      case BadgeType.nightOwl:
        return '🦉';
      case BadgeType.weekendWarrior:
        return '🏆';
      case BadgeType.consistentDad:
        return '📅';
      case BadgeType.fiveStarDad:
        return '⭐';
      case BadgeType.varietyKing:
        return '👑';
    }
  }
}

class Badge {
  final BadgeType type;
  final DateTime earnedAt;

  Badge({required this.type, required this.earnedAt});

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'earnedAt': earnedAt.toIso8601String(),
    };
  }

  factory Badge.fromMap(Map<String, dynamic> map) {
    return Badge(
      type: BadgeType.values.firstWhere(
        (b) => b.name == map['type'],
        orElse: () => BadgeType.speedDemon,
      ),
      earnedAt: map['earnedAt'] != null
          ? DateTime.parse(map['earnedAt'])
          : DateTime.now(),
    );
  }
}
