/// The member profile "shared by the care team", shown and inline-edited on the
/// Verify-your-information step. Fields are stored as plain strings so they can
/// round-trip through the REST API unchanged.
class UserProfile {
  const UserProfile({
    this.fullName = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.primaryDiagnosis = '',
    this.diagnosedDate = '',
    this.otherConditions = '',
    this.currentMedications = '',
  });

  final String fullName;

  /// ISO date, `yyyy-MM-dd`.
  final String dateOfBirth;
  final String gender;
  final String primaryDiagnosis;

  /// `yyyy-MM`.
  final String diagnosedDate;
  final String otherConditions;
  final String currentMedications;

  bool get isFemale => gender.trim().toLowerCase() == 'female';

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? '' : parts.first;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    fullName: json['fullName'] as String? ?? '',
    dateOfBirth: json['dateOfBirth'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    primaryDiagnosis: json['primaryDiagnosis'] as String? ?? '',
    diagnosedDate: json['diagnosedDate'] as String? ?? '',
    otherConditions: json['otherConditions'] as String? ?? '',
    currentMedications: json['currentMedications'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'primaryDiagnosis': primaryDiagnosis,
    'diagnosedDate': diagnosedDate,
    'otherConditions': otherConditions,
    'currentMedications': currentMedications,
  };

  UserProfile copyWith({
    String? fullName,
    String? dateOfBirth,
    String? gender,
    String? primaryDiagnosis,
    String? diagnosedDate,
    String? otherConditions,
    String? currentMedications,
  }) => UserProfile(
    fullName: fullName ?? this.fullName,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    primaryDiagnosis: primaryDiagnosis ?? this.primaryDiagnosis,
    diagnosedDate: diagnosedDate ?? this.diagnosedDate,
    otherConditions: otherConditions ?? this.otherConditions,
    currentMedications: currentMedications ?? this.currentMedications,
  );
}
