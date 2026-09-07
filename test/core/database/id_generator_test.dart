import 'package:coach_app/core/database/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('newId', () {
    test('returns a canonical 36-character UUID', () {
      final id = newId();
      expect(id, hasLength(36));
      expect(
        id,
        matches(
          RegExp(
            '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}'
            r'-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('sets the version nibble to 7', () {
      // Character 14 is the version. v7 is what makes ids sort by time.
      expect(newId()[14], '7');
    });

    test('sets the RFC 4122 variant bits', () {
      expect('89ab'.contains(newId()[19]), isTrue);
    });

    test('is unique across a tight loop', () {
      final ids = List.generate(1000, (_) => newId());
      expect(ids.toSet(), hasLength(1000));
    });

    test('sorts chronologically, which is the point of v7', () async {
      final first = newId();
      // v7's timestamp has millisecond resolution, so separate the samples.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = newId();
      expect(first.compareTo(second), lessThan(0));
    });
  });
}
