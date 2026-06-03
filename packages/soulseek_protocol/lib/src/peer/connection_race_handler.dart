/// Handles the Soulseek connection race condition.
///
/// When two peers attempt to connect to each other simultaneously,
/// both will initiate TCP connections. The "winner" is determined
/// by comparing the usernames and IP addresses:
///
/// 1. If the remote username is lexicographically greater than local,
///    the remote should accept our connection.
/// 2. If the local username is greater, we should accept their connection
///    and drop ours.
///
/// If both have the same username (impossible), compare IPs.
class ConnectionRaceHandler {
  final String _localUsername;
  final int _localIp;

  ConnectionRaceHandler({
    required String localUsername,
    required int localIp,
  })  : _localUsername = localUsername,
        _localIp = localIp;

  /// Returns true if we should initiate the connection (we are the "winner").
  bool shouldWeConnect(String remoteUsername, int remoteIp) {
    final usernameCompare = _localUsername.compareTo(remoteUsername);
    if (usernameCompare != 0) {
      return usernameCompare < 0;
    }
    return _localIp < remoteIp;
  }

  /// Returns true if the remote peer should initiate (they should connect to us).
  bool shouldRemoteConnect(String remoteUsername, int remoteIp) {
    return !shouldWeConnect(remoteUsername, remoteIp);
  }

  /// Determines if we should accept an incoming connection from this peer.
  bool shouldAcceptConnection(String remoteUsername, int remoteIp) {
    return shouldRemoteConnect(remoteUsername, remoteIp);
  }

  /// Determines if we should drop an outgoing connection in favor of
  /// an incoming one from the same peer (connection race resolution).
  bool shouldUseOutgoingOrIncoming(String remoteUsername, int remoteIp) {
    if (shouldWeConnect(remoteUsername, remoteIp)) {
      return true; // Use outgoing
    }
    return false; // Use incoming
  }
}
