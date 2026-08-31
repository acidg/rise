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

  testWidgets('an empty day shows a blank temperature field', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayDetailSheet(
            entry: DayEntry(date: DateTime(2026, 3, 1)),
            onSave: (_) {},
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('temperature-field')),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('stepping from a blank field seeds the default value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DayEntry? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayDetailSheet(
            entry: DayEntry(date: DateTime(2026, 3, 1)),
            onSave: (e) => saved = e,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('temperature-field')),
    );
    expect(field.controller!.text, '36.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved!.temperature, 36.50);
  });

  testWidgets('closing the sheet without Save still persists changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DayEntry? saved;
    final entry = DayEntry(date: DateTime(2026, 3, 1), temperature: 36.50);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayDetailSheet(entry: entry, onSave: (e) => saved = e),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('temperature-field')), '36.99');
    // Dismiss the way a drag-down or tap-outside would: the sheet leaves the tree.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.temperature, 36.99);
  });

  testWidgets('viewing a day and closing without edits saves nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DayEntry? saved;
    // An empty day: closing it must not write the placeholder temperature.
    final entry = DayEntry(date: DateTime(2026, 3, 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayDetailSheet(entry: entry, onSave: (e) => saved = e),
        ),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();

    expect(saved, isNull);
  });

  testWidgets('the synced measurement time is shown and kept on save', (
    tester,
  ) async {
    final entry = DayEntry(
      date: DateTime(2026, 3, 1),
      temperature: 36.50,
      temperatureAt: DateTime(2026, 3, 1, 6, 30),
    );

    final saved = await editAndSave(tester, entry, (t) async {
      // A time is present, so the chip does not offer to add one.
      expect(find.text('Add time'), findsNothing);
    });

    // Saving without touching the time preserves it.
    expect(saved.temperatureAt, DateTime(2026, 3, 1, 6, 30));
  });

  testWidgets('a time can be added by hand when none was synced', (
    tester,
  ) async {
    final entry = DayEntry(date: DateTime(2026, 3, 1), temperature: 36.50);

    final saved = await editAndSave(tester, entry, (t) async {
      expect(find.text('Add time'), findsOneWidget);
      await t.tap(find.byKey(const Key('temperature-time')));
      await t.pumpAndSettle();
      // Confirm the picker's initial time.
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
    });

    // The picked time lands on the entry's own date.
    expect(saved.temperatureAt, isNotNull);
    expect(saved.temperatureAt!.year, 2026);
    expect(saved.temperatureAt!.month, 3);
    expect(saved.temperatureAt!.day, 1);
  });
}
