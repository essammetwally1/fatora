class SearchUtils {
  static final RegExp _arabicDiacriticsRegex = RegExp(r'[\u064B-\u065F\u0670]');
  static final RegExp _alefVariantsRegex = RegExp(r'[أإآٱ]');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  const SearchUtils._();

  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(_arabicDiacriticsRegex, '')
        .replaceAll(_alefVariantsRegex, 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(_whitespaceRegex, ' ');
  }
}
