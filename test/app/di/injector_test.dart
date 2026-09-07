import 'package:coach_app/app/di/injector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('configureDependencies', () {
    tearDown(resetDependencies);

    test('completes and leaves the locator ready', () async {
      await configureDependencies();
      expect(getIt.allReadySync(), isTrue);
    });

    test('is safe to run again after a reset', () async {
      await configureDependencies();
      await resetDependencies();
      await expectLater(configureDependencies(), completes);
    });
  });
}
