/// FolioMed's starter forms. A ward can copy one and change it; its copy
/// (same key) then replaces the built-in on that ward.
library;

import 'form_model.dart';

FormFieldDef _ok(String id, String label) => FormFieldDef(id: id, label: label, type: FieldType.yesNo, normal: kYes);
FormFieldDef _no(String id, String label) => FormFieldDef(id: id, label: label, type: FieldType.yesNo, normal: kNo);
FormFieldDef _exam(String id, String label) =>
    FormFieldDef(id: id, label: label, type: FieldType.choice, options: const ['Normal', 'Abnormal'], normal: 'Normal');
FormFieldDef _text(String id, String label, [String? hint]) =>
    FormFieldDef(id: id, label: label, type: FieldType.text, hint: hint);
const _vitals = FormFieldDef(id: 'vitals', label: 'Vital signs', type: FieldType.vitals);

FormFieldDef _item(String id, String label, List<String> options, List<int> points, {String? normal}) =>
    FormFieldDef(id: id, label: label, type: FieldType.score, options: options, points: points, normal: normal);

/// FLACC behavioural pain scale (Merkel et al., Pediatr Nurs 1997): five
/// items scored 0–2, total 0–10. For children who can't rate their pain.
FormSectionDef flaccSection(String prefix) => FormSectionDef(
  id: '${prefix}flacc',
  title: 'Pain (FLACC)',
  score: const ScoreSpec(
    name: 'FLACC',
    bands: [
      ScoreBand(0, 'relaxed and comfortable'),
      ScoreBand(1, 'mild discomfort'),
      ScoreBand(4, 'moderate pain', abnormal: true),
      ScoreBand(7, 'severe pain', abnormal: true),
    ],
  ),
  fields: [
    _item(
      '${prefix}flacc_face',
      'Face',
      const [
        'No particular expression, or smiling',
        'Now and then grimaces or frowns; withdrawn',
        'Often or always frowning, jaw clenched, chin quivering',
      ],
      const [0, 1, 2],
      normal: 'No particular expression, or smiling',
    ),
    _item(
      '${prefix}flacc_legs',
      'Legs',
      const ['Relaxed, normal position', 'Restless, tense, uneasy', 'Kicking, or legs drawn up'],
      const [0, 1, 2],
      normal: 'Relaxed, normal position',
    ),
    _item(
      '${prefix}flacc_activity',
      'Activity',
      const ['Lying quietly, moves easily', 'Squirming, shifting, tense', 'Arched, rigid or jerking'],
      const [0, 1, 2],
      normal: 'Lying quietly, moves easily',
    ),
    _item(
      '${prefix}flacc_cry',
      'Cry',
      const [
        'Not crying',
        'Moaning or whimpering; complains now and then',
        'Crying steadily, screaming or sobbing; complains often',
      ],
      const [0, 1, 2],
      normal: 'Not crying',
    ),
    _item(
      '${prefix}flacc_consolability',
      'Consolability',
      const [
        'Content and relaxed',
        'Settles with touch, cuddles or talking; can be distracted',
        'Hard to console or comfort',
      ],
      const [0, 1, 2],
      normal: 'Content and relaxed',
    ),
  ],
);

/// Modified Aldrete score (Aldrete, J Clin Anesth 1995): five items scored
/// 0–2; 9 or more is the usual cut-off for leaving recovery.
const _aldrete = FormSectionDef(
  id: 'aldrete',
  title: 'Recovery (Modified Aldrete)',
  score: ScoreSpec(
    name: 'Aldrete',
    bands: [ScoreBand(0, 'not ready to leave recovery', abnormal: true), ScoreBand(9, 'ready to leave recovery')],
  ),
  fields: [
    FormFieldDef(
      id: 'aldrete_activity',
      label: 'Activity',
      type: FieldType.score,
      options: ['Moves all four limbs', 'Moves two limbs', 'Moves no limbs'],
      points: [2, 1, 0],
      normal: 'Moves all four limbs',
    ),
    FormFieldDef(
      id: 'aldrete_breathing',
      label: 'Breathing',
      type: FieldType.score,
      options: ['Breathes deeply and coughs freely', 'Short of breath or shallow breathing', 'Not breathing'],
      points: [2, 1, 0],
      normal: 'Breathes deeply and coughs freely',
    ),
    FormFieldDef(
      id: 'aldrete_circulation',
      label: 'Blood pressure (vs before anaesthesia)',
      type: FieldType.score,
      options: ['Within 20%', 'Within 20–49%', 'Differs by 50% or more'],
      points: [2, 1, 0],
      normal: 'Within 20%',
    ),
    FormFieldDef(
      id: 'aldrete_conscious',
      label: 'Consciousness',
      type: FieldType.score,
      options: ['Fully awake', 'Wakes when called', 'Not responding'],
      points: [2, 1, 0],
      normal: 'Fully awake',
    ),
    FormFieldDef(
      id: 'aldrete_spo2',
      label: 'Oxygen saturation',
      type: FieldType.score,
      options: ['Above 92% in room air', 'Needs oxygen to stay above 90%', 'Below 90% even with oxygen'],
      points: [2, 1, 0],
      normal: 'Above 92% in room air',
    ),
  ],
);

