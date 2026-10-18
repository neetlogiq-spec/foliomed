class MonitorAlert {
  final String id;
  final String patientId;
  final String message;
  final String severity;
  final DateTime time;

  const MonitorAlert({
    required this.id,
    required this.patientId,
    required this.message,
    required this.severity,
    required this.time,
  });
}
