import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/procedure_template.dart';
import '../models/user_profile.dart';
import '../qr/asset_qr_support.dart';
import 'add_work_order_page.dart';
import '../services/company_scope_service.dart';
import '../services/storage_service.dart';
import '../services/work_order_offline_service.dart';
import 'work_order_pdf_service.dart';
import 'work_order_helpers.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.task,
    required this.asset,
    this.canManageAll = true,
    this.canEditFullOrder = false,
    this.canCloseWorkOrder = true,
    this.technicianName,
    this.locationName,
    this.userProfile,
  });

  final Map<String, dynamic> task;
  final Map<String, dynamic> asset;
  final bool canManageAll;
  final bool canEditFullOrder;
  final bool canCloseWorkOrder;
  final String? technicianName;
  final String? locationName;
  final UserProfile? userProfile;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final supabase = Supabase.instance.client;
  final audioRecorder = AudioRecorder();
  final audioPlayer = AudioPlayer();
  late Map<String, dynamic> task;
  late Map<String, dynamic> currentAsset;
  StreamSubscription<PlayerState>? audioPlayerStateSubscription;
  bool isDeleting = false;
  bool supportsAudioNotes = false;
  bool hasValidatedAssetQr = false;
  bool hasPendingSync = false;
  bool isRecordingAudio = false;
  bool isSavingAudio = false;
  bool isPlayingAudio = false;
  bool isGeneratingSharePdf = false;
  String? technicianName;
  String? locationName;
  String? pendingQueuedAt;

  @override
  void initState() {
    super.initState();
    task = Map<String, dynamic>.from(widget.task);
    currentAsset = Map<String, dynamic>.from(widget.asset);
    technicianName = widget.technicianName;
    locationName = widget.locationName;
    hasPendingSync = task['_offline_pending'] == true;
    pendingQueuedAt = task['_offline_queued_at']?.toString();
    audioPlayerStateSubscription = audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() {
        isPlayingAudio = state == PlayerState.playing;
      });
    });
    loadFeatureSupport();
    loadPendingState();
    loadSupportingData();
  }

  @override
  void dispose() {
    audioPlayerStateSubscription?.cancel();
    audioPlayer.dispose();
    audioRecorder.dispose();
    super.dispose();
  }

  Future<void> loadFeatureSupport() async {
    final supported = await CompanyScopeService.instance.tableSupportsColumn(
      'work_orders',
      'audio_note_url',
    );
    if (!mounted) return;
    setState(() {
      supportsAudioNotes = supported;
    });
  }

  Future<void> loadPendingState() async {
    final resolvedTask = await WorkOrderOfflineService.instance
        .mergePendingStateIntoWorkOrder(task);
    if (!mounted) return;
    setState(() {
      task = resolvedTask;
      hasPendingSync = task['_offline_pending'] == true;
      pendingQueuedAt = task['_offline_queued_at']?.toString();
    });
  }

  Future<void> loadSupportingData() async {
    try {
      String? resolvedTechnicianName = technicianName;
      String? resolvedLocationName = locationName;
      Map<String, dynamic> resolvedAsset = currentAsset;

      final assetData = await supabase
          .from('assets')
          .select()
          .eq('id', task['asset_id'])
          .maybeSingle();
      if (assetData != null) {
        resolvedAsset = Map<String, dynamic>.from(assetData);
      }

      final technicianId = task['technician_id']?.toString();
      if (widget.userProfile?.isClient != true &&
          (resolvedTechnicianName?.isEmpty ?? true) &&
          technicianId != null &&
          technicianId.isNotEmpty) {
        final technicianData = await supabase
            .from('technicians')
            .select('name')
            .eq('id', technicianId)
            .maybeSingle();
        resolvedTechnicianName = technicianData?['name']?.toString();
      }

      if (resolvedLocationName?.isEmpty ?? true) {
        final locationId = resolvedAsset['location_id'];
        if (locationId != null) {
          final locationData = await supabase
              .from('locations')
              .select('name')
              .eq('id', locationId)
              .maybeSingle();
          resolvedLocationName = locationData?['name']?.toString();
        }
      }

      if (!mounted) return;
      setState(() {
        technicianName = resolvedTechnicianName;
        locationName = resolvedLocationName;
        currentAsset = resolvedAsset;
      });
    } catch (_) {}
  }

  Future<void> refreshTask() async {
    try {
      final data = await supabase
          .from('work_orders')
          .select()
          .eq('id', task['id'])
          .maybeSingle();

      if (!mounted || data == null) return;

      setState(() {
        task = Map<String, dynamic>.from(data);
        hasValidatedAssetQr = false;
      });
    } catch (_) {}

    await loadPendingState();
    await loadSupportingData();
  }

  bool get requiresMaintenanceQrValidation =>
      AssetQrSupport.requiresQrForMaintenance(currentAsset);

  String? get assetQrValue => AssetQrSupport.qrValueFromAsset(currentAsset);
  bool get isClientViewer => widget.userProfile?.isClient == true;
  bool get canShowClientDescription =>
      !isClientViewer || widget.userProfile?.canClientViewDescription == true;
  bool get canShowClientComments =>
      !isClientViewer || widget.userProfile?.canClientViewComments == true;
  bool get canShowClientPhotos =>
      !isClientViewer || widget.userProfile?.canClientViewPhotos == true;
  bool get canShowClientAttachments =>
      !isClientViewer || widget.userProfile?.canClientViewAttachments == true;
  bool get canShowClientScheduling =>
      !isClientViewer || widget.userProfile?.canClientViewScheduling == true;
  bool get canShowClientTechnician =>
      !isClientViewer || widget.userProfile?.canClientViewTechnician == true;
  bool get canShowClientLocation =>
      !isClientViewer || widget.userProfile?.canClientViewLocation == true;
  bool get canToggleProcedureChecklist =>
      widget.canManageAll || !isClientViewer;
  bool get isMobileAudioCapturePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get canRecordAudioNote =>
      supportsAudioNotes &&
      !widget.canManageAll &&
      !isClientViewer &&
      isMobileAudioCapturePlatform;
  bool get canDeleteAudioNote =>
      supportsAudioNotes &&
      !widget.canManageAll &&
      !isClientViewer &&
      workOrderAudioNoteUrl(task).trim().isNotEmpty;
  bool get canShowAudioNoteSection =>
      supportsAudioNotes &&
      !isClientViewer &&
      (canRecordAudioNote || workOrderAudioNoteUrl(task).isNotEmpty);
  bool get canSharePdf => widget.canManageAll;

  Future<bool> ensureMaintenanceQrValidated() async {
    if (widget.canManageAll || !requiresMaintenanceQrValidation) {
      return true;
    }

    if (hasValidatedAssetQr) {
      return true;
    }

    final expectedQrValue = assetQrValue;
    if (expectedQrValue == null || expectedQrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este ativo exige leitura de QR, mas ainda nao tem um QR associado.',
          ),
        ),
      );
      return false;
    }

    final scannedQrValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AssetQrScannerPage()),
    );

    if (!mounted || scannedQrValue == null || scannedQrValue.trim().isEmpty) {
      return false;
    }

    if (scannedQrValue.trim() != expectedQrValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O QR lido nao corresponde ao ativo desta manutencao.'),
        ),
      );
      return false;
    }

    setState(() {
      hasValidatedAssetQr = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR do ativo validado com sucesso.')),
    );
    return true;
  }

  Future<void> openEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddWorkOrderPage(asset: widget.asset, workOrder: task),
      ),
    );

    if (changed == true) {
      await refreshTask();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<WorkOrderUpdateOutcome?> updateTechnicianFields({
    required String notificationMessage,
    String? status,
    String? observations,
    String? photoUrl,
    String? audioNoteUrl,
    String? measurementValue,
    bool clearAudioNote = false,
    Iterable<DeferredStorageDelete> storageDeletesOnSuccessfulSync = const [],
  }) async {
    final isQrValidated = await ensureMaintenanceQrValidated();
    if (!isQrValidated) return null;

    final nowIso = DateTime.now().toIso8601String();
    final previousStatus = task['status']?.toString();
    final nextStatus = status ?? task['status']?.toString();

    if (nextStatus == 'concluido') {
      final missingRequirement = validateCompletionRequirements(
        photoUrl: photoUrl,
        measurementValue: measurementValue,
      );
      if (missingRequirement != null) {
        if (!mounted) return null;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(missingRequirement)));
        return null;
      }
    }

    final resolvedAudioNoteUrl = clearAudioNote
        ? null
        : audioNoteUrl ??
              (workOrderAudioNoteUrl(task).trim().isEmpty
                  ? null
                  : workOrderAudioNoteUrl(task).trim());

    final englishData = {
      'status': nextStatus,
      'comment': observations,
      'photo_url': photoUrl,
      'measurement_value': measurementValue,
      'updated_at': nowIso,
    };
    if (supportsAudioNotes) {
      englishData['audio_note_url'] = resolvedAudioNoteUrl;
    }

    final outcome = await WorkOrderOfflineService.instance.saveTechnicianUpdate(
      workOrder: task,
      patch: englishData,
      notificationMessage: notificationMessage,
      shouldCreateRecurringOnCompletion:
          previousStatus != 'concluido' && nextStatus == 'concluido',
      storageDeletesOnSuccessfulSync: storageDeletesOnSuccessfulSync,
    );

    if (!mounted) return outcome;
    setState(() {
      task = Map<String, dynamic>.from(outcome.workOrder);
      hasPendingSync = !outcome.synced;
      pendingQueuedAt = task['_offline_queued_at']?.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.synced
              ? 'Alteracao guardada com sucesso.'
              : 'Alteracao guardada offline. Vai sincronizar quando houver ligacao.',
        ),
      ),
    );

    return outcome;
  }

  Future<void> updateAdminQuickFields({
    String? observations,
    String? photoUrl,
    String? measurementValue,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final englishData = {
      'comment': observations,
      'photo_url': photoUrl,
      'measurement_value': measurementValue,
      'updated_at': nowIso,
    };
    await supabase.from('work_orders').update(englishData).eq('id', task['id']);

    await refreshTask();
  }

  Future<void> updateProcedureSteps(List<ProcedureChecklistItem> steps) async {
    if (!widget.canManageAll) {
      final isQrValidated = await ensureMaintenanceQrValidated();
      if (!isQrValidated) return;
    }

    final nowIso = DateTime.now().toIso8601String();
    final supportsProcedureSteps = await CompanyScopeService.instance
        .tableSupportsColumn('work_orders', 'procedure_steps');
    if (!supportsProcedureSteps) return;

    final patch = {
      'procedure_steps': ProcedureChecklistItem.toSnapshotJson(steps),
      'updated_at': nowIso,
    };

    if (widget.canManageAll) {
      await supabase.from('work_orders').update(patch).eq('id', task['id']);
      await refreshTask();
      return;
    }

    final outcome = await WorkOrderOfflineService.instance.saveTechnicianUpdate(
      workOrder: task,
      patch: patch,
      notificationMessage:
          'O tecnico atualizou o procedimento da ordem "${workOrderTitle(task)}".',
    );

    if (!mounted) return;
    setState(() {
      task = Map<String, dynamic>.from(outcome.workOrder);
      hasPendingSync = !outcome.synced;
      pendingQueuedAt = task['_offline_queued_at']?.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.synced
              ? 'Procedimento guardado com sucesso.'
              : 'Procedimento guardado offline. Vai sincronizar quando houver ligacao.',
        ),
      ),
    );
  }

  Future<void> toggleProcedureStep(
    ProcedureChecklistItem step,
    bool isChecked,
  ) async {
    final currentSteps = workOrderProcedureSteps(task);
    final updatedSteps = currentSteps
        .map(
          (item) =>
              item.id == step.id ? item.copyWith(isChecked: isChecked) : item,
        )
        .toList();

    await updateProcedureSteps(updatedSteps);
  }

  Future<void> uploadProcedureStepPhoto(ProcedureChecklistItem step) async {
    if (!widget.canManageAll) {
      final isQrValidated = await ensureMaintenanceQrValidated();
      if (!isQrValidated) return;
    }

    try {
      final url = await StorageService.instance.pickAndUploadPhoto();
      if (!mounted || url == null) return;

      final currentSteps = workOrderProcedureSteps(task);
      final updatedSteps = currentSteps
          .map(
            (item) => item.id == step.id ? item.copyWith(photoUrl: url) : item,
          )
          .toList();

      await updateProcedureSteps(updatedSteps);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografia do passo atualizada com sucesso.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao guardar a fotografia do passo: $error'),
        ),
      );
    }
  }

  Future<void> removeProcedureStepPhoto(ProcedureChecklistItem step) async {
    final currentSteps = workOrderProcedureSteps(task);
    final updatedSteps = currentSteps
        .map(
          (item) => item.id == step.id ? item.copyWith(clearPhoto: true) : item,
        )
        .toList();

    await updateProcedureSteps(updatedSteps);
  }

  Future<void> editAdminObservations() async {
    final controller = TextEditingController(text: workOrderObservations(task));

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Observacoes'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Adicionar observacoes a esta ordem',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await updateAdminQuickFields(
      observations: result.isEmpty ? null : result,
      photoUrl: workOrderPhotoUrl(task).isEmpty
          ? null
          : workOrderPhotoUrl(task),
      measurementValue: workOrderMeasurement(task).isEmpty
          ? null
          : workOrderMeasurement(task),
    );
  }

  Future<void> editMeasurement({required bool isTechnician}) async {
    final controller = TextEditingController(text: workOrderMeasurement(task));

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Medicao'),
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Ex: 5.2 bar, 72 C, 380V',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    if (isTechnician) {
      await updateTechnicianFields(
        notificationMessage:
            'O tecnico atualizou a medicao da ordem "${workOrderTitle(task)}".',
        observations: workOrderObservations(task).isEmpty
            ? null
            : workOrderObservations(task),
        status: task['status']?.toString(),
        photoUrl: workOrderPhotoUrl(task).isEmpty
            ? null
            : workOrderPhotoUrl(task),
        measurementValue: result.isEmpty ? null : result,
      );
      return;
    }

    await updateAdminQuickFields(
      observations: workOrderObservations(task).isEmpty
          ? null
          : workOrderObservations(task),
      photoUrl: workOrderPhotoUrl(task).isEmpty
          ? null
          : workOrderPhotoUrl(task),
      measurementValue: result.isEmpty ? null : result,
    );
  }

  Future<void> uploadAdminPhoto() async {
    try {
      final url = await StorageService.instance.pickAndUploadPhoto();
      if (!mounted || url == null) return;

      await updateAdminQuickFields(
        observations: workOrderObservations(task).isEmpty
            ? null
            : workOrderObservations(task),
        photoUrl: url,
        measurementValue: workOrderMeasurement(task).isEmpty
            ? null
            : workOrderMeasurement(task),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotografia atualizada com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao guardar fotografia: $e')),
      );
    }
  }

  Future<void> editObservations() async {
    final controller = TextEditingController(text: workOrderObservations(task));

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Observacoes'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Adicionar observacoes do tecnico',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await updateTechnicianFields(
      notificationMessage:
          'O tecnico atualizou as observacoes da ordem "${workOrderTitle(task)}".',
      observations: result.isEmpty ? null : result,
      status: task['status']?.toString(),
      photoUrl: workOrderPhotoUrl(task).isEmpty
          ? null
          : workOrderPhotoUrl(task),
      measurementValue: workOrderMeasurement(task).isEmpty
          ? null
          : workOrderMeasurement(task),
    );
  }

  Future<void> updateStatus() async {
    final selectedStatus = await showDialog<String>(
      context: context,
      builder: (context) {
        final availableStatuses = <String>[
          'pendente',
          'em curso',
          if (widget.canCloseWorkOrder) 'concluido',
        ];

        return AlertDialog(
          title: const Text('Alterar estado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableStatuses.map((status) {
              final label = switch (status) {
                'pendente' => 'Pendente',
                'em curso' => 'Em curso',
                'concluido' => 'Concluido',
                _ => status,
              };

              return ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(context, status),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selectedStatus == null ||
        selectedStatus == task['status']?.toString()) {
      return;
    }

    await updateTechnicianFields(
      notificationMessage:
          'O tecnico alterou o estado da ordem "${workOrderTitle(task)}" para "$selectedStatus".',
      status: selectedStatus,
      observations: workOrderObservations(task).isEmpty
          ? null
          : workOrderObservations(task),
      photoUrl: workOrderPhotoUrl(task).isEmpty
          ? null
          : workOrderPhotoUrl(task),
      measurementValue: workOrderMeasurement(task).isEmpty
          ? null
          : workOrderMeasurement(task),
    );
  }

  Future<void> uploadTechnicianPhoto() async {
    try {
      final url = await StorageService.instance.pickAndUploadPhoto();
      if (!mounted || url == null) return;

      await updateTechnicianFields(
        notificationMessage:
            'O tecnico adicionou/atualizou a fotografia da ordem "${workOrderTitle(task)}".',
        status: task['status']?.toString(),
        observations: workOrderObservations(task).isEmpty
            ? null
            : workOrderObservations(task),
        photoUrl: url,
        measurementValue: workOrderMeasurement(task).isEmpty
            ? null
            : workOrderMeasurement(task),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotografia atualizada com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao guardar fotografia: $e')),
      );
    }
  }

  Future<void> startTechnicianAudioRecording() async {
    if (!canRecordAudioNote || isRecordingAudio || isSavingAudio) return;

    if (requiresMaintenanceQrValidation && !hasValidatedAssetQr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Valida primeiro o QR do ativo antes de gravar a nota audio.',
          ),
        ),
      );
      return;
    }

    try {
      final alreadyGranted = await audioRecorder.hasPermission(request: false);
      if (!alreadyGranted) {
        final granted = await audioRecorder.hasPermission();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? 'Permissao de microfone concedida. Mantem o botao novamente para gravar.'
                  : 'Sem acesso ao microfone nao e possivel gravar audio.',
            ),
          ),
        );
        return;
      }

      await audioPlayer.stop();
      final temporaryPath = await buildTemporaryAudioRecordingPath();
      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: temporaryPath,
      );

      if (!mounted) return;
      setState(() {
        isRecordingAudio = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao iniciar a gravacao audio: $error')),
      );
    }
  }

  Future<void> stopAndSaveTechnicianAudioRecording() async {
    if (!isRecordingAudio || isSavingAudio) return;
    final previousAudioNote = workOrderAudioNoteUrl(task).trim();
    String? uploadedAudioPath;

    try {
      setState(() {
        isSavingAudio = true;
      });

      final recordedPath = await audioRecorder.stop();
      if (recordedPath == null || recordedPath.trim().isEmpty) {
        throw StateError('A gravacao nao gerou um ficheiro valido.');
      }

      final audioFile = XFile(recordedPath, mimeType: 'audio/mp4');
      final audioBytes = await audioFile.readAsBytes();
      if (audioBytes.isEmpty) {
        throw StateError('A gravacao ficou vazia.');
      }

      uploadedAudioPath = await StorageService.instance
          .uploadWorkOrderAudioNote(
            workOrderId: task['id']?.toString() ?? 'ordem',
            bytes: audioBytes,
            fileName: audioNoteFileNameFromPath(recordedPath),
          );

      final outcome = await updateTechnicianFields(
        notificationMessage:
            'O tecnico adicionou/atualizou uma nota audio na ordem "${workOrderTitle(task)}".',
        status: task['status']?.toString(),
        observations: workOrderObservations(task).isEmpty
            ? null
            : workOrderObservations(task),
        photoUrl: workOrderPhotoUrl(task).isEmpty
            ? null
            : workOrderPhotoUrl(task),
        audioNoteUrl: uploadedAudioPath,
        measurementValue: workOrderMeasurement(task).isEmpty
            ? null
            : workOrderMeasurement(task),
        storageDeletesOnSuccessfulSync:
            previousAudioNote.isNotEmpty &&
                previousAudioNote != uploadedAudioPath
            ? [
                DeferredStorageDelete(
                  bucket: 'work-order-attachments',
                  storedValue: previousAudioNote,
                ),
              ]
            : const [],
      );

      if (outcome == null && uploadedAudioPath != null) {
        try {
          await StorageService.instance.deleteStoredObject(
            bucket: 'work-order-attachments',
            storedValue: uploadedAudioPath,
          );
        } catch (_) {}
        uploadedAudioPath = null;
      }
    } catch (error) {
      if (uploadedAudioPath != null) {
        try {
          await StorageService.instance.deleteStoredObject(
            bucket: 'work-order-attachments',
            storedValue: uploadedAudioPath,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao guardar a nota audio: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isRecordingAudio = false;
          isSavingAudio = false;
        });
      }
    }
  }

  Future<void> cancelTechnicianAudioRecording() async {
    if (!isRecordingAudio) return;

    try {
      await audioRecorder.cancel();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      isRecordingAudio = false;
    });
  }

  Future<String> buildTemporaryAudioRecordingPath() async {
    final workOrderId = sanitizeAudioFileSegment(
      task['id']?.toString() ?? 'ordem',
    );
    final fileName =
        'work_order_audio_${workOrderId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    if (kIsWeb) {
      return fileName;
    }

    final temporaryDirectory = await getTemporaryDirectory();
    return '${temporaryDirectory.path}/$fileName';
  }

  String audioNoteFileNameFromPath(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
    final segments = normalizedPath.split('/');
    final candidate = segments.isEmpty ? '' : segments.last.trim();
    if (candidate.isEmpty) {
      return 'nota_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    return candidate;
  }

  String sanitizeAudioFileSegment(String value) {
    final sanitized = value.trim().replaceAll(
      RegExp(r'[^\w\-]+', unicode: true),
      '_',
    );
    return sanitized.isEmpty ? 'ordem' : sanitized;
  }

  Future<void> toggleAudioNotePlayback() async {
    final audioNoteUrl = workOrderAudioNoteUrl(task).trim();
    if (audioNoteUrl.isEmpty || isSavingAudio) return;

    try {
      if (isPlayingAudio) {
        await audioPlayer.stop();
        return;
      }

      final uri = await StorageService.instance.resolveFileUri(
        bucket: 'work-order-attachments',
        storedValue: audioNoteUrl,
      );
      if (uri == null) {
        throw StateError('Nao foi possivel preparar o audio.');
      }

      await audioPlayer.stop();
      await audioPlayer.play(UrlSource(uri.toString()));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao reproduzir a nota audio: $error')),
      );
    }
  }

  Future<void> deleteTechnicianAudioNote() async {
    final audioNoteUrl = workOrderAudioNoteUrl(task).trim();
    if (!canDeleteAudioNote || audioNoteUrl.isEmpty || isSavingAudio) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar nota audio'),
          content: const Text(
            'Queres eliminar a nota audio associada a esta ordem?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      setState(() {
        isSavingAudio = true;
      });

      await audioPlayer.stop();
      await updateTechnicianFields(
        notificationMessage:
            'O tecnico eliminou a nota audio da ordem "${workOrderTitle(task)}".',
        status: task['status']?.toString(),
        observations: workOrderObservations(task).isEmpty
            ? null
            : workOrderObservations(task),
        photoUrl: workOrderPhotoUrl(task).isEmpty
            ? null
            : workOrderPhotoUrl(task),
        measurementValue: workOrderMeasurement(task).isEmpty
            ? null
            : workOrderMeasurement(task),
        clearAudioNote: true,
        storageDeletesOnSuccessfulSync: [
          DeferredStorageDelete(
            bucket: 'work-order-attachments',
            storedValue: audioNoteUrl,
          ),
        ],
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao eliminar a nota audio: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingAudio = false;
        });
      }
    }
  }

  Future<void> deleteTask() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar ordem'),
          content: Text('Queres eliminar "${workOrderTitle(task)}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      isDeleting = true;
    });

    try {
      await supabase.from('work_orders').delete().eq('id', task['id']);

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  String _buildPdfFileName() {
    final reference = workOrderReference(task).trim();
    final title = workOrderTitle(task).trim();
    final rawValue = reference.isNotEmpty ? reference : title;
    final sanitized = rawValue.replaceAll(
      RegExp(r'[^\w\-]+', unicode: true),
      '_',
    );
    final safeValue = sanitized.isEmpty ? 'ordem' : sanitized;
    return 'ordem_${safeValue.toLowerCase()}.pdf';
  }

  Future<void> _showWorkOrderPdfDialog() async {
    if (!canSharePdf || isGeneratingSharePdf) return;

    var options = const WorkOrderPdfOptions();
    final result = await showDialog<_WorkOrderPdfDialogResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Widget optionTile({
              required String label,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return CheckboxListTile(
                value: value,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(label),
                onChanged: (nextValue) {
                  if (nextValue == null) return;
                  setDialogState(() {
                    onChanged(nextValue);
                  });
                },
              );
            }

            void closeWith(_WorkOrderPdfAction action) {
              if (!options.hasSelection) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Escolhe pelo menos uma secao antes de gerar o PDF.',
                    ),
                  ),
                );
                return;
              }

              Navigator.of(dialogContext).pop(
                _WorkOrderPdfDialogResult(action: action, options: options),
              );
            }

            return AlertDialog(
              title: const Text('PDF da ordem'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Escolhe exatamente a informacao que queres incluir no PDF desta ordem.',
                      ),
                      const SizedBox(height: 16),
                      optionTile(
                        label: 'Resumo principal',
                        value: options.includeSummary,
                        onChanged: (value) =>
                            options = options.copyWith(includeSummary: value),
                      ),
                      optionTile(
                        label: 'Descricao',
                        value: options.includeDescription,
                        onChanged: (value) => options = options.copyWith(
                          includeDescription: value,
                        ),
                      ),
                      optionTile(
                        label: 'Atribuicao (tecnico e localizacao)',
                        value: options.includeAssignment,
                        onChanged: (value) => options = options.copyWith(
                          includeAssignment: value,
                        ),
                      ),
                      optionTile(
                        label: 'Datas e tipo de ordem',
                        value: options.includeDatesAndType,
                        onChanged: (value) => options = options.copyWith(
                          includeDatesAndType: value,
                        ),
                      ),
                      optionTile(
                        label: 'Requisitos',
                        value: options.includeRequirements,
                        onChanged: (value) => options = options.copyWith(
                          includeRequirements: value,
                        ),
                      ),
                      optionTile(
                        label: 'Medicao',
                        value: options.includeMeasurement,
                        onChanged: (value) => options = options.copyWith(
                          includeMeasurement: value,
                        ),
                      ),
                      optionTile(
                        label: 'Observacoes',
                        value: options.includeObservations,
                        onChanged: (value) => options = options.copyWith(
                          includeObservations: value,
                        ),
                      ),
                      optionTile(
                        label: 'Procedimento e checklist',
                        value: options.includeProcedure,
                        onChanged: (value) =>
                            options = options.copyWith(includeProcedure: value),
                      ),
                      optionTile(
                        label: 'Fotografia',
                        value: options.includePhoto,
                        onChanged: (value) =>
                            options = options.copyWith(includePhoto: value),
                      ),
                      optionTile(
                        label: 'Anexos e referencias',
                        value: options.includeAttachments,
                        onChanged: (value) => options = options.copyWith(
                          includeAttachments: value,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => closeWith(_WorkOrderPdfAction.preview),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Previsualizar'),
                ),
                FilledButton.icon(
                  onPressed: () => closeWith(_WorkOrderPdfAction.share),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Partilhar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    await _generateWorkOrderPdf(options: result.options, action: result.action);
  }

  Future<void> _generateWorkOrderPdf({
    required WorkOrderPdfOptions options,
    required _WorkOrderPdfAction action,
  }) async {
    if (!options.hasSelection || isGeneratingSharePdf) return;

    setState(() {
      isGeneratingSharePdf = true;
    });

    try {
      final bytes = await WorkOrderPdfService.instance.buildPdf(
        task: task,
        asset: currentAsset,
        technicianName: technicianName,
        locationName: locationName,
        options: options,
      );
      final fileName = _buildPdfFileName();

      if (action == _WorkOrderPdfAction.preview) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel gerar o PDF da ordem: $error'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isGeneratingSharePdf = false;
      });
    }
  }

  Future<void> openUrl(String value) async {
    if (value.isEmpty) return;

    final uri = Uri.tryParse(value);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openAttachmentUrl(String value) async {
    final uri = await StorageService.instance.resolveFileUri(
      bucket: 'work-order-attachments',
      storedValue: value,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? validateCompletionRequirements({
    required String? photoUrl,
    required String? measurementValue,
  }) {
    if (workOrderRequiresPhoto(task) &&
        (photoUrl == null || photoUrl.trim().isEmpty)) {
      return 'Esta ordem exige fotografia antes de concluir.';
    }

    if (workOrderRequiresMeasurement(task) &&
        (measurementValue == null || measurementValue.trim().isEmpty)) {
      return 'Esta ordem exige medicao antes de concluir.';
    }

    final procedureError = validateProcedureStepsForCompletion(
      workOrderProcedureSteps(task),
    );
    if (procedureError != null) {
      return procedureError;
    }

    return null;
  }

  Color statusColor(String status, ThemeData theme) {
    switch (status) {
      case 'concluido':
        return Colors.green;
      case 'em curso':
        return Colors.orange;
      default:
        return theme.colorScheme.primary;
    }
  }

  Widget infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }

  Widget buildAudioNoteCard(BuildContext context) {
    final theme = Theme.of(context);
    final audioNoteUrl = workOrderAudioNoteUrl(task).trim();
    final hasAudioNote = audioNoteUrl.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nota audio', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              canRecordAudioNote
                  ? 'Mantem o botao premido para gravar uma nota audio. Ao largar, a gravacao para e fica associada a esta ordem.'
                  : 'Esta ordem tem uma nota audio gravada pelo tecnico.',
              style: theme.textTheme.bodySmall,
            ),
            if (canRecordAudioNote) ...[
              const SizedBox(height: 12),
              Listener(
                onPointerDown: (_) => startTechnicianAudioRecording(),
                onPointerUp: (_) => stopAndSaveTechnicianAudioRecording(),
                onPointerCancel: (_) => cancelTechnicianAudioRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: isRecordingAudio
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRecordingAudio
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isRecordingAudio ? Icons.mic : Icons.mic_none_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isSavingAudio
                              ? 'A guardar a nota audio...'
                              : isRecordingAudio
                              ? 'A gravar. Larga o botao para guardar.'
                              : 'Premir e manter para gravar',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (hasAudioNote)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: isRecordingAudio
                        ? null
                        : toggleAudioNotePlayback,
                    icon: Icon(
                      isPlayingAudio
                          ? Icons.stop_circle_outlined
                          : Icons.play_arrow,
                    ),
                    label: Text(isPlayingAudio ? 'Parar audio' : 'Ouvir audio'),
                  ),
                  TextButton.icon(
                    onPressed: isRecordingAudio
                        ? null
                        : () => openAttachmentUrl(audioNoteUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir'),
                  ),
                  if (canDeleteAudioNote)
                    TextButton.icon(
                      onPressed: isRecordingAudio || isSavingAudio
                          ? null
                          : deleteTechnicianAudioNote,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar'),
                    ),
                ],
              )
            else
              Text(
                canRecordAudioNote
                    ? 'Ainda nao existe nenhuma nota audio nesta ordem.'
                    : 'Sem nota audio associada.',
                style: theme.textTheme.bodySmall,
              ),
            if (isSavingAudio) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A enviar o audio para a ordem...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildProcedureCard(
    BuildContext context,
    List<ProcedureChecklistItem> procedureSteps,
  ) {
    final completedSteps = procedureSteps
        .where((step) => step.isChecked)
        .length;
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workOrderProcedureName(task).trim().isEmpty
                            ? 'Procedimento'
                            : workOrderProcedureName(task).trim(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$completedSteps de ${procedureSteps.length} passos concluidos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                CircularProgressIndicator(
                  value: procedureSteps.isEmpty
                      ? 0
                      : completedSteps / procedureSteps.length,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...procedureSteps.map(
              (step) => _buildProcedureStepCard(context, step),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcedureStepCard(
    BuildContext context,
    ProcedureChecklistItem step,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canToggleProcedureChecklist)
                Checkbox(
                  value: step.isChecked,
                  onChanged: (value) {
                    if (value == null) return;
                    toggleProcedureStep(step, value);
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Icon(
                    step.isChecked
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: canToggleProcedureChecklist ? 10 : 8,
                      ),
                      child: Text(
                        step.title,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (step.isRequired || step.requiresPhoto) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (step.isRequired)
                            const Chip(
                              label: Text('Obrigatorio'),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (step.requiresPhoto)
                            const Chip(
                              avatar: Icon(
                                Icons.photo_camera_outlined,
                                size: 16,
                              ),
                              label: Text('Fotografia'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (step.requiresPhoto) ...[
            const SizedBox(height: 8),
            if (step.hasPhoto) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  step.photoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nao foi possivel carregar a fotografia deste passo.',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ] else
              Text(
                'Sem fotografia neste passo.',
                style: theme.textTheme.bodySmall,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canToggleProcedureChecklist)
                  OutlinedButton.icon(
                    onPressed: () => uploadProcedureStepPhoto(step),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      step.hasPhoto
                          ? 'Atualizar fotografia'
                          : 'Adicionar fotografia',
                    ),
                  ),
                if (step.hasPhoto)
                  TextButton.icon(
                    onPressed: () => openUrl(step.photoUrl!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir'),
                  ),
                if (canToggleProcedureChecklist && step.hasPhoto)
                  TextButton(
                    onPressed: () => removeProcedureStepPhoto(step),
                    child: const Text('Remover'),
                  ),
              ],
            ),
            if (step.isRequired && !step.hasPhoto)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Este passo obrigatorio precisa de fotografia antes de concluir a ordem.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = workOrderPhotoUrl(task);
    final attachmentUrl = workOrderAttachmentUrl(task);
    final audioNoteUrl = workOrderAudioNoteUrl(task);
    final assetDeviceName = workOrderAssetDeviceName(task).trim();
    final status = task['status']?.toString() ?? '-';
    final assetRequiresQr = requiresMaintenanceQrValidation;
    final assetQrIsConfigured = assetQrValue?.isNotEmpty == true;
    final procedureSteps = workOrderProcedureSteps(task);

    return Scaffold(
      appBar: AppBar(
        title: Text(workOrderTitle(task)),
        actions: [
          if (canSharePdf)
            IconButton(
              onPressed: isGeneratingSharePdf ? null : _showWorkOrderPdfDialog,
              icon: isGeneratingSharePdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              tooltip: 'PDF da ordem',
            ),
          if (widget.canManageAll || widget.canEditFullOrder)
            IconButton(
              onPressed: openEdit,
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
            ),
          if (widget.canManageAll)
            IconButton(
              onPressed: isDeleting ? null : deleteTask,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.info_outline, size: 18),
                        label: Text(status),
                        side: BorderSide.none,
                        backgroundColor: statusColor(
                          status,
                          theme,
                        ).withValues(alpha: 0.12),
                      ),
                      if (workOrderReference(task).isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.tag, size: 18),
                          label: Text(workOrderReference(task)),
                          side: BorderSide.none,
                        ),
                      if (hasPendingSync)
                        const Chip(
                          avatar: Icon(Icons.cloud_upload_outlined, size: 18),
                          label: Text('Por sincronizar'),
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (canShowClientDescription)
                    Text(
                      workOrderDescription(task).isEmpty
                          ? 'Sem descricao'
                          : workOrderDescription(task),
                      style: theme.textTheme.bodyLarge,
                    ),
                  if (widget.canManageAll) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: editAdminObservations,
                          icon: const Icon(Icons.notes),
                          label: const Text('Observacoes'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => editMeasurement(isTechnician: false),
                          icon: const Icon(Icons.speed_outlined),
                          label: const Text('Medicao'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: uploadAdminPhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Fotografia'),
                        ),
                      ],
                    ),
                  ],
                  if (!widget.canManageAll && !isClientViewer) ...[
                    const SizedBox(height: 12),
                    if (hasPendingSync)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sync_problem),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pendingQueuedAt == null
                                    ? 'Esta ordem tem alteracoes locais por sincronizar.'
                                    : 'Esta ordem tem alteracoes locais por sincronizar desde ${formatDateValue(pendingQueuedAt)}.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (assetRequiresQr)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hasValidatedAssetQr
                                      ? Icons.verified
                                      : Icons.qr_code_scanner,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hasValidatedAssetQr
                                        ? 'QR do ativo ja validado nesta manutencao.'
                                        : 'A leitura do QR deste ativo e obrigatoria para atualizar a manutencao.',
                                  ),
                                ),
                              ],
                            ),
                            if (!hasValidatedAssetQr)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: OutlinedButton.icon(
                                  onPressed: assetQrIsConfigured
                                      ? ensureMaintenanceQrValidated
                                      : null,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: Text(
                                    assetQrIsConfigured
                                        ? 'Validar QR do ativo'
                                        : 'Ativo sem QR configurado',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: updateStatus,
                          icon: const Icon(Icons.sync),
                          label: Text(
                            widget.canCloseWorkOrder
                                ? 'Mudar estado'
                                : 'Atualizar estado',
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: editObservations,
                          icon: const Icon(Icons.notes),
                          label: const Text('Observacoes'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => editMeasurement(isTechnician: true),
                          icon: const Icon(Icons.speed_outlined),
                          label: const Text('Medicao'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: uploadTechnicianPhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Fotografia'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (procedureSteps.isNotEmpty)
            buildProcedureCard(context, procedureSteps),
          if (canShowClientTechnician)
            infoTile(
              icon: Icons.engineering_outlined,
              label: 'Tecnico',
              value: technicianName?.isNotEmpty == true ? technicianName! : '',
            ),
          if (canShowClientLocation)
            infoTile(
              icon: Icons.place_outlined,
              label: 'Localizacao',
              value: locationName ?? '',
            ),
          if (assetDeviceName.isNotEmpty)
            infoTile(
              icon: Icons.memory_outlined,
              label: 'Dispositivo',
              value: assetDeviceName,
            ),
          infoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Data de criacao',
            value: formatDateValue(task['created_at']),
          ),
          infoTile(
            icon: Icons.category_outlined,
            label: 'Tipo de ordem',
            value: workOrderTypeLabel(workOrderType(task)),
          ),
          if (canShowClientScheduling)
            infoTile(
              icon: Icons.event_outlined,
              label: 'Data planeada',
              value: formatDateOnlyValue(workOrderScheduledFor(task)),
            ),
          if (isPreventiveOrder(task))
            infoTile(
              icon: Icons.repeat_outlined,
              label: 'Recorrencia',
              value: recurrenceSummary(task),
            ),
          infoTile(
            icon: Icons.speed_outlined,
            label: 'Medicao',
            value: workOrderMeasurement(task),
          ),
          if (supportsWorkOrderRequirements(task) &&
              (workOrderRequiresPhoto(task) ||
                  workOrderRequiresMeasurement(task) ||
                  assetRequiresQr))
            infoTile(
              icon: Icons.rule_folder_outlined,
              label: 'Requisitos',
              value: [
                if (workOrderRequiresPhoto(task)) 'Fotografia obrigatoria',
                if (workOrderRequiresMeasurement(task)) 'Medicao obrigatoria',
                if (assetRequiresQr) 'Leitura de QR obrigatoria',
              ].join(' | '),
            ),
          infoTile(
            icon: Icons.update_outlined,
            label: 'Ultima alteracao',
            value: formatDateValue(workOrderUpdatedAt(task)),
          ),
          if (canShowClientComments)
            infoTile(
              icon: Icons.notes_outlined,
              label: 'Observacoes',
              value: workOrderObservations(task),
            ),
          if (canShowAudioNoteSection || audioNoteUrl.isNotEmpty)
            buildAudioNoteCard(context),
          if (canShowClientAttachments)
            Card(
              child: ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Anexo'),
                subtitle: Text(
                  attachmentUrl.isEmpty ? 'Sem anexo' : attachmentUrl,
                ),
                trailing: attachmentUrl.isEmpty
                    ? null
                    : const Icon(Icons.open_in_new),
                onTap: attachmentUrl.isEmpty
                    ? null
                    : () => openAttachmentUrl(attachmentUrl),
              ),
            ),
          if (canShowClientPhotos)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fotografia', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (photoUrl.isEmpty)
                      const Text('Sem fotografia associada')
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photoUrl,
                          height: 220,
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => openUrl(photoUrl),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir original'),
                        ),
                      ),
                    ],
                    if (widget.canManageAll)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: uploadAdminPhoto,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            photoUrl.isEmpty
                                ? 'Adicionar fotografia'
                                : 'Atualizar fotografia',
                          ),
                        ),
                      ),
                    if (!widget.canManageAll && !isClientViewer)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: uploadTechnicianPhoto,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Atualizar fotografia'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkOrderPdfDialogResult {
  const _WorkOrderPdfDialogResult({
    required this.action,
    required this.options,
  });

  final _WorkOrderPdfAction action;
  final WorkOrderPdfOptions options;
}

enum _WorkOrderPdfAction { preview, share }
