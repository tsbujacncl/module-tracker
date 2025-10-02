import 'package:flutter/material.dart';

/// Shows a date picker with Monday as the first day of the week
Future<DateTime?> showMondayFirstDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: const Locale('en', 'GB'), // UK locale uses Monday as first day
  );
}
