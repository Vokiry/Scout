import 'dart:async';
import 'dart:math';

import 'socket_manager.dart';

class ReconnectionManager {
  final SocketTransport _socketManager;
  final ReconnectionConfig _config;

  bool _isRunning = false;
  int _attempt = 0;
  Timer? _timer;
  String? _host;
  int? _port;

  final _stateController = StreamController<ReconnectionState>.broadcast();

  ReconnectionManager(this._socketManager, {ReconnectionConfig? config})
      : _config = config ?? ReconnectionConfig();

  Stream<ReconnectionState> get stateChanges => _stateController.stream;
  ReconnectionState get state => ReconnectionState(
    isRunning: _isRunning,
    attempt: _attempt,
    nextDelay: _calculateDelay(),
    lastError: null,
  );

  void start(String host, int port) {
    _host = host;
    _port = port;
    _isRunning = true;
    _attempt = 0;
    _socketManager.stateChanges.listen(_onSocketStateChange);
    _tryReconnect();
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _attempt = 0;
    _emitState();
  }

  void reset() {
    _attempt = 0;
    _timer?.cancel();
    _emitState();
  }

  void _onSocketStateChange(SocketStateChanged event) {
    if (event.state == SocketState.connected) {
      _isRunning = false;
      _attempt = 0;
      _timer?.cancel();
      _emitState();
    } else if (event.state == SocketState.disconnected && _isRunning) {
      _scheduleReconnect(event.errorMessage);
    }
  }

  void _scheduleReconnect([String? errorMessage]) {
    _timer?.cancel();
    final delay = _calculateDelay();
    _attempt++;
    _emitState(errorMessage: errorMessage);

    _timer = Timer(delay, _tryReconnect);
  }

  void _tryReconnect() {
    if (!_isRunning || _host == null || _port == null) return;

    if (_config.maxAttempts >= 0 && _attempt >= _config.maxAttempts) {
      _isRunning = false;
      _emitState(isFinal: true);
      return;
    }

    _socketManager.connect(_host!, _port!).catchError((_) {});
  }

  Duration _calculateDelay() {
    if (_attempt == 0) return Duration.zero;
    final baseMs = _config.baseDelay.inMilliseconds;
    final maxMs = _config.maxDelay.inMilliseconds;
    final delay = min(baseMs * pow(_config.multiplier, _attempt - 1).toInt(), maxMs);
    final jitter = _config.jitterMs > 0
        ? Random().nextInt(_config.jitterMs) - (_config.jitterMs ~/ 2)
        : 0;
    return Duration(milliseconds: delay + jitter);
  }

  void _emitState({String? errorMessage, bool isFinal = false}) {
    if (_stateController.isClosed) return;
    _stateController.add(ReconnectionState(
      isRunning: _isRunning,
      attempt: _attempt,
      nextDelay: _calculateDelay(),
      lastError: errorMessage,
      isFinal: isFinal,
    ));
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}

class ReconnectionConfig {
  final Duration baseDelay;
  final Duration maxDelay;
  final double multiplier;
  final int maxAttempts;
  final int jitterMs;

  const ReconnectionConfig({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
    this.multiplier = 2.0,
    this.maxAttempts = -1, // -1 means unlimited
    this.jitterMs = 1000,
  });
}

class ReconnectionState {
  final bool isRunning;
  final int attempt;
  final Duration nextDelay;
  final String? lastError;
  final bool isFinal;

  const ReconnectionState({
    required this.isRunning,
    required this.attempt,
    required this.nextDelay,
    this.lastError,
    this.isFinal = false,
  });
}
