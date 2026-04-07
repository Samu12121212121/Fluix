import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/features/autenticacion/pantallas/pantalla_login.dart';

void main() {
  testWidgets('Pantalla Login tiene campos y botón', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaLogin()));

    expect(find.byType(TextFormField), findsNWidgets(2)); // Email + Pass
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}

