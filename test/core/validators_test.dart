import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('isNonEmptyTrimmed', () {
      expect(Validators.isNonEmptyTrimmed('  hi '), isTrue);
      expect(Validators.isNonEmptyTrimmed('   '), isFalse);
      expect(Validators.isNonEmptyTrimmed(null), isFalse);
    });

    test('geo ranges', () {
      expect(Validators.isValidLatitude(90), isTrue);
      expect(Validators.isValidLatitude(-91), isFalse);
      expect(Validators.isValidLongitude(180), isTrue);
      expect(Validators.isValidLongitude(-181), isFalse);
    });

    test('speed and battery', () {
      expect(Validators.isValidSpeed(-1), isFalse);
      expect(Validators.isValidSpeed(0), isTrue);
      expect(Validators.isValidBattery(100), isTrue);
      expect(Validators.isValidBattery(101), isFalse);
    });

    test('message', () {
      expect(Validators.isValidMessage('   '), isFalse);
      expect(Validators.isValidMessage('hello'), isTrue);
      expect(Validators.isValidMessage('x' * 5000), isFalse);
    });

    test('poll options need at least two', () {
      expect(Validators.isValidPollOptions(['a']), isFalse);
      expect(Validators.isValidPollOptions(['a', 'b']), isTrue);
      expect(Validators.isValidPollOptions(['a', '  ', '']), isFalse);
    });

    test('route points need at least one valid point', () {
      expect(Validators.isValidRoutePoints([]), isFalse);
      expect(
        Validators.isValidRoutePoints([
          (lat: 0, lng: 0),
          (lat: 91, lng: 0),
        ]),
        isFalse,
      );
      expect(
        Validators.isValidRoutePoints([(lat: 50, lng: 30)]),
        isTrue,
      );
    });
  });
}
