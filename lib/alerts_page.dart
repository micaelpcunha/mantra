import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/admin_notification.dart';
import 'services/notification_service.dart';
import 'work_orders/task_detail_page.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final supabase = Supabase.instance.client;
  List<AdminNotification> notifications = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loaded = await NotificationService.instance.fetchNotifications();

      if (!mounted) return;

      setState(() {
        notifications = loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar os alertas.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatCreatedAt(DateTime? dateTime) {
    if (dateTime == null) return '-';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  Future<void> markAsRead(AdminNotification notification) async {
    if (notification.isRead) return;

    await NotificationService.instance.markAsRead(notification.id);
    await fetchNotifications();
  }

  Future<void> openNotification(AdminNotification notification) async {
    final workOrderId = notification.workOrderId;
    if (workOrderId == null) {
      await markAsRead(notification);
      return;
    }

    try {
      final workOrderData = await supabase
          .from('work_orders')
          .select()
          .eq('id', workOrderId)
          .maybeSingle();

      if (!mounted) return;

      if (workOrderData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A ordem associada a este alerta ja nao existe.'),
          ),
        );
        await markAsRead(notification);
        return;
      }

      final workOrder = Map<String, dynamic>.from(workOrderData);
      final assetId = workOrder['asset_id'];
      Map<String, dynamic> asset = {
        'id': assetId,
        'name': workOrder['asset_name'],
      };

      if (assetId != null) {
        final assetData = await supabase
            .from('assets')
            .select()
            .eq('id', assetId)
            .maybeSingle();

        if (assetData != null) {
          asset = Map<String, dynamic>.from(assetData);
        }
      }

      if (!mounted) return;

      if (!notification.isRead) {
        await NotificationService.instance.markAsRead(notification.id);
        if (!mounted) return;
      }

      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailPage(
            task: workOrder,
            asset: asset,
          ),
        ),
      );

      if (!mounted) return;
      if (changed == true || !notification.isRead) {
        await fetchNotifications();
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel abrir a ordem associada ao alerta.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: fetchNotifications,
        child: ListView(
          children: const [
            SizedBox(
              height: 320,
              child: Center(child: Text('Sem alertas')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchNotifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: notifications.map((notification) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: notification.isRead
                ? null
                : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: notification.isRead
                    ? Colors.blueGrey.withOpacity(0.12)
                    : Colors.orange.withOpacity(0.16),
                child: Icon(
                  notification.isRead
                      ? Icons.notifications_none
                      : Icons.notification_important,
                  color: notification.isRead ? Colors.blueGrey : Colors.orange,
                ),
              ),
              title: Text(notification.message),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tarefa: ${notification.workOrderId ?? '-'} | ${formatCreatedAt(notification.createdAt)}',
                ),
              ),
              trailing: notification.isRead
                  ? null
                  : TextButton(
                      onPressed: () => markAsRead(notification),
                      child: const Text('Lido'),
                    ),
              onTap: () => openNotification(notification),
            ),
          );
        }).toList(),
      ),
    );
  }
}
