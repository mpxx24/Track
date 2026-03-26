class PlannedRoute {
  final String id;
  final String name;
  final double distanceKm;
  final DateTime createdAt;
  final int waypointCount;

  const PlannedRoute({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.createdAt,
    required this.waypointCount,
  });

  factory PlannedRoute.fromJson(Map<String, dynamic> json) {
    return PlannedRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      waypointCount: json['waypointCount'] as int,
    );
  }
}
