import 'procedure_template.dart';

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.title,
    required this.reference,
    required this.description,
    required this.status,
    required this.assetId,
    required this.technicianId,
    required this.createdAt,
    required this.comment,
    required this.photoUrl,
    required this.priority,
    required this.attachmentUrl,
    this.companyId,
    this.assetDeviceId,
    this.assetDeviceName,
    this.procedureTemplateId,
    this.procedureName,
    this.procedureSteps = const [],
  });

  final dynamic id;
  final String title;
  final String reference;
  final String description;
  final String status;
  final dynamic assetId;
  final String? technicianId;
  final DateTime? createdAt;
  final String? comment;
  final String? photoUrl;
  final String priority;
  final String? attachmentUrl;
  final String? companyId;
  final String? assetDeviceId;
  final String? assetDeviceName;
  final String? procedureTemplateId;
  final String? procedureName;
  final List<ProcedureChecklistItem> procedureSteps;

  WorkOrder copyWith({
    dynamic id,
    String? title,
    String? reference,
    String? description,
    String? status,
    dynamic assetId,
    String? technicianId,
    DateTime? createdAt,
    String? comment,
    String? photoUrl,
    String? priority,
    String? attachmentUrl,
    String? companyId,
    String? assetDeviceId,
    String? assetDeviceName,
    String? procedureTemplateId,
    String? procedureName,
    List<ProcedureChecklistItem>? procedureSteps,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      title: title ?? this.title,
      reference: reference ?? this.reference,
      description: description ?? this.description,
      status: status ?? this.status,
      assetId: assetId ?? this.assetId,
      technicianId: technicianId ?? this.technicianId,
      createdAt: createdAt ?? this.createdAt,
      comment: comment ?? this.comment,
      photoUrl: photoUrl ?? this.photoUrl,
      priority: priority ?? this.priority,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      companyId: companyId ?? this.companyId,
      assetDeviceId: assetDeviceId ?? this.assetDeviceId,
      assetDeviceName: assetDeviceName ?? this.assetDeviceName,
      procedureTemplateId: procedureTemplateId ?? this.procedureTemplateId,
      procedureName: procedureName ?? this.procedureName,
      procedureSteps: procedureSteps ?? this.procedureSteps,
    );
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map) {
    return WorkOrder(
      id: map['id'],
      title: map['title']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      assetId: map['asset_id'],
      technicianId: map['technician_id']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      comment: map['comment']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      priority: map['priority']?.toString() ?? 'normal',
      attachmentUrl: map['attachment_url']?.toString(),
      companyId: map['company_id']?.toString(),
      assetDeviceId: map['asset_device_id']?.toString(),
      assetDeviceName: map['asset_device_name']?.toString(),
      procedureTemplateId: map['procedure_template_id']?.toString(),
      procedureName: map['procedure_name']?.toString(),
      procedureSteps: ProcedureChecklistItem.listFromDynamic(
        map['procedure_steps'],
      ),
    );
  }
}
