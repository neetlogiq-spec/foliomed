import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/patient_infusion.dart';
import '../models/ward_drug_setting.dart';
import 'supabase_service.dart';

/// Ward drug settings and sign-off, and the infusions running on patients.
/// Every write goes through an RPC (see migration 20261101000000_drugs).
class DrugService {
  DrugService({SupabaseClient? client}) : _client = client ?? supabase;
  final SupabaseClient _client;

  /// Live: the ward's settings by drug key.
  Stream<Map<String, WardDrugSetting>> watchWard(String wardId) => _client
      .from('ward_drug_settings')
      .stream(primaryKey: ['ward_id', 'drug_key'])
      .eq('ward_id', wardId)
      .map((rows) => {for (final r in rows.map(WardDrugSetting.fromRow)) r.drugKey: r});

  /// Owner only. Null vial/mixture = FolioMed's default.
  Future<void> setWardDrug({
    required String wardId,
    required String drugKey,
    double? vialPerMl,
    double? mixAt1MlH,
    bool hidden = false,
    String? note,
  }) => _client.rpc(
    'set_ward_drug',
    params: {
      'p_ward': wardId,
      'p_key': drugKey,
      'p_vial': vialPerMl,
      'p_mix': mixAt1MlH,
      'p_hidden': hidden,
      'p_note': note,
    },
  );

  /// Signs off what the app showed ([signature]); null withdraws it.
  Future<void> checkWardDrug(String wardId, String drugKey, String? signature) =>
      _client.rpc('check_ward_drug', params: {'p_ward': wardId, 'p_key': drugKey, 'p_signature': signature});

  /// Live, newest first.
  Stream<List<PatientInfusion>> watchInfusions(String patientId) => _client
      .from('patient_infusions')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('started_at')
      .map((rows) => rows.map(PatientInfusion.fromRow).toList());

  /// Running infusions for these patients (one fetch), by patient.
  Future<Map<String, List<PatientInfusion>>> runningFor(List<String> patientIds) async {
    if (patientIds.isEmpty) return const {};
    final rows = await _client
        .from('patient_infusions')
        .select()
        .inFilter('patient_id', patientIds)
        .isFilter('stopped_at', null)
        .order('started_at');
    final out = <String, List<PatientInfusion>>{};
    for (final i in rows.map(PatientInfusion.fromRow)) {
      (out[i.patientId] ??= []).add(i);
    }
    return out;
  }

  Future<String> start({
    required String patientId,
    String? drugKey,
    required String drugName,
    required double dose,
    required String doseUnit,
    required double rateMlH,
    required double concentration,
    required String concUnit,
    String syringe = '',
    double? weightKg,
  }) async {
    final id = await _client.rpc(
      'start_infusion',
      params: {
        'p_patient': patientId,
        'p_drug_key': drugKey ?? '',
        'p_drug_name': drugName,
        'p_dose': dose,
        'p_dose_unit': doseUnit,
        'p_rate': rateMlH,
        'p_concentration': concentration,
        'p_conc_unit': concUnit,
        'p_syringe': syringe,
        'p_weight': weightKg,
      },
    );
    return id as String;
  }

  Future<void> change(String id, {required double dose, required double rateMlH}) =>
      _client.rpc('change_infusion', params: {'p_id': id, 'p_dose': dose, 'p_rate': rateMlH});

  Future<void> stop(String id) => _client.rpc('stop_infusion', params: {'p_id': id});
}
