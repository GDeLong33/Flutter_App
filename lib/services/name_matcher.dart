/// Loose player-name matching that tolerates case, punctuation and suffixes:
/// "Devonta Smith" == "DeVonta Smith", "James Cook" == "James Cook III",
/// "Harold Fannin" == "Harold Fannin Jr.".
class NameMatcher {
  static const _suffixes = {'jr', 'sr', 'ii', 'iii', 'iv', 'v'};

  static String normalize(String name) {
    final words = name
        .toLowerCase()
        .replaceAll(RegExp(r"[.'’`-]"), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    while (words.length > 1 && _suffixes.contains(words.last)) {
      words.removeLast();
    }
    return words.join(' ');
  }

  static bool matches(String a, String b) => normalize(a) == normalize(b);
}
