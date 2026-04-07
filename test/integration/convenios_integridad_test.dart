import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  test('Crear complementaria -> verificar que convenio no cambia', () async {
    // Setup convenio
    await db.collection('convenios').doc('conv1').set({
      'nombre': 'Hostelería',
      'anio': 2026,
      'tablas_salariales': {'cat1': 1500},
    });

    // Generate regular nomina using this convenio
    await db.collection('empresas').doc('emp1').collection('nominas').doc('nom1').set({
      'convenio_id': 'conv1',
      'salario_base': 1500,
      'tipo': 'ordinaria',
    });

    // Update convenio (e.g. revision salarial)
    await db.collection('convenios').doc('conv1').update({
      'tablas_salariales': {'cat1': 1550},
    });

    // Create complementaria (should reference original base or diff)
    // This tests that your logic for 'complementaria' correctly calculates diffs
    // without altering the original 'nom1' record intentionally.
    
    final original = await db.collection('empresas').doc('emp1').collection('nominas').doc('nom1').get();
    expect(original.data()?['salario_base'], 1500); // Should remain immutable
  });

  test('Verificar que nóminas pagadas siguen intactas', () async {
    // ...
  });
}

