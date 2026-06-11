// Basic "looks like a real name" check — rejects digits, random symbols, and
// consonant-mash gibberish (e.g. "3289r0wf", "juf49wfj", "f0920nf").
bool isValidName(String input) {
  final s = input.trim();
  if (s.length < 2) return false;
  // letters plus a few name punctuation chars only — no digits/symbols
  if (!RegExp(r"^[A-Za-z][A-Za-z .'-]*$").hasMatch(s)) return false;
  // must contain at least one vowel
  if (!RegExp(r"[AEIOUaeiou]").hasMatch(s)) return false;
  return true;
}
