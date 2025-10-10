import 'package:flutter/material.dart';

/// Shows a date picker with Monday as the first day of the week
/// This function is kept for backwards compatibility
Future<DateTime?> showMondayFirstDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showCustomDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    firstDayOfWeek: 1, // Monday
  );
}

/// Shows a date picker with configurable first day of week
/// @param firstDayOfWeek: 1 = Monday (default), 7 = Sunday
Future<DateTime?> showCustomDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  int firstDayOfWeek = 1, // 1 = Monday, 7 = Sunday
}) {
  // Use locale to control first day of week
  // en_GB (UK) = Monday first
  // en_US (US) = Sunday first
  final locale = firstDayOfWeek == 7
    ? const Locale('en', 'US') // Sunday first
    : const Locale('en', 'GB'); // Monday first

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: locale,
  );
}
