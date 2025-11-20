import 'package:intl/intl.dart';
import 'package:gercorridas/domain/time_utils.dart';
import 'package:gercorridas/data/models/counter.dart';
/// Utilitário para sanitização de textos antes do compartilhamento.
///
/// Requisitos:
/// - Remove asteriscos `*` para evitar formatação indesejada.
/// - Preserva estrutura HTML válida (não altera tags, apenas remove `*`).
/// - Mantém legibilidade e formatação básica (quebra de linhas, espaços).
String sanitizeForShare(String input) {
  // Remove asteriscos (markdown/bolding) sem afetar tags HTML
  final noStars = input.replaceAll('*', '');

  // Normaliza espaços em cada linha, preservando quebras de linha
  final lines = noStars
      .split('\n')
      .map((line) {
        // Colapsa múltiplos espaços para um único
        final normalized = line.replaceAll(RegExp(r' {2,}'), ' ');
        // Remove espaços à direita mantendo indentação à esquerda quando existir
        return normalized.replaceAll(RegExp(r'\s+$'), '');
      })
      .toList();

  // Junta novamente e remove espaços extras no início/fim geral
  return lines.join('\n').trim();
}

String buildShareText(Counter counter, DateTime effectiveDate, bool isFuture) {
  final now = DateTime.now();
  final comps = calendarDiff(now, effectiveDate);
  final timeText = isFuture ? 'Faltam' : 'Passaram';
  String formattedTime = '';
  if (comps.years > 0) formattedTime += '${comps.years} ano${comps.years == 1 ? '' : 's'}, ';
  if (comps.months > 0) formattedTime += '${comps.months} ${comps.months == 1 ? 'mês' : 'meses'}, ';
  if (comps.days > 0) formattedTime += '${comps.days} dia${comps.days == 1 ? '' : 's'}, ';
  if (comps.hours > 0) formattedTime += '${comps.hours} hora${comps.hours == 1 ? '' : 's'}, ';
  if (comps.minutes > 0) formattedTime += '${comps.minutes} minuto${comps.minutes == 1 ? '' : 's'}, ';
  if (comps.seconds > 0) formattedTime += '${comps.seconds} segundo${comps.seconds == 1 ? '' : 's'}, ';
  if (formattedTime.endsWith(', ')) {
    formattedTime = formattedTime.substring(0, formattedTime.length - 2);
  }
  final df = DateFormat('dd/MM/yyyy HH:mm');
  final desc = (counter.description?.trim().isNotEmpty == true) ? counter.description!.trim() : null;
  final cat = (counter.category?.trim().isNotEmpty == true) ? counter.category!.trim() : null;
  final url = (counter.registrationUrl?.trim().isNotEmpty == true) ? counter.registrationUrl!.trim() : null;
  final buffer = StringBuffer();
  buffer.writeln('📊 **${counter.name}**');
  buffer.writeln();
  if (desc != null) buffer.writeln(desc);
  buffer.writeln();
  buffer.writeln('📅 **Data do evento:** ${df.format(effectiveDate)}');
  if (cat != null) buffer.writeln('🏷️ **Categoria:** $cat');
  buffer.writeln('⏰ **Tempo ${timeText.toLowerCase()}:** ${formattedTime.isNotEmpty ? formattedTime : 'menos de 1 segundo'}');
  if (url != null) buffer.writeln('🔗 $url');
  buffer.writeln();
  buffer.writeln('📱 Compartilhado por PlanRace');
  return buffer.toString();
}