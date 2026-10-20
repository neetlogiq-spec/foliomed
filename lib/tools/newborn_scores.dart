/// Newborn bedside scores as data: items, the points for each option, and
/// how totals are read. Wording is FolioMed's own summary of each published
/// score; the citation is on [ScoreDefinition.source].
library;

class ScoreOption {
  const ScoreOption(this.points, this.label);
  final int points;
  final String label;
}

class ScoreItem {
  const ScoreItem(this.name, this.options);
  final String name;
  final List<ScoreOption> options;
  int get maxPoints => options.map((o) => o.points).reduce((a, b) => a > b ? a : b);
}

/// Totals from [min] to [max] (inclusive) read as [label].
class ScoreBand {
  const ScoreBand(this.min, this.max, this.label, {this.concern = 0});
  final int min;
  final int max;
  final String label;

  /// 0 reassuring … 2 worrying; drives colour only.
  final int concern;
}

class ScoreDefinition {
  const ScoreDefinition({
    required this.id,
    required this.name,
    required this.purpose,
    required this.items,
    required this.bands,
    required this.source,
    this.higherIsWorse = true,
  });

  final String id;
  final String name;
  final String purpose;
  final List<ScoreItem> items;
  final List<ScoreBand> bands;
  final String source;
  final bool higherIsWorse;

  int get maxTotal => items.fold(0, (s, i) => s + i.maxPoints);

  ScoreBand? bandFor(int total) {
    for (final b in bands) {
      if (total >= b.min && total <= b.max) return b;
    }
    return null;
  }
}

/// A (possibly partial) set of answers: item index → option index.
class ScoreAnswers {
  const ScoreAnswers(this.definition, [this.choices = const {}]);
  final ScoreDefinition definition;
  final Map<int, int> choices;

  ScoreAnswers choose(int item, int option) => ScoreAnswers(definition, {...choices, item: option});

  bool get complete => choices.length == definition.items.length;
  int get answered => choices.length;

  int get total => choices.entries.fold(0, (s, e) => s + definition.items[e.key].options[e.value].points);

  ScoreBand? get band => complete ? definition.bandFor(total) : null;

  /// One line for a note: "Downes 4/10 — moderate respiratory distress.
  /// Respiratory rate: 60–80/min (1); …".
  String summary() {
    final d = definition;
    final parts = [
      for (var i = 0; i < d.items.length; i++)
        if (choices[i] != null)
          '${d.items[i].name}: ${d.items[i].options[choices[i]!].label} (${d.items[i].options[choices[i]!].points})',
    ];
    final b = band;
    return '${d.name} $total/${d.maxTotal}${b == null ? '' : ' — ${b.label}'}.\n${parts.join('; ')}.';
  }
}

const apgar = ScoreDefinition(
  id: 'apgar',
  name: 'Apgar',
  purpose: 'Condition at 1, 5 and 10 minutes after birth',
  higherIsWorse: false,
  items: [
    ScoreItem('Colour', [
      ScoreOption(0, 'Blue or pale all over'),
      ScoreOption(1, 'Pink body, blue hands and feet'),
      ScoreOption(2, 'Pink all over'),
    ]),
    ScoreItem('Heart rate', [
      ScoreOption(0, 'Absent'),
      ScoreOption(1, 'Below 100/min'),
      ScoreOption(2, '100/min or more'),
    ]),
    ScoreItem('Response to stimulation', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Grimace'),
      ScoreOption(2, 'Cries, coughs or pulls away'),
    ]),
    ScoreItem('Muscle tone', [
      ScoreOption(0, 'Limp'),
      ScoreOption(1, 'Some flexion'),
      ScoreOption(2, 'Active movement'),
    ]),
    ScoreItem('Breathing', [
      ScoreOption(0, 'Absent'),
      ScoreOption(1, 'Slow, weak or irregular'),
      ScoreOption(2, 'Good, crying'),
    ]),
  ],
  bands: [
    ScoreBand(0, 3, 'low', concern: 2),
    ScoreBand(4, 6, 'moderately abnormal', concern: 1),
    ScoreBand(7, 10, 'reassuring'),
  ],
  source: 'Apgar V, 1953. Bands per AAP/ACOG committee opinion "The Apgar Score" (2015). '
      'Describes condition; not used alone to decide resuscitation or predict outcome.',
);

const downes = ScoreDefinition(
  id: 'downes',
  name: 'Downes',
  purpose: 'Respiratory distress, mostly in term and late-preterm babies',
  items: [
    ScoreItem('Respiratory rate', [
      ScoreOption(0, 'Under 60/min'),
      ScoreOption(1, '60–80/min'),
      ScoreOption(2, 'Over 80/min'),
    ]),
    ScoreItem('Retractions', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Mild'),
      ScoreOption(2, 'Moderate to severe'),
    ]),
    ScoreItem('Cyanosis', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'In room air, settles with oxygen'),
      ScoreOption(2, 'Despite 40% oxygen'),
    ]),
    ScoreItem('Air entry', [
      ScoreOption(0, 'Good'),
      ScoreOption(1, 'Reduced'),
      ScoreOption(2, 'Barely heard'),
    ]),
    ScoreItem('Grunting', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Heard with a stethoscope'),
      ScoreOption(2, 'Heard without a stethoscope'),
    ]),
  ],
  bands: [
    ScoreBand(0, 3, 'mild respiratory distress'),
    ScoreBand(4, 7, 'moderate respiratory distress', concern: 1),
    ScoreBand(8, 10, 'impending respiratory failure', concern: 2),
  ],
  source: 'Downes JJ et al., Clin Pediatr 1970. Bands as commonly taught; a score over 7 calls for a blood gas '
      'and escalation.',
);

