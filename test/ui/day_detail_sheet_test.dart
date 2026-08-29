import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/ui/detail/day_detail_sheet.dart';

void main() {
  Future<DayEntry> editAndSave(
    WidgetTester tester,
    DayEntry entry,
    Future<void> Function(WidgetTester) interact,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late DayEntry saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayDetailSheet(entry: entry, onSave: (e) => saved = e),
        ),
      ),
    );
    await interact(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('typing a temperature saves the entered value', (tester) async {
    final entry = DayEntry(date: DateTime(2026, 3, 1), temperature: 36.50);

    final saved = await editAndSave(tester, entry, (t) async {
      await t.enterText(find.byKey(const Key('temperature-field')), '36.82');
    });

    expect(saved.temperature, 36.82);
  });

  testWidgets('the stepper adjusts the value shown in the field', (
    tester,
  ) async {
    final entry = DayEntry(date: DateTime(2026, 3, 1), temperature: 36.50);

    final saved = await editAndSave(tester, entry, (t) async {
      await t.enterText(find.byKey(const Key('temperature-field')), '36.80');
      await t.tap(find.byIcon(Icons.add));
      await t.pumpAndSettle();
      final field = t.widget<TextField>(
        find.byKey(const Key('temperature-field')),
      );
      expect(field.controller!.text, '36.81');
    });

    expect(saved.temperature, 36.81);
  });

  testWidgets('a comma decimal separator is accepted', (tester) async {
    final entry = DayEntry(date: DateTime(2026, 3, 1), temperature: 36.50);

    final saved = await editAndSave(tester, entry, (t) async {
      await t.enterText(find.byKey(const Key('temperature-field')), '36,73');
    });

    expect(saved.temperature, 36.73);
  });
}
