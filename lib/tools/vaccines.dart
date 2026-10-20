/// India's National Immunization Schedule (MoHFW / NHM, infants and
/// children) as data, with the "can be given till" limits the schedule
/// states. Used to list what is due, overdue, or past its window.
library;

class VaccineDose {
  const VaccineDose(this.name, this.dueDays, {this.latestDays, this.note});
  final String name;

  /// Age at which it is due, in days from birth.
  final int dueDays;

  /// Last age it may still be given, in days, where the schedule says so.
  final int? latestDays;
  final String? note;
}

const int _week = 7;
const int _month = 30; // schedule months, for due-date display only
const int _year = 365;

/// Birth to 5–6 years. Doses at the same age are listed together.
const List<VaccineDose> kNisDoses = [
  VaccineDose('BCG', 0, latestDays: _year, note: 'Can be given until 1 year'),
  VaccineDose('Hepatitis B birth dose', 0, latestDays: 1, note: 'Only within 24 hours of birth'),
  VaccineDose('OPV-0', 0, latestDays: 15, note: 'Only within the first 15 days'),
  VaccineDose('OPV-1', 6 * _week, latestDays: 5 * _year, note: 'OPV can be given until 5 years'),
  VaccineDose('Pentavalent-1', 6 * _week, latestDays: _year, note: 'Can be given until 1 year'),
  VaccineDose('Rotavirus-1', 6 * _week, latestDays: _year, note: 'Can be given until 1 year'),
  VaccineDose('fIPV-1', 6 * _week),
  VaccineDose('PCV-1', 6 * _week, note: 'Where PCV is in the programme'),
  VaccineDose('OPV-2', 10 * _week, latestDays: 5 * _year),
  VaccineDose('Pentavalent-2', 10 * _week, latestDays: _year),
  VaccineDose('Rotavirus-2', 10 * _week, latestDays: _year),
  VaccineDose('OPV-3', 14 * _week, latestDays: 5 * _year),
  VaccineDose('Pentavalent-3', 14 * _week, latestDays: _year),
  VaccineDose('Rotavirus-3', 14 * _week, latestDays: _year),
  VaccineDose('fIPV-2', 14 * _week),
  VaccineDose('PCV-2', 14 * _week, note: 'Where PCV is in the programme'),
  VaccineDose('Measles-Rubella-1', 9 * _month, latestDays: 5 * _year, note: 'Measles can be given until 5 years'),
  VaccineDose('Vitamin A (1st)', 9 * _month, note: '1 lakh IU, with MR-1'),
  VaccineDose('JE-1', 9 * _month, note: 'Endemic districts only'),
  VaccineDose('PCV booster', 9 * _month, note: 'Where PCV is in the programme'),
  VaccineDose('DPT booster-1', 16 * _month),
  VaccineDose('Measles-Rubella-2', 16 * _month, latestDays: 5 * _year),
  VaccineDose('OPV booster', 16 * _month, latestDays: 5 * _year),
  VaccineDose('JE-2', 16 * _month, note: 'Endemic districts only'),
  VaccineDose('Vitamin A (2nd)', 16 * _month, note: '2 lakh IU; then every 6 months to 5 years'),
  VaccineDose('DPT booster-2', 5 * _year),
];

enum DoseStatus {
  given('Given'),
  overdue('Due now'),
  upcoming('Upcoming'),
  missedWindow('Past its window');

  const DoseStatus(this.label);
  final String label;
}

class DosePlan {
  const DosePlan(this.dose, this.dueOn, this.status, {this.lastDay});
  final VaccineDose dose;
  final DateTime dueOn;
  final DateTime? lastDay;
  final DoseStatus status;
}

/// Each dose's due date and status on [today], given which doses (by name)
/// are already done.
List<DosePlan> vaccinePlan({required DateTime born, required DateTime today, Set<String> given = const {}}) {
  final birth = DateTime(born.year, born.month, born.day);
  final now = DateTime(today.year, today.month, today.day);
  return [
    for (final d in kNisDoses)
      () {
        final due = birth.add(Duration(days: d.dueDays));
        final last = d.latestDays == null ? null : birth.add(Duration(days: d.latestDays!));
        final status = given.contains(d.name)
            ? DoseStatus.given
            : last != null && now.isAfter(last)
                ? DoseStatus.missedWindow
                : !now.isBefore(due)
                    ? DoseStatus.overdue
                    : DoseStatus.upcoming;
        return DosePlan(d, due, status, lastDay: last);
      }(),
  ];
}
