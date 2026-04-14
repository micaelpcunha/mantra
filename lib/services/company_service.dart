import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company_profile.dart';
import 'company_scope_service.dart';

class CompanyService {
  CompanyService._();

  static final CompanyService instance = CompanyService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<CompanyProfile?> fetchCompanyProfile() async {
    final companyId = await CompanyScopeService.instance.currentCompanyId();
    final supportsCompanyId = await CompanyScopeService.instance
        .tableSupportsCompanyId('company_profile');
    final data = await _fetchCompanyProfileData(
      companyId: supportsCompanyId ? companyId : null,
    );

    if (data != null) {
      return CompanyProfile.fromMap(Map<String, dynamic>.from(data));
    }

    final companyData = await _fetchCompanyData(companyId: companyId);
    if (companyData == null) return null;

    return CompanyProfile.fromMap({
      'id': companyData['id'],
      'company_id': companyData['id'],
      'name': companyData['display_name'],
      'legal_name': companyData['legal_name'],
      'created_at': companyData['created_at'],
      'updated_at': companyData['updated_at'],
    });
  }

  Future<CompanyProfile> upsertCompanyProfile({
    String? existingId,
    required Map<String, dynamic> payload,
  }) async {
    final scopedPayload = await CompanyScopeService.instance
        .attachCurrentCompanyId(
          table: 'company_profile',
          payload: {
            if (existingId != null && existingId.isNotEmpty) 'id': existingId,
            ...payload,
          },
        );
    final compatiblePayload = await _removeUnsupportedCompanyProfileColumns(
      scopedPayload,
    );

    final response = Map<String, dynamic>.from(
      await _client
          .from('company_profile')
          .upsert(compatiblePayload)
          .select()
          .single(),
    );

    await _syncCompanyIdentity(
      companyId: response['company_id']?.toString(),
      profilePayload: response,
    );

    return CompanyProfile.fromMap(response);
  }

  Future<Map<String, dynamic>> _removeUnsupportedCompanyProfileColumns(
    Map<String, dynamic> payload,
  ) async {
    final filtered = Map<String, dynamic>.from(payload);
    final optionalColumns = <String>[
      'authorization_email_provider',
      'authorization_email_connection_id',
      'authorization_email_send_mode',
      'authorization_email_signature',
      'authorization_sender_email',
    ];

    for (final column in optionalColumns) {
      if (!filtered.containsKey(column)) continue;

      final supported = await CompanyScopeService.instance.tableSupportsColumn(
        'company_profile',
        column,
      );
      if (!supported) {
        filtered.remove(column);
      }
    }

    return filtered;
  }

  Future<Map<String, dynamic>?> _fetchCompanyProfileData({
    String? companyId,
  }) async {
    if (companyId != null && companyId.isNotEmpty) {
      try {
        final scopedData = await _client
            .from('company_profile')
            .select()
            .eq('company_id', companyId)
            .order('created_at')
            .limit(1)
            .maybeSingle();

        if (scopedData != null) {
          return Map<String, dynamic>.from(scopedData);
        }
      } on PostgrestException catch (error) {
        if (!CompanyScopeService.instance.isMissingCompanyColumnError(error)) {
          rethrow;
        }
      }
    }

    final legacyData = await _client
        .from('company_profile')
        .select()
        .order('created_at')
        .limit(1)
        .maybeSingle();

    if (legacyData == null) return null;
    return Map<String, dynamic>.from(legacyData);
  }

  Future<Map<String, dynamic>?> _fetchCompanyData({String? companyId}) async {
    if (companyId != null && companyId.isNotEmpty) {
      final scopedData = await _client
          .from('companies')
          .select('id, display_name, legal_name, created_at, updated_at')
          .eq('id', companyId)
          .maybeSingle();

      if (scopedData != null) {
        return Map<String, dynamic>.from(scopedData);
      }
    }

    final legacyData = await _client
        .from('companies')
        .select('id, display_name, legal_name, created_at, updated_at')
        .order('created_at')
        .limit(1)
        .maybeSingle();

    if (legacyData == null) return null;
    return Map<String, dynamic>.from(legacyData);
  }

  Future<void> _syncCompanyIdentity({
    required String? companyId,
    required Map<String, dynamic> profilePayload,
  }) async {
    final normalizedCompanyId = companyId?.trim();
    if (normalizedCompanyId == null || normalizedCompanyId.isEmpty) {
      return;
    }

    final displayName = profilePayload['name']?.toString().trim();
    final legalName = profilePayload['legal_name']?.toString().trim();
    if ((displayName == null || displayName.isEmpty) &&
        (legalName == null || legalName.isEmpty)) {
      return;
    }

    try {
      await _client
          .from('companies')
          .update({
            if (displayName != null && displayName.isNotEmpty)
              'display_name': displayName,
            'legal_name': legalName == null || legalName.isEmpty
                ? null
                : legalName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', normalizedCompanyId);
    } on PostgrestException {
      // Keep company profile updates working even if `companies` is still using
      // an older schema or stricter policies than the profile table.
    }
  }
}
