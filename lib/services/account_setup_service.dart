import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'local_cache_service.dart';

class AccountSetupState {
  const AccountSetupState({
    required this.requiresCompanySetup,
    this.email,
    this.fullName,
    this.pendingCompanyName,
  });

  final bool requiresCompanySetup;
  final String? email;
  final String? fullName;
  final String? pendingCompanyName;
}

class AccountSetupService {
  AccountSetupService._();

  static final AccountSetupService instance = AccountSetupService._();

  SupabaseClient get _client => Supabase.instance.client;

  User? get _currentUser => _client.auth.currentUser;

  Future<AccountSetupState> fetchCurrentState() async {
    return _fetchCurrentStateInternal();
  }

  Future<AccountSetupState> _fetchCurrentStateInternal({
    bool allowJwtRetry = true,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nao existe utilizador autenticado.');
    }

    final fallbackFullName = _readNonEmpty(user.userMetadata?['full_name']);
    final fallbackCompanyName = _readNonEmpty(
      user.userMetadata?['pending_company_name'],
    );

    try {
      final data = await _client
          .from('profiles')
          .select('company_id, full_name')
          .eq('id', user.id)
          .maybeSingle();

      final resolvedState = data == null
          ? AccountSetupState(
              requiresCompanySetup: true,
              email: user.email,
              fullName: fallbackFullName,
              pendingCompanyName: fallbackCompanyName,
            )
          : AccountSetupState(
              requiresCompanySetup:
                  _readNonEmpty(
                    Map<String, dynamic>.from(data)['company_id'],
                  ) ==
                  null,
              email: user.email,
              fullName:
                  _readNonEmpty(Map<String, dynamic>.from(data)['full_name']) ??
                  fallbackFullName,
              pendingCompanyName: fallbackCompanyName,
            );

      await LocalCacheService.instance.writeJson(
        _cacheKeyForUser(user.id),
        _stateToMap(resolvedState),
      );
      return resolvedState;
    } catch (error) {
      if (allowJwtRetry && _isInvalidJwtError(error)) {
        final refreshed = await _refreshSessionIfPossible();
        if (refreshed) {
          return _fetchCurrentStateInternal(allowJwtRetry: false);
        }
      }

      final cached = await LocalCacheService.instance.readJsonMap(
        _cacheKeyForUser(user.id),
      );
      if (cached != null) {
        return _stateFromMap(cached);
      }
      rethrow;
    }
  }

  Future<void> bootstrapNewCompany({
    required String fullName,
    required String companyName,
  }) async {
    await _bootstrapNewCompanyInternal(
      fullName: fullName,
      companyName: companyName,
    );
  }

  Future<void> _bootstrapNewCompanyInternal({
    required String fullName,
    required String companyName,
    bool allowJwtRetry = true,
  }) async {
    await _refreshSessionIfPossible();

    try {
      await _client.functions.invoke(
        'account-bootstrap',
        body: {
          'full_name': fullName.trim(),
          'company_name': companyName.trim(),
        },
      );
    } on FunctionException catch (error) {
      if (allowJwtRetry && _isInvalidJwtError(error)) {
        final refreshed = await _refreshSessionIfPossible();
        if (refreshed) {
          return _bootstrapNewCompanyInternal(
            fullName: fullName,
            companyName: companyName,
            allowJwtRetry: false,
          );
        }
      }
      rethrow;
    }

    await _refreshSessionIfPossible();
  }

  String? _readNonEmpty(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Future<bool> _refreshSessionIfPossible() async {
    try {
      return await AuthService.instance.refreshSessionIfPossible();
    } catch (_) {
      return false;
    }
  }

  String _cacheKeyForUser(String userId) => 'account_setup_state:$userId';

  Map<String, dynamic> _stateToMap(AccountSetupState state) {
    return {
      'requires_company_setup': state.requiresCompanySetup,
      'email': state.email,
      'full_name': state.fullName,
      'pending_company_name': state.pendingCompanyName,
    };
  }

  AccountSetupState _stateFromMap(Map<String, dynamic> map) {
    return AccountSetupState(
      requiresCompanySetup: map['requires_company_setup'] == true,
      email: _readNonEmpty(map['email']),
      fullName: _readNonEmpty(map['full_name']),
      pendingCompanyName: _readNonEmpty(map['pending_company_name']),
    );
  }

  String extractFunctionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final direct = _readNonEmpty(details['error']);
      if (direct != null) return direct;
      final message = _readNonEmpty(details['message']);
      if (message != null) return message;
    }

    final text = _readNonEmpty(details);
    if (text != null) return text;

    final reason = _readNonEmpty(error.reasonPhrase);
    if (reason != null) return reason;

    return 'Nao foi possivel concluir a criacao da empresa.';
  }

  bool isBootstrapFunctionMissing(Object error) {
    if (error is! FunctionException) return false;
    final details = error.details?.toString().toLowerCase() ?? '';
    final reason = error.reasonPhrase?.toLowerCase() ?? '';
    return details.contains('account-bootstrap') ||
        details.contains('function') && details.contains('not found') ||
        reason.contains('not found');
  }

  bool _isInvalidJwtError(Object error) {
    if (error is AuthException) {
      final code = error.code?.toLowerCase().trim() ?? '';
      final message = error.message.toLowerCase();
      return code == 'bad_jwt' ||
          message.contains('invalid jwt') ||
          message.contains('jwt');
    }

    if (error is PostgrestException) {
      final text = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
          .toLowerCase();
      return text.contains('invalid jwt') || text.contains('jwt');
    }

    if (error is FunctionException) {
      final text = '${error.reasonPhrase ?? ''} ${error.details ?? ''}'
          .toLowerCase();
      return text.contains('invalid jwt') || text.contains('jwt');
    }

    final text = error.toString().toLowerCase();
    return text.contains('invalid jwt') || text.contains('jwt');
  }
}
