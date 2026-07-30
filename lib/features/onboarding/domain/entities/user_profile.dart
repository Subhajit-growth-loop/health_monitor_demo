class UserProfile {
  const UserProfile({
    this.fullName = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.primaryDiagnosis = '',
    this.diagnosedDate = '',
    this.otherConditions = const [],
    this.currentMedications = const [],
    this.currentSupplements = const [],
  });

  final String fullName;
  final String dateOfBirth;
  final String gender;
  final String primaryDiagnosis;
  final String diagnosedDate;
  final List<String> otherConditions;
  final List<String> currentMedications;
  final List<String> currentSupplements;

  bool get isFemale => gender.trim().toLowerCase() == 'female';

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? '' : parts.first;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return [v];
      return [];
    }
    return UserProfile(
      fullName: json['fullName'] as String? ??
          json['name'] as String? ??
          json['full_name'] as String? ??
          '',
      dateOfBirth: json['dateOfBirth'] as String? ?? json['date_of_birth'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      primaryDiagnosis: json['primaryDiagnosis'] as String? ?? json['primary_diagnosis'] as String? ?? '',
      diagnosedDate: json['diagnosedDate'] as String? ?? json['diagnosed_at'] as String? ?? '',
      otherConditions: strList(json['otherConditions'] ?? json['other_conditions']),
      currentMedications: strList(json['currentMedications'] ?? json['current_medications']),
      currentSupplements: strList(json['currentSupplements'] ?? json['current_supplements']),
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'primaryDiagnosis': primaryDiagnosis,
    'diagnosedDate': diagnosedDate,
    'otherConditions': otherConditions,
    'currentMedications': currentMedications,
    'currentSupplements': currentSupplements,
  };

  UserProfile copyWith({
    String? fullName,
    String? dateOfBirth,
    String? gender,
    String? primaryDiagnosis,
    String? diagnosedDate,
    List<String>? otherConditions,
    List<String>? currentMedications,
    List<String>? currentSupplements,
  }) => UserProfile(
    fullName: fullName ?? this.fullName,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    primaryDiagnosis: primaryDiagnosis ?? this.primaryDiagnosis,
    diagnosedDate: diagnosedDate ?? this.diagnosedDate,
    otherConditions: otherConditions ?? this.otherConditions,
    currentMedications: currentMedications ?? this.currentMedications,
    currentSupplements: currentSupplements ?? this.currentSupplements,
  );
}
