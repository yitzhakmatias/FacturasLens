import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoicereader/presentation/core/app_theme.dart';

void main() {
  testWidgets('Paychain-inspired theme renders primary controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {},
              child: const Text('Escanear'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Escanear'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });
}
