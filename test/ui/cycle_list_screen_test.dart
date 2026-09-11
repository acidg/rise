import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rise/ble/thermometer_service.dart';
import 'package:rise/data/entry_repository.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';
import 'package:rise/theme/app_theme.dart';
import 'package:rise/ui/app_controller.dart';
import 'package:rise/ui/cycles/cycle_list_screen.dart';
import 'package:rise/ui/cycles/cycle_sparkline.dart';

void main() {
  Future<AppController> controllerWith(List<DayEntry> entries) async {
    final controller = AppController(
      repository: InMemoryEntryRepository(entries),
      thermometer: FakeThermometerService(),
      now: () => DateTime(2026, 1, 30),
    );
    await controller.load();
    return controller;
  }

  Future<void> pumpScreen(WidgetTester tester, AppController controller) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: CycleListScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty history shows no cycles', (tester) async {
    final controller = await controllerWith(const []);

    await pumpScreen(tester, controller);

    expect(find.text('No cycles recorded yet'), findsNothing);
    // The day added for today forms one run, which has no known start.
    expect(find.text('Before the record'), findsOneWidget);
  });

  testWidgets('a confirmed cycle explains how the rise was read', (
    tester,
  ) async {
    final start = DateTime(2026, 1, 1);
    final entries = [
      for (var i = 0; i < 12; i++)
        DayEntry(
          date: start.add(Duration(days: i)),
          temperature: i < 8 ? 36.40 : 36.75,
          menstruation: i == 0 ? Menstruation.medium : Menstruation.none,
        ),
    ];
    final controller = await controllerWith(entries);

    await pumpScreen(tester, controller);

    expect(find.byType(CycleSparkline), findsWidgets);
    expect(find.textContaining('Rise confirmed on'), findsOneWidget);
    expect(find.textContaining('Coverline at 36.40'), findsOneWidget);
    expect(find.textContaining('five-day rule'), findsOneWidget);
  });

  testWidgets('a cycle the rules could not evaluate says what is missing', (
    tester,
  ) async {
    final start = DateTime(2026, 1, 1);
    final entries = [
      for (var i = 0; i < 20; i++)
        DayEntry(
          date: start.add(Duration(days: i)),
          menstruation: i == 0 ? Menstruation.medium : Menstruation.none,
        ),
    ];
    final controller = await controllerWith(entries);

    await pumpScreen(tester, controller);

    expect(
      find.textContaining('nothing was measured in this cycle'),
      findsOneWidget,
    );
    expect(find.textContaining('Measure on waking'), findsOneWidget);
    expect(find.textContaining('No mucus logged'), findsOneWidget);
    expect(find.textContaining('The window never closed'), findsOneWidget);
  });

  testWidgets('tapping a cycle returns its first day to the caller', (
    tester,
  ) async {
    final start = DateTime(2026, 1, 1);
    final entries = [
      for (var i = 0; i < 12; i++)
        DayEntry(
          date: start.add(Duration(days: i)),
          temperature: i < 8 ? 36.40 : 36.75,
          menstruation: i == 0 ? Menstruation.medium : Menstruation.none,
        ),
    ];
    final controller = await controllerWith(entries);
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              picked = await Navigator.of(context).push<DateTime>(
                MaterialPageRoute<DateTime>(
                  builder: (_) => CycleListScreen(controller: controller),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cycle 1'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2026, 1, 1));
  });
}
