import '../models/procedure_template.dart';

const List<String> workOrderPriorityOptions = <String>[
  'baixa',
  'normal',
  'alta',
  'urgente',
];

String normalizeWorkOrderPriority(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (workOrderPriorityOptions.contains(normalized)) {
    return normalized;
  }
  return 'normal';
}

String workOrderPriority(Map<String, dynamic> workOrder) {
  return normalizeWorkOrderPriority(workOrder['priority']?.toString());
}

String workOrderPriorityLabel(String priority) {
  switch (normalizeWorkOrderPriority(priority)) {
    case 'baixa':
      return 'Baixa';
    case 'alta':
      return 'Alta';
    case 'urgente':
      return 'Urgente';
    case 'normal':
    default:
      return 'Normal';
  }
}

String workOrderTitle(Map<String, dynamic> workOrder) {
  final title = workOrder['title']?.toString().trim() ?? '';
  if (title.isNotEmpty) return title;

  final description = workOrderDescription(workOrder).trim();
  if (description.isNotEmpty) return description;

  return 'Sem titulo';
}

String workOrderReference(Map<String, dynamic> workOrder) {
  return workOrder['reference']?.toString() ?? '';
}

String workOrderDescription(Map<String, dynamic> workOrder) {
  return workOrder['description']?.toString() ?? '';
}

String workOrderObservations(Map<String, dynamic> workOrder) {
  return workOrder['comment']?.toString() ?? '';
}

String workOrderPhotoUrl(Map<String, dynamic> workOrder) {
  return workOrder['photo_url']?.toString() ?? '';
}

String workOrderAttachmentUrl(Map<String, dynamic> workOrder) {
  return workOrder['attachment_url']?.toString() ?? '';
}

String workOrderAudioNoteUrl(Map<String, dynamic> workOrder) {
  return workOrder['audio_note_url']?.toString() ?? '';
}

String workOrderAssetDeviceName(Map<String, dynamic> workOrder) {
  return workOrder['asset_device_name']?.toString().trim() ?? '';
}

