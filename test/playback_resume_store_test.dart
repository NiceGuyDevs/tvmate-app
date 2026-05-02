import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tvmatepro/player/playback_resume_store.dart';

void main() {
  test('save and read resume ms', () async {
    SharedPreferences.setMockInitialValues({});
    await PlaybackResumeStore.setResumePositionMs('movie_x', 42000);
    expect(await PlaybackResumeStore.getResumePositionMs('movie_x'), 42000);
    await PlaybackResumeStore.clear('movie_x');
    expect(await PlaybackResumeStore.getResumePositionMs('movie_x'), isNull);
  });
}
