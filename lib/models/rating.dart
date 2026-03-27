class Rating {
  final double speed;
  final double foodChoice;
  final double communication;
  final double overallDadness;

  Rating({
    required this.speed,
    required this.foodChoice,
    required this.communication,
    required this.overallDadness,
  });

  double get average => (speed + foodChoice + communication + overallDadness) / 4;

  Map<String, dynamic> toMap() {
    return {
      'speed': speed,
      'foodChoice': foodChoice,
      'communication': communication,
      'overallDadness': overallDadness,
    };
  }

  factory Rating.fromMap(Map<String, dynamic> map) {
    return Rating(
      speed: (map['speed'] ?? 0.0).toDouble(),
      foodChoice: (map['foodChoice'] ?? 0.0).toDouble(),
      communication: (map['communication'] ?? 0.0).toDouble(),
      overallDadness: (map['overallDadness'] ?? 0.0).toDouble(),
    );
  }
}
