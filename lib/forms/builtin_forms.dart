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

final kBuiltInForms = <FormTemplate>[
  FormTemplate(
    key: 'ward_round',
    name: 'Ward round',
    description: 'Daily review: vitals, quick checks, plan',
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
            _ok('active', 'Active / mobilising'),
          ],
        ),
        FormSectionDef(id: 'plan', title: 'Plan', fields: [_text('plan', 'Plan', 'What happens next')]),
      ],
    ),
  ),
  FormTemplate(
    key: 'nursing_vitals',
    name: 'Nursing vitals',
    description: 'Vital signs, Hb / Hct and comments',
    definition: FormDefinition(
      sections: [
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
        FormSectionDef(
          id: 'blood',
          title: 'Blood',
          fields: [
            const FormFieldDef(id: 'hb', label: 'Hb', type: FieldType.number, unit: 'g/dL'),
            const FormFieldDef(id: 'hct', label: 'Hct', type: FieldType.number, unit: '%'),
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
    description: 'History, examination by system, fit for treatment',
    definition: FormDefinition(
      sections: [
        FormSectionDef(
          id: 'history',
          title: 'History',
          fields: [
            _no('recent_illness', 'Fever, cough or cold in the last 2 weeks'),
            _no('allergies', 'Known allergies'),
            _no('medicines', 'Takes regular medicines'),
            _no('surgery', 'Previous surgery'),
            _no('anaesthesia', 'Problems with anaesthesia (patient or family)'),
            _no('chronic', 'Long-term illness (heart, lung, kidney, liver)'),
            _no('preterm', 'Born preterm'),
            _no('development', 'Developmental delay'),
            _no('bleeding', 'Bleeding or bruising problems'),
            _no('seizures', 'Seizures'),
          ],
        ),
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
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
          title: 'Outcome',
          fields: [
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
    description: 'Anaesthetic history, airway, fasting, plan',
    definition: FormDefinition(
      sections: [
        FormSectionDef(
          id: 'history',
          title: 'Anaesthetic history',
          fields: [
            const FormFieldDef(id: 'previous', label: 'Had anaesthesia before', type: FieldType.yesNo),
            _no('problems', 'Problems with a previous anaesthetic'),
            _no('family', 'Family history of anaesthetic problems'),
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
          title: 'Fasting',
          fields: [
            const FormFieldDef(id: 'solids', label: 'Since solids / milk', type: FieldType.number, unit: 'h'),
            const FormFieldDef(id: 'clear', label: 'Since clear fluids', type: FieldType.number, unit: 'h'),
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
    key: 'post_op',
    name: 'Post-op and discharge',
    description: 'Back on the ward, each post-op day, going home',
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
              options: ['Back on ward', 'Post-op day 1', 'Post-op day 2', 'Post-op day 3+', 'Discharge'],
            ),
          ],
        ),
        const FormSectionDef(id: 'vitals', title: 'Vital signs', fields: [_vitals]),
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
            _ok('follow_up', 'Follow-up booked'),
          ],
        ),
        FormSectionDef(id: 'plan', title: 'Plan', fields: [_text('plan', 'Plan')]),
      ],
    ),
  ),
];

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
