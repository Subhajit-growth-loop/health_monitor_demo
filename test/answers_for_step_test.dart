import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:health_monitor_demo/features/onboarding/presentation/providers/onboarding_providers.dart';

void main() {
  // A draft with every field answered, so a step leaking another step's data is
  // immediately visible.
  const full = OnboardingDraft(
    motivations: ['recently_diagnosed'],
    supportTypes: ['accountability'],
    activityLevel: 'moderate',
    eatingRhythm: 'three_meals',
    sleepHours: 6,
    dietaryPrefs: ['mediterranean'],
    menstrualCycle: 'regular_cycles',
    symptoms: ['fatigue'],
    feeling: Feeling(sleep: 0.3, energy: 0.2, stress: 0.8, mood: 0.5),
    note: 'the AI narrative',
    connectChoice: 'connected',
    connectedSources: ['apple_health'],
    firstAction: 'walk_10_min',
  );

  group('each step sends only its own fields', () {
    test('motivation', () {
      expect(answersForStep(OnboardingStep.motivation, full).keys, [
        'motivations',
        'supportTypes',
      ]);
    });

    test('rhythm', () {
      expect(answersForStep(OnboardingStep.rhythm, full), {
        'activityLevel': 'moderate',
        'eatingRhythm': 'three_meals',
        'sleepHours': 6,
        'dietaryPrefs': ['mediterranean'],
      });
    });

    test('cycle', () {
      expect(answersForStep(OnboardingStep.cycle, full), {
        'menstrualCycle': 'regular_cycles',
      });
    });

    test('symptoms', () {
      expect(answersForStep(OnboardingStep.symptoms, full), {
        'symptoms': ['fatigue'],
      });
    });

    test('feeling sends the sliders as a nested map', () {
      expect(answersForStep(OnboardingStep.feeling, full), {
        'feeling': {'sleep': 0.3, 'energy': 0.2, 'stress': 0.8, 'mood': 0.5},
      });
    });

    test('note sends the chat narrative', () {
      expect(answersForStep(OnboardingStep.note, full), {
        'note': 'the AI narrative',
      });
    });

    test('connect', () {
      expect(answersForStep(OnboardingStep.connect, full), {
        'connectChoice': 'connected',
        'connectedSources': ['apple_health'],
      });
    });

    test('firstAction', () {
      expect(answersForStep(OnboardingStep.firstAction, full), {
        'firstAction': 'walk_10_min',
      });
    });
  });

  group('steps that own no draft fields send nothing', () {
    test('verifyInfo writes to /patient/me/details instead', () {
      expect(answersForStep(OnboardingStep.verifyInfo, full), isEmpty);
    });

    test('letter is read-only', () {
      expect(answersForStep(OnboardingStep.letter, full), isEmpty);
    });
  });

  group('no step leaks another step\'s answers', () {
    test('every key belongs to exactly one step', () {
      final owners = <String, List<OnboardingStep>>{};
      for (final step in OnboardingStep.values) {
        for (final key in answersForStep(step, full).keys) {
          owners.putIfAbsent(key, () => []).add(step);
        }
      }
      for (final entry in owners.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason: '${entry.key} is sent by ${entry.value}',
        );
      }
    });

    test('the union covers every draft field', () {
      final sent = {
        for (final step in OnboardingStep.values)
          ...answersForStep(step, full).keys,
      };
      // toJson is the full draft shape — nothing may be unreachable, or it would
      // never persist.
      expect(sent, containsAll(full.toJson().keys));
    });
  });

  group('empty answers are still sent, so a step can be cleared', () {
    test('a blank draft yields keys with empty values, not a missing key', () {
      const blank = OnboardingDraft();
      final answers = answersForStep(OnboardingStep.symptoms, blank);
      expect(answers.containsKey('symptoms'), isTrue);
      expect(answers['symptoms'], isEmpty);
    });

    test('activity level defaults to low rather than null', () {
      const blank = OnboardingDraft();
      expect(
        answersForStep(OnboardingStep.rhythm, blank)['activityLevel'],
        'low',
      );
    });
  });
}