String? workOrderAssetDeviceId(Map<String, dynamic> workOrder) {
  final value = workOrder['asset_device_id']?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

String workOrderMeasurement(Map<String, dynamic> workOrder) {
  return workOrder['measurement_value']?.toString() ?? '';
}

bool workOrderRequiresPhoto(Map<String, dynamic> workOrder) {
  final value = workOrder['requires_photo'];
  return value == true;
}

bool workOrderRequiresMeasurement(Map<String, dynamic> workOrder) {
  final value = workOrder['requires_measurement'];
  return value == true;
}

String workOrderType(Map<String, dynamic> workOrder) {
  final type = workOrder['order_type']?.toString() ?? '';
  return type.isEmpty ? 'corretiva' : type;
}

String workOrderTypeLabel(String type) {
  switch (type) {
    case 'preventiva':
      return 'Preventiva';
    case 'medicoes_verificacoes':
      return 'Medicoes e verificacoes';
    case 'corretiva':
    default:
      return 'Corretiva';
  }
}

bool isPreventiveOrder(Map<String, dynamic> workOrder) {
  return workOrderType(workOrder) == 'preventiva';
}

bool isMeasurementVerificationOrder(Map<String, dynamic> workOrder) {
  return workOrderType(workOrder) == 'medicoes_verificacoes';
}

bool supportsWorkOrderRequirements(Map<String, dynamic> workOrder) {
  final type = workOrderType(workOrder);
  return type == 'preventiva' || type == 'medicoes_verificacoes';
}

dynamic workOrderScheduledFor(Map<String, dynamic> workOrder) {
  return workOrder['scheduled_for'];
}

int? workOrderRecurrenceInterval(Map<String, dynamic> workOrder) {
  final value = workOrder['recurrence_interval'];
  if (value == null) return null;
  return int.tryParse(value.toString());
}

String workOrderRecurrenceUnit(Map<String, dynamic> workOrder) {
  return workOrder['recurrence_unit']?.toString() ?? '';
}

dynamic workOrderMaintenancePlanId(Map<String, dynamic> workOrder) {
  return workOrder['maintenance_plan_id'];
}

dynamic workOrderUpdatedAt(Map<String, dynamic> workOrder) {
  return workOrder['updated_at'];
}

String? workOrderProcedureTemplateId(Map<String, dynamic> workOrder) {
  final value = workOrder['procedure_template_id']?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

String workOrderProcedureName(Map<String, dynamic> workOrder) {
  return workOrder['procedure_name']?.toString().trim() ?? '';
}

List<ProcedureChecklistItem> workOrderProcedureSteps(
  Map<String, dynamic> workOrder,
) {
  return ProcedureChecklistItem.listFromDynamic(workOrder['procedure_steps']);
}

int workOrderProcedureCompletedSteps(Map<String, dynamic> workOrder) {
  return workOrderProcedureSteps(
    workOrder,
  ).where((step) => step.isChecked).length;
}

String? validateProcedureStepsForCompletion(
  List<ProcedureChecklistItem> steps,
) {
  final missingRequiredSteps = steps
      .where((step) => step.isRequired && !step.isChecked)
      .toList();
  if (missingRequiredSteps.isNotEmpty) {
    return 'Faltam concluir passos obrigatorios do procedimento: ${_summarizeProcedureStepTitles(missingRequiredSteps)}.';
  }

  final missingRequiredPhotos = steps
      .where((step) => step.isRequired && step.requiresPhoto && !step.hasPhoto)
      .toList();
  if (missingRequiredPhotos.isNotEmpty) {
    return 'Faltam fotografias nos passos obrigatorios: ${_summarizeProcedureStepTitles(missingRequiredPhotos)}.';
  }

  return null;
}

String _summarizeProcedureStepTitles(List<ProcedureChecklistItem> steps) {
  final titles = steps
      .map((step) => step.title.trim())
      .where((title) => title.isNotEmpty)
      .take(3)
      .toList();

  if (titles.isEmpty) {
    return 'alguns passos';
  }

  if (steps.length > titles.length) {
    return '${titles.join(', ')} e mais ${steps.length - titles.length}';
  }

  return titles.join(', ');
}

DateTime? parseDateValue(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String formatDateValue(dynamic value) {
  final parsed = parseDateValue(value);
  if (parsed == null) return 'Sem registo';

  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}

String formatDateOnlyValue(dynamic value) {
  final parsed = parseDateValue(value);
  if (parsed == null) return 'Sem registo';

  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();

  return '$day/$month/$year';
}

String recurrenceSummary(Map<String, dynamic> workOrder) {
  final interval = workOrderRecurrenceInterval(workOrder);
  final unit = workOrderRecurrenceUnit(workOrder);
  if (interval == null || interval <= 0 || unit.isEmpty) return 'Nao repete';

  return 'A cada $interval ${recurrenceUnitLabel(unit, plural: interval != 1)}';
}

String recurrenceUnitLabel(String unit, {bool plural = true}) {
  if (unit == 'dia' || unit == 'dias') {
    return plural ? 'dias' : 'dia';
  }
  if (unit == 'semana' || unit == 'semanas') {
    return plural ? 'semanas' : 'semana';
  }
  if (unit == 'mes' || unit == 'meses') {
    return plural ? 'meses' : 'mes';
  }
  if (unit == 'ano' || unit == 'anos') {
    return plural ? 'anos' : 'ano';
  }
  return unit;
}

DateTime? calculateNextScheduledDate(
  DateTime? baseDate,
  int? interval,
  String unit,
) {
  if (baseDate == null || interval == null || interval <= 0 || unit.isEmpty) {
    return null;
  }

  if (unit == 'dia' || unit == 'dias') {
    return baseDate.add(Duration(days: interval));
  }
  if (unit == 'semana' || unit == 'semanas') {
    return baseDate.add(Duration(days: interval * 7));
  }
  if (unit == 'mes' || unit == 'meses') {
    return DateTime(
      baseDate.year,
      baseDate.month + interval,
      baseDate.day,
      baseDate.hour,
      baseDate.minute,
      baseDate.second,
      baseDate.millisecond,
      baseDate.microsecond,
    );
  }
  if (unit == 'ano' || unit == 'anos') {
    return DateTime(
      baseDate.year + interval,
      baseDate.month,
      baseDate.day,
      baseDate.hour,
      baseDate.minute,
      baseDate.second,
      baseDate.millisecond,
      baseDate.microsecond,
    );
  }
  return null;
}

Map<String, dynamic> buildEnglishWorkOrderPayload({
  required String title,
  required String reference,
  required String description,
  required String status,
  required String priority,
  required dynamic assetId,
  required String? technicianId,
  required String? photoUrl,
  required String? attachmentUrl,
  required String? observations,
  String? measurementValue,
  String? assetDeviceId,
  String? assetDeviceName,
  bool requiresPhoto = false,
  bool requiresMeasurement = false,
  String orderType = 'corretiva',
  String? scheduledFor,
  int? recurrenceInterval,
  String? recurrenceUnit,
  dynamic maintenancePlanId,
  String? procedureTemplateId,
  String? procedureName,
  List<Map<String, dynamic>>? procedureSteps,
}) {
  return {
    'title': title,
    'reference': reference,
    'description': description,
    'status': status,
    'priority': normalizeWorkOrderPriority(priority),
    'asset_id': assetId,
    'technician_id': technicianId,
    'photo_url': photoUrl,
    'attachment_url': attachmentUrl,
    'comment': observations,
    'measurement_value': measurementValue,
    'asset_device_id': assetDeviceId,
    'asset_device_name': assetDeviceName,
    'requires_photo': requiresPhoto,
    'requires_measurement': requiresMeasurement,
    'order_type': orderType,
    'scheduled_for': scheduledFor,
    'recurrence_interval': recurrenceInterval,
    'recurrence_unit': recurrenceUnit,
    'maintenance_plan_id': maintenancePlanId,
    'procedure_template_id': procedureTemplateId,
    'procedure_name': procedureName,
    'procedure_steps': procedureSteps,
  };
}
