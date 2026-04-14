import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/procedure_template.dart';
import 'company_scope_service.dart';

class ProcedureTemplateService {
  ProcedureTemplateService._();

  static final ProcedureTemplateService instance = ProcedureTemplateService._();

  SupabaseClient get _client => Supabase.instance.client;

  bool? _tableAvailable;
  bool? _supportsAssetAssociation;

  Future<bool> isAvailable() async {
    final cached = _tableAvailable;
    if (cached == true) {
      return true;
    }

    try {
      await _client.from('procedure_templates').select('id').limit(1);
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

  Future<List<ProcedureTemplate>> fetchTemplates() async {
    final available = await isAvailable();
    if (!available) return const [];

    final companyId = await CompanyScopeService.instance.currentCompanyId();
    if (companyId == null || companyId.isEmpty) return const [];

    final response = await _client
        .from('procedure_templates')
        .select()
        .eq('company_id', companyId)
        .order('name');

    return List<Map<String, dynamic>>.from(
      response,
    ).map(ProcedureTemplate.fromMap).toList();
  }

  Future<ProcedureTemplate> createTemplate({
    required String name,
    String? description,
    required List<ProcedureChecklistItem> steps,
    bool isActive = true,
    String? assetId,
    String? assetDeviceId,
    String? assetDeviceName,
  }) async {
    final payload = await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'procedure_templates',
      payload: await _sanitizeAssetAssociationPayload({
        'name': name,
        'description': _nullableText(description),
        'steps': ProcedureChecklistItem.toTemplateJson(steps),
        'is_active': isActive,
        'asset_id': _nullableText(assetId),
        'asset_device_id': _nullableText(assetDeviceId),
        'asset_device_name': _nullableText(assetDeviceName),
      }),
    );

    final response = await _client
        .from('procedure_templates')
        .insert(payload)
        .select()
        .single();

    return ProcedureTemplate.fromMap(Map<String, dynamic>.from(response));
  }

  Future<ProcedureTemplate> updateTemplate({
    required String templateId,
    required String name,
    String? description,
    required List<ProcedureChecklistItem> steps,
    bool isActive = true,
    String? assetId,
    String? assetDeviceId,
    String? assetDeviceName,
  }) async {
    final response = await _client
        .from('procedure_templates')
        .update(await _sanitizeAssetAssociationPayload({
          'name': name,
          'description': _nullableText(description),
          'steps': ProcedureChecklistItem.toTemplateJson(steps),
          'is_active': isActive,
          'asset_id': _nullableText(assetId),
          'asset_device_id': _nullableText(assetDeviceId),
          'asset_device_name': _nullableText(assetDeviceName),
        }))
        .eq('id', templateId)
        .select()
        .single();

    return ProcedureTemplate.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> deleteTemplate(String templateId) {
    return _client.from('procedure_templates').delete().eq('id', templateId);
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<bool> supportsAssetAssociation() async {
    final cached = _supportsAssetAssociation;
    if (cached != null) {
      return cached;
    }

    final supportsAssetId = await CompanyScopeService.instance
        .tableSupportsColumn('procedure_templates', 'asset_id');
    final supportsAssetDeviceId = await CompanyScopeService.instance
        .tableSupportsColumn('procedure_templates', 'asset_device_id');
    final supportsAssetDeviceName = await CompanyScopeService.instance
        .tableSupportsColumn('procedure_templates', 'asset_device_name');

    final supported =
        supportsAssetId && supportsAssetDeviceId && supportsAssetDeviceName;
    _supportsAssetAssociation = supported;
    return supported;
  }

  Future<Map<String, dynamic>> _sanitizeAssetAssociationPayload(
    Map<String, dynamic> payload,
  ) async {
    final sanitized = Map<String, dynamic>.from(payload);
    if (!await supportsAssetAssociation()) {
      sanitized.remove('asset_id');
      sanitized.remove('asset_device_id');
      sanitized.remove('asset_device_name');
    }
    return sanitized;
  }

  bool _isMissingTableError(PostgrestException error) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains('procedure_templates') &&
        (message.contains('does not exist') ||
            message.contains('schema cache') ||
            message.contains('could not find'));
  }
}
