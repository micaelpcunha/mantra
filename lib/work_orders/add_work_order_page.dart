import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/procedure_template.dart';
import '../services/asset_device_service.dart';
import '../services/company_scope_service.dart';
import '../services/procedure_template_service.dart';
import '../services/storage_service.dart';
import 'work_order_helpers.dart';

class AddWorkOrderPage extends StatefulWidget {
  const AddWorkOrderPage({super.key, required this.asset, this.workOrder});

  final Map<String, dynamic> asset;
  final Map<String, dynamic>? workOrder;

  @override
  State<AddWorkOrderPage> createState() => _AddWorkOrderPageState();
}

class _AddWorkOrderPageState extends State<AddWorkOrderPage> {
  static const String _legacyProcedureDropdownValue =
      '__legacy_procedure_snapshot__';
  static const String _legacyAssetDeviceDropdownValue =
      '__legacy_asset_device_snapshot__';

  final supabase = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final referenceController = TextEditingController();
  final descriptionController = TextEditingController();
  final observationsController = TextEditingController();
  final measurementController = TextEditingController();

  List<Map<String, dynamic>> technicians = [];
  List<Map<String, dynamic>> assetDevices = const [];
  List<ProcedureTemplate> procedureTemplates = const [];
  String? selectedTechnician;
  String status = 'pendente';
  String priority = 'normal';
  String orderType = 'corretiva';
  DateTime? scheduledFor;
  bool repeats = false;
  int recurrenceInterval = 1;
  String recurrenceUnit = 'meses';
  bool requiresPhoto = false;
  bool requiresMeasurement = false;
  String? photoUrl;
  String? attachmentUrl;
  bool isSaving = false;
  bool procedureTemplatesAvailable = false;
  bool assetDevicesAvailable = false;
  bool workOrdersSupportProcedureTemplateId = false;
  bool workOrdersSupportProcedureName = false;
  bool workOrdersSupportProcedureSteps = false;
  bool workOrdersSupportAssetDeviceId = false;
  bool workOrdersSupportAssetDeviceName = false;
  bool isLoadingProcedureSupport = true;
  bool isLoadingAssetDevices = true;
  String? selectedProcedureTemplateId;
  String selectedProcedureName = '';
  List<ProcedureChecklistItem> procedureSteps = const [];
  String? selectedAssetDeviceId;
  String selectedAssetDeviceName = '';

  bool get isEditing => widget.workOrder != null;

  bool get procedureFeatureReady =>
      procedureTemplatesAvailable &&
      workOrdersSupportProcedureName &&
      workOrdersSupportProcedureSteps;

  bool get hasProcedureSelected =>
      selectedProcedureName.trim().isNotEmpty || procedureSteps.isNotEmpty;

  bool get workOrdersSupportAssetDevice =>
      workOrdersSupportAssetDeviceId && workOrdersSupportAssetDeviceName;

