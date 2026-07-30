/// A fact the AI extracted from the patient's answers, always carrying the
/// patient's verbatim words in [sourceQuote].
class ExtractedFact {
  const ExtractedFact({
    required this.category,
    required this.value,
    required this.sourceQuote,
  });

  /// One of: barrier, lifestyle_constraint, prior_attempt, psychosocial,
  /// symptom_detail, motivation, support_system, preference, care_team_flag.
  /// Kept as a String rather than an enum so a new server-side category can't
  /// crash the parse.
  final String category;
  final String value;
  final String sourceQuote;

  factory ExtractedFact.fromJson(Map<String, dynamic> json) => ExtractedFact(
    category: json['category'] as String? ?? '',
    value: json['value'] as String? ?? '',
    sourceQuote: json['source_quote'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'category': category,
    'value': value,
    'source_quote': sourceQuote,
  };
}

/// The consolidated patient summary returned when the conversation ends.
class PatientSummary {
  const PatientSummary({this.facts = const [], this.narrative = ''});

  final List<ExtractedFact> facts;

  /// 3-5 sentence context summary for the care team and downstream AI.
  final String narrative;

  factory PatientSummary.fromJson(Map<String, dynamic> json) => PatientSummary(
    facts: (json['facts'] as List? ?? const [])
        .whereType<Map>()
        .map((f) => ExtractedFact.fromJson(Map<String, dynamic>.from(f)))
        .toList(),
    narrative: json['narrative'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'facts': facts.map((f) => f.toJson()).toList(),
    'narrative': narrative,
  };
}

/// Unified response for `/onboarding-chat/start`, `/turn` and `/skip`.
///
/// While [done] is false, render [acknowledgment] (when present) followed by
/// [question]. Once [done] is true the conversation is over, [question] is null
/// and [summary] is populated.
class OnboardingChatResponse {
  const OnboardingChatResponse({
    required this.sessionId,
    required this.done,
    this.acknowledgment,
    this.question,
    this.summary,
  });

  final String sessionId;
  final bool done;

  /// Warm one-sentence reply to the previous answer. Null on `/start`.
  final String? acknowledgment;

  /// The next question to show. Null when [done].
  final String? question;

  /// Populated only when [done].
  final PatientSummary? summary;

  factory OnboardingChatResponse.fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      if (v is! String) return null;
      final trimmed = v.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final summary = json['summary'];
    return OnboardingChatResponse(
      sessionId: json['session_id'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      acknowledgment: text(json['acknowledgment']),
      question: text(json['question']),
      summary: summary is Map
          ? PatientSummary.fromJson(Map<String, dynamic>.from(summary))
          : null,
    );
  }
}

/// One rendered bubble in the conversation.
class ChatMessage {
  const ChatMessage({required this.text, required this.fromPatient});

  const ChatMessage.coach(String text) : this(text: text, fromPatient: false);
  const ChatMessage.patient(String text) : this(text: text, fromPatient: true);

  final String text;
  final bool fromPatient;
}