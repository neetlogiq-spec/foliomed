class AppConstants {
  static const String appName = 'FolioMed';
  static const String appVersion = '1.0.0';

  static const String usersCollection = 'users';
  static const String patientsCollection = 'patients';
  static const String notesCollection = 'notes';
  static const String wardsCollection = 'wards';

  static const List<String> noteCategories = [
    'Medication',
    'Procedure',
    'Observation',
    'Alert',
    'General',
  ];

  static const List<String> notePriorities = [
    'Low',
    'Normal',
    'Urgent',
  ];
}
