/// Language picker labels **always in English** so anyone can find and change
/// the interface language even when the rest of the UI is in another locale.
class LanguagePickerEnglish {
  LanguagePickerEnglish._();

  static const settingsTitle = 'Language';
  static const settingsSubtitle = 'Interface language';
  static const screenTitle = 'Language';

  static const english = 'English';
  static const hebrew = 'Hebrew';
  static const french = 'French';
  static const spanish = 'Spanish';
  static const arabic = 'Arabic';

  static String nameForCode(String code) => switch (code) {
        'en' => english,
        'he' => hebrew,
        'fr' => french,
        'es' => spanish,
        'ar' => arabic,
        _ => code,
      };
}
