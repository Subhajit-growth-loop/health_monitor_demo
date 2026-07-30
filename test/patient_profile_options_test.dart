import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/features/onboarding/domain/entities/patient_profile_options.dart';

void main() {
  group('option values match the backend enums', () {
    test('primary_diagnosis', () {
      expect(PatientProfileOptions.primaryDiagnosis.map((o) => o.$1), [
        'masld', 'mash', 'prediabetes', 'type_2_diabetes', 'obesity',
        'metabolic_syndrome', 'pcos', 'hypertension', 'high_cholesterol',
        'none',
      ]);
    });

    test('other_conditions', () {
      expect(PatientProfileOptions.otherConditions.map((o) => o.$1), [
        'prediabetes', 'type_2_diabetes', 'hypertension', 'high_cholesterol',
        'obesity', 'pcos', 'sleep_apnea', 'hypothyroidism', 'depression',
        'anxiety', 'none',
      ]);
    });

    test('current_medications', () {
      expect(PatientProfileOptions.medications.map((o) => o.$1), [
        'metformin', 'ozempic', 'mounjaro', 'wegovy', 'jardiance', 'insulin',
        'statin', 'blood_pressure_medication', 'none', 'other',
      ]);
    });

    test('current_supplements', () {
      expect(PatientProfileOptions.supplements.map((o) => o.$1), [
        'vitamin_d', 'vitamin_b12', 'omega_3', 'magnesium', 'probiotics',
        'milk_thistle', 'turmeric', 'multivitamin', 'none', 'other',
      ]);
    });

    test('only medications and supplements offer an "other" member', () {
      expect(PatientProfileOptions.valuesOf(PatientProfileOptions.medications), contains('other'));
      expect(PatientProfileOptions.valuesOf(PatientProfileOptions.supplements), contains('other'));
      expect(PatientProfileOptions.valuesOf(PatientProfileOptions.otherConditions), isNot(contains('other')));
      expect(PatientProfileOptions.valuesOf(PatientProfileOptions.primaryDiagnosis), isNot(contains('other')));
    });
  });

  group('forApi keeps valid selections untouched', () {
    test('recognised values pass through in order', () {
      expect(
        PatientProfileOptions.forApi(['vitamin_d', 'omega_3'], PatientProfileOptions.supplements),
        ['vitamin_d', 'omega_3'],
      );
    });

    test('an empty selection stays empty', () {
      expect(PatientProfileOptions.forApi([], PatientProfileOptions.supplements), isEmpty);
    });

    test('every listed value except `other` survives its own list', () {
      for (final (value, _) in PatientProfileOptions.supplements) {
        final sent = PatientProfileOptions.forApi(
          [value],
          PatientProfileOptions.supplements,
        );
        // `other` is a UI affordance, never a submitted answer.
        expect(sent, value == 'other' ? isEmpty : [value]);
      }
    });
  });

  group('medications and supplements take the typed name', () {
    test('a typed name is sent as typed', () {
      // The server: "'other' is not an answer on its own — send the name of what
      // the patient takes instead."
      expect(
        PatientProfileOptions.forApi(
          ['vitamin_d', 'Ashwagandha 500mg'],
          PatientProfileOptions.supplements,
        ),
        ['vitamin_d', 'Ashwagandha 500mg'],
      );
    });

    test('bare `other` is dropped, keeping the rest', () {
      expect(
        PatientProfileOptions.forApi(
          ['vitamin_d', 'other'],
          PatientProfileOptions.supplements,
        ),
        ['vitamin_d'],
      );
    });

    test('`other` alongside its typed name leaves only the name', () {
      expect(
        PatientProfileOptions.forApi(
          ['other', 'Ashwagandha'],
          PatientProfileOptions.supplements,
        ),
        ['Ashwagandha'],
      );
    });

    test('`other` on its own sends nothing at all', () {
      expect(
        PatientProfileOptions.forApi(['other'], PatientProfileOptions.supplements),
        isEmpty,
      );
    });

    test('several typed names are all kept', () {
      expect(
        PatientProfileOptions.forApi(
          ['Ashwagandha', 'Creatine'],
          PatientProfileOptions.supplements,
        ),
        ['Ashwagandha', 'Creatine'],
      );
    });

    test('duplicates are dropped', () {
      expect(
        PatientProfileOptions.forApi(
          ['Creatine', 'Creatine'],
          PatientProfileOptions.supplements,
        ),
        ['Creatine'],
      );
    });

    test('medications behave the same way', () {
      expect(
        PatientProfileOptions.forApi(
          ['metformin', 'other', 'Some Brand 10mg'],
          PatientProfileOptions.medications,
        ),
        ['metformin', 'Some Brand 10mg'],
      );
    });
  });

  group('free text is dropped where there is no "other" member', () {
    test('unrecognised conditions are removed, not coerced', () {
      // Coercing to `other` here would just be a different invalid enum.
      expect(
        PatientProfileOptions.forApi(['pcos', 'Metformin 500mg'], PatientProfileOptions.otherConditions),
        ['pcos'],
      );
    });

    test('an all-free-text selection collapses to empty', () {
      expect(PatientProfileOptions.forApi(['Metformin 500mg'], PatientProfileOptions.otherConditions), isEmpty);
    });

    test('the result never contains a value outside the enum', () {
      final sent = PatientProfileOptions.forApi(
        ['anxiety', 'made up', 'also made up'],
        PatientProfileOptions.otherConditions,
      );
      expect(sent.every(PatientProfileOptions.valuesOf(PatientProfileOptions.otherConditions).contains), isTrue);
    });
  });

  group('none is exclusive', () {
    test('the exact 422 case: none combined with other values', () {
      expect(
        PatientProfileOptions.forApi(['pcos', 'anxiety', 'none'], PatientProfileOptions.otherConditions),
        ['none'],
      );
    });

    test('none wins regardless of position', () {
      expect(
        PatientProfileOptions.forApi(['none', 'pcos'], PatientProfileOptions.otherConditions),
        ['none'],
      );
    });

    test('none plus free text still collapses to none alone', () {
      expect(
        PatientProfileOptions.forApi(['none', 'Ashwagandha'], PatientProfileOptions.supplements),
        ['none'],
      );
    });

    test('none plus a bare other collapses to none alone', () {
      expect(
        PatientProfileOptions.forApi(['none', 'other'], PatientProfileOptions.supplements),
        ['none'],
      );
    });

    test('none on its own is unchanged', () {
      expect(PatientProfileOptions.forApi(['none'], PatientProfileOptions.supplements), ['none']);
    });
  });
}