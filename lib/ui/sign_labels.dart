import '../domain/models/signs.dart';

/// Human-readable labels for the sign enums, used by the detail sheet chips.
/// These are presentation strings only; the stored values are the enums.

extension MenstruationLabel on Menstruation {
  String get label => switch (this) {
    Menstruation.none => 'None',
    Menstruation.spotting => 'Spotting',
    Menstruation.light => 'Light',
    Menstruation.medium => 'Medium',
    Menstruation.heavy => 'Heavy',
  };
}

extension CervicalMucusLabel on CervicalMucus {
  String get label => switch (this) {
    CervicalMucus.none => 'None',
    CervicalMucus.dry => 'Dry',
    CervicalMucus.sticky => 'Sticky',
    CervicalMucus.creamy => 'Creamy',
    CervicalMucus.watery => 'Watery',
    CervicalMucus.eggWhite => 'Egg-white',
  };
}

extension CervixLabel on Cervix {
  String get label => switch (this) {
    Cervix.lowFirm => 'Low / firm',
    Cervix.medium => 'Medium',
    Cervix.highSoft => 'High / soft',
  };
}

extension PainLabel on Pain {
  String get label => switch (this) {
    Pain.none => 'None',
    Pain.mild => 'Mild',
    Pain.moderate => 'Moderate',
    Pain.severe => 'Severe',
  };
}

extension MoodLabel on Mood {
  String get label => switch (this) {
    Mood.great => 'Great',
    Mood.good => 'Good',
    Mood.neutral => 'Neutral',
    Mood.low => 'Low',
    Mood.irritable => 'Irritable',
  };
}

extension IntercourseLabel on Intercourse {
  String get label => switch (this) {
    Intercourse.none => 'None',
    Intercourse.protectedSex => 'Protected',
    Intercourse.unprotectedSex => 'Unprotected',
    Intercourse.withdrawal => 'Withdrawal',
    Intercourse.self => 'Self',
  };
}

extension LibidoLabel on Libido {
  String get label => switch (this) {
    Libido.none => 'None',
    Libido.low => 'Low',
    Libido.medium => 'Medium',
    Libido.high => 'High',
  };
}
