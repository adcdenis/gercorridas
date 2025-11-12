import 'recurrence.dart';

class TimeDiffComponents {
  final int years;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  const TimeDiffComponents({
    required this.years,
    required this.months,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });
}

/// Calcula a diferença entre duas datas em componentes de calendário
/// normalizados (anos, meses, dias, horas, minutos, segundos).
/// Todos os componentes retornados são não negativos.
TimeDiffComponents calendarDiff(DateTime start, DateTime end) {
  // Normaliza ambos para o mesmo timezone (local) para evitar desvios de horas
  start = start.toLocal();
  end = end.toLocal();
  // Garante ordem
  if (end.isBefore(start)) {
    final tmp = start;
    start = end;
    end = tmp;
  }

  var years = end.year - start.year;
  var months = end.month - start.month;
  var days = end.day - start.day;
  var hours = end.hour - start.hour;
  var minutes = end.minute - start.minute;
  var seconds = end.second - start.second;

  if (seconds < 0) {
    seconds += 60;
    minutes -= 1;
  }
  if (minutes < 0) {
    minutes += 60;
    hours -= 1;
  }
  if (hours < 0) {
    hours += 24;
    days -= 1;
  }
  if (days < 0) {
    // Pega dias do mês anterior ao 'end'
    final prevMonth = end.month == 1 ? 12 : end.month - 1;
    final prevYear = end.month == 1 ? end.year - 1 : end.year;
    final dim = _daysInMonth(prevYear, prevMonth);
    days += dim;
    months -= 1;
  }
  if (months < 0) {
    months += 12;
    years -= 1;
  }

  return TimeDiffComponents(
    years: years,
    months: months,
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
  );
}

/// Calcula a diferença absoluta como duração normalizada (dias, horas, minutos, segundos).
/// Usa UTC para evitar discrepâncias de timezone. Meses/anos retornam zero.
TimeDiffComponents durationDiff(DateTime start, DateTime end) {
  // Unifica em horário LOCAL para evitar discrepâncias quando uma das datas vier em UTC
  // e a outra em local (cenário comum ao ler/gravar em diferentes plataformas).
  final a = start.toLocal();
  final b = end.toLocal();
  var d = b.difference(a);
  if (d.isNegative) d = d.abs();

  final days = d.inDays;
  final hours = d.inHours - days * 24;
  final minutes = d.inMinutes - d.inHours * 60;
  final seconds = d.inSeconds - d.inMinutes * 60;

  return TimeDiffComponents(
    years: 0,
    months: 0,
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
  );
}

Duration timeToEvent(DateTime eventDate, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return eventDate.difference(reference);
}

bool isPast(DateTime eventDate, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return eventDate.isBefore(reference);
}

DateTime nextRecurringDate(DateTime base, Recurrence recurrence, DateTime now) {
  // Normaliza para timezone local para consistência
  base = base.toLocal();
  now = now.toLocal();
  if (recurrence == Recurrence.none) {
    return base;
  }
  if (!base.isBefore(now)) return base;

  switch (recurrence) {
    case Recurrence.weekly:
      final daysDiff = now.difference(base).inDays;
      final weeksToAdd = (daysDiff ~/ 7) + 1;
      return base.add(Duration(days: weeksToAdd * 7));
    case Recurrence.monthly:
      final monthsBetween = _monthsBetween(base, now);
      var candidate = _addMonths(base, monthsBetween);
      if (candidate.isBefore(now)) {
        candidate = _addMonths(base, monthsBetween + 1);
      }
      return candidate;
    case Recurrence.yearly:
      final yearsBetween = now.year - base.year;
      var candidate = _addYearsClamped(base, yearsBetween);
      if (candidate.isBefore(now)) {
        candidate = _addYearsClamped(base, yearsBetween + 1);
      }
      return candidate;
    case Recurrence.none:
      return base;
  }
}

int _monthsBetween(DateTime start, DateTime end) {
  var months = (end.year - start.year) * 12 + (end.month - start.month);
  final candidate = _addMonths(start, months);
  if (candidate.isBefore(end)) {
    return months + 1;
  }
  return months;
}

DateTime _addMonths(DateTime date, int months) {
  final totalMonths = date.month + months;
  final newYear = date.year + ((totalMonths - 1) ~/ 12);
  final newMonth = ((totalMonths - 1) % 12) + 1;
  final day = _clampDay(date.day, newYear, newMonth);
  return DateTime(newYear, newMonth, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
}

DateTime _addYearsClamped(DateTime date, int years) {
  final newYear = date.year + years;
  final day = _clampDay(date.day, newYear, date.month);
  return DateTime(newYear, date.month, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
}

int _clampDay(int desiredDay, int year, int month) {
  final last = _daysInMonth(year, month);
  return desiredDay > last ? last : desiredDay;
}

int _daysInMonth(int year, int month) {
  final beginningNextMonth = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  return beginningNextMonth.subtract(const Duration(days: 1)).day;
}