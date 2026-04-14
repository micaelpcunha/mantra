import 'package:supabase_flutter/supabase_flutter.dart';

import 'company_scope_service.dart';

class AssetDeviceService {
  AssetDeviceService._();

  static final AssetDeviceService instance = AssetDeviceService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> isAvailable() async {
    try {
      await _client.from('asset_devices').select('id').limit(1);
      return true;
    } on PostgrestException catch (error) {
      if (isMissingTableError(error)) {
        return false;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDevicesForAsset(
    dynamic assetId,
  ) async {
    final data = await _client
        .from('asset_devices')
        .select()
        .eq('asset_id', assetId)
        .order('name');

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createDevice({
    required dynamic assetId,
    required Map<String, dynamic> payload,
  }) async {
    final scopedPayload = await CompanyScopeService.instance
        .attachCurrentCompanyId(
          table: 'asset_devices',
          payload: {...payload, 'asset_id': assetId},
        );

    await _client.from('asset_devices').insert(scopedPayload);
  }

  Future<void> updateDevice({
    required dynamic deviceId,
    required Map<String, dynamic> payload,
  }) async {
    await _client.from('asset_devices').update(payload).eq('id', deviceId);
  }

  Future<void> deleteDevice({required dynamic deviceId}) async {
    await _client.from('asset_devices').delete().eq('id', deviceId);
  }

  bool isMissingTableError(PostgrestException error) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains('asset_devices') &&
        (message.contains('schema cache') ||
            message.contains('relation') ||
            message.contains('table'));
  }
}