/// STRONGkids nutrition risk screen (Hulst et al., Clin Nutr 2010): four
/// questions on admission; 0 low, 1–3 medium, 4–5 high risk.
const _strongKids = FormSectionDef(
  id: 'nutrition',
  title: 'Nutrition risk (STRONGkids)',
  score: ScoreSpec(
    name: 'STRONGkids',
    bands: [
      ScoreBand(0, 'low risk'),
      ScoreBand(1, 'medium risk — weigh twice a week, review intake'),
      ScoreBand(4, 'high risk — dietitian review', abnormal: true),
    ],
  ),
  fields: [
    FormFieldDef(
      id: 'nutr_disease',
      label: 'Illness with a high risk of malnutrition, or major surgery expected',
      type: FieldType.score,
      options: ['No', 'Yes'],
      points: [0, 2],
      normal: 'No',
    ),
    FormFieldDef(
      id: 'nutr_looks',
      label: 'Looks undernourished (wasted, thin, loss of fat or muscle)',
      type: FieldType.score,
      options: ['No', 'Yes'],
      points: [0, 1],
      normal: 'No',
    ),
    FormFieldDef(
      id: 'nutr_intake',
      label:
          'Poor intake or losses: diarrhoea 5+ a day, vomiting 3+ a day, eating less, or already on nutrition support',
      type: FieldType.score,
      options: ['No', 'Yes'],
      points: [0, 1],
      normal: 'No',
    ),
    FormFieldDef(
      id: 'nutr_weight',
      label: 'Weight loss, or (under 1 year) poor weight gain in recent weeks',
      type: FieldType.score,
      options: ['No', 'Yes'],
      points: [0, 1],
      normal: 'No',
    ),
  ],
);

FormFieldDef _linked(String id, String label, String link) =>
    FormFieldDef(id: id, label: label, type: FieldType.yesNo, normal: kNo, link: link);
FormFieldDef _num(String id, String label, String unit) =>
    FormFieldDef(id: id, label: label, type: FieldType.number, unit: unit);

