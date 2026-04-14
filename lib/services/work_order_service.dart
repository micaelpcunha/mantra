import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/procedure_template.dart';
import '../models/work_order.dart';
import 'company_scope_service.dart';

class WorkOrderService {
  WorkOrderService._();

  static final WorkOrderService instance = WorkOrderService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<WorkOrder>> fetchWorkOrders() async {
    final data = await _client.from('work_orders').select().order('id');
    return List<Map<String, dynamic>>.from(
      data,
    ).map(WorkOrder.fromMap).toList();
  }

  Future<List<WorkOrder>> fetchWorkOrdersForTechnician(
    String technicianId,
  ) async {
    final data = await _client
        .from('work_orders')
        .select()
        .eq('technician_id', technicianId)
        .order('id');
    return List<Map<String, dynamic>>.from(
      data,
    ).map(WorkOrder.fromMap).toList();
  }

  Future<List<WorkOrder>> fetchWorkOrdersForAsset(dynamic assetId) async {
    final data = await _client
        .from('work_orders')
        .select()
        .eq('asset_id', assetId)
        .order('id');
    return List<Map<String, dynamic>>.from(
      data,
    ).map(WorkOrder.fromMap).toList();
  }

  Future<void> createWorkOrder({
    required String title,
    required String reference,
    required String description,
    required String status,
    required String priority,
    required dynamic assetId,
    String? technicianId,
    String? photoUrl,
    String? attachmentUrl,
    String? comment,
    String? assetDeviceId,
    String? assetDeviceName,
    String? procedureTemplateId,
    String? procedureName,
    List<ProcedureChecklistItem> procedureSteps = const [],
  }) async {
    final payload = await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'work_orders',
      payload: {
        'title': title,
        'reference': reference,
        'description': description,
        'status': status,
        'priority': priority,
        'asset_id': assetId,
        'technician_id': technicianId,
        'photo_url': photoUrl,
        'attachment_url': attachmentUrl,
        'comment': comment,
        'asset_device_id': assetDeviceId,
        'asset_device_name': assetDeviceName,
        'procedure_template_id': procedureTemplateId,
        'procedure_name': procedureName,
        'procedure_steps': ProcedureChecklistItem.toSnapshotJson(
          procedureSteps,
        ),
        'created_at': DateTime.now().toIso8601String(),
      },
    );

    await _client.from('work_orders').insert(payload);
  }

  Future<WorkOrder?> fetchWorkOrderById({required dynamic workOrderId}) async {
    final data = await _client
        .from('work_orders')
        .select()
        .eq('id', workOrderId)
        .maybeSingle();

    if (data == null) return null;

    return WorkOrder.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> updateWorkOrderStatus({
    required dynamic workOrderId,
    required String status,
  }) {
    return _client
        .from('work_orders')
        .update({'status': status})
        .eq('id', workOrderId);
  }

  Future<void> updateWorkOrder({
    required dynamic workOrderId,
    required String title,
    required String reference,
    required String description,
    required String status,
    required String priority,
    required dynamic assetId,
    String? technicianId,
    String? photoUrl,
    String? attachmentUrl,
    String? comment,
    String? assetDeviceId,
    String? assetDeviceName,
    String? procedureTemplateId,
    String? procedureName,
    List<ProcedureChecklistItem> procedureSteps = const [],
  }) {
    return _client
        .from('work_orders')
        .update({
          'title': title,
          'reference': reference,
          'description': description,
          'status': status,
          'priority': priority,
          'asset_id': assetId,
          'technician_id': technicianId,
          'photo_url': photoUrl,
          'attachment_url': attachmentUrl,
          'comment': comment,
          'asset_device_id': assetDeviceId,
          'asset_device_name': assetDeviceName,
          'procedure_template_id': procedureTemplateId,
          'procedure_name': procedureName,
          'procedure_steps': ProcedureChecklistItem.toSnapshotJson(
            procedureSteps,
          ),
        })
        .eq('id', workOrderId);
  }

  Future<void> updateWorkOrderDetails({
    required dynamic workOrderId,
    String? comment,
    String? photoUrl,
  }) {
    return _client
        .from('work_orders')
        .update({'comment': comment, 'photo_url': photoUrl})
        .eq('id', workOrderId);
  }

  Future<void> deleteWorkOrder({required dynamic workOrderId}) {
    return _client.from('work_orders').delete().eq('id', workOrderId);
  }
}
