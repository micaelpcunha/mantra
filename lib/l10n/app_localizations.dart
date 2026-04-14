import 'package:flutter/material.dart';

import '../config/branding.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('pt'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'pt': {
      'appTitle': productName,
      'loginError': 'Erro no login',
      'password': 'Palavra-passe',
      'login': 'Entrar',
      'assets': 'Ativos',
      'locations': 'Locais',
      'technicians': 'Tecnicos',
      'alerts': 'Alertas',
      'workOrders': 'Ordens de trabalho',
      'myWorkOrders': 'Minhas ordens',
      'newAsset': 'Novo ativo',
      'newLocation': 'Nova localizacao',
      'newTechnician': 'Novo tecnico',
      'newWorkOrder': 'Nova ordem',
      'changeViewForTests': 'Mudar vista para testes',
      'logout': 'Terminar sessao',
      'technicianInSimulation': 'Tecnico em simulacao',
      'testView': 'Vista para testes',
      'administrator': 'Administrador',
      'technician': 'Tecnico',
      'chooseAsset': 'Escolher ativo',
      'noNamedAsset': 'Sem nome',
      'noAssetsForWorkOrder': 'Nao existem ativos para associar a ordem.',
      'language': 'Idioma',
      'portuguese': 'Portugues',
      'english': 'Ingles',
      'profileLoadError': 'Nao foi possivel carregar o perfil.',
    },
    'en': {
      'appTitle': productName,
      'loginError': 'Login error',
      'password': 'Password',
      'login': 'Sign in',
      'assets': 'Assets',
      'locations': 'Locations',
      'technicians': 'Technicians',
      'alerts': 'Alerts',
      'workOrders': 'Work orders',
      'myWorkOrders': 'My work orders',
      'newAsset': 'New asset',
      'newLocation': 'New location',
      'newTechnician': 'New technician',
      'newWorkOrder': 'New work order',
      'changeViewForTests': 'Switch test view',
      'logout': 'Sign out',
      'technicianInSimulation': 'Technician in simulation',
      'testView': 'Test view',
      'administrator': 'Administrator',
      'technician': 'Technician',
      'chooseAsset': 'Choose asset',
      'noNamedAsset': 'Unnamed',
      'noAssetsForWorkOrder': 'There are no assets available for this work order.',
      'language': 'Language',
      'portuguese': 'Portuguese',
      'english': 'English',
      'profileLoadError': 'Could not load the profile.',
    },
  };

  String _text(String key) =>
      _localizedValues[locale.languageCode]?[key] ??
      _localizedValues['pt']![key] ??
      key;

  String get appTitle => _text('appTitle');
  String get loginError => _text('loginError');
  String get password => _text('password');
  String get login => _text('login');
  String get assets => _text('assets');
  String get locations => _text('locations');
  String get technicians => _text('technicians');
  String get alerts => _text('alerts');
  String get workOrders => _text('workOrders');
  String get myWorkOrders => _text('myWorkOrders');
  String get newAsset => _text('newAsset');
  String get newLocation => _text('newLocation');
  String get newTechnician => _text('newTechnician');
  String get newWorkOrder => _text('newWorkOrder');
  String get changeViewForTests => _text('changeViewForTests');
  String get logout => _text('logout');
  String get technicianInSimulation => _text('technicianInSimulation');
  String get testView => _text('testView');
  String get administrator => _text('administrator');
  String get technician => _text('technician');
  String get chooseAsset => _text('chooseAsset');
  String get noNamedAsset => _text('noNamedAsset');
  String get noAssetsForWorkOrder => _text('noAssetsForWorkOrder');
  String get language => _text('language');
  String get portuguese => _text('portuguese');
  String get english => _text('english');
  String get profileLoadError => _text('profileLoadError');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