  String? get normalizedProcedureTemplateId {
    final value = selectedProcedureTemplateId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get normalizedProcedureName {
    final value = selectedProcedureName.trim();
    return value.isEmpty ? null : value;
  }

  String? get selectedProcedureDropdownValue {
    final templateId = normalizedProcedureTemplateId;
    if (templateId != null) {
      return templateId;
    }
    if (normalizedProcedureName != null) {
      return _legacyProcedureDropdownValue;
    }
    return null;
  }

  String? get normalizedAssetDeviceId {
    final value = selectedAssetDeviceId?.trim() ?? '';
    if (value.isEmpty || value == _legacyAssetDeviceDropdownValue) {
      return null;
    }
    return value;
  }

  String? get normalizedAssetDeviceName {
    final value = selectedAssetDeviceName.trim();
    return value.isEmpty ? null : value;
  }

  bool get hasSelectedAssetDeviceInList {
    final deviceId = normalizedAssetDeviceId;
    if (deviceId == null) {
      return false;
    }

    for (final device in assetDevices) {
      if (device['id']?.toString() == deviceId) {
        return true;
      }
    }

    return false;
  }

  Map<String, dynamic>? get selectedAssetDeviceDetails {
    final deviceId = normalizedAssetDeviceId;
    if (deviceId == null) {
      return null;
    }

    for (final device in assetDevices) {
      if (device['id']?.toString() == deviceId) {
        return device;
      }
    }

    return null;
  }

  String? get selectedAssetDeviceDropdownValue {
    final deviceId = normalizedAssetDeviceId;
    if (deviceId != null && hasSelectedAssetDeviceInList) {
      return deviceId;
    }
    if (normalizedAssetDeviceName != null) {
      return _legacyAssetDeviceDropdownValue;
    }
    return null;
  }

  List<ProcedureTemplate> get selectableProcedureTemplates {
    final selectedId = normalizedProcedureTemplateId;
    final items = <ProcedureTemplate>[];
    final currentAssetId = widget.asset['id']?.toString();
    for (final template in procedureTemplates) {
      final matchesAsset =
          template.assetId == null ||
          template.assetId == currentAssetId ||
          template.id == selectedId;
      if ((template.isActive || template.id == selectedId) && matchesAsset) {
        items.add(template);
      }
    }
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  ProcedureTemplate? get selectedProcedureTemplate {
    final templateId = normalizedProcedureTemplateId;
    if (templateId == null) return null;
    for (final template in procedureTemplates) {
      if (template.id == templateId) {
        return template;
      }
    }
    return null;
  }

  IconData _priorityIcon(String value) {
    switch (normalizeWorkOrderPriority(value)) {
      case 'baixa':
        return Icons.keyboard_arrow_down_rounded;
      case 'alta':
        return Icons.keyboard_double_arrow_up_rounded;
      case 'urgente':
        return Icons.priority_high_rounded;
      case 'normal':
      default:
        return Icons.drag_handle_rounded;
    }
  }

  Color _priorityColor(BuildContext context, String value) {
    final scheme = Theme.of(context).colorScheme;
    switch (normalizeWorkOrderPriority(value)) {
      case 'baixa':
        return Colors.blueGrey;
      case 'alta':
        return const Color(0xFFE67E22);
      case 'urgente':
        return scheme.error;
      case 'normal':
      default:
        return const Color(0xFF2E9F5D);
    }
  }

  Widget buildPrioritySelector(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prioridade', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final useSingleRow =
                constraints.maxWidth >= 560 &&
                workOrderPriorityOptions.isNotEmpty;
            final spacing = 8.0;
            final itemWidth = useSingleRow
                ? (constraints.maxWidth -
                          (spacing * (workOrderPriorityOptions.length - 1))) /
                      workOrderPriorityOptions.length
                : (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: workOrderPriorityOptions.map((option) {
                final selected = priority == option;
                final color = _priorityColor(context, option);
                final textColor = selected
                    ? color
                    : theme.colorScheme.onSurfaceVariant;

                return SizedBox(
                  width: itemWidth > 0 ? itemWidth : constraints.maxWidth,
                  child: Material(
                    color: selected
                        ? color.withOpacity(0.12)
                        : theme.colorScheme.surface,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? color
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: isSaving
                          ? null
                          : () {
                              setState(() {
                                priority = option;
                              });
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _priorityIcon(option),
                              size: 18,
                              color: textColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              workOrderPriorityLabel(option),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    titleController.text =
        widget.workOrder?['title']?.toString() ??
        workOrderTitle(widget.workOrder ?? const {});
    referenceController.text = workOrderReference(widget.workOrder ?? const {});
    descriptionController.text = workOrderDescription(
      widget.workOrder ?? const {},
    );
    observationsController.text = workOrderObservations(
      widget.workOrder ?? const {},
    );
    measurementController.text = workOrderMeasurement(
      widget.workOrder ?? const {},
    );
    selectedTechnician =
        widget.workOrder?['technician_id']?.toString() ??
        widget.asset['default_technician_id']?.toString();
    status = widget.workOrder?['status']?.toString() ?? 'pendente';
    priority = workOrderPriority(widget.workOrder ?? const {});
    orderType = workOrderType(widget.workOrder ?? const {});
    scheduledFor = parseDateValue(
      workOrderScheduledFor(widget.workOrder ?? const {}),
    );
    final savedRecurrenceInterval = workOrderRecurrenceInterval(
      widget.workOrder ?? const {},
    );
    final savedRecurrenceUnit = workOrderRecurrenceUnit(
      widget.workOrder ?? const {},
    );
    repeats =
        savedRecurrenceInterval != null &&
        savedRecurrenceInterval > 0 &&
        savedRecurrenceUnit.isNotEmpty;
    recurrenceInterval = savedRecurrenceInterval ?? 1;
    recurrenceUnit = savedRecurrenceUnit.isEmpty
        ? 'meses'
        : savedRecurrenceUnit;
    requiresPhoto = workOrderRequiresPhoto(widget.workOrder ?? const {});
    requiresMeasurement = workOrderRequiresMeasurement(
      widget.workOrder ?? const {},
    );
    photoUrl = workOrderPhotoUrl(widget.workOrder ?? const {});
    attachmentUrl = workOrderAttachmentUrl(widget.workOrder ?? const {});
    selectedAssetDeviceId = workOrderAssetDeviceId(
      widget.workOrder ?? const {},
    );
    selectedAssetDeviceName = workOrderAssetDeviceName(
      widget.workOrder ?? const {},
    );
    selectedProcedureTemplateId = workOrderProcedureTemplateId(
      widget.workOrder ?? const {},
    );
    selectedProcedureName = workOrderProcedureName(
      widget.workOrder ?? const {},
    );
    procedureSteps = workOrderProcedureSteps(widget.workOrder ?? const {});
    loadTechnicians();
    loadAssetDevices();
    loadProcedureSupport();
  }

  @override
  void dispose() {
    titleController.dispose();
    referenceController.dispose();
    descriptionController.dispose();
    observationsController.dispose();
    measurementController.dispose();
    super.dispose();
  }

  Future<void> loadTechnicians() async {
    try {
      final data = await supabase.from('technicians').select().order('name');

      if (!mounted) return;

      final loadedTechnicians = List<Map<String, dynamic>>.from(data);
      final hasSelectedTechnician = loadedTechnicians.any(
        (technician) => technician['id']?.toString() == selectedTechnician,
      );

      setState(() {
        technicians = loadedTechnicians;
        if (!hasSelectedTechnician) {
          selectedTechnician = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel carregar os tecnicos.')),
      );
    }
  }

  Future<void> loadAssetDevices() async {
    setState(() {
      isLoadingAssetDevices = true;
    });

    try {
      final available = await AssetDeviceService.instance.isAvailable();
      final loadedDevices = available
          ? await AssetDeviceService.instance.fetchDevicesForAsset(
              widget.asset['id'],
            )
          : const <Map<String, dynamic>>[];
      final currentDeviceId = normalizedAssetDeviceId;
      final hasCurrentDevice =
          currentDeviceId != null &&
          loadedDevices.any(
            (device) => device['id']?.toString() == currentDeviceId,
          );

      if (!mounted) return;
      setState(() {
        assetDevicesAvailable = available;
        assetDevices = loadedDevices;
        if (!hasCurrentDevice) {
          selectedAssetDeviceId = null;
        }
        isLoadingAssetDevices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        assetDevicesAvailable = false;
        assetDevices = const [];
        isLoadingAssetDevices = false;
      });
    }
  }

  Future<void> loadProcedureSupport() async {
    try {
      final available = await ProcedureTemplateService.instance.isAvailable();
      final supportsTemplateId = await CompanyScopeService.instance
          .tableSupportsColumn('work_orders', 'procedure_template_id');
      final supportsName = await CompanyScopeService.instance
          .tableSupportsColumn('work_orders', 'procedure_name');
      final supportsSteps = await CompanyScopeService.instance
          .tableSupportsColumn('work_orders', 'procedure_steps');
      final supportsAssetDeviceId = await CompanyScopeService.instance
          .tableSupportsColumn('work_orders', 'asset_device_id');
      final supportsAssetDeviceName = await CompanyScopeService.instance
          .tableSupportsColumn('work_orders', 'asset_device_name');
      final loadedTemplates = available
          ? await ProcedureTemplateService.instance.fetchTemplates()
          : const <ProcedureTemplate>[];

      if (!mounted) return;
      setState(() {
        procedureTemplatesAvailable = available;
        workOrdersSupportProcedureTemplateId = supportsTemplateId;
        workOrdersSupportProcedureName = supportsName;
        workOrdersSupportProcedureSteps = supportsSteps;
        workOrdersSupportAssetDeviceId = supportsAssetDeviceId;
        workOrdersSupportAssetDeviceName = supportsAssetDeviceName;
        procedureTemplates = loadedTemplates;
        isLoadingProcedureSupport = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingProcedureSupport = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar os procedimentos.'),
        ),
      );
    }
  }

  Future<void> uploadPhoto() async {
    try {
      final url = await StorageService.instance.pickAndUploadPhoto();
      if (!mounted || url == null) return;

      setState(() {
        photoUrl = url;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar a fotografia.'),
        ),
      );
    }
  }

  Future<void> uploadAttachment() async {
    try {
      final url = await StorageService.instance.pickAndUploadAttachment();
      if (!mounted || url == null) return;

      setState(() {
        attachmentUrl = url;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel carregar o anexo.')),
      );
    }
  }

  Future<void> openAttachment() async {
    if (attachmentUrl == null || attachmentUrl!.isEmpty) return;
    final uri = await StorageService.instance.resolveFileUri(
      bucket: 'work-order-attachments',
      storedValue: attachmentUrl!,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> pickScheduledDate() async {
    final now = DateTime.now();
    final initialDate = scheduledFor ?? now;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (selectedDate == null) return;

    setState(() {
      scheduledFor = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        initialDate.hour,
        initialDate.minute,
      );
    });
  }

  void applyProcedureTemplate(ProcedureTemplate template) {
    setState(() {
      selectedProcedureTemplateId = template.id;
      selectedProcedureName = template.name;
      procedureSteps = ProcedureChecklistItem.resetChecks(template.steps);
      if (template.assetDeviceName?.trim().isNotEmpty == true &&
          (template.assetId == null ||
              template.assetId == widget.asset['id']?.toString())) {
        selectedAssetDeviceId = template.assetDeviceId?.trim().isEmpty ?? true
            ? _legacyAssetDeviceDropdownValue
            : template.assetDeviceId;
        selectedAssetDeviceName = template.assetDeviceName!.trim();
      }
    });
  }

  void clearProcedure() {
    setState(() {
      selectedProcedureTemplateId = null;
      selectedProcedureName = '';
      procedureSteps = const [];
    });
  }

  Map<String, dynamic> _removeUnsupportedOptionalFields(
    Map<String, dynamic> payload,
  ) {
    final sanitized = Map<String, dynamic>.from(payload);
    if (!workOrdersSupportProcedureTemplateId) {
      sanitized.remove('procedure_template_id');
    }
    if (!workOrdersSupportProcedureName) {
      sanitized.remove('procedure_name');
    }
    if (!workOrdersSupportProcedureSteps) {
      sanitized.remove('procedure_steps');
    }
    if (!workOrdersSupportAssetDeviceId) {
      sanitized.remove('asset_device_id');
    }
    if (!workOrdersSupportAssetDeviceName) {
      sanitized.remove('asset_device_name');
    }
    return sanitized;
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;

    if (status == 'concluido') {
      final completionError = validateProcedureStepsForCompletion(
        procedureSteps,
      );
      if (completionError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(completionError)));
        return;
      }
    }

    final observations = observationsController.text.trim().isEmpty
        ? null
        : observationsController.text.trim();

    final supportsRequirements =
        orderType == 'preventiva' || orderType == 'medicoes_verificacoes';

    final payload = {
      'title': titleController.text.trim(),
      'reference': referenceController.text.trim(),
      'description': descriptionController.text.trim(),
      'status': status,
      'priority': priority,
      'asset_id': widget.asset['id'],
      'technician_id': selectedTechnician,
      'photo_url': photoUrl,
      'attachment_url': attachmentUrl,
      'comment': observations,
      'asset_device_id': workOrdersSupportAssetDevice
          ? normalizedAssetDeviceId
          : null,
      'asset_device_name': workOrdersSupportAssetDevice
          ? normalizedAssetDeviceName
          : null,
      'measurement_value': measurementController.text.trim().isEmpty
          ? null
          : measurementController.text.trim(),
      'requires_photo': supportsRequirements ? requiresPhoto : false,
      'requires_measurement': supportsRequirements
          ? requiresMeasurement
          : false,
      'order_type': orderType,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'recurrence_interval': repeats && orderType == 'preventiva'
          ? recurrenceInterval
          : null,
      'recurrence_unit': repeats && orderType == 'preventiva'
          ? recurrenceUnit
          : null,
      'procedure_template_id':
          procedureFeatureReady && workOrdersSupportProcedureTemplateId
          ? normalizedProcedureTemplateId
          : null,
      'procedure_name': procedureFeatureReady ? normalizedProcedureName : null,
      'procedure_steps': procedureFeatureReady
          ? ProcedureChecklistItem.toSnapshotJson(procedureSteps)
          : null,
    };

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditing) {
        await _updateWorkOrder(payload);
      } else {
        await _createWorkOrder(payload);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel guardar a ordem de trabalho.'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _createWorkOrder(Map<String, dynamic> payload) async {
    final nowIso = DateTime.now().toIso8601String();
    final englishData =
        buildEnglishWorkOrderPayload(
            title: payload['title']?.toString() ?? '',
            reference: payload['reference']?.toString() ?? '',
            description: payload['description']?.toString() ?? '',
            status: payload['status']?.toString() ?? 'pendente',
            priority: payload['priority']?.toString() ?? 'normal',
            assetId: payload['asset_id'],
            technicianId: payload['technician_id']?.toString(),
            photoUrl: payload['photo_url']?.toString(),
            attachmentUrl: payload['attachment_url']?.toString(),
            observations: payload['comment']?.toString(),
            assetDeviceId: payload['asset_device_id']?.toString(),
            assetDeviceName: payload['asset_device_name']?.toString(),
            measurementValue: payload['measurement_value']?.toString(),
            requiresPhoto: payload['requires_photo'] == true,
            requiresMeasurement: payload['requires_measurement'] == true,
            orderType: payload['order_type']?.toString() ?? 'corretiva',
            scheduledFor: payload['scheduled_for']?.toString(),
            recurrenceInterval: payload['recurrence_interval'] as int?,
            recurrenceUnit: payload['recurrence_unit']?.toString(),
            procedureTemplateId: payload['procedure_template_id']?.toString(),
            procedureName: payload['procedure_name']?.toString(),
            procedureSteps: payload['procedure_steps'] is List
                ? List<Map<String, dynamic>>.from(
                    payload['procedure_steps'] as List,
                  )
                : null,
          )
          ..['created_at'] = nowIso
          ..['updated_at'] = nowIso;
    final scopedData = await CompanyScopeService.instance
        .attachCurrentCompanyId(
          table: 'work_orders',
          payload: _removeUnsupportedOptionalFields(englishData),
        );
    final inserted = await supabase
        .from('work_orders')
        .insert(scopedData)
        .select('id')
        .maybeSingle();
    await _ensureMaintenancePlanId(inserted?['id']);
  }

  Future<void> _updateWorkOrder(Map<String, dynamic> payload) async {
    final nowIso = DateTime.now().toIso8601String();
    final previousStatus = widget.workOrder?['status']?.toString();
    final newStatus = payload['status']?.toString() ?? 'pendente';
    final englishData = buildEnglishWorkOrderPayload(
      title: payload['title']?.toString() ?? '',
      reference: payload['reference']?.toString() ?? '',
      description: payload['description']?.toString() ?? '',
      status: payload['status']?.toString() ?? 'pendente',
      priority: payload['priority']?.toString() ?? 'normal',
      assetId: payload['asset_id'],
      technicianId: payload['technician_id']?.toString(),
      photoUrl: payload['photo_url']?.toString(),
      attachmentUrl: payload['attachment_url']?.toString(),
      observations: payload['comment']?.toString(),
      assetDeviceId: payload['asset_device_id']?.toString(),
      assetDeviceName: payload['asset_device_name']?.toString(),
      measurementValue: payload['measurement_value']?.toString(),
      requiresPhoto: payload['requires_photo'] == true,
      requiresMeasurement: payload['requires_measurement'] == true,
      orderType: payload['order_type']?.toString() ?? 'corretiva',
      scheduledFor: payload['scheduled_for']?.toString(),
      recurrenceInterval: payload['recurrence_interval'] as int?,
      recurrenceUnit: payload['recurrence_unit']?.toString(),
      maintenancePlanId: workOrderMaintenancePlanId(
        widget.workOrder ?? const {},
      ),
      procedureTemplateId: payload['procedure_template_id']?.toString(),
      procedureName: payload['procedure_name']?.toString(),
      procedureSteps: payload['procedure_steps'] is List
          ? List<Map<String, dynamic>>.from(payload['procedure_steps'] as List)
          : null,
    )..['updated_at'] = nowIso;
    await supabase
        .from('work_orders')
        .update(_removeUnsupportedOptionalFields(englishData))
        .eq('id', widget.workOrder!['id']);

    if (previousStatus != 'concluido' && newStatus == 'concluido') {
      await _createNextRecurringWorkOrder(
        widget.workOrder ?? const {},
        payload,
      );
    }
  }

  Future<void> _ensureMaintenancePlanId(dynamic insertedId) async {
    if (insertedId == null || orderType != 'preventiva' || !repeats) return;

    await supabase
        .from('work_orders')
        .update({'maintenance_plan_id': insertedId})
        .eq('id', insertedId);
  }

  Future<void> _createNextRecurringWorkOrder(
    Map<String, dynamic> currentWorkOrder,
    Map<String, dynamic> payload,
  ) async {
    final currentType =
        payload['order_type']?.toString() ?? workOrderType(currentWorkOrder);
    final interval =
        payload['recurrence_interval'] as int? ??
        workOrderRecurrenceInterval(currentWorkOrder);
    final unit =
        payload['recurrence_unit']?.toString() ??
        workOrderRecurrenceUnit(currentWorkOrder);
    if (currentType != 'preventiva' ||
        interval == null ||
        interval <= 0 ||
        unit.isEmpty) {
      return;
    }

    final baseDate =
        parseDateValue(payload['scheduled_for']) ??
        parseDateValue(workOrderScheduledFor(currentWorkOrder)) ??
        DateTime.now();
    final nextDate = calculateNextScheduledDate(baseDate, interval, unit);
    if (nextDate == null) return;

    final payloadProcedureSteps = ProcedureChecklistItem.listFromDynamic(
      payload['procedure_steps'],
    );
    final nextProcedureSteps = ProcedureChecklistItem.resetChecks(
      procedureFeatureReady
          ? payloadProcedureSteps
          : workOrderProcedureSteps(currentWorkOrder),
    );
    final payloadProcedureName =
        payload['procedure_name']?.toString().trim() ?? '';
    final payloadProcedureTemplateId =
        payload['procedure_template_id']?.toString().trim() ?? '';

    final nowIso = DateTime.now().toIso8601String();
    final maintenancePlanId =
        workOrderMaintenancePlanId(currentWorkOrder) ?? currentWorkOrder['id'];

    final englishData =
        buildEnglishWorkOrderPayload(
            title:
                payload['title']?.toString() ??
                workOrderTitle(currentWorkOrder),
            reference:
                payload['reference']?.toString() ??
                workOrderReference(currentWorkOrder),
            description:
                payload['description']?.toString() ??
                workOrderDescription(currentWorkOrder),
            status: 'pendente',
            priority:
                payload['priority']?.toString() ??
                workOrderPriority(currentWorkOrder),
            assetId: payload['asset_id'] ?? currentWorkOrder['asset_id'],
            technicianId:
                payload['technician_id']?.toString() ??
                currentWorkOrder['technician_id']?.toString(),
            photoUrl: null,
            attachmentUrl:
                payload['attachment_url']?.toString() ??
                workOrderAttachmentUrl(currentWorkOrder),
            observations: null,
            assetDeviceId:
                payload['asset_device_id']?.toString() ??
                workOrderAssetDeviceId(currentWorkOrder),
            assetDeviceName:
                payload['asset_device_name']?.toString() ??
                (workOrderAssetDeviceName(currentWorkOrder).trim().isEmpty
                    ? null
                    : workOrderAssetDeviceName(currentWorkOrder).trim()),
            measurementValue: null,
            requiresPhoto:
                payload['requires_photo'] == true ||
                workOrderRequiresPhoto(currentWorkOrder),
            requiresMeasurement:
                payload['requires_measurement'] == true ||
                workOrderRequiresMeasurement(currentWorkOrder),
            orderType: currentType,
            scheduledFor: nextDate.toIso8601String(),
            recurrenceInterval: interval,
            recurrenceUnit: unit,
            maintenancePlanId: maintenancePlanId,
            procedureTemplateId: procedureFeatureReady
                ? (payloadProcedureTemplateId.isEmpty
                      ? null
                      : payloadProcedureTemplateId)
                : workOrderProcedureTemplateId(currentWorkOrder),
            procedureName: procedureFeatureReady
                ? (payloadProcedureName.isEmpty ? null : payloadProcedureName)
                : (workOrderProcedureName(currentWorkOrder).trim().isEmpty
                      ? null
                      : workOrderProcedureName(currentWorkOrder).trim()),
            procedureSteps: ProcedureChecklistItem.toSnapshotJson(
              nextProcedureSteps,
            ),
          )
          ..['created_at'] = nowIso
          ..['updated_at'] = nowIso;
    final scopedData = await CompanyScopeService.instance
        .attachCurrentCompanyId(
          table: 'work_orders',
          payload: _removeUnsupportedOptionalFields(englishData),
        );
    await supabase.from('work_orders').insert(scopedData);
  }

  Widget buildAssetDeviceCard(BuildContext context) {
    final theme = Theme.of(context);
    final currentDeviceId = selectedAssetDeviceDropdownValue;
    final selectedDevice = selectedAssetDeviceDetails;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispositivo do ativo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Se esta ordem ou procedimento se aplica a um dispositivo concreto dentro do ativo, liga-o aqui para ficar identificado no terreno e no historico.',
            ),
            const SizedBox(height: 12),
            if (isLoadingAssetDevices)
              const LinearProgressIndicator()
            else if (!assetDevicesAvailable) ...[
              const Text(
                'Os dispositivos ainda nao estao ativados nesta base de dados.',
              ),
            ] else if (assetDevices.isEmpty) ...[
              const Text('Este ativo ainda nao tem dispositivos registados.'),
            ] else ...[
              DropdownButtonFormField<String?>(
                value: currentDeviceId,
                decoration: const InputDecoration(
                  labelText: 'Dispositivo associado',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem dispositivo'),
                  ),
                  ...assetDevices.map((device) {
                    return DropdownMenuItem<String?>(
                      value: device['id']?.toString(),
                      child: Text(device['name']?.toString() ?? 'Dispositivo'),
                    );
                  }),
                  if (!hasSelectedAssetDeviceInList &&
                      normalizedAssetDeviceName != null)
                    DropdownMenuItem<String?>(
                      value: _legacyAssetDeviceDropdownValue,
                      child: Text('${normalizedAssetDeviceName!} (historico)'),
                    ),
                ],
                onChanged: (value) {
                  if (value == _legacyAssetDeviceDropdownValue) return;
                  if (value == null) {
                    setState(() {
                      selectedAssetDeviceId = null;
                      selectedAssetDeviceName = '';
                    });
                    return;
                  }

                  Map<String, dynamic>? matchedDevice;
                  for (final device in assetDevices) {
                    if (device['id']?.toString() == value) {
                      matchedDevice = device;
                      break;
                    }
                  }

                  setState(() {
                    selectedAssetDeviceId = value;
                    selectedAssetDeviceName =
                        matchedDevice?['name']?.toString().trim() ?? '';
                  });
                },
              ),
              if (selectedDevice != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((selectedDevice['manufacturer_reference']
                            ?.toString()
                            .trim()
                            .isNotEmpty ??
                        false))
                      Chip(
                        label: Text(
                          'Ref. fabricante: ${selectedDevice['manufacturer_reference']?.toString().trim()}',
                        ),
                      ),
                    if ((selectedDevice['internal_reference']
                            ?.toString()
                            .trim()
                            .isNotEmpty ??
                        false))
                      Chip(
                        label: Text(
                          'Ref. interna: ${selectedDevice['internal_reference']?.toString().trim()}',
                        ),
                      ),
                    if ((selectedDevice['qr_code']
                            ?.toString()
                            .trim()
                            .isNotEmpty ??
                        false))
                      const Chip(label: Text('Tem QR proprio')),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget buildProcedureCard(BuildContext context) {
    final requiredSteps = procedureSteps
        .where((step) => step.isRequired)
        .length;
    final photoSteps = procedureSteps
        .where((step) => step.requiresPhoto)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Procedimento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Associa um procedimento reutilizavel a esta ordem. Os passos ficam gravados na ordem com as regras de obrigatoriedade e fotografia definidas no template.',
            ),
            const SizedBox(height: 12),
            if (isLoadingProcedureSupport)
              const LinearProgressIndicator()
            else if (!procedureFeatureReady) ...[
              const Text(
                'Para ativar os procedimentos, executa o script SUPABASE_WORK_ORDER_PROCEDURES.sql no Supabase.',
              ),
            ] else ...[
              DropdownButtonFormField<String?>(
                value: selectedProcedureDropdownValue,
                decoration: const InputDecoration(
                  labelText: 'Template de procedimento',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem procedimento'),
                  ),
                  ...selectableProcedureTemplates.map((template) {
                    final suffix = template.isActive ? '' : ' (inativo)';
                    return DropdownMenuItem<String?>(
                      value: template.id,
                      child: Text('${template.name}$suffix'),
                    );
                  }),
                  if (selectedProcedureTemplate == null &&
                      selectedProcedureDropdownValue != null)
                    DropdownMenuItem<String?>(
                      value: selectedProcedureDropdownValue,
                      child: Text(
                        '${normalizedProcedureName ?? 'Procedimento atual'} (historico)',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == _legacyProcedureDropdownValue) return;
                  if (value == null) {
                    clearProcedure();
                    return;
                  }

                  for (final template in procedureTemplates) {
                    if (template.id == value) {
                      applyProcedureTemplate(template);
                      return;
                    }
                  }
                },
              ),
              if (hasProcedureSelected) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        normalizedProcedureName ?? 'Procedimento associado',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${procedureSteps.length} passos preparados'),
                      if (requiredSteps > 0 || photoSteps > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (requiredSteps > 0)
                              Chip(label: Text('$requiredSteps obrigatorios')),
                            if (photoSteps > 0)
                              Chip(
                                avatar: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                ),
                                label: Text('$photoSteps com fotografia'),
                              ),
                            if (selectedProcedureTemplate?.assetDeviceName
                                    ?.trim()
                                    .isNotEmpty ??
                                false)
                              Chip(
                                avatar: const Icon(
                                  Icons.memory_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  'Dispositivo: ${selectedProcedureTemplate!.assetDeviceName!.trim()}',
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (selectedProcedureTemplate == null &&
                          normalizedProcedureName != null) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Este procedimento ja nao existe nas definicoes, mas continua guardado nesta ordem.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...procedureSteps
                    .take(6)
                    .map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_box_outline_blank,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step.title),
                                  if (step.isRequired ||
                                      step.requiresPhoto) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (step.isRequired)
                                          const Chip(
                                            label: Text('Obrigatorio'),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        if (step.requiresPhoto)
                                          const Chip(
                                            avatar: Icon(
                                              Icons.photo_camera_outlined,
                                              size: 16,
                                            ),
                                            label: Text('Fotografia'),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (procedureSteps.length > 6)
                  Text(
                    'E mais ${procedureSteps.length - 6} passos...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final technicianDropdownValue =
        technicians.any(
          (technician) => technician['id']?.toString() == selectedTechnician,
        )
        ? selectedTechnician
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar ordem' : 'Nova ordem')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titulo',
                        hintText: 'Ex: Revisao preventiva do compressor',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Ref.',
                        hintText: 'Ex: OT-2026-015',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 4,
                      validator: (value) {
                        final title = titleController.text.trim();
                        final description = value?.trim() ?? '';
                        if (title.isEmpty && description.isEmpty) {
                          return 'Preenche pelo menos o titulo ou a descricao.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Descricao',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: orderType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de ordem',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'corretiva',
                          child: Text('Corretiva'),
                        ),
                        DropdownMenuItem(
                          value: 'preventiva',
                          child: Text('Preventiva'),
                        ),
                        DropdownMenuItem(
                          value: 'medicoes_verificacoes',
                          child: Text('Medicoes e verificacoes'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          orderType = value;
                          if (orderType != 'preventiva') {
                            repeats = false;
                          }
                          if (orderType != 'preventiva' &&
                              orderType != 'medicoes_verificacoes') {
                            requiresPhoto = false;
                            requiresMeasurement = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    buildPrioritySelector(context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            buildProcedureCard(context),
            const SizedBox(height: 12),
            buildAssetDeviceCard(context),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      value: technicianDropdownValue,
                      decoration: const InputDecoration(labelText: 'Tecnico'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sem tecnico'),
                        ),
                        ...technicians.map((technician) {
                          return DropdownMenuItem<String?>(
                            value: technician['id']?.toString(),
                            child: Text(technician['name']?.toString() ?? ''),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedTechnician = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                          value: 'pendente',
                          child: Text('Pendente'),
                        ),
                        DropdownMenuItem(
                          value: 'em curso',
                          child: Text('Em curso'),
                        ),
                        DropdownMenuItem(
                          value: 'concluido',
                          child: Text('Concluido'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          status = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: observationsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observacoes',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: measurementController,
                      decoration: const InputDecoration(
                        labelText: 'Medicao',
                        hintText: 'Ex: 5.2 bar, 72 C, 380V',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Data planeada'),
                      subtitle: Text(
                        scheduledFor == null
                            ? 'Sem data definida'
                            : formatDateOnlyValue(
                                scheduledFor!.toIso8601String(),
                              ),
                      ),
                      trailing: TextButton(
                        onPressed: pickScheduledDate,
                        child: Text(
                          scheduledFor == null ? 'Escolher' : 'Alterar',
                        ),
                      ),
                    ),
                    if (scheduledFor != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              scheduledFor = null;
                            });
                          },
                          child: const Text('Remover data planeada'),
                        ),
                      ),
                    if (orderType == 'preventiva' ||
                        orderType == 'medicoes_verificacoes') ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fotografia obrigatoria'),
                        subtitle: const Text(
                          'Nao permitir concluir sem fotografia',
                        ),
                        value: requiresPhoto,
                        onChanged: (value) {
                          setState(() {
                            requiresPhoto = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Medicao obrigatoria'),
                        subtitle: const Text(
                          'Nao permitir concluir sem preencher a medicao',
                        ),
                        value: requiresMeasurement,
                        onChanged: (value) {
                          setState(() {
                            requiresMeasurement = value;
                          });
                        },
                      ),
                    ],
                    if (orderType == 'preventiva') ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Repetir automaticamente'),
                        subtitle: const Text(
                          'Criar a proxima ordem quando esta ficar concluida',
                        ),
                        value: repeats,
                        onChanged: (value) {
                          setState(() {
                            repeats = value;
                          });
                        },
                      ),
                      if (repeats) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: recurrenceInterval.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Intervalo',
                                ),
                                onChanged: (value) {
                                  recurrenceInterval = int.tryParse(value) ?? 1;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: recurrenceUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Unidade',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'dias',
                                    child: Text('Dias'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'semanas',
                                    child: Text('Semanas'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'meses',
                                    child: Text('Meses'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'anos',
                                    child: Text('Anos'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    recurrenceUnit = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fotografia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isSaving ? null : uploadPhoto,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        photoUrl?.isNotEmpty == true
                            ? 'Substituir foto'
                            : 'Carregar foto',
                      ),
                    ),
                    if (photoUrl?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photoUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Nao foi possivel carregar a fotografia.',
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isSaving
                            ? null
                            : () {
                                setState(() {
                                  photoUrl = null;
                                });
                              },
                        child: const Text('Remover fotografia'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anexo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isSaving ? null : uploadAttachment,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        attachmentUrl?.isNotEmpty == true
                            ? 'Substituir anexo'
                            : 'Carregar anexo',
                      ),
                    ),
                    if (attachmentUrl?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        attachmentUrl!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: isSaving ? null : openAttachment,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir'),
                          ),
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () {
                                    setState(() {
                                      attachmentUrl = null;
                                    });
                                  },
                            child: const Text('Remover'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isSaving ? null : save,
              icon: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(isEditing ? 'Atualizar ordem' : 'Guardar ordem'),
            ),
          ],
        ),
      ),
    );
  }
}
