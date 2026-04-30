import 'package:flutter_test/flutter_test.dart';

import 'package:bizimatch_flutter/models/community_plan_model.dart';
import 'package:bizimatch_flutter/models/community_plan_type.dart';

void main() {
  group('Community plan types', () {
    test('parses raw values into enum values', () {
      expect(communityPlanTypeFromValue('canas'), CommunityPlanType.canas);
      expect(communityPlanTypeFromValue('deporte'), CommunityPlanType.deporte);
      expect(communityPlanTypeFromValue('turismo'), CommunityPlanType.turismo);
      expect(communityPlanTypeFromValue('unknown'), CommunityPlanType.otro);
    });

    test('serializes type to Firestore value', () {
      final plan = CommunityPlan(
        id: 'plan-1',
        titulo: 'Cañas en el centro',
        descripcion: 'Plan informal',
        creadorId: 'uid-1',
        creadorNombre: 'Ana',
        ciudad: 'Madrid',
        fechaHora: DateTime(2026, 4, 30, 20, 0),
        tipoPlan: CommunityPlanType.canas,
        asistentesIds: ['uid-1'],
      );

      final map = plan.toMap();
      expect(map['tipo_plan'], 'canas');
      expect(plan.isAttending('uid-1'), isTrue);
      expect(plan.isAttending('uid-2'), isFalse);
    });
  });
}
