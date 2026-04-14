import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import 'company_scope_service.dart';

class AssetService {
  AssetService._();

  static final AssetService instance = AssetService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Asset>> fetchAssets() async {
    final data = await _client.from('assets').select().order('id');
    return List<Map<String, dynamic>>.from(data).map(Asset.fromMap).toList();
  }

  Future<void> createAsset({
    required String name,
    required String status,
    dynamic locationId,
  }) async {
    final payload = await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'assets',
      payload: {
        'name': name,
        'status': status,
        'tarefas_concluidas': 0,
        'location_id': locationId,
      },
    );

    await _client.from('assets').insert(payload);
  }

  Future<void> updateAsset({
    required dynamic assetId,
    required String name,
    required String status,
    dynamic locationId,
  }) {
    return _client.from('assets').update({
      'name': name,
      'status': status,
      'location_id': locationId,
    }).eq('id', assetId);
  }

  Future<void> updateCompletedTasks({
    required dynamic assetId,
    required int completedTasks,
  }) {
    return _client.from('assets').update({
      'tarefas_concluidas': completedTasks,
    }).eq('id', assetId);
  }

  Future<void> deleteAsset({
    required dynamic assetId,
  }) {
    return _client.from('assets').delete().eq('id', assetId);
  }
}
