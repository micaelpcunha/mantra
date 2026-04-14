import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company_email_connection.dart';
import 'company_service.dart';
import 'company_scope_service.dart';

class DeleteCompanyEmailConnectionResult {
  const DeleteCompanyEmailConnectionResult({
    required this.deletedActiveConnection,
    required this.deletedConnectionId,
    this.deletedProvider,
    this.deletedEmail,
    required this.usedServerCleanup,
  });

  final bool deletedActiveConnection;
  final String deletedConnectionId;
  final String? deletedProvider;
  final String? deletedEmail;
  final bool usedServerCleanup;

  factory DeleteCompanyEmailConnectionResult.fromRpc(dynamic payload) {
    final map = payload is Map
        ? Map<String, dynamic>.from(payload)
        : const <String, dynamic>{};

    return DeleteCompanyEmailConnectionResult(
      deletedActiveConnection: map['deleted_active_connection'] == true,
      deletedConnectionId: map['deleted_connection_id']?.toString() ?? '',
      deletedProvider: map['deleted_provider']?.toString(),
      deletedEmail: map['deleted_email']?.toString(),
      usedServerCleanup: true,
    );
  }
}

class CompanyEmailConnectionService {
  CompanyEmailConnectionService._();

  static final CompanyEmailConnectionService instance =
      CompanyEmailConnectionService._();

  SupabaseClient get _client => Supabase.instance.client;

  bool? _tableAvailable;
  bool? _deleteRpcAvailable;

  Future<bool> isAvailable() async {
    final cached = _tableAvailable;
    if (cached != null) {
      return cached;
    }

    try {
      await _client.from('company_email_connections').select('id').limit(1);
      _tableAvailable = true;
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error)) {
        _tableAvailable = false;
        return false;
      }
      rethrow;
    }
  }

  Future<List<CompanyEmailConnection>> fetchConnections() async {
    final available = await isAvailable();
    if (!available) return const [];

    final companyId = await CompanyScopeService.instance.currentCompanyId();
    if (companyId == null || companyId.isEmpty) return const [];

    final response = await _client
        .from('company_email_connections')
        .select()
        .eq('company_id', companyId)
        .order('provider')
        .order('email');

    return List<Map<String, dynamic>>.from(
      response,
    ).map(CompanyEmailConnection.fromMap).toList();
  }

  Future<CompanyEmailConnection?> fetchConnectionById(
    String connectionId,
  ) async {
    final normalizedId = connectionId.trim();
    if (normalizedId.isEmpty) return null;

    final available = await isAvailable();
    if (!available) return null;

    final response = await _client
        .from('company_email_connections')
        .select()
        .eq('id', normalizedId)
        .maybeSingle();

    if (response == null) return null;
    return CompanyEmailConnection.fromMap(Map<String, dynamic>.from(response));
  }

  Future<DeleteCompanyEmailConnectionResult> deleteConnection({
    required CompanyEmailConnection connection,
    required String? activeConnectionId,
    required String? authorizationSenderEmail,
  }) async {
    final normalizedId = connection.id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(connection.id, 'connection.id');
    }

    final available = await isAvailable();
    if (!available) {
      throw StateError(
        'A tabela company_email_connections nao esta disponivel.',
      );
    }

    final rpcAvailable = await _supportsDeleteRpc();
    if (rpcAvailable) {
      try {
        final result = await _client.rpc(
          'delete_company_email_connection',
          params: {'p_connection_id': normalizedId},
        );
        return DeleteCompanyEmailConnectionResult.fromRpc(result);
      } on PostgrestException catch (error) {
        if (_isMissingDeleteRpcError(error)) {
          _deleteRpcAvailable = false;
        } else {
          rethrow;
        }
      }
    }

    final normalizedActiveConnectionId = activeConnectionId?.trim();
    final deletedActiveConnection =
        normalizedActiveConnectionId == normalizedId;
    final shouldClearSenderEmail =
        deletedActiveConnection &&
        _emailsMatch(authorizationSenderEmail, connection.email);

    if (deletedActiveConnection) {
      final profile = await CompanyService.instance.fetchCompanyProfile();
      await CompanyService.instance.upsertCompanyProfile(
        existingId: profile?.id,
        payload: {
          'authorization_email_send_mode': 'manual',
          'authorization_email_provider': 'manual',
          'authorization_email_connection_id': null,
          if (shouldClearSenderEmail) 'authorization_sender_email': null,
        },
      );
    }

    await _client
        .from('company_email_connections')
        .delete()
        .eq('id', normalizedId);

    return DeleteCompanyEmailConnectionResult(
      deletedActiveConnection: deletedActiveConnection,
      deletedConnectionId: normalizedId,
      deletedProvider: connection.provider,
      deletedEmail: connection.email,
      usedServerCleanup: false,
    );
  }

  Future<bool> _supportsDeleteRpc() async {
    final cached = _deleteRpcAvailable;
    if (cached != null) {
      return cached;
    }

    try {
      await _client.rpc(
        'delete_company_email_connection',
        params: {'p_connection_id': '00000000-0000-0000-0000-000000000000'},
      );
      _deleteRpcAvailable = true;
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingDeleteRpcError(error)) {
        _deleteRpcAvailable = false;
        return false;
      }

      _deleteRpcAvailable = true;
      return true;
    }
  }

  bool _emailsMatch(String? left, String? right) {
    final normalizedLeft = left?.trim().toLowerCase();
    final normalizedRight = right?.trim().toLowerCase();
    return normalizedLeft != null &&
        normalizedLeft.isNotEmpty &&
        normalizedRight != null &&
        normalizedRight.isNotEmpty &&
        normalizedLeft == normalizedRight;
  }

  bool _isMissingDeleteRpcError(PostgrestException error) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains('delete_company_email_connection') &&
        (message.contains('does not exist') ||
            message.contains('could not find') ||
            message.contains('schema cache'));
  }

  bool _isMissingTableError(PostgrestException error) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains('company_email_connections') &&
        (message.contains('does not exist') ||
            message.contains('schema cache') ||
            message.contains('could not find'));
  }
}
