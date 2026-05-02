/// Heuristic: **Hebrew-dominant** EPG text → RTL layout in the hero; otherwise LTR.
///
/// Counts Hebrew letters (Unicode **U+0590–U+05FF**) vs basic Latin letters.
bool isHebrewDominantEpg(String title, String description) {
  final t = '$title $description';
  var he = 0;
  var lat = 0;
  for (final c in t.runes) {
    if (c >= 0x0590 && c <= 0x05ff) {
      he++;
    } else if ((c >= 0x0041 && c <= 0x005a) ||
        (c >= 0x0061 && c <= 0x007a)) {
      lat++;
    }
  }
  if (he == 0 && lat == 0) return false;
  return he >= lat;
}
