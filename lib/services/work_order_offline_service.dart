import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/procedure_template.dart';
import '../models/user_profile.dart';
import '../work_orders/work_order_helpers.dart';
import 'client_scope_service.dart';
import 'company_scope_service.dart';
import 'local_cache_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class WorkOrdersSnapshot {
  const WorkOrdersSnapshot({
    required this.workOrders,
    required this.technicianNamesById,
    required this.assetsById,
    required this.locationNamesById,
    this.usedOfflineCache = false,
    this.pendingChangesCount = 0,
    this.lastSyncedAt,
  });

  final List<Map<String, dynamic>> workOrders;
  final Map<String, String> technicianNamesById;
  final Map<String, Map<String, dynamic>> assetsById;
  final Map<String, String> locationNamesById;
  final bool usedOfflineCache;
  final int pendingChangesCount;
  final DateTime? lastSyncedAt;

  WorkOrdersSnapshot copyWith({
    List<Map<String, dynamic>>? workOrders,
    Map<String, String>? technicianNamesById,
    Map<String, Map<String, dynamic>>? assetsById,
    Map<String, String>? locationNamesById,
    bool? usedOfflineCache,
    int? pendingChangesCount,
    DateTime? lastSyncedAt,
  }) {
    return WorkOrdersSnapshot(
      workOrders: workOrders ?? this.workOrders,
      technicianNamesById: technicianNamesById ?? this.technicianNamesById,
      assetsById: assetsById ?? this.assetsById,
      locationNamesById: locationNamesById ?? this.locationNamesById,
      usedOfflineCache: usedOfflineCache ?? this.usedOfflineCache,
      pendingChangesCount: pendingChangesCount ?? this.pendingChangesCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class WorkOrderUpdateOutcome {
  const WorkOrderUpdateOutcome({
    required this.workOrder,
    required this.synced,
    required this.pendingChangesCount,
  });

  final Map<String, dynamic> workOrder;
  final bool synced;
  final int pendingChangesCount;
}

class DeferredStorageDelete {
  const DeferredStorageDelete({
    required this.bucket,
    required this.storedValue,
  });

  final String bucket;
  final String storedValue;

  String get dedupeKey => '$bucket::$storedValue';

  factory DeferredStorageDelete.fromMap(Map<String, dynamic> map) {
    return DeferredStorageDelete(
      bucket: map['bucket']?.toString() ?? '',
      storedValue: map['stored_value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'bucket': bucket, 'stored_value': storedValue};
  }
}

class WorkOrderOfflineEvent {
  const WorkOrderOfflineEvent({
    required this.pendingChangesCount,
    required this.syncedChanges,
  });

  final int pendingChangesCount;
  final bool syncedChanges;
}

class _PendingWorkOrderChange {
  const _PendingWorkOrderChange({
    required this.workOrderId,
    required this.patch,
    required this.workOrderSnapshot,
    required this.queuedAt,
    this.notificationMessage,
    this.shouldCreateRecurringOnCompletion = false,
    this.storageDeletesOnSuccessfulSync = const [],
  });

  final String workOrderId;
  final Map<String, dynamic> patch;
  final Map<String, dynamic> workOrderSnapshot;
  final String queuedAt;
  final String? notificationMessage;
  final bool shouldCreateRecurringOnCompletion;
  final List<DeferredStorageDelete> storageDeletesOnSuccessfulSync;

  factory _PendingWorkOrderChange.fromMap(Map<String, dynamic> map) {
    return _PendingWorkOrderChange(
      workOrderId: map['work_order_id']?.toString() ?? '',
      patch: map['patch'] is Map
          ? Map<String, dynamic>.from(map['patch'] as Map)
          : const {},
      workOrderSnapshot: map['work_order_snapshot'] is Map
          ? Map<String, dynamic>.from(map['work_order_snapshot'] as Map)
          : const {},
      queuedAt:
          map['queued_at']?.toString() ?? DateTime.now().toIso8601String(),
      notificationMessage: map['notification_message']?.toString(),
      shouldCreateRecurringOnCompletion:
          map['should_create_recurring_on_completion'] == true,
      storageDeletesOnSuccessfulSync:
          map['storage_deletes_on_successful_sync'] is List
          ? List<Map<String, dynamic>>.from(
              map['storage_deletes_on_successful_sync'] as List,
            ).map(DeferredStorageDelete.fromMap).toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'work_order_id': workOrderId,
      'patch': patch,
      'work_order_snapshot': workOrderSnapshot,
      'queued_at': queuedAt,
      'notification_message': notificationMessage,
      'should_create_recurring_on_completion':
          shouldCreateRecurringOnCompletion,
      'storage_deletes_on_successful_sync': storageDeletesOnSuccessfulSync
          .map((item) => item.toMap())
          .toList(),
    };
  }
}

class WorkOrderOfflineService {
  WorkOrderOfflineService._();

  static final WorkOrderOfflineService instance = WorkOrderOfflineService._();

  final StreamController<WorkOrderOfflineEvent> _events =
      StreamController<WorkOrderOfflineEvent>.broadcast();

  Timer? _autoSyncTimer;
  Future<void>? _activeSync;

  SupabaseClient get _client => Supabase.instance.client;

  Stream<WorkOrderOfflineEvent> get events => _events.stream;

  Future<WorkOrdersSnapshot> loadVisibleWorkOrders({
    required UserProfile? userProfile,
    required bool canManageAll,
    required String? technicianId,
  }) async {
    await syncPendingChanges();

    final pendingChanges = await _readPendingChanges();
    final cacheKey = _cacheKeyForScope(
      canManageAll: canManageAll,
      technicianId: technicianId,
    );

    try {
      final remoteSnapshot = await _fetchRemoteSnapshot(
        userProfile: userProfile,
        canManageAll: canManageAll,
        technicianId: technicianId,
      );
      await LocalCacheService.instance.writeJson(
        cacheKey,
        _snapshotToCacheMap(remoteSnapshot),
      );
      return _applyPendingChanges(
        remoteSnapshot,
        pendingChanges,
        usedOfflineCache: false,
      );
    } catch (_) {
      final cachedMap = await LocalCacheService.instance.readJsonMap(cacheKey);
      if (cachedMap == null) rethrow;

      final cachedSnapshot = _snapshotFromCacheMap(cachedMap);
      return _applyPendingChanges(
        cachedSnapshot,
        pendingChanges,
        usedOfflineCache: true,
      );
    }
  }

  Future<Map<String, dynamic>> mergePendingStateIntoWorkOrder(
    Map<String, dynamic> workOrder,
  ) async {
    final pendingChanges = await _readPendingChanges();
    final workOrderId = workOrder['id']?.toString();
    if (workOrderId == null || workOrderId.isEmpty) {
      return Map<String, dynamic>.from(workOrder);
    }

    _PendingWorkOrderChange? change;
    for (final item in pendingChanges) {
      if (item.workOrderId == workOrderId) {
        change = item;
        break;
      }
    }

    if (change == null) {
      return Map<String, dynamic>.from(workOrder);
    }

    return _decoratePendingWorkOrder(
      Map<String, dynamic>.from(workOrder)..addAll(change.patch),
      queuedAt: change.queuedAt,
    );
  }

  Future<bool> hasPendingChangeForWorkOrder(dynamic workOrderId) async {
    final resolvedId = workOrderId?.toString();
    if (resolvedId == null || resolvedId.isEmpty) return false;
    final pendingChanges = await _readPendingChanges();
    return pendingChanges.any((item) => item.workOrderId == resolvedId);
  }

  Future<int> pendingChangesCount() async {
    final pendingChanges = await _readPendingChanges();
    return pendingChanges.length;
  }

  Future<WorkOrderUpdateOutcome> saveTechnicianUpdate({
    required Map<String, dynamic> workOrder,
    required Map<String, dynamic> patch,
    String? notificationMessage,
    bool shouldCreateRecurringOnCompletion = false,
    Iterable<DeferredStorageDelete> storageDeletesOnSuccessfulSync =
        const [],
  }) async {
    final queuedWorkOrder = await _queuePendingChange(
      workOrder: workOrder,
      patch: patch,
      notificationMessage: notificationMessage,
      shouldCreateRecurringOnCompletion: shouldCreateRecurringOnCompletion,
      storageDeletesOnSuccessfulSync: storageDeletesOnSuccessfulSync,
    );

    await syncPendingChanges();

    final stillPending = await hasPendingChangeForWorkOrder(workOrder['id']);
    return WorkOrderUpdateOutcome(
      workOrder:
          stillPending
                ? queuedWorkOrder
                : Map<String, dynamic>.from(queuedWorkOrder)
            ..remove('_offline_pending')
            ..remove('_offline_queued_at'),
      synced: !stillPending,
      pendingChangesCount: await pendingChangesCount(),
    );
  }

  Future<void> syncPendingChanges() async {
    final currentSync = _activeSync;
    if (currentSync != null) {
      await currentSync;
      return;
    }

    final completer = Completer<void>();
    _activeSync = completer.future;

    try {
      var pendingChanges = await _readPendingChanges();
      final initialPendingCount = pendingChanges.length;
      var syncedAny = false;

      while (pendingChanges.isNotEmpty) {
        final nextChange = pendingChanges.first;
        try {
          await _applyPendingChangeRemotely(nextChange);
          pendingChanges = pendingChanges.sublist(1);
          await _writePendingChanges(pendingChanges);
          syncedAny = true;
        } catch (_) {
          break;
        }
      }

      if (syncedAny || pendingChanges.length != initialPendingCount) {
        _emitPendingState(
          pendingChangesCount: pendingChanges.length,
          syncedChanges: syncedAny,
        );
      }
    } finally {
      completer.complete();
      _activeSync = null;
    }
  }

  void startAutoSync({Duration interval = const Duration(seconds: 30)}) {
    if (_autoSyncTimer != null) return;

    unawaited(syncPendingChanges());
    _autoSyncTimer = Timer.periodic(interval, (_) {
      unawaited(syncPendingChanges());
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  Future<WorkOrdersSnapshot> _fetchRemoteSnapshot({
    required UserProfile? userProfile,
    required bool canManageAll,
    required String? technicianId,
  }) async {
    final workOrdersQuery = canManageAll || userProfile?.isClient == true
        ? _client.from('work_orders').select().order('id')
        : technicianId == null
        ? Future.value(<dynamic>[])
        : _client
              .from('work_orders')
              .select()
              .eq('technician_id', technicianId as Object)
              .order('id');

    final results = await Future.wait([
      workOrdersQuery,
      userProfile?.isClient == true
          ? Future.value(<dynamic>[])
          : _client.from('technicians').select(),
      _client.from('assets').select('id, name, location_id'),
      _client.from('locations').select('id, name'),
    ]);

    final loadedOrders = List<Map<String, dynamic>>.from(results[0]);
    final loadedTechnicians = List<Map<String, dynamic>>.from(results[1]);
    final loadedAssets = List<Map<String, dynamic>>.from(results[2]);
    final loadedLocations = List<Map<String, dynamic>>.from(results[3]);

    final assetMap = <String, Map<String, dynamic>>{
      for (final asset in loadedAssets) asset['id']?.toString() ?? '': asset,
    };
    final locationMap = <String, String>{
      for (final location in loadedLocations)
        location['id']?.toString() ?? '': location['name']?.toString() ?? '',
    };

    final enrichedOrders = loadedOrders.map((workOrder) {
      final asset = assetMap[workOrder['asset_id']?.toString() ?? ''];
      final locationName =
          locationMap[asset?['location_id']?.toString() ?? ''] ?? '';

      return {
        ...workOrder,
        'asset_name': asset?['name']?.toString() ?? '',
        'location_name': locationName,
      };
    }).toList();

    final visibleOrders = enrichedOrders
        .where(
          (order) => ClientScopeService.canAccessWorkOrder(
            userProfile,
            order,
            assetsById: assetMap,
          ),
        )
        .toList();

    return WorkOrdersSnapshot(
      workOrders: visibleOrders,
      technicianNamesById: {
        for (final technician in loadedTechnicians)
          technician['id']?.toString() ?? '':
              technician['name']?.toString() ?? '',
      },
      assetsById: assetMap,
      locationNamesById: locationMap,
      lastSyncedAt: DateTime.now(),
    );
  }

  WorkOrdersSnapshot _applyPendingChanges(
    WorkOrdersSnapshot snapshot,
    List<_PendingWorkOrderChange> pendingChanges, {
    required bool usedOfflineCache,
  }) {
    final pendingById = <String, _PendingWorkOrderChange>{
      for (final change in pendingChanges) change.workOrderId: change,
    };

    final resolvedOrders = snapshot.workOrders.map((workOrder) {
      final workOrderId = workOrder['id']?.toString() ?? '';
      final pendingChange = pendingById[workOrderId];
      if (pendingChange == null) {
        return Map<String, dynamic>.from(workOrder);
      }

      return _decoratePendingWorkOrder(
        Map<String, dynamic>.from(workOrder)..addAll(pendingChange.patch),
        queuedAt: pendingChange.queuedAt,
      );
    }).toList();

    return snapshot.copyWith(
      workOrders: resolvedOrders,
      usedOfflineCache: usedOfflineCache,
      pendingChangesCount: pendingChanges.length,
    );
  }

  Future<Map<String, dynamic>> _queuePendingChange({
    required Map<String, dynamic> workOrder,
    required Map<String, dynamic> patch,
    String? notificationMessage,
    required bool shouldCreateRecurringOnCompletion,
    required Iterable<DeferredStorageDelete> storageDeletesOnSuccessfulSync,
  }) async {
    final pendingChanges = await _readPendingChanges();
    final workOrderId = workOrder['id']?.toString();
    if (workOrderId == null || workOrderId.isEmpty) {
      throw StateError('A ordem precisa de um id valido para modo offline.');
    }

    final nowIso = DateTime.now().toIso8601String();
    final existingIndex = pendingChanges.indexWhere(
      (item) => item.workOrderId == workOrderId,
    );
    final existingChange = existingIndex >= 0
        ? pendingChanges[existingIndex]
        : null;

    final mergedPatch = <String, dynamic>{...?existingChange?.patch, ...patch};
    final mergedStorageDeletes = <String, DeferredStorageDelete>{
      for (final item in existingChange?.storageDeletesOnSuccessfulSync ?? const <DeferredStorageDelete>[])
        item.dedupeKey: item,
      for (final item in storageDeletesOnSuccessfulSync)
        if (item.bucket.trim().isNotEmpty && item.storedValue.trim().isNotEmpty)
          item.dedupeKey: DeferredStorageDelete(
            bucket: item.bucket.trim(),
            storedValue: item.storedValue.trim(),
          ),
    };
    final mergedWorkOrder = _stripOfflineFields(
      Map<String, dynamic>.from(existingChange?.workOrderSnapshot ?? workOrder),
    )..addAll(mergedPatch);

    final normalizedMessage = notificationMessage?.trim();
    final updatedChange = _PendingWorkOrderChange(
      workOrderId: workOrderId,
      patch: mergedPatch,
      workOrderSnapshot: mergedWorkOrder,
      queuedAt: nowIso,
      notificationMessage:
          normalizedMessage != null && normalizedMessage.isNotEmpty
          ? normalizedMessage
          : existingChange?.notificationMessage,
      shouldCreateRecurringOnCompletion:
          shouldCreateRecurringOnCompletion ||
          existingChange?.shouldCreateRecurringOnCompletion == true,
      storageDeletesOnSuccessfulSync: mergedStorageDeletes.values.toList(),
    );

    if (existingIndex >= 0) {
      pendingChanges[existingIndex] = updatedChange;
    } else {
      pendingChanges.add(updatedChange);
    }

    await _writePendingChanges(pendingChanges);
    _emitPendingState(
      pendingChangesCount: pendingChanges.length,
      syncedChanges: false,
    );

    return _decoratePendingWorkOrder(mergedWorkOrder, queuedAt: nowIso);
  }

  Future<void> _applyPendingChangeRemotely(
    _PendingWorkOrderChange change,
  ) async {
    await _client
        .from('work_orders')
        .update(change.patch)
        .eq('id', change.workOrderId);

    final message = change.notificationMessage?.trim();
    if (message != null && message.isNotEmpty) {
      await NotificationService.instance.createNotification(
        message: message,
        workOrderId: change.workOrderId,
      );
    }

    if (change.shouldCreateRecurringOnCompletion) {
      await _createNextRecurringWorkOrder(change.workOrderSnapshot);
    }

    for (final item in change.storageDeletesOnSuccessfulSync) {
      try {
        await StorageService.instance.deleteStoredObject(
          bucket: item.bucket,
          storedValue: item.storedValue,
        );
      } catch (_) {
        // Keep the work-order sync successful even if storage cleanup fails.
      }
    }
  }

  Future<void> _createNextRecurringWorkOrder(
    Map<String, dynamic> currentWorkOrder,
  ) async {
    if (!isPreventiveOrder(currentWorkOrder)) return;

    final interval = workOrderRecurrenceInterval(currentWorkOrder);
    final unit = workOrderRecurrenceUnit(currentWorkOrder);
    final baseDate =
        parseDateValue(workOrderScheduledFor(currentWorkOrder)) ??
        DateTime.now();
    final nextDate = calculateNextScheduledDate(baseDate, interval, unit);
    if (nextDate == null) return;

    final maintenancePlanId =
        workOrderMaintenancePlanId(currentWorkOrder) ?? currentWorkOrder['id'];
    try {
      final existing = await _client
          .from('work_orders')
          .select('id')
          .eq('maintenance_plan_id', maintenancePlanId)
          .eq('asset_id', currentWorkOrder['asset_id'])
          .eq('scheduled_for', nextDate.toIso8601String())
          .maybeSingle();
      if (existing != null) return;
    } catch (_) {
      // If dedup probing fails, continue with the insert attempt below.
    }

    final nextProcedureSteps = ProcedureChecklistItem.resetChecks(
      workOrderProcedureSteps(currentWorkOrder),
    );
    final nowIso = DateTime.now().toIso8601String();
    final englishData =
        buildEnglishWorkOrderPayload(
            title:
                currentWorkOrder['title']?.toString() ??
                workOrderTitle(currentWorkOrder),
            reference: workOrderReference(currentWorkOrder),
            description: workOrderDescription(currentWorkOrder),
            status: 'pendente',
            priority: workOrderPriority(currentWorkOrder),
            assetId: currentWorkOrder['asset_id'],
            technicianId: currentWorkOrder['technician_id']?.toString(),
            photoUrl: null,
            attachmentUrl: workOrderAttachmentUrl(currentWorkOrder).isEmpty
                ? null
                : workOrderAttachmentUrl(currentWorkOrder),
            observations: null,
            assetDeviceId: workOrderAssetDeviceId(currentWorkOrder),
            assetDeviceName:
                workOrderAssetDeviceName(currentWorkOrder).trim().isEmpty
                ? null
                : workOrderAssetDeviceName(currentWorkOrder).trim(),
            measurementValue: null,
            requiresPhoto: workOrderRequiresPhoto(currentWorkOrder),
            requiresMeasurement: workOrderRequiresMeasurement(currentWorkOrder),
            orderType: workOrderType(currentWorkOrder),
            scheduledFor: nextDate.toIso8601String(),
            recurrenceInterval: interval,
            recurrenceUnit: unit,
            maintenancePlanId: maintenancePlanId,
            procedureTemplateId: workOrderProcedureTemplateId(currentWorkOrder),
            procedureName:
                workOrderProcedureName(currentWorkOrder).trim().isEmpty
                ? null
                : workOrderProcedureName(currentWorkOrder).trim(),
            procedureSteps: ProcedureChecklistItem.toSnapshotJson(
              nextProcedureSteps,
            ),
          )
          ..['created_at'] = nowIso
          ..['updated_at'] = nowIso;

    final scopedData = await CompanyScopeService.instance
        .attachCurrentCompanyId(
          table: 'work_orders',
          payload: await _sanitizeRecurringOptionalFields(englishData),
        );
    await _client.from('work_orders').insert(scopedData);
  }

  Future<Map<String, dynamic>> _sanitizeRecurringOptionalFields(
    Map<String, dynamic> payload,
  ) async {
    final sanitized = Map<String, dynamic>.from(payload);
    final supportsTemplateId = await CompanyScopeService.instance
        .tableSupportsColumn('work_orders', 'procedure_template_id');
    final supportsName = await CompanyScopeService.instance.tableSupportsColumn(
      'work_orders',
      'procedure_name',
    );
    final supportsSteps = await CompanyScopeService.instance
        .tableSupportsColumn('work_orders', 'procedure_steps');
    final supportsAssetDeviceId = await CompanyScopeService.instance
        .tableSupportsColumn('work_orders', 'asset_device_id');
    final supportsAssetDeviceName = await CompanyScopeService.instance
        .tableSupportsColumn('work_orders', 'asset_device_name');

    if (!supportsTemplateId) {
      sanitized.remove('procedure_template_id');
    }
    if (!supportsName) {
      sanitized.remove('procedure_name');
    }
    if (!supportsSteps) {
      sanitized.remove('procedure_steps');
    }
    if (!supportsAssetDeviceId) {
      sanitized.remove('asset_device_id');
    }
    if (!supportsAssetDeviceName) {
      sanitized.remove('asset_device_name');
    }

    return sanitized;
  }

  Map<String, dynamic> _snapshotToCacheMap(WorkOrdersSnapshot snapshot) {
    return {
      'saved_at': snapshot.lastSyncedAt?.toIso8601String(),
      'work_orders': snapshot.workOrders,
      'technician_names_by_id': snapshot.technicianNamesById,
      'assets_by_id': snapshot.assetsById,
      'location_names_by_id': snapshot.locationNamesById,
    };
  }

  WorkOrdersSnapshot _snapshotFromCacheMap(Map<String, dynamic> map) {
    final rawTechnicianNames = map['technician_names_by_id'];
    final rawAssets = map['assets_by_id'];
    final rawLocations = map['location_names_by_id'];

    return WorkOrdersSnapshot(
      workOrders: map['work_orders'] is List
          ? List<Map<String, dynamic>>.from(map['work_orders'] as List)
          : const [],
      technicianNamesById: rawTechnicianNames is Map
          ? rawTechnicianNames.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            )
          : const {},
      assetsById: rawAssets is Map
          ? rawAssets.map(
              (key, value) => MapEntry(
                key.toString(),
                value is Map ? Map<String, dynamic>.from(value) : const {},
              ),
            )
          : const {},
      locationNamesById: rawLocations is Map
          ? rawLocations.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            )
          : const {},
      lastSyncedAt: DateTime.tryParse(map['saved_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> _decoratePendingWorkOrder(
    Map<String, dynamic> workOrder, {
    required String queuedAt,
  }) {
    return {
      ...workOrder,
      '_offline_pending': true,
      '_offline_queued_at': queuedAt,
    };
  }

  Map<String, dynamic> _stripOfflineFields(Map<String, dynamic> workOrder) {
    final cleaned = Map<String, dynamic>.from(workOrder);
    cleaned.remove('_offline_pending');
    cleaned.remove('_offline_queued_at');
    return cleaned;
  }

  Future<List<_PendingWorkOrderChange>> _readPendingChanges() async {
    final rawItems = await LocalCacheService.instance.readJsonMapList(
      _pendingChangesKey(),
    );
    return rawItems.map(_PendingWorkOrderChange.fromMap).toList();
  }

  Future<void> _writePendingChanges(
    List<_PendingWorkOrderChange> pendingChanges,
  ) {
    return LocalCacheService.instance.writeJson(
      _pendingChangesKey(),
      pendingChanges.map((item) => item.toMap()).toList(),
    );
  }

  String _cacheKeyForScope({
    required bool canManageAll,
    required String? technicianId,
  }) {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final scope = canManageAll ? 'all' : (technicianId ?? 'none');
    return 'work_orders_cache:$userId:$scope';
  }

  String _pendingChangesKey() {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    return 'work_orders_pending:$userId';
  }

  void _emitPendingState({
    required int pendingChangesCount,
    required bool syncedChanges,
  }) {
    if (_events.isClosed) return;
    _events.add(
      WorkOrderOfflineEvent(
        pendingChangesCount: pendingChangesCount,
        syncedChanges: syncedChanges,
      ),
    );
  }
}
