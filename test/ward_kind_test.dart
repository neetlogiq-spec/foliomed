import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/ward.dart';

void main() {
  test('guesses the ward type from common names', () {
    final cases = {
      'NICU': WardKind.nicu,
      'NICU 2': WardKind.nicu,
      'SNCU': WardKind.nicu,
      'Neonatal unit': WardKind.nicu,
      'PICU': WardKind.picu,
      'PNC ward': WardKind.pnc,
      'Postnatal 3': WardKind.pnc,
      'Maternity': WardKind.pnc,
      'Paeds Ward A': WardKind.paeds,
      'Pediatrics': WardKind.paeds,
      "Children's ward": WardKind.paeds,
      'Medical ICU': WardKind.adult,
      'Female Surgical': WardKind.adult,
      'Ward 4': null,
      'Unit B': null,
    };
    cases.forEach((name, kind) => expect(WardKind.guessFrom(name), kind, reason: name));
  });

  test('PICU is not mistaken for adult ICU, nor NICU for ICU', () {
    expect(WardKind.guessFrom('picu-1'), WardKind.picu);
    expect(WardKind.guessFrom('nicu/sncu'), WardKind.nicu);
  });

  test('unknown or missing stored type reads as Other', () {
    expect(WardKind.fromName(null), WardKind.other);
    expect(WardKind.fromName('icu'), WardKind.other);
    expect(WardKind.fromName('picu'), WardKind.picu);
  });
}
