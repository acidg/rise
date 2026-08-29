import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rise/ble/thermometer_service.dart';
import 'package:rise/data/entry_repository.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';
import 'package:rise/theme/app_theme.dart';
import 'package:rise/ui/app_controller.dart';
import 'package:rise/ui/chart/chart_screen.dart';
import 'package:rise/ui/detail/day_detail_sheet.dart';

List<DayEntry> sampleEntries() {
  final base = DateTime(2026, 3, 1);
  return [
    for (var i = 0; i < 10; i++)
      DayEntry(
        date: base.add(Duration(days: i)),
        temperature: 36.4 + (i > 5 ? 0.3 : 0.0),
        menstruation: i == 0 ? Menstruation.medium : Menstruation.none,
      ),
  ];
}

AppController loadedController() {
  return AppController(
    repository: InMemoryEntryRepository(sampleEntries()),
    thermometer: FakeThermometerService(),
  );
}

Widget wrap(AppController controller) => MaterialApp(
  theme: buildLightTheme(),
  home: ChartScreen(controller: controller),
);

void main() {
  testWidgets('renders the chart for the loaded days', (tester) async {
    final controller = loadedController();
    await controller.load();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    expect(find.text('Rise'), findsOneWidget);
    expect(find.byKey(const Key('chart')), findsOneWidget);
  });

  testWidgets('tapping a day opens its editable detail sheet', (tester) async {
    final controller = loadedController();
    await controller.load();
    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chart')));
    await tester.pumpAndSettle();

    expect(find.byType(DayDetailSheet), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
