import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyScopeService {
  CompanyScopeService._();

  static final CompanyScopeService instance = CompanyScopeService._();

  SupabaseClient get _client => Supabase.instance.client;

  final Map<String, bool> _tableSupportsCompanyIdCache = {};
  final Map<String, bool> _tableSupportsColumnCache = {};
  String? _cachedCompanyId;
  String? _cachedUserId;
  bool _didResolveCompanyId = false;

  Future<String?> currentCompanyId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _clearCompanyCache();
      return null;
    }

    if (_didResolveCompanyId && _cachedUserId == user.id) {
      return _cachedCompanyId;
    }

    _cachedUserId = user.id;
    _didResolveCompanyId = true;

    try {
      final data = await _client
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();

      final companyId = data?['company_id']?.toString().trim();
      _cachedCompanyId = companyId == null || companyId.isEmpty
          ? null
          : companyId;
      return _cachedCompanyId;
    } on PostgrestException catch (error) {
      if (isMissingCompanyColumnError(error)) {
        _cachedCompanyId = null;
        return null;
      }
      rethrow;
    }
  }

  Future<bool> tableSupportsCompanyId(String table) async {
    final cached = _tableSupportsCompanyIdCache[table];
    if (cached == true) {
      return true;
    }

    final supported = await tableSupportsColumn(table, 'company_id');
    _tableSupportsCompanyIdCache[table] = supported;
    return supported;
  }

  Future<bool> tableSupportsColumn(String table, String column) async {
    final cacheKey = '$table.$column';
    final cached = _tableSupportsColumnCache[cacheKey];
    if (cached == true) {
      return true;
    }

    try {
      await _client.from(table).select(column).limit(1);
      _tableSupportsColumnCache[cacheKey] = true;
      return true;
    } on PostgrestException catch (error) {
      if (isMissingColumnError(error, column)) {
        _tableSupportsColumnCache[cacheKey] = false;
        return false;
      }
      // If row-level security blocks metadata probing, stay conservative in the
      // client and let the database-side defaults/triggers fill the column.
      _tableSupportsColumnCache[cacheKey] = false;
      return false;
    }
  }

  Future<Map<String, dynamic>> attachCurrentCompanyId({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final existing = payload['company_id']?.toString().trim();
    if (existing != null && existing.isNotEmpty) {
      return Map<String, dynamic>.from(payload);
    }

    final companyId = await currentCompanyId();
    if (companyId == null || companyId.isEmpty) {
      return Map<String, dynamic>.from(payload);
    }

    final supportsCompanyId = await tableSupportsCompanyId(table);
    if (!supportsCompanyId) {
      return Map<String, dynamic>.from(payload);
    }

    return {...payload, 'company_id': companyId};
  }

  bool isMissingCompanyColumnError(PostgrestException error) {
    return isMissingColumnError(error, 'company_id');
  }

  bool isMissingColumnError(PostgrestException error, String column) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains(column.toLowerCase()) &&
        (message.contains('column') ||
            message.contains('schema cache') ||
            message.contains('could not find'));
  }

  void _clearCompanyCache() {
    _cachedCompanyId = null;
    _cachedUserId = null;
    _didResolveCompanyId = false;
  }
}
