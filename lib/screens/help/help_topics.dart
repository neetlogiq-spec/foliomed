/// Help content, written for how FolioMed works today. Plain language,
/// one task per answer.
class HelpTopic {
  const HelpTopic(this.question, this.answer);
  final String question;
  final String answer;
}

class HelpSection {
  const HelpSection(this.title, this.topics);
  final String title;
  final List<HelpTopic> topics;
}

const List<HelpSection> kHelpSections = [
  HelpSection('Getting started', [
    HelpTopic('How do I get my team on FolioMed?',
        'Open Wards, tap +, and create a ward. You get a 5-digit code — share it from the ward page with Invite. Colleagues tap + → Join with a code and type it in.'),
    HelpTopic('What do the four tabs do?',
        'Today is what needs doing now: reminders, pending and urgent notes. Patients lists everyone on your wards. Wards is where you create, join and manage wards and units. Profile holds your details and settings.'),
    HelpTopic('Doctor or nurse — what changes?',
        'Both see the same patients and notes. Doctors post notes from the compose button; nurses confirm notes through the acknowledgement sheet, which records what was done. You can switch role in Profile.'),
  ]),
  HelpSection('Patients', [
    HelpTopic('How do I admit a patient?',
        'Tap the person+ button on Today or Patients. Name is the only required field; choose the ward (and unit, if your ward uses them). FolioMed gives every patient a permanent ID such as FM000123.'),
    HelpTopic('How do I edit, transfer or discharge?',
        'Open the patient and tap ••• in the top corner. Edit details changes the record; Transfer moves the patient — with their notes and reminders — to another ward you belong to; Discharge moves them to the Discharged list, and Readmit brings them back under the same ID.'),
    HelpTopic('Can I find a baby by the mother’s name?',
        'Yes. Search on the Patients tab matches the patient’s name, the mother’s name, bed, diagnosis, FolioMed ID and hospital ID.'),
  ]),
  HelpSection('Newborns', [
    HelpTopic('How are hours of life worked out?',
        'From the birth date and time entered on the patient. Age shows in hours for the first week, then days, months and years.'),
    HelpTopic('How do the 48- and 72-hour investigations work?',
        'When you add a birth time, FolioMed asks whether you’ll send the investigations at 48 or 72 hours and how early to remind you (8 or 12 hours). At the hour it asks the ward whether they were sent, then asks for the results.'),
    HelpTopic('What do the bilirubin lines mean?',
        'The chart plots each reading against the phototherapy and exchange lines for the baby’s gestation (and, for AAP, neurotoxicity risk factors). Switch between AAP 2022 and NICE above the chart. This is decision support only — always confirm against the guideline and your clinical judgement.'),
    HelpTopic('Why does AAP ask about risk factors?',
        'AAP 2022 uses lower thresholds when a baby has a neurotoxicity risk factor such as haemolysis, G6PD deficiency or sepsis. Record them (or "none") under Bilirubin on the patient page; until then FolioMed won’t apply AAP lines.'),
  ]),
  HelpSection('Notes and reminders', [
    HelpTopic('Who sees a note?',
        'Everyone in that patient’s ward, in real time. Urgent notes are highlighted and alert the team.'),
    HelpTopic('Can I make the feed shorter?',
        'On Today, tap the ⇕ button next to Ward notes to show one line per note. Tap a line to read it in full.'),
    HelpTopic('How do reminders follow up?',
        'When a reminder is due, FolioMed asks "has this been done?". Yes closes it for the whole ward; Not yet asks again in an hour.'),
  ]),
  HelpSection('Wards and units', [
    HelpTopic('What is a unit?',
        'A team inside a ward, such as Unit A and Unit B. The ward owner creates units on the ward page; patients can then be assigned to one. Everyone in the ward still sees every unit.'),
    HelpTopic('How do I see only my unit?',
        'Open the ward and set My unit. Today and Patients then open on your unit; use the filter button to change it.'),
    HelpTopic('Census and handover',
        'On Patients, tap the clipboard button. Census gives the day’s head count; Handover lists each baby with what needs attention, ready to share.'),
  ]),
  HelpSection('Alerts', [
    HelpTopic('I’m not getting alerts',
        'On Android, open Profile → Alert Setup and make sure every item shows a tick. Some brands also need auto-start allowed — the screen tells you where.'),
  ]),
  HelpSection('Account and privacy', [
    HelpTopic('Where is patient data kept?',
        'In FolioMed’s secure database, visible only to members of the patient’s ward. Photos you scan are read on your phone and never uploaded. See the privacy policy for details.'),
    HelpTopic('How do I delete my account?',
        'Profile → Delete account. This also deletes any wards you own, with their patients and notes, so hand ownership on first if your team still needs them.'),
  ]),
];

/// Topics whose question or answer contain every word of [query].
List<(HelpSection, HelpTopic)> searchHelp(String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return [
    for (final s in kHelpSections)
      for (final t in s.topics)
        if (words.every((w) => '${t.question} ${t.answer}'.toLowerCase().contains(w))) (s, t),
  ];
}
