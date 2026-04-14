import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_notification.dart';
import 'company_scope_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AdminNotification>> fetchNotifications() async {
    try {
      final data = await _client
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data)
          .map(AdminNotification.fromMap)
          .toList();
    } on PostgrestException {
      final data = await _client
          .from('admin_notifications')
          .select()
          .order('data_criacao', ascending: false);

      return List<Map<String, dynamic>>.from(data)
          .map(AdminNotification.fromMap)
          .toList();
    }
  }

  Future<void> createNotification({
    required String message,
    required dynamic workOrderId,
  }) async {
    final englishPayload =
        await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'admin_notifications',
      payload: {
        'message': message,
        'work_order_id': workOrderId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      },
    );

    final legacyPayload =
        await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'admin_notifications',
      payload: {
        'mensagem': message,
        'ordem_trabalho_id': workOrderId,
        'lido': false,
        'data_criacao': DateTime.now().toIso8601String(),
      },
    );

    try {
      await _client.from('admin_notifications').insert(englishPayload);
    } on PostgrestException {
      await _client.from('admin_notifications').insert(legacyPayload);
    }
  }

  Future<void> markAsRead(dynamic id) async {
    try {
      await _client.from('admin_notifications').update({
        'is_read': true,
      }).eq('id', id);
    } on PostgrestException {
      await _client.from('admin_notifications').update({
        'lido': true,
      }).eq('id', id);
    }
  }
}
