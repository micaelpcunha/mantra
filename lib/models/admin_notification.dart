class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.message,
    required this.workOrderId,
    required this.isRead,
    required this.createdAt,
  });

  final dynamic id;
  final String message;
  final dynamic workOrderId;
  final bool isRead;
  final DateTime? createdAt;

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id'],
      message: map['message']?.toString() ??
          map['mensagem']?.toString() ??
          '',
      workOrderId: map['work_order_id'] ?? map['ordem_trabalho_id'],
      isRead: map['is_read'] == true || map['lido'] == true,
      createdAt: DateTime.tryParse(
        map['created_at']?.toString() ?? map['data_criacao']?.toString() ?? '',
      ),
    );
  }
}