const silvermanAnderson = ScoreDefinition(
  id: 'silverman',
  name: 'Silverman-Anderson',
  purpose: 'Respiratory distress, especially in preterm babies',
  items: [
    ScoreItem('Chest movement', [
      ScoreOption(0, 'Chest and abdomen rise together'),
      ScoreOption(1, 'Chest lags behind abdomen'),
      ScoreOption(2, 'See-saw'),
    ]),
    ScoreItem('Lower chest (intercostal) retraction', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Just visible'),
      ScoreOption(2, 'Marked'),
    ]),
    ScoreItem('Xiphoid retraction', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Just visible'),
      ScoreOption(2, 'Marked'),
    ]),
    ScoreItem('Nasal flaring', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Minimal'),
      ScoreOption(2, 'Marked'),
    ]),
    ScoreItem('Expiratory grunt', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Heard with a stethoscope'),
      ScoreOption(2, 'Heard without a stethoscope'),
    ]),
  ],
  bands: [
    ScoreBand(0, 0, 'no respiratory distress'),
    ScoreBand(1, 3, 'mild respiratory distress'),
    ScoreBand(4, 6, 'moderate respiratory distress', concern: 1),
    ScoreBand(7, 10, 'severe respiratory distress', concern: 2),
  ],
  source: 'Silverman WA, Andersen DH, Pediatrics 1956.',
);

const thompson = ScoreDefinition(
  id: 'thompson',
  name: 'Thompson',
  purpose: 'Severity of hypoxic-ischaemic encephalopathy, scored daily',
  items: [
    ScoreItem('Tone', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Increased'),
      ScoreOption(2, 'Decreased'),
      ScoreOption(3, 'Flaccid'),
    ]),
    ScoreItem('Level of consciousness', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Hyperalert, staring'),
      ScoreOption(2, 'Lethargic'),
      ScoreOption(3, 'Comatose'),
    ]),
    ScoreItem('Fits', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'Fewer than 3 a day'),
      ScoreOption(2, '3 or more a day'),
    ]),
    ScoreItem('Posture', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Fisting, cycling'),
      ScoreOption(2, 'Strong distal flexion'),
      ScoreOption(3, 'Decerebrate'),
    ]),
    ScoreItem('Moro reflex', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Partial'),
      ScoreOption(2, 'Absent'),
    ]),
    ScoreItem('Grasp', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Poor'),
      ScoreOption(2, 'Absent'),
    ]),
    ScoreItem('Suck', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Poor'),
      ScoreOption(2, 'Absent, with or without biting'),
    ]),
    ScoreItem('Breathing', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Hyperventilating'),
      ScoreOption(2, 'Brief apnoeas'),
      ScoreOption(3, 'Ventilated for apnoea'),
    ]),
    ScoreItem('Fontanelle', [
      ScoreOption(0, 'Normal'),
      ScoreOption(1, 'Full, not tense'),
      ScoreOption(2, 'Tense'),
    ]),
  ],
  bands: [
    ScoreBand(0, 0, 'normal'),
    ScoreBand(1, 10, 'mild HIE'),
    ScoreBand(11, 14, 'moderate HIE', concern: 1),
    ScoreBand(15, 22, 'severe HIE', concern: 2),
  ],
  source: 'Thompson CM et al., Acta Paediatr 1997.',
);

const latch = ScoreDefinition(
  id: 'latch',
  name: 'LATCH',
  purpose: 'Breastfeeding assessment',
  higherIsWorse: false,
  items: [
    ScoreItem('Latch', [
      ScoreOption(0, 'Too sleepy or won’t latch'),
      ScoreOption(1, 'Repeated attempts; nipple held in mouth; needs stimulating to suck'),
      ScoreOption(2, 'Grasps breast, tongue down, lips flanged, rhythmic sucking'),
    ]),
    ScoreItem('Audible swallowing', [
      ScoreOption(0, 'None'),
      ScoreOption(1, 'A few, with stimulation'),
      ScoreOption(2, 'Spontaneous — intermittent under 24 h, frequent after'),
    ]),
    ScoreItem('Type of nipple', [
      ScoreOption(0, 'Inverted'),
      ScoreOption(1, 'Flat'),
      ScoreOption(2, 'Everted (after stimulation)'),
    ]),
    ScoreItem('Comfort (breast and nipple)', [
      ScoreOption(0, 'Engorged, cracked, bleeding or blistered; severe discomfort'),
      ScoreOption(1, 'Filling; reddened or small blisters; mild to moderate discomfort'),
      ScoreOption(2, 'Soft, not tender'),
    ]),
    ScoreItem('Hold (positioning)', [
      ScoreOption(0, 'Staff hold the baby at the breast'),
      ScoreOption(1, 'Some help; mother takes over once positioned'),
      ScoreOption(2, 'No help needed'),
    ]),
  ],
  bands: [
    ScoreBand(0, 5, 'needs breastfeeding support', concern: 1),
    ScoreBand(6, 7, 'some support may help'),
    ScoreBand(8, 10, 'breastfeeding going well'),
  ],
  source: 'Jensen D, Wallace S, Kelsay P, JOGNN 1994. Bands are a common practical reading, not part of the '
      'original score — follow your lactation team.',
);

const List<ScoreDefinition> kNewbornScores = [apgar, downes, silvermanAnderson, thompson, latch];
