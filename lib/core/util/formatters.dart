/// Formateo compartido de fechas y duraciones para que todas las pantallas
/// muestren lo mismo (antes cada pantalla duplicaba su propio helper).
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "12 jun 2026" en hora local. Cadena vacía si [date] es null.
String formatLongDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// "12 min" — para la ficha de usuario. Cadena vacía si no hay duración.
String formatMinutes(Duration duration) {
  if (duration <= Duration.zero) return '';
  return '${duration.inMinutes} min';
}

/// "12:05" — formato preciso para el panel de administración.
String formatClock(int seconds) {
  if (seconds <= 0) return '';
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}
