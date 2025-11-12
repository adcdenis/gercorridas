import 'package:characters/characters.dart';

String normalizeCategory(String input) {
  var s = input.trim().toLowerCase();
  s = _removeDiacritics(s);
  s = s.replaceAll(RegExp(r"[\s_]+"), '-');
  s = s.replaceAll(RegExp(r"[^a-z0-9-]"), '');
  s = s.replaceAll(RegExp(r"-+"), '-');
  return s;
}

String _removeDiacritics(String s) {
  const map = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'Á': 'a', 'À': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a',
    'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
    'É': 'e', 'Ê': 'e', 'È': 'e', 'Ë': 'e',
    'í': 'i', 'î': 'i', 'ì': 'i', 'ï': 'i',
    'Í': 'i', 'Î': 'i', 'Ì': 'i', 'Ï': 'i',
    'ó': 'o', 'ô': 'o', 'ò': 'o', 'õ': 'o', 'ö': 'o',
    'Ó': 'o', 'Ô': 'o', 'Ò': 'o', 'Õ': 'o', 'Ö': 'o',
    'ú': 'u', 'û': 'u', 'ù': 'u', 'ü': 'u',
    'Ú': 'u', 'Û': 'u', 'Ù': 'u', 'Ü': 'u',
    'ç': 'c', 'Ç': 'c',
    'ñ': 'n', 'Ñ': 'n'
  };
  final buffer = StringBuffer();
  for (final ch in s.characters) {
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString();
}