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