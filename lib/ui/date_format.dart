/// Short date forms shared by the chart headers, the day sheet, and the cycle
/// list, so the app speaks about dates in one voice.
library;

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "8 Nov".
String formatDayMonth(DateTime date) =>
    '${date.day} ${_monthAbbr[date.month - 1]}';

/// "8 Nov 2024".
String formatDayMonthYear(DateTime date) =>
    '${formatDayMonth(date)} ${date.year}';
