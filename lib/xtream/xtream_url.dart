import 'xtream_exceptions.dart';

/// Root URI for stream paths (`/live`, `/movie`, `/series`) — includes subfolder if present.
Uri xtreamStreamRootUri(String rawBase) {
  var s = rawBase.trim();
  if (s.isEmpty) {
    throw XtreamBadUrlException('Server URL is empty.');
  }
  s = s.replaceAll(RegExp(r'/+$'), '');
  if (!s.contains('://')) {
    s = 'http://$s';
  }
  Uri uri;
  try {
    uri = Uri.parse(s);
  } catch (_) {
    throw XtreamBadUrlException('Could not parse server URL.');
  }
  if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw XtreamBadUrlException('Server URL must use http or https.');
  }
  if (uri.host.isEmpty) {
    throw XtreamBadUrlException('Server URL is missing a host.');
  }
  return uri.replace(query: '', fragment: '');
}

/// `player_api.php` next to the same path prefix as the panel URL.
Uri xtreamPlayerApiUri(String rawBase) {
  final root = xtreamStreamRootUri(rawBase);
  var p = root.path;
  if (p.endsWith('/')) p = p.substring(0, p.length - 1);
  final apiPath = p.isEmpty ? '/player_api.php' : '$p/player_api.php';
  return root.replace(path: apiPath, queryParameters: const {});
}
