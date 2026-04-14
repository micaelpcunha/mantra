import 'package:supabase_flutter/supabase_flutter.dart';

class TechnicianDeleteImpact {
  const TechnicianDeleteImpact({
    required this.linkedUserCount,
    required this.workOrderCount,
    required this.defaultAssetCount,
    required this.plannedDayAssetCount,
  });

  final int linkedUserCount;
  final int workOrderCount;
  final int defaultAssetCount;
  final int plannedDayAssetCount;

  bool get removesLinkedAccess => linkedUserCount > 0;

  bool get hasImpact =>
      workOrderCount > 0 ||
      defaultAssetCount > 0 ||
      plannedDayAssetCount > 0 ||
      linkedUserCount > 0;

  factory TechnicianDeleteImpact.fromDynamic(dynamic value) {
    final map = value is Map ? Map<String, dynamic>.from(value) : const {};
    return TechnicianDeleteImpact(
      linkedUserCount: _readInt(map['linked_user_count']),
      workOrderCount: _readInt(map['work_order_count']),
      defaultAssetCount: _readInt(map['default_asset_count']),
      plannedDayAssetCount: _readInt(map['planned_day_asset_count']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ManagedAccountService {
  ManagedAccountService._();

  static final ManagedAccountService instance = ManagedAccountService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> createAuthUser({
    required String email,
    required String password,
    required String role,
    String? fullName,
    String? technicianId,
  }) async {
    final result = await _client.rpc(
      'admin_create_auth_user',
      params: {
        'p_email': email,
        'p_password': password,
        'p_role': role,
        'p_full_name': fullName,
        'p_technician_id': technicianId,
      },
    );

    final userId = result?.toString().trim() ?? '';
    if (userId.isEmpty) {
      throw StateError('Nao foi recebido o ID do novo utilizador.');
    }

    return userId;
  }

  Future<void> deleteAuthUser({required String userId}) {
    return _client.rpc('admin_delete_auth_user', params: {'p_user_id': userId});
  }

  Future<TechnicianDeleteImpact> previewTechnicianDeleteImpact({
    required String technicianId,
  }) async {
    final result = await _client.rpc(
      'admin_preview_technician_delete',
      params: {'p_technician_id': technicianId},
    );

    return TechnicianDeleteImpact.fromDynamic(result);
  }

  Future<TechnicianDeleteImpact> deleteTechnicianBundle({
    required String technicianId,
  }) async {
    final result = await _client.rpc(
      'admin_delete_technician_bundle',
      params: {'p_technician_id': technicianId},
    );

    return TechnicianDeleteImpact.fromDynamic(result);
  }
}
