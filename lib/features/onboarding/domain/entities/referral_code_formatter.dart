import 'package:flutter/services.dart';

/// Formats a referral code as the user types: `NEU-BUJL`.
///
/// - Upper-cases everything, so `neu-bujl` becomes `NEU-BUJL`.
/// - Inserts the hyphen automatically after the 3-character prefix — the user
///   never types it, and typing one is harmless because separators are stripped
///   before reformatting.
/// - Applies on paste too, since [TextInputFormatter] runs on every edit
///   regardless of source: pasting `neubujl` yields `NEU-BUJL`.
/// - Drops anything that isn't a letter or digit (spaces, stray punctuation),
///   which is what makes a pasted code with odd whitespace still work.
///
/// The trailing hyphen appears as soon as the prefix is complete, except while
/// deleting — otherwise backspacing over it would immediately re-add it and the
/// caret would appear stuck.
class ReferralCodeFormatter extends TextInputFormatter {
  const ReferralCodeFormatter({this.prefixLength = 3, this.maxRawLength = 7});

  /// Characters before the hyphen (`NEU`).
  final int prefixLength;

  /// Total letters/digits allowed, hyphen excluded (`NEU` + `BUJL` = 7).
  final int maxRawLength;

  static final _notAlphanumeric = RegExp(r'[^A-Z0-9]');

  /// The bare code, upper-cased with separators removed.
  String _raw(String text) =>
      text.toUpperCase().replaceAll(_notAlphanumeric, '');

  String _format(String raw, {required bool withTrailingHyphen}) {
    if (raw.length < prefixLength) return raw;
    final prefix = raw.substring(0, prefixLength);
    final rest = raw.substring(prefixLength);
    if (rest.isEmpty) return withTrailingHyphen ? '$prefix-' : prefix;
    return '$prefix-$rest';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final deleting = newValue.text.length < oldValue.text.length;

    var raw = _raw(newValue.text);
    if (raw.length > maxRawLength) raw = raw.substring(0, maxRawLength);

    final text = _format(raw, withTrailingHyphen: !deleting);

    // Keep the caret after the same number of real characters it was after
    // before reformatting, so editing mid-string doesn't jump to the end.
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final rawBeforeCursor = _raw(newValue.text.substring(0, cursor)).length;

    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < rawBeforeCursor) {
      if (text[offset] != '-') seen++;
      offset++;
    }
    // Sitting exactly on the hyphen means the prefix was just completed — step
    // past it so the next keystroke lands in the suffix.
    if (offset < text.length && text[offset] == '-') offset++;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
