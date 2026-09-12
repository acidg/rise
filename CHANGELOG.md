# Changelog

All notable changes to Rise are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Rise follows
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- The Cycles page turned into a blank grey block partway down a long record. A
  cycle that ends before the calendar rules would have opened its window - four
  days of bleeding, then bleeding again, while the five-day rule frees days 1 to
  5 - was asked for the date of a day it never had, and the resulting error took
  the whole list down with it. Such a cycle now says what happened: the window
  would have opened on day 6, but the cycle ended on day 4.

### Changed

- Cycles in the list start folded, showing the verdict and how many hints wait
  behind the arrow; only the newest cycle opens unfolded. Years of history were
  otherwise an unbroken wall of text, since most of the account repeats from
  cycle to cycle.

## [1.2.0] - 2026-09-11

### Added

- A Cycles page, reached from the chart, lists every cycle with its curve in
  miniature and an account of how the rules read it: which one opened the fertile
  window, how far the temperature evaluation got and what closed it, what the
  mucus added. Where the rules could say nothing it says what the record was
  missing - a rise with too few measurements before it to draw a coverline,
  measurement times spread across hours, no mucus logged - so the next cycle can
  be recorded in a way the rules can use. Tapping a cycle closes the page and
  scrolls the chart to its first day.
- The chart marks where the record crosses into a new calendar year: a line
  through the full height, labelled with the year it opens. Scrolling back
  through several years of history no longer leaves the year a guess.
- A cycle whose window rests on no evaluation is now shown as such. When neither
  calendar rule can be applied - no twelve documented cycles carrying a
  temperature shift, and a previous cycle that could not be evaluated - the
  whole cycle counts as fertile out of caution. That is a fallback, not a
  finding, so the band is drawn in neutral grey instead of fertile green and the
  status line reads "No evaluation possible" rather than "Fertile".

### Changed

- The chart's upper reference line now rests on the measurement that completed
  the temperature evaluation - the third higher one when it reached 0.2 C above
  the coverline, otherwise the fourth that confirmed it instead - and so does the
  difference it labels. The line therefore marks the day the temperature closed
  the fertile window; it is drawn in a dimmer green when the evaluation finished
  below the 0.2 mark. It used to rest on the lowest of the higher measurements,
  which is almost always the first one, and reported a gap of a few hundredths
  that said nothing about the rule.
- The temperature evaluation now applies the method's second exception: a second
  or third higher measurement that falls back onto or below the coverline is
  disregarded rather than breaking the rise, and one further measurement is
  awaited, which must reach 0.2 C above the coverline. Only one measurement may
  be disregarded, and only from those two positions. Rise used to discard the
  whole rise on any fall back, which is stricter than the method.
- The first higher measurement must now clear the coverline by at least 0.05 C.
  Sensiplan asks only that it lie above, by any amount, which let a reading two
  hundredths up - inside the noise of a basal measurement - open the rise, date
  ovulation a day early and close the fertile window two days early. The change
  only ever delays a shift, never brings it forward.
- A fertile window without a confirmed temperature shift no longer closes at
  all. Only the shift ends the fertile phase under the symptothermal method, so
  a cycle that was never evaluated stays fertile from the calendar start to its
  last day instead of closing on a prediction. The predicted closing day is
  still what the chart draws ahead to.
- The predicted ovulation day no longer averages in runs far outside a plausible
  cycle length. A stretch where bleeding went unlogged is one long run, not a
  cycle, and averaging it in pushed the prediction days late for every cycle
  after it.

### Fixed

- A fertile window without a temperature evaluation ignored the logged mucus and
  closed on the calendar guess alone, which can fall days before the mucus peak -
  ending the fertile phase while fertile-quality mucus is still being recorded.
  An observed sign now outranks the guess: such a window cannot close before
  three days after the peak, the same bound a confirmed window already
  respected.
- A temperature rise of exactly 0.2 C over the coverline confirmed the shift a
  day late: the threshold was compared in binary floating point, where
  36.42 + 0.2 comes out just above 36.62. Temperatures are now compared in
  hundredths, the precision they are recorded at.

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

[1.2.0]: https://github.com/acidg/rise/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/acidg/rise/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/acidg/rise/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/acidg/rise/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/acidg/rise/releases/tag/v1.0.0
