class PaidSlotModel {
  final String id;
  final DateTime startsAt;
  final DateTime expiresAt;
  final bool isExpiringSoon;

  const PaidSlotModel({
    required this.id,
    required this.startsAt,
    required this.expiresAt,
    required this.isExpiringSoon,
  });

  factory PaidSlotModel.fromJson(Map<String, dynamic> json) {
    return PaidSlotModel(
      id: json['id'] as String? ?? '',
      startsAt:
          DateTime.tryParse(json['startsAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
      isExpiringSoon: json['isExpiringSoon'] as bool? ?? false,
    );
  }
}

class ActivePetSummaryItem {
  final String id;
  final String name;
  final String? animalType;
  final String? breed;
  final String? imageUrl;
  final String? profilePictureUrl;
  final DateTime? activatedAt;

  const ActivePetSummaryItem({
    required this.id,
    required this.name,
    this.animalType,
    this.breed,
    this.imageUrl,
    this.profilePictureUrl,
    this.activatedAt,
  });

  factory ActivePetSummaryItem.fromJson(Map<String, dynamic> json) {
    return ActivePetSummaryItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      animalType: json['animalType'] as String?,
      breed: json['breed'] as String?,
      imageUrl: json['imageUrl'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      activatedAt: json['activatedAt'] != null
          ? DateTime.tryParse(json['activatedAt'].toString())
          : null,
    );
  }
}

class ActivationSummaryModel {
  final int allowedActive;
  final int activeCount;
  final int freeSlots;
  final int paidSlotsCount;
  final int maxPaidSlots;
  final int availableSlotsToPurchase;
  final List<PaidSlotModel> paidSlots;
  final List<ActivePetSummaryItem> activePets;
  final double pricePerSlotNpr;
  final int slotDurationDays;
  final String? expiringSoonWarning;
  final String? recentDowngradeMessage;

  const ActivationSummaryModel({
    required this.allowedActive,
    required this.activeCount,
    required this.freeSlots,
    required this.paidSlotsCount,
    required this.maxPaidSlots,
    required this.availableSlotsToPurchase,
    required this.paidSlots,
    required this.activePets,
    required this.pricePerSlotNpr,
    required this.slotDurationDays,
    this.expiringSoonWarning,
    this.recentDowngradeMessage,
  });

  factory ActivationSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawPaidSlots = json['paidSlots'] as List<dynamic>? ?? [];
    final rawActivePets = json['activePets'] as List<dynamic>? ?? [];
    return ActivationSummaryModel(
      allowedActive: json['allowedActive'] as int? ?? 1,
      activeCount: json['activeCount'] as int? ?? 0,
      freeSlots: json['freeSlots'] as int? ?? 1,
      paidSlotsCount: json['paidSlotsCount'] as int? ?? 0,
      maxPaidSlots: json['maxPaidSlots'] as int? ?? 1,
      availableSlotsToPurchase: json['availableSlotsToPurchase'] as int? ?? 1,
      paidSlots: rawPaidSlots
          .whereType<Map<String, dynamic>>()
          .map((s) => PaidSlotModel.fromJson(s))
          .toList(),
      activePets: rawActivePets
          .whereType<Map<String, dynamic>>()
          .map((p) => ActivePetSummaryItem.fromJson(p))
          .toList(),
      pricePerSlotNpr: (json['pricePerSlotNpr'] as num?)?.toDouble() ?? 100.0,
      slotDurationDays: json['slotDurationDays'] as int? ?? 30,
      expiringSoonWarning: json['expiringSoonWarning'] as String?,
      recentDowngradeMessage: json['recentDowngradeMessage'] as String?,
    );
  }
}
