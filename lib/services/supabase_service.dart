import 'package:supabase_flutter/supabase_flutter.dart';

/// Shorthand for the app-wide Supabase client. Initialised in `main()`.
SupabaseClient get supabase => Supabase.instance.client;

/// Table and RPC names, kept in one place so a rename is a one-line change.
class Tables {
  Tables._();
  static const String profiles = 'profiles';
  static const String wards = 'wards';
  static const String patients = 'patients';
  static const String notes = 'notes';
  static const String noteComments = 'note_comments';
  static const String monitorVitals = 'monitor_vitals';
  static const String monitorVitalsHistory = 'monitor_vitals_history';
}

class Buckets {
  Buckets._();
  static const String monitorSnapshots = 'monitor-snapshots';
}
