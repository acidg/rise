/// Categorical symptothermal signs logged for a single day.
///
/// Each enum is ordered from "least" to "most" (for example no bleeding through
/// heavy bleeding), so rendering code may rely on `index` for intensity.
library;

/// Menstrual bleeding intensity.
enum Menstruation { none, spotting, light, medium, heavy }

/// Cervical mucus quality, from none through the highly fertile egg-white type.
enum CervicalMucus { none, dry, sticky, creamy, watery, eggWhite }

/// Cervix position and firmness.
enum Cervix { lowFirm, medium, highSoft }

/// Pain or cramping intensity.
enum Pain { none, mild, moderate, severe }

/// Overall mood.
enum Mood { great, good, neutral, low, irritable }

/// Intercourse type, including none and self-stimulation.
enum Intercourse { none, protectedSex, unprotectedSex, withdrawal, self }

/// Libido level.
enum Libido { none, low, medium, high }

extension MenstruationSigns on Menstruation {
  /// Whether this counts as real menstrual flow (light or heavier). Spotting
  /// does not, so mid-cycle spotting never starts a new cycle.
  bool get isFlow =>
      this == Menstruation.light ||
      this == Menstruation.medium ||
      this == Menstruation.heavy;
}

extension CervicalMucusSigns on CervicalMucus {
  /// Whether fertile-type mucus is present. Any departure from dry/none opens
  /// the fertile window under the mucus rule.
  bool get isPresent =>
      this == CervicalMucus.sticky ||
      this == CervicalMucus.creamy ||
      this == CervicalMucus.watery ||
      this == CervicalMucus.eggWhite;

  /// Whether this is peak-quality mucus (egg-white or watery), used to close the
  /// window three days after the last such day.
  bool get isPeak =>
      this == CervicalMucus.watery || this == CervicalMucus.eggWhite;
}
