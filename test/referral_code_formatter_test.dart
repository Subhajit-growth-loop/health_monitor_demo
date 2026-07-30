import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/features/onboarding/domain/entities/referral_code_formatter.dart';

void main() {
  const formatter = ReferralCodeFormatter();

  /// Runs the formatter as the field would, with the caret at the end.
  TextEditingValue apply(String before, String after) => formatter.formatEditUpdate(
        TextEditingValue(
          text: before,
          selection: TextSelection.collapsed(offset: before.length),
        ),
        TextEditingValue(
          text: after,
          selection: TextSelection.collapsed(offset: after.length),
        ),
      );

  /// Types [input] one character at a time, as a real user would.
  TextEditingValue type(String input) {
    var value = const TextEditingValue();
    for (final ch in input.split('')) {
      final next = value.text + ch;
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        ),
      );
    }
    return value;
  }

  group('upper-cases everything', () {
    test('lowercase typing', () {
      expect(type('neubujl').text, 'NEU-BUJL');
    });

    test('mixed case', () {
      expect(type('NeUbUjL').text, 'NEU-BUJL');
    });
  });

  group('inserts the hyphen after the 3-character prefix', () {
    test('appears as soon as the prefix is complete', () {
      expect(type('NEU').text, 'NEU-');
    });

    test('is not duplicated when the user types one', () {
      expect(type('NEU-BUJL').text, 'NEU-BUJL');
    });

    test('the full code types cleanly', () {
      expect(type('NEUBUJL').text, 'NEU-BUJL');
    });

    test('nothing is added before the prefix is complete', () {
      expect(type('NE').text, 'NE');
    });
  });

  group('paste', () {
    test('an unformatted code gains the hyphen', () {
      expect(apply('', 'neubujl').text, 'NEU-BUJL');
    });

    test('an already-formatted code is unchanged', () {
      expect(apply('', 'NEU-BUJL').text, 'NEU-BUJL');
    });

    test('surrounding whitespace is stripped', () {
      expect(apply('', '  neu bujl  ').text, 'NEU-BUJL');
    });

    test('stray separators are normalised', () {
      expect(apply('', 'neu_bujl').text, 'NEU-BUJL');
      expect(apply('', 'NEU--BUJL').text, 'NEU-BUJL');
    });

    test('digits are kept — codes are alphanumeric', () {
      expect(apply('', 'neu7f2a').text, 'NEU-7F2A');
    });

    test('overlong input is truncated to the code length', () {
      expect(apply('', 'NEUBUJLEXTRA').text, 'NEU-BUJL');
    });
  });

  group('deleting is not fought by the formatter', () {
    test('backspacing the auto hyphen removes it instead of re-adding it', () {
      // Without the deleting check the hyphen would come straight back and the
      // caret would appear stuck at "NEU-".
      expect(apply('NEU-', 'NEU').text, 'NEU');
    });

    test('backspacing into the suffix keeps the hyphen', () {
      expect(apply('NEU-BU', 'NEU-B').text, 'NEU-B');
    });

    test('clearing the field leaves it empty', () {
      expect(apply('NEU-BUJL', '').text, '');
    });
  });

  group('caret position', () {
    test('lands after the hyphen once the prefix completes', () {
      final value = type('NEU');
      expect(value.text, 'NEU-');
      expect(value.selection.baseOffset, 4);
    });

    test('sits at the end of a complete code', () {
      final value = type('NEUBUJL');
      expect(value.selection.baseOffset, value.text.length);
      expect(value.selection.baseOffset, 8);
    });

    test('is never past the end of the text', () {
      for (final input in ['N', 'NE', 'NEU', 'NEUB', 'NEUBUJL']) {
        final value = type(input);
        expect(
          value.selection.baseOffset,
          lessThanOrEqualTo(value.text.length),
          reason: input,
        );
      }
    });
  });

  test('the verified format matches the documented code shape', () {
    expect(type('neubujl').text, matches(RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]{4}$')));
  });
}
