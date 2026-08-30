import 'package:daw_webapp/features/editor/domain/export_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'export filename is safe and contains exactly one selected extension',
    () {
      expect(exportFileName('  song.mp3  ', ExportFormat.mp3), 'song.mp3');
      expect(exportFileName('song.wav', ExportFormat.mp3), 'song.mp3');
      expect(
        exportFileName(r'bad:/name?.wav', ExportFormat.wav),
        'bad--name-.wav',
      );
    },
  );

  test('WAV and MP3 size estimates use their authoritative formulas', () {
    expect(
      estimateExportBytes(
        format: ExportFormat.wav,
        durationSeconds: 10,
        sampleRate: 48000,
        channelCount: 2,
      ),
      44 + 10 * 48000 * 2 * 2,
    );
    expect(
      estimateExportBytes(
        format: ExportFormat.mp3,
        durationSeconds: 10,
        sampleRate: 48000,
        channelCount: 2,
        mp3BitrateKbps: 256,
      ),
      322048,
    );
  });
}
