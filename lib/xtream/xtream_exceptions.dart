class XtreamBadUrlException implements Exception {
  XtreamBadUrlException(this.message);
  final String message;

  @override
  String toString() => message;
}

class XtreamAuthException implements Exception {
  XtreamAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class XtreamNetworkException implements Exception {
  XtreamNetworkException(this.message);
  final String message;

  @override
  String toString() => message;
}

class XtreamParseException implements Exception {
  XtreamParseException(this.message);
  final String message;

  @override
  String toString() => message;
}
