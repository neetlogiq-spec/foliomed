/// New Ballard Score (Ballard et al., J Pediatr 1991): six neuromuscular
/// and six physical signs; the total gives gestation as
/// weeks = (2 × score + 120) ÷ 5 (−10 → 20 weeks … 50 → 44 weeks).
/// Physical descriptions follow the official score sheet
/// (ballardscore.com); neuromuscular ones are written as angles and
/// landmarks because the sheet shows them as pictures.
library;

import 'newborn_scores.dart';

const _posture = ScoreItem('Posture (at rest, supine)', [
  ScoreOption(0, 'Arms and legs extended'),
  ScoreOption(1, 'Hips and knees starting to flex, arms extended'),
  ScoreOption(2, 'Legs more flexed, arms extended'),
  ScoreOption(3, 'Arms slightly flexed, legs flexed and abducted'),
  ScoreOption(4, 'Arms and legs fully flexed'),
]);

const _squareWindow = ScoreItem('Square window (wrist)', [
  ScoreOption(-1, 'More than 90°'),
  ScoreOption(0, '90°'),
  ScoreOption(1, '60°'),
  ScoreOption(2, '45°'),
  ScoreOption(3, '30°'),
  ScoreOption(4, '0°'),
]);

const _armRecoil = ScoreItem('Arm recoil', [
  ScoreOption(0, '180° — no recoil'),
  ScoreOption(1, '140–180°'),
  ScoreOption(2, '110–140°'),
  ScoreOption(3, '90–110°'),
  ScoreOption(4, 'Under 90° — brisk, fist to face'),
]);

const _popliteal = ScoreItem('Popliteal angle', [
  ScoreOption(-1, '180°'),
  ScoreOption(0, '160°'),
  ScoreOption(1, '140°'),
  ScoreOption(2, '120°'),
  ScoreOption(3, '100°'),
  ScoreOption(4, '90°'),
  ScoreOption(5, 'Under 90°'),
]);

const _scarf = ScoreItem('Scarf sign (elbow reaches)', [
  ScoreOption(-1, 'Full scarf, at the neck'),
  ScoreOption(0, 'Opposite axillary line'),
  ScoreOption(1, 'Opposite nipple line'),
  ScoreOption(2, 'Xiphoid'),
  ScoreOption(3, 'Same-side nipple line'),
  ScoreOption(4, 'Same-side axillary line'),
]);

const _heelToEar = ScoreItem('Heel to ear (resistance felt at)', [
  ScoreOption(-1, 'Ear'),
  ScoreOption(0, 'Nose'),
  ScoreOption(1, 'Chin'),
  ScoreOption(2, 'Nipple line'),
  ScoreOption(3, 'Umbilicus'),
  ScoreOption(4, 'Femoral crease'),
]);

const _skin = ScoreItem('Skin', [
  ScoreOption(-1, 'Sticky, friable, transparent'),
  ScoreOption(0, 'Gelatinous, red, translucent'),
  ScoreOption(1, 'Smooth, pink, visible veins'),
  ScoreOption(2, 'Superficial peeling or rash, few veins'),
  ScoreOption(3, 'Cracking, pale areas, rare veins'),
  ScoreOption(4, 'Parchment, deep cracking, no vessels'),
  ScoreOption(5, 'Leathery, cracked, wrinkled'),
]);

const _lanugo = ScoreItem('Lanugo', [
  ScoreOption(-1, 'None'),
  ScoreOption(0, 'Sparse'),
  ScoreOption(1, 'Abundant'),
  ScoreOption(2, 'Thinning'),
  ScoreOption(3, 'Bald areas'),
  ScoreOption(4, 'Mostly bald'),
]);

const _plantar = ScoreItem('Plantar surface', [
  ScoreOption(-2, 'Heel–toe under 40 mm'),
  ScoreOption(-1, 'Heel–toe 40–50 mm'),
  ScoreOption(0, 'Over 50 mm, no creases'),
  ScoreOption(1, 'Faint red marks'),
  ScoreOption(2, 'Anterior transverse crease only'),
  ScoreOption(3, 'Creases over the front two-thirds'),
  ScoreOption(4, 'Creases over the whole sole'),
]);

const _breast = ScoreItem('Breast', [
  ScoreOption(-1, 'Imperceptible'),
  ScoreOption(0, 'Barely perceptible'),
  ScoreOption(1, 'Flat areola, no bud'),
  ScoreOption(2, 'Stippled areola, 1–2 mm bud'),
  ScoreOption(3, 'Raised areola, 3–4 mm bud'),
  ScoreOption(4, 'Full areola, 5–10 mm bud'),
]);

const _eyeEar = ScoreItem('Eye and ear', [
  ScoreOption(-2, 'Lids fused tightly'),
  ScoreOption(-1, 'Lids fused loosely'),
  ScoreOption(0, 'Lids open; pinna flat, stays folded'),
  ScoreOption(1, 'Pinna slightly curved, soft, slow recoil'),
  ScoreOption(2, 'Pinna well curved, soft, ready recoil'),
  ScoreOption(3, 'Formed and firm, instant recoil'),
  ScoreOption(4, 'Thick cartilage, ear stiff'),
]);

const _genitalsMale = ScoreItem('Genitals (male)', [
  ScoreOption(-1, 'Scrotum flat, smooth'),
  ScoreOption(0, 'Scrotum empty, faint rugae'),
  ScoreOption(1, 'Testes in upper canal, rare rugae'),
  ScoreOption(2, 'Testes descending, few rugae'),
  ScoreOption(3, 'Testes down, good rugae'),
  ScoreOption(4, 'Testes pendulous, deep rugae'),
]);

const _genitalsFemale = ScoreItem('Genitals (female)', [
  ScoreOption(-1, 'Clitoris prominent, labia flat'),
  ScoreOption(0, 'Clitoris prominent, small labia minora'),
  ScoreOption(1, 'Clitoris prominent, labia minora enlarging'),
  ScoreOption(2, 'Labia majora and minora equally prominent'),
  ScoreOption(3, 'Labia majora large, minora small'),
  ScoreOption(4, 'Labia majora cover clitoris and minora'),
]);

const List<ScoreItem> kBallardNeuromuscular = [_posture, _squareWindow, _armRecoil, _popliteal, _scarf, _heelToEar];

/// Physical items for a baby of the given sex (one genitals item).
List<ScoreItem> ballardPhysical({required bool male}) =>
    [_skin, _lanugo, _plantar, _breast, _eyeEar, male ? _genitalsMale : _genitalsFemale];

/// Gestation in weeks for a New Ballard total: (2 × score + 120) ÷ 5.
double ballardWeeks(int score) => (2 * score + 120) / 5;
