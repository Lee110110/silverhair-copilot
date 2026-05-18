class Protocol {
  // Message types
  static const sessionJoin = 'session.join';
  static const sessionReady = 'session.ready';
  static const sessionEnd = 'session.end';
  static const sessionPeerDisconnect = 'session.peer_disconnect';
  static const frameScreen = 'frame.screen';
  static const frameAck = 'frame.ack';
  static const annotationStart = 'annotation.start';
  static const annotationStroke = 'annotation.stroke';
  static const annotationEnd = 'annotation.end';
  static const annotationClear = 'annotation.clear';
  static const annotationClearAll = 'annotation.clear_all';
  static const sosAlert = 'sos.alert';
  static const sosAccept = 'sos.accept';
  static const sosCancel = 'sos.cancel';
  static const heartbeatPing = 'heartbeat.ping';
  static const heartbeatPong = 'heartbeat.pong';

  static Map<String, dynamic> createMessage({
    required String type,
    String? sessionId,
    Map<String, dynamic> payload = const {},
  }) {
    return {
      'type': type,
      if (sessionId != null) 'session_id': sessionId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    };
  }
}