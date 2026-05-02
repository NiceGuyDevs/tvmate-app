import 'package:flutter_test/flutter_test.dart';
import 'package:tvmatepro/player/mock_stream_urls.dart';

void main() {
  test('demo HLS URLs are hosted HTTPS m3u8 endpoints', () {
    for (final u in kDemoHlsUrls) {
      expect(u, startsWith('https://'));
      expect(u, contains('.m3u8'));
    }
    expect(mockLiveStreamUrlForChannel('ch1'), isNotEmpty);
    expect(mockVodStreamUrlForMovie('m1'), isNotEmpty);
    expect(mockVodStreamUrlForEpisode('e1'), isNotEmpty);
  });
}
