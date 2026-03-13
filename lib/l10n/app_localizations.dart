import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  String get appTitle => locale.languageCode == 'zh' ? 'lbpSSH' : 'lbpSSH';
  String get connect => locale.languageCode == 'zh' ? '连接' : 'Connect';
  String get disconnect => locale.languageCode == 'zh' ? '断开' : 'Disconnect';
  String get noConnection => locale.languageCode == 'zh' ? '暂无保存的连接' : 'No saved connections';
  String get createLocalTerminal => locale.languageCode == 'zh' ? '创建本地终端' : 'Create Local Terminal';
  String get clickToConnect => locale.languageCode == 'zh' ? '点击左侧连接以打开终端' : 'Click a connection on the left to open terminal';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
