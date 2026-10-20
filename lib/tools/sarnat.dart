/// Modified Sarnat staging of neonatal encephalopathy, in the form used by
/// the NICHD cooling trial (Shankaran et al., NEJM 2005). Six areas are
/// each graded normal → severe; areas with two or three signs take their
/// worst sign. Wording is FolioMed's own.
library;

enum SarnatGrade {
  normal('Normal'),
  mild('Mild'),
  moderate('Moderate'),
  severe('Severe');

  const SarnatGrade(this.label);
  final String label;
}

/// One sign and how it looks at each grade (normal first).
class SarnatSign {
  const SarnatSign(this.name, this.looks);
  final String name;

  /// Descriptions for normal, mild, moderate, severe — in that order.
  final List<String> looks;
}

class SarnatArea {
  const SarnatArea(this.name, this.signs);
  final String name;
  final List<SarnatSign> signs;
}

const List<SarnatArea> kSarnatAreas = [
  SarnatArea('Level of consciousness', [
    SarnatSign('Consciousness', ['Alert', 'Hyperalert', 'Lethargic', 'Stupor or coma']),
  ]),
  SarnatArea('Spontaneous activity', [
    SarnatSign('Activity', ['Normal', 'Normal or increased', 'Decreased', 'None']),
  ]),
  SarnatArea('Posture', [
    SarnatSign('Posture', ['Normal flexion', 'Mild distal flexion', 'Strong distal flexion, full extension', 'Decerebrate']),
  ]),
  SarnatArea('Tone', [
    SarnatSign('Tone', ['Normal', 'Increased (jittery)', 'Reduced, focal or general', 'Flaccid']),
  ]),
  SarnatArea('Primitive reflexes', [
    SarnatSign('Suck', ['Normal', 'Weak or incomplete', 'Weak, or bites', 'Absent']),
    SarnatSign('Moro', ['Normal', 'Strong, low threshold', 'Incomplete', 'Absent']),
  ]),
  SarnatArea('Autonomic system', [
    SarnatSign('Pupils', ['Normal', 'Dilated, reactive', 'Constricted', 'Deviated, dilated or not reacting to light']),
    SarnatSign('Heart rate', ['Normal', 'Fast', 'Slow', 'Variable']),
    SarnatSign('Breathing', ['Normal', 'Normal', 'Periodic breathing', 'Apnoea']),
  ]),
];

/// Grades chosen so far: (area, sign) → grade.
class SarnatAnswers {
  const SarnatAnswers([this.grades = const {}]);
  final Map<(int, int), SarnatGrade> grades;

  SarnatAnswers set(int area, int sign, SarnatGrade g) => SarnatAnswers({...grades, (area, sign): g});

  int get signCount => kSarnatAreas.fold(0, (s, a) => s + a.signs.length);
  bool get complete => grades.length == signCount;

  /// An area's grade is its worst sign; null until every sign is graded.
  SarnatGrade? areaGrade(int area) {
    final signs = kSarnatAreas[area].signs;
    SarnatGrade? worst;
    for (var s = 0; s < signs.length; s++) {
      final g = grades[(area, s)];
      if (g == null) return null;
      if (worst == null || g.index > worst.index) worst = g;
    }
    return worst;
  }

  List<SarnatGrade> get areaGrades => [
        for (var a = 0; a < kSarnatAreas.length; a++)
          if (areaGrade(a) != null) areaGrade(a)!,
      ];

  /// Areas graded moderate or severe.
  int get moderateOrWorse => areaGrades.where((g) => g.index >= SarnatGrade.moderate.index).length;

  /// NICHD criterion: 3 or more of the 6 areas moderate or severe.
  bool get meetsNichdCriterion => complete && moderateOrWorse >= 3;

  /// The overall stage: the grade most areas share (a tie goes to the more
  /// severe). Null until complete.
  SarnatGrade? get stage {
    if (!complete) return null;
    final counts = {for (final g in SarnatGrade.values) g: 0};
    for (final g in areaGrades) {
      counts[g] = counts[g]! + 1;
    }
    SarnatGrade best = SarnatGrade.normal;
    for (final g in SarnatGrade.values) {
      if (counts[g]! >= counts[best]!) best = g;
    }
    return best;
  }

  String summary() {
    final lines = [
      for (var a = 0; a < kSarnatAreas.length; a++)
        if (areaGrade(a) != null) '${kSarnatAreas[a].name}: ${areaGrade(a)!.label.toLowerCase()}',
    ];
    final s = stage;
    return 'Modified Sarnat${s == null ? '' : ': ${s.label.toLowerCase()} encephalopathy'} '
        '($moderateOrWorse of 6 areas moderate or severe'
        '${meetsNichdCriterion ? ' — meets the NICHD criterion for moderate/severe' : ''}).\n'
        '${lines.join('; ')}.';
  }
}
