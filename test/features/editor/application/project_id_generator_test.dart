import 'package:daw_webapp/features/editor/application/project_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistent entity generators emit namespaced UUID v4 IDs', () {
    final generator = ProjectIdGenerator();
    final ids = <String>{};
    final factories = <String, String Function()>{
      'track': generator.newTrackId,
      'clip': generator.newClipId,
      'source': generator.newSourceId,
      'marker': generator.newMarkerId,
      'section': generator.newSectionId,
    };
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    for (final entry in factories.entries) {
      for (var index = 0; index < 50; index++) {
        final id = entry.value();
        expect(id, startsWith('${entry.key}-'));
        expect(uuidV4.hasMatch(id.substring(entry.key.length + 1)), isTrue);
        expect(ids.add(id), isTrue);
      }
    }
  });
}
