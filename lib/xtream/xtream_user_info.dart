/// Parses Xtream `user_info.exp_date` (Unix seconds, string or int). `0` / empty = none.
int? xtreamParseExpDateUnix(Map<String, dynamic> userInfo) {
  final raw = userInfo['exp_date'];
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty || s == '0') return null;
  final v = int.tryParse(s);
  if (v == null || v <= 0) return null;
  return v;
}
