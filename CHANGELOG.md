# Changelog

All notable changes to Rise are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Rise follows
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-09-10

### Fixed

- Importing a long history no longer takes minutes. Every imported day rewrote
  the whole store, so a file covering years cost one full rewrite per day in it;
  the import now writes the batch once. Syncing the thermometer writes once as
  well.
- The chart stayed responsive only on a short history: both the graph and the
  attribute table drew every day of the record on each repaint, which on several
  years of data meant a picture tens of thousands of pixels wide and a text
  layout per day. Only the columns in view are drawn now.

### Added

- Import and export show what they are doing while they run, instead of leaving
  the screen quiet long enough to look like the button did nothing.

## [1.1.0] - 2026-09-10

### Added

- Disturbed measurements can be excluded from the fertility analysis. A
  temperature taken after a short night or during an illness, and a bleed that
  should not open a new cycle, stay recorded but no longer drive the rules: an
  excluded temperature counts as a measurement gap for the "three over six"
  rule, and excluded bleeding does not start a cycle.
- The day sheet offers the exclude toggle next to the temperature and the
  bleeding, shown only once there is a value to exclude.
- The chart keeps excluded values visible: the temperature dot is drawn muted
  with the curve breaking around it, and excluded bleeding is outlined instead
  of filled.

### Changed

- The CSV history gained a `temperatureExcluded` and a `menstruationExcluded`
  column. Files exported by earlier versions still import; their days read as
  not excluded.

## [1.0.1] - 2026-09-09

### Fixed

- The chart always shows today, even when nothing has been logged for it yet.
- The landing page navigation no longer overlaps its content on narrow screens.

## [1.0.0] - 2026-08-31

### Added

- First release: a privacy-first symptothermal cycle tracker that keeps the Ovy
  OT35 Bluetooth thermometer usable after its own app dropped older Android
  versions.
- Bluetooth sync of the thermometer's stored readings, with a confirmation
  before a synced reading overwrites a temperature already logged for the day.
- Sensiplan analysis: cycle detection from the first day of bleeding, the
  "three over six" temperature shift with the fourth-day exception and gap
  bridging, mucus onset and peak, the five-day and "minus 8" calendar rules.
- Cycle chart with the temperature curve, fertile window, ovulation, coverline
  and the lowest higher measurement, plus an attribute table for the other
  signs.
- Day sheet to record temperature and measurement time, bleeding, cervical
  mucus, cervix, pain, mood, sex, libido, and free-text notes.
- CSV export and import of the whole history, so the data stays portable and
  the record is never locked into the app.

[1.1.1]: https://github.com/acidg/rise/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/acidg/rise/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/acidg/rise/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/acidg/rise/releases/tag/v1.0.0
