class MonitorComment {
  final String id;
  final String patientId;
  final String text;
  final String author;
  final DateTime time;
  final String type; // 'order' | 'note'

  const MonitorComment({
    required this.id,
    required this.patientId,
    required this.text,
    required this.author,
    required this.time,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
    'patientId': patientId,
    'text': text,
    'author': author,
    'time': time.toIso8601String(),
    'type': type,
  };

  factory MonitorComment.fromMap(String id, Map<String, dynamic> m) => MonitorComment(
    id: id,
    patientId: m['patientId'] as String,
    text: m['text'] as String,
    author: m['author'] as String,
    time: DateTime.parse(m['time'] as String),
    type: m['type'] as String? ?? 'note',
  );
}
