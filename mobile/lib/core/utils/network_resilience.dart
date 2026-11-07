/// Centralized network error and TLS handshake exception detector.
/// Detects when cloud network calls fail due to carrier filtering, TLS termination,
/// DNS failures, or offline state, allowing graceful fallback to local data.
bool isNetworkOrHandshakeError(dynamic e) {
  if (e == null) return false;
  final str = e.toString().toLowerCase();
  return str.contains('handshake') ||
      str.contains('connection terminated') ||
      str.contains('socketexception') ||
      str.contains('failed host lookup') ||
      str.contains('no address associated') ||
      str.contains('connection refused') ||
      str.contains('clientexception') ||
      str.contains('timeout') ||
      str.contains('errno = 7') ||
      str.contains('errno = 104') ||
      str.contains('network is unreachable') ||
      str.contains('software caused connection abort') ||
      str.contains('connection reset') ||
      str.contains('os error');
}
