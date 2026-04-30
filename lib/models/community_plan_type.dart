import 'package:flutter/material.dart';

enum CommunityPlanType { canas, deporte, turismo, otro }

extension CommunityPlanTypeX on CommunityPlanType {
  String get value => switch (this) {
    CommunityPlanType.canas => 'canas',
    CommunityPlanType.deporte => 'deporte',
    CommunityPlanType.turismo => 'turismo',
    CommunityPlanType.otro => 'otro',
  };

  String get label => switch (this) {
    CommunityPlanType.canas => 'Cañas',
    CommunityPlanType.deporte => 'Deporte',
    CommunityPlanType.turismo => 'Turismo',
    CommunityPlanType.otro => 'Otro',
  };

  IconData get icon => switch (this) {
    CommunityPlanType.canas => Icons.local_bar,
    CommunityPlanType.deporte => Icons.directions_run,
    CommunityPlanType.turismo => Icons.map,
    CommunityPlanType.otro => Icons.celebration,
  };
}

CommunityPlanType communityPlanTypeFromValue(String raw) {
  return CommunityPlanType.values.firstWhere(
    (type) => type.value == raw,
    orElse: () => CommunityPlanType.otro,
  );
}
