/// Curated [TMDB](https://www.themoviedb.org/) image paths — real posters & backdrops,
/// deterministic per [seed] so the same title always maps to the same art (no random photos).
abstract final class TvTmdbPlaceholders {
  static const String _host = 'https://image.tmdb.org/t/p';

  /// Portrait one-sheets (movie-style).
  static const List<String> _posterPaths = [
    '/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
    '/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
    '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    '/zSqJ1qFq8NXFfi7Je0YM3Z8wTwj.jpg',
    '/8UlWLLSIfJFEKPrRIWki6EMyXGc.jpg',
    '/heNkWamLuZqzF38fFv3OINUjzUY.jpg',
    '/wMqLk2jKjpwmyBMhbefv5ZaJvpC.jpg',
    '/fSRb7XeAPTmRUvVUfagMCBOaqGq.jpg',
    '/dxJvxTBcprD5Q2RKKJiBLvWt6c.jpg',
    '/n2CDJg0Xd6fRetzpclj3fQsDWEr.jpg',
    '/kcFVqNkv9FYMbWWKptDdVvEcUeR.jpg',
    '/6oom5QYQ2yQTMJIJnVBk37T4P07.jpg',
    '/8YftR4TpRbd62AGiZtblEZURJKR.jpg',
    '/svPW2JE5izHyI0HtXApJk1Om5Zl.jpg',
    '/lXhgpmFORZiHXVhYFFVK8iKQ4th.jpg',
    '/pWHf4khOloNVfCxscsXFj3jj6g.jpg',
    '/67HggiWaP9ZLvzsurpmuoTyEw1b.jpg',
    '/5qeq89ZHGY91YPsztiAMtYxsr4g.jpg',
    '/q4P9P5KGsLSc69FqEeC1Pgpk14a.jpg',
    '/cw6zHGola3AscWt6pSwGZIUGoJ6.jpg',
    '/fVIPRWG0RYrdgFhJCrW6k4Dhgdg.jpg',
    '/2kNqoyARnFYERDS5MLgKMuEGE1S.jpg',
    '/vSNxAJG8nkfwzWrNnNIV5jD1WJz.jpg',
    '/eku6pzsH4GxwBPWDk8dtbKiuh1f.jpg',
    '/aHx0W7C0fNtzHNA7ySBJfgi6LXZ.jpg',
    '/62HCnUTziyWcpDaBO2i1DX17ljH.jpg',
    '/orVBX5NV7JiKoAHrVLUZ04AgSC4.jpg',
    '/iOPdn3lBegqVK8yI5TsrgbCtFjn.jpg',
    '/rTharKtol7QhkgrYiCZSlA9piT.jpg',
    '/lFPH5PvncCSspHqvXRtqWr5m1Kr.jpg',
    '/1hRoyzDtpgnu7EhFd31nAWSq2qU.jpg',
  ];

  /// Wide cinematic stills for heroes & backdrops (TMDB-hosted, widely cached).
  static const List<String> _backdropPaths = [
    '/nMKdUUepR6iGcKKgpVGu2qnWZnk.jpg',
    '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
    '/xJHokMbljvjADYdit5fK5VQsXVS.jpg',
    '/uDO8zWDhfWwoFdKS4fMJUvyJsqp.jpg',
    '/fqP3LaMWWo4FwOVjWbRgIHTikl0.jpg',
    '/hiK4qc0uZrAqmcWUh2OgWKEUrwm.jpg',
    '/nlqUCWb2lp7nKMmEwM5MMXWvNxg.jpg',
    '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
    '/2I115CN7D3Qf3QkJQMITP0mUnru.jpg',
    '/46wpJ4qBQxiwBwd8pUbWrw16yAq.jpg',
    '/nMKdUUepR6iGcKKgpVGu2qnWZnk.jpg',
    '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
    '/xJHokMbljvjADYdit5fK5VQsXVS.jpg',
    '/uDO8zWDhfWwoFdKS4fMJUvyJsqp.jpg',
    '/fqP3LaMWWo4FwOVjWbRgIHTikl0.jpg',
    '/hiK4qc0uZrAqmcWUh2OgWKEUrwm.jpg',
    '/nlqUCWb2lp7nKMmEwM5MMXWvNxg.jpg',
    '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
  ];

  /// 16:9 frames for episode tiles (backdrop crops).
  static const List<String> _stillPaths = [
    '/nMKdUUepR6iGcKKgpVGu2qnWZnk.jpg',
    '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
    '/xJHokMbljvjADYdit5fK5VQsXVS.jpg',
    '/uDO8zWDhfWwoFdKS4fMJUvyJsqp.jpg',
    '/fqP3LaMWWo4FwOVjWbRgIHTikl0.jpg',
    '/hiK4qc0uZrAqmcWUh2OgWKEUrwm.jpg',
    '/nlqUCWb2lp7nKMmEwM5MMXWvNxg.jpg',
    '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
    '/2I115CN7D3Qf3QkJQMITP0mUnru.jpg',
    '/46wpJ4qBQxiwBwd8pUbWrw16yAq.jpg',
  ];

  static int _ix(String seed, int n) {
    if (n <= 0) return 0;
    return seed.hashCode.abs() % n;
  }

  /// ~2:3 theatrical poster.
  static String posterForSeed(String seed) =>
      '$_host/w500${_posterPaths[_ix(seed, _posterPaths.length)]}';

  /// ~16:9 cinematic backdrop.
  static String backdropForSeed(String seed) =>
      '$_host/w1280${_backdropPaths[_ix(seed, _backdropPaths.length)]}';

  /// Slightly different hash bucket for “episode” art so neighbors differ.
  static String stillForSeed(String seed) {
    final i = _ix('still_$seed', _stillPaths.length);
    return '$_host/w780${_stillPaths[i]}';
  }

  /// Square-ish key art for channel tiles (uses poster crop).
  static String channelArtForSeed(String seed) =>
      '$_host/w342${_posterPaths[_ix('ch_$seed', _posterPaths.length)]}';
}
