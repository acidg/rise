/// Fertility phase of the current day, for the title bar.
enum CyclePhase { fertile, infertile }

/// A compact summary of the current cycle shown in the title bar: the current
/// cycle day, the fertility phase, and the next expected event.
///
/// When no cycle can be detected (no bleeding logged, or the record starts
/// mid-cycle) the status is [CycleStatus.unknown]: [cycleDay] is null and is
/// rendered as "?".
class CycleStatus {
  final int? cycleDay;
  final CyclePhase? phase;
  final String? nextEvent;

  const CycleStatus({
    required this.cycleDay,
    required this.phase,
    required this.nextEvent,
  });

  const CycleStatus.unknown() : cycleDay = null, phase = null, nextEvent = null;

  bool get isKnown => cycleDay != null;
}
