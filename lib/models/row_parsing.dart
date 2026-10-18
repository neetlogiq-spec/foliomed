/// Helpers for turning Supabase (PostgREST) rows into model fields.
///
/// Postgres `timestamptz` columns arrive as ISO-8601 strings; arrays
/// arrive as `List<dynamic>`. Anything malformed falls back to a safe
/// default rather than throwing inside a stream mapper.
library;

typedef DbRow = Map<String, dynamic>;

DateTime? parseTimestampOrNull(Object? value) {
  if (value is DateTime) return value.toLocal();
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

DateTime parseTimestamp(Object? value) =>
    parseTimestampOrNull(value) ?? DateTime.now();

List<String> parseStringList(Object? value) =>
    (value as List?)?.whereType<String>().toList() ?? const [];

String? toTimestampOrNull(DateTime? value) =>
    value?.toUtc().toIso8601String();

String toTimestamp(DateTime value) => value.toUtc().toIso8601String();
