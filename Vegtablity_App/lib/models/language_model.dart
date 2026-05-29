class LanguageModel {
  final String languageCode;
  final String languageName;

  const LanguageModel(this.languageCode, this.languageName);

  static const List<LanguageModel> supportedLanguages = [
    LanguageModel('ar', 'العربية'),
    LanguageModel('en', 'English'),
  ];
}
