import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionRaceHandler', () {
    group('shouldWeConnect', () {
      test('local username < remote username -> should connect', () {
        final handler = ConnectionRaceHandler(localUsername: 'alice', localIp: 1);
        expect(handler.shouldWeConnect('bob', 2), isTrue);
      });

      test('local username > remote username -> should not connect', () {
        final handler = ConnectionRaceHandler(localUsername: 'zara', localIp: 1);
        expect(handler.shouldWeConnect('bob', 2), isFalse);
      });

      test('same username, local IP < remote IP -> should connect', () {
        final handler = ConnectionRaceHandler(localUsername: 'alice', localIp: 0x01010101);
        expect(handler.shouldWeConnect('alice', 0x02020202), isTrue);
      });

      test('same username, local IP > remote IP -> should not connect', () {
        final handler = ConnectionRaceHandler(localUsername: 'alice', localIp: 0x02020202);
        expect(handler.shouldWeConnect('alice', 0x01010101), isFalse);
      });

      test('same username and IP -> should not connect (equal)', () {
        final handler = ConnectionRaceHandler(localUsername: 'alice', localIp: 1);
        expect(handler.shouldWeConnect('alice', 1), isFalse);
      });

      test('empty usernames are compared lexicographically', () {
        final handler = ConnectionRaceHandler(localUsername: '', localIp: 1);
        // '' < 'a', so local username < remote username -> should connect
        expect(handler.shouldWeConnect('a', 2), isTrue);
      });
    });

    group('shouldRemoteConnect', () {
      test('mirrors shouldWeConnect', () {
        final handler = ConnectionRaceHandler(localUsername: 'alice', localIp: 1);
        final weConnect = handler.shouldWeConnect('bob', 2);
        expect(handler.shouldRemoteConnect('bob', 2), isNot(equals(weConnect)));
      });
    });

    group('shouldAcceptConnection', () {
      test('accept when remote should connect', () {
        // local > remote, so remote should connect -> we accept
        final handler = ConnectionRaceHandler(localUsername: 'zara', localIp: 1);
        expect(handler.shouldAcceptConnection('alice', 2), isTrue);
      });

      test('reject when we should connect', () {
        // local < remote, so we should connect -> we do not accept incoming
        final handler = ConnectionRaceHandler(localUsername: 'alice', localIp: 1);
        expect(handler.shouldAcceptConnection('bob', 2), isFalse);
      });
    });

    group('shouldUseOutgoingOrIncoming', () {
      test('returns true when we should use outgoing', () {
        final handler = ConnectionRaceHandler(localUsername: 'alice', localIp: 1);
        // local < remote -> we connect -> use outgoing
        expect(handler.shouldUseOutgoingOrIncoming('bob', 2), isTrue);
      });

      test('returns false when we should use incoming', () {
        final handler = ConnectionRaceHandler(localUsername: 'zara', localIp: 1);
        expect(handler.shouldUseOutgoingOrIncoming('alice', 2), isFalse);
      });
    });
  });
}