final kBuiltInForms = <FormTemplate>[
  FormTemplate(
    key: 'ward_round',
    name: 'Ward round',
    description: 'Daily review: vitals, checks, things to review, plan',
    definition: FormDefinition(
      sections: [
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
        FormSectionDef(
          id: 'today',
          title: 'Today',
          fields: [
            _ok('afebrile', 'Afebrile'),
            _ok('feeding', 'Tolerating feeds / oral intake'),
            _ok('pain', 'Pain controlled'),
            _ok('chest', 'Chest clear'),
            _ok('wound', 'Wound clean and intact'),
            _ok('bleeding', 'No bleeding'),
            _ok('line', 'IV line working'),
            _ok('urine', 'Passing urine'),
            _ok('bowels', 'Bowels opened'),
            _ok('skin', 'Skin and pressure areas intact'),
            _ok('active', 'Active / mobilising'),
          ],
        ),
        FormSectionDef(
          id: 'review',
          title: 'Review',
          fields: [
            _ok('fluids', 'Fluid balance and feeds on target'),
            _ok('glucose', 'Blood glucose in range'),
            _ok('lines_needed', 'Lines, catheters and tubes still needed'),
            _num('line_days', 'Longest line in for', 'days'),
            const FormFieldDef(
              id: 'antibiotics',
              label: 'Antibiotics',
              type: FieldType.choice,
              options: ['None', 'Continue', 'Switch to oral', 'Stop today', 'Review cultures'],
            ),
            _num('antibiotic_day', 'Antibiotic day', 'day'),
            _ok('family', 'Family updated today'),
            _text('chase', 'Results to chase'),
            const FormFieldDef(id: 'discharge_date', label: 'Expected discharge', type: FieldType.date),
          ],
        ),
        FormSectionDef(id: 'plan', title: 'Plan', fields: [_text('plan', 'Plan', 'What happens next')]),
      ],
    ),
  ),
  FormTemplate(
    key: 'nursing_admission',
    name: 'Nursing admission',
    description: 'Within 24 h: safety checks, pain, nutrition, falls and skin',
    definition: FormDefinition(
      sections: [
        FormSectionDef(
          id: 'safety',
          title: 'On arrival',
          fields: [
            _ok('id_band', 'Name band on and correct'),
            _ok('allergy_band', 'Allergy band on (if allergic)'),
            _ok('oriented', 'Parent or carer shown the ward and call bell'),
          ],
        ),
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
        flaccSection(''),
        _strongKids,
        FormSectionDef(
          id: 'falls',
          title: 'Falls',
          fields: [
            _no('falls_young', 'Under 3, or unsteady for age'),
            _no('falls_meds', 'On sedating, seizure or blood-pressure medicines'),
            _no('falls_recent', 'Fallen recently or since admission'),
            _no('falls_post', 'Just had sedation or an anaesthetic'),
            _ok('cot_sides', 'Cot sides / bed rails up and safe'),
          ],
        ),
        FormSectionDef(
          id: 'skin',
          title: 'Skin',
          fields: [
            _ok('skin_intact', 'Skin intact over pressure points (head, heels, sacrum)'),
            _no('skin_devices', 'Devices pressing on skin (masks, probes, splints, tubes)'),
            _no('skin_immobile', 'Can’t change position alone'),
            _ok('cannula', 'Cannula site healthy (no redness, swelling or pain)'),
          ],
        ),
        FormSectionDef(id: 'notes', title: 'Comments', fields: [_text('comments', 'Comments')]),
      ],
    ),
  ),
  FormTemplate(
    key: 'nursing_vitals',
    name: 'Nursing vitals',
    description: 'Vital signs, pain, Hb / Hct and comments',
    definition: FormDefinition(
      sections: [
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
        flaccSection(''),
        FormSectionDef(
          id: 'blood',
          title: 'Blood',
          fields: [
            _num('hb', 'Hb', 'g/dL'),
            _num('hct', 'Hct', '%'),
            const FormFieldDef(
              id: 'hb_by',
              label: 'Hb measured by',
              type: FieldType.choice,
              options: ['Lab', 'Point of care'],
            ),
          ],
        ),
        FormSectionDef(id: 'notes', title: 'Comments', fields: [_text('comments', 'Comments')]),
      ],
    ),
  ),
  FormTemplate(
    key: 'admission',
    name: 'Admission evaluation',
    description: 'Presentation, background, examination, diagnosis and plan',
    definition: FormDefinition(
      sections: [
        FormSectionDef(
          id: 'presentation',
          title: 'Presentation',
          fields: [_text('complaint', 'Presenting complaint'), _text('hpi', 'History of the illness')],
        ),
        FormSectionDef(
          id: 'history',
          title: 'History',
          fields: [
            _no('recent_illness', 'Fever, cough or cold in the last 2 weeks'),
            _linked('allergies', 'Known allergies', kLinkAllergy),
            _linked('medicines', 'Takes regular medicines', kLinkDrugHistory),
            _no('surgery', 'Previous surgery'),
            _no('anaesthesia', 'Problems with anaesthesia (patient or family)'),
            _no('chronic', 'Long-term illness (heart, lung, kidney, liver)'),
            _no('preterm', 'Born preterm'),
            _no('bleeding', 'Bleeding or bruising problems'),
            _no('seizures', 'Seizures'),
          ],
        ),
        FormSectionDef(
          id: 'background',
          title: 'Background',
          fields: [
            _text('birth', 'Birth history'),
            const FormFieldDef(
              id: 'immunisation',
              label: 'Immunisations',
              type: FieldType.choice,
              options: ['Up to date', 'Behind', 'Not known'],
              normal: 'Up to date',
            ),
            const FormFieldDef(
              id: 'development',
              label: 'Development',
              type: FieldType.choice,
              options: ['Normal for age', 'Delayed', 'Not assessed'],
              normal: 'Normal for age',
            ),
            _text('family_history', 'Family history'),
            _text('social', 'Social history'),
            _no('safeguarding', 'Any safeguarding concern'),
          ],
        ),
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
        FormSectionDef(
          id: 'measurements',
          title: 'Measurements',
          fields: [_num('height', 'Height / length', 'cm'), _num('head', 'Head circumference', 'cm')],
        ),
        FormSectionDef(
          id: 'exam',
          title: 'Examination',
          fields: [
            _exam('general', 'General appearance'),
            _exam('hydration', 'Hydration'),
            _exam('cvs', 'Heart and circulation'),
            _exam('resp', 'Chest'),
            _exam('abdomen', 'Abdomen'),
            _exam('neuro', 'Neurology'),
            _exam('skin', 'Skin'),
            _exam('ent', 'Ears, nose, throat, airway'),
          ],
        ),
        FormSectionDef(
          id: 'outcome',
          title: 'Assessment and plan',
          fields: [
            _text('diagnosis', 'Working diagnosis'),
            _text('differentials', 'Differentials'),
            const FormFieldDef(
              id: 'fit',
              label: 'Fit for planned treatment',
              type: FieldType.choice,
              options: ['Yes', 'No', 'Pending tests'],
              normal: 'Yes',
            ),
            _text('plan', 'Plan'),
          ],
        ),
      ],
    ),
  ),
  FormTemplate(
    key: 'pre_anaesthesia',
    name: 'Pre-anaesthesia',
    description: 'Anaesthetic history, airway, fasting, readiness, plan',
    definition: FormDefinition(
      sections: [
        FormSectionDef(
          id: 'history',
          title: 'Anaesthetic history',
          fields: [
            const FormFieldDef(id: 'previous', label: 'Had anaesthesia before', type: FieldType.yesNo),
            _no('problems', 'Problems with a previous anaesthetic'),
            _no('family', 'Family history of anaesthetic problems'),
            _no('mh', 'Family history of malignant hyperthermia or unexplained anaesthetic death'),
            _no('snoring', 'Snoring or sleep apnoea'),
            _no('infection', 'Chest or throat infection in the last 2 weeks'),
            _no('teeth', 'Loose teeth'),
          ],
        ),
        FormSectionDef(
          id: 'airway',
          title: 'Airway',
          fields: [
            const FormFieldDef(
              id: 'mallampati',
              label: 'Mallampati',
              type: FieldType.choice,
              options: ['I', 'II', 'III', 'IV', 'Not assessable'],
            ),
            const FormFieldDef(
              id: 'mouth',
              label: 'Mouth opening',
              type: FieldType.choice,
              options: ['Normal', 'Limited'],
              normal: 'Normal',
            ),
            const FormFieldDef(
              id: 'neck',
              label: 'Neck movement',
              type: FieldType.choice,
              options: ['Normal', 'Limited'],
              normal: 'Normal',
            ),
            _no('difficult', 'Difficult airway expected'),
          ],
        ),
        FormSectionDef(
          id: 'fasting',
          title: 'Fasting (hours since)',
          fields: [
            _num('solids', 'Solids, formula or cow’s milk', 'h'),
            _num('breast', 'Breast milk', 'h'),
            _num('clear', 'Clear fluids', 'h'),
          ],
        ),
        FormSectionDef(
          id: 'ready',
          title: 'Ready for theatre',
          fields: [
            _ok('consent', 'Consent signed'),
            _ok('weight_today', 'Weighed today'),
            _ok('bloods', 'Hb / group and save done if needed'),
            _ok('iv', 'IV access, or plan for it'),
            _text('premed', 'Premedication'),
          ],
        ),
        FormSectionDef(
          id: 'plan',
          title: 'Plan',
          fields: [
            const FormFieldDef(id: 'asa', label: 'ASA', type: FieldType.choice, options: ['I', 'II', 'III', 'IV', 'V']),
            const FormFieldDef(
              id: 'technique',
              label: 'Anaesthesia',
              type: FieldType.choice,
              options: ['General', 'Sedation', 'Regional', 'Local'],
            ),
            const FormFieldDef(
              id: 'cleared',
              label: 'Cleared for surgery',
              type: FieldType.choice,
              options: ['Yes', 'No', 'Pending'],
              normal: 'Yes',
            ),
            _text('notes', 'Notes'),
          ],
        ),
      ],
    ),
  ),
  FormTemplate(
    key: 'surgical_safety',
    name: 'Surgical safety checklist',
    description: 'Sign in, time out, sign out — adapted from the WHO checklist',
    definition: FormDefinition(
      sections: [
        FormSectionDef(
          id: 'sign_in',
          title: 'Sign in (before anaesthesia)',
          fields: [
            _ok('identity', 'Identity, site, procedure and consent confirmed with the parent or patient'),
            const FormFieldDef(
              id: 'site_marked',
              label: 'Site marked',
              type: FieldType.choice,
              options: ['Yes', 'Not applicable', 'No'],
              normal: 'Yes',
            ),
            _ok('machine', 'Anaesthesia machine and medicines checked'),
            _ok('oximeter', 'Pulse oximeter on and working'),
            _no('known_allergy', 'Known allergy'),
            _no('airway_risk', 'Difficult airway or aspiration risk (equipment and help ready?)'),
            _no('blood_loss', 'Risk of blood loss over 7 mL/kg (access and fluids ready?)'),
          ],
        ),
        FormSectionDef(
          id: 'time_out',
          title: 'Time out (before incision)',
          fields: [
            _ok('team', 'Team introduced by name and role'),
            _ok('confirm', 'Patient, site and procedure confirmed aloud'),
            const FormFieldDef(
              id: 'antibiotic',
              label: 'Antibiotic given in the last 60 minutes',
              type: FieldType.choice,
              options: ['Yes', 'Not applicable', 'No'],
              normal: 'Yes',
            ),
            _text('surgeon', 'Surgeon: critical steps, length, expected blood loss'),
            _text('anaesthetist', 'Anaesthetist: concerns for this patient'),
            _ok('sterile', 'Sterility confirmed; no equipment problems'),
            const FormFieldDef(
              id: 'imaging',
              label: 'Essential imaging displayed',
              type: FieldType.choice,
              options: ['Yes', 'Not applicable', 'No'],
              normal: 'Yes',
            ),
          ],
        ),
        FormSectionDef(
          id: 'sign_out',
          title: 'Sign out (before leaving theatre)',
          fields: [
            _ok('procedure_recorded', 'Procedure name recorded'),
            _ok('counts', 'Instrument, swab and needle counts correct'),
            const FormFieldDef(
              id: 'specimen',
              label: 'Specimens labelled (read aloud with the patient’s name)',
              type: FieldType.choice,
              options: ['Yes', 'Not applicable', 'No'],
              normal: 'Yes',
            ),
            _no('equipment', 'Equipment problems to report'),
            _text('recovery', 'Key concerns for recovery'),
          ],
        ),
      ],
    ),
  ),
  FormTemplate(
    key: 'post_op',
    name: 'Post-op and discharge',
    description: 'Recovery score, pain, each post-op day, going home',
    definition: FormDefinition(
      sections: [
        const FormSectionDef(
          id: 'stage',
          title: 'When',
          fields: [
            FormFieldDef(
              id: 'stage',
              label: 'Stage',
              type: FieldType.choice,
              options: [
                'Leaving recovery',
                'Back on ward',
                'Post-op day 1',
                'Post-op day 2',
                'Post-op day 3+',
                'Discharge',
              ],
            ),
          ],
        ),
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
        _aldrete,
        flaccSection(''),
        FormSectionDef(
          id: 'checks',
          title: 'Checks',
          fields: [
            _ok('awake', 'Awake and responsive'),
            _ok('pain', 'Pain controlled'),
            _ok('nausea', 'No nausea or vomiting'),
            _ok('oral', 'Tolerating oral intake'),
            _ok('wound', 'Wound dry and intact'),
            _ok('urine', 'Passed urine'),
            _ok('drain', 'Drain output acceptable'),
          ],
        ),
        FormSectionDef(
          id: 'home',
          title: 'Going home',
          fields: [
            _ok('meds_explained', 'Medicines explained'),
            _ok('wound_care', 'Wound care explained'),
            _ok('danger_signs', 'Danger signs explained'),
            _ok('escort', 'Responsible adult to go home with'),
            _ok('follow_up', 'Follow-up booked'),
          ],
        ),
        FormSectionDef(id: 'plan', title: 'Plan', fields: [_text('plan', 'Plan')]),
      ],
    ),
  ),
];

/// Forms every admitted patient should have within 24 hours.
const kAdmissionFormKeys = {'admission': 'Admission evaluation', 'nursing_admission': 'Nursing admission'};

/// The forms a ward sees: its own (active) ones, plus each built-in it has
/// not replaced with its own copy (same key).
List<FormTemplate> formsForWard(List<FormTemplate> wardForms) {
  final own = [
    for (final f in wardForms)
      if (!f.archived) f,
  ];
  final ownKeys = {for (final f in wardForms) f.key};
  return [
    for (final b in kBuiltInForms)
      if (!ownKeys.contains(b.key)) b,
    ...own,
  ];
}
