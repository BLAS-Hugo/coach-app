/// Diacritics that appear in French exercise names, and their bare forms.
///
/// Deliberately a small table rather than full Unicode normalisation: the
/// input is exercise names a user types on a phone, and pulling in a
/// normalisation library to fold six vowels would be the more expensive
/// answer to a smaller problem.
const _foldedCharacters = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
};

final _whitespace = RegExp(r'\s+');

/// The comparison key for a user-typed name.
///
/// Lowercased, trimmed, inner whitespace collapsed, and diacritics folded
/// away, so "Élévations latérales" and "elevations laterales" are the same
/// exercise. Two spellings of one movement would otherwise split its
/// history in half, which is the only reason exercises carry an identity
/// (PRD §4.5).
///
/// Used for matching and for ordering, never for storage: what the user
/// typed is what gets displayed.
String foldForSearch(String value) {
  final folded = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    folded.write(_foldedCharacters[character] ?? character);
  }
  return folded.toString().trim().replaceAll(_whitespace, ' ');
}
