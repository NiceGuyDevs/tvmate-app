/// Thrown when the downloaded bytes look like an HLS master/variant playlist, not a single media file.
class VodHlsPlaylistException implements Exception {
  const VodHlsPlaylistException();
}

/// Visible file name (sanitized title + extension).
///
/// [httpContentType] is preferred (e.g. `video/mp4`). Many IPTV URLs end in `.php`
/// or similar — those are **not** real file extensions; we fall back to [mp4].
String vodDownloadSuggestedFileName(
  String title,
  String streamUrl, {
  String? httpContentType,
}) {
  final fromMime = _extensionFromContentType(httpContentType);
  final fromUrl = _extensionFromUrl(streamUrl);
  final ext = fromMime ?? fromUrl;
  final base = _sanitizeFileBase(title);
  return '$base.$ext';
}

/// Gateways often use `movie/.../12345.php` — treat script extensions as unknown.
const _bogusPathExtensions = <String>{
  'php',
  'html',
  'htm',
  'asp',
  'aspx',
  'jsp',
  'cgi',
  'pl',
  'py',
  'do',
  'action',
  'xml',
  'json',
  'ashx',
};

const _knownVideoExtensions = <String>{
  'mp4',
  'mkv',
  'ts',
  'm2ts',
  'avi',
  'mov',
  'webm',
  'm4v',
  'mpg',
  'mpeg',
  'flv',
  'wmv',
  '3gp',
};

String? _extensionFromContentType(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final mime = raw.split(';').first.trim().toLowerCase();
  switch (mime) {
    case 'video/mp4':
      return 'mp4';
    case 'video/webm':
      return 'webm';
    case 'video/quicktime':
      return 'mov';
    case 'video/x-msvideo':
      return 'avi';
    case 'video/x-matroska':
      return 'mkv';
    case 'video/mp2t':
      return 'ts';
    case 'video/mpeg':
      return 'mpeg';
    case 'video/x-flv':
      return 'flv';
    default:
      return null;
  }
}

String _extensionFromUrl(String url) {
  try {
    final segments = Uri.parse(url).pathSegments;
    if (segments.isEmpty) return 'mp4';
    final seg = segments.last;
    if (seg.contains('.')) {
      final ext = seg.split('.').last.toLowerCase();
      if (ext.length <= 6 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
        if (_bogusPathExtensions.contains(ext)) {
          return 'mp4';
        }
        if (_knownVideoExtensions.contains(ext)) {
          return ext;
        }
        // Unknown short extension from URL — default to mp4 (not .php/.html etc.)
        return 'mp4';
      }
    }
  } catch (_) {}
  return 'mp4';
}

String _sanitizeFileBase(String title) {
  var s = title
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  while (s.startsWith('.')) {
    s = s.length > 1 ? s.substring(1) : '';
  }
  if (s.isEmpty) return 'video';
  if (s.length > 120) s = s.substring(0, 120);
  return s;
}

/// Human-readable size for the download strip (e.g. `12.4 MB`).
String vodDownloadFormatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
