/// Public demo HLS endpoints for builds without a real playlist.
/// Apple stream is a standard test asset; Mux stream is widely used for player QA.

const String kAppleBipbopHls =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';

const String kAppleAdvancedFmp4Hls =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_fmp4/master.m3u8';

const String kMuxBigBuckBunnyHls =
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

const List<String> kDemoHlsUrls = [
  kAppleBipbopHls,
  kMuxBigBuckBunnyHls,
  kAppleAdvancedFmp4Hls,
];

/// Single canonical demo stream for empty-library mode (live, movies, series).
const String kTvMateSingleDemoHls = kAppleBipbopHls;

String mockLiveStreamUrlForChannel(String channelId) {
  return kTvMateSingleDemoHls;
}

String mockVodStreamUrlForMovie(String movieId) {
  return kTvMateSingleDemoHls;
}

String mockVodStreamUrlForEpisode(String episodeId) {
  return kTvMateSingleDemoHls;
}
