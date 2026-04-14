import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/company_email_connection.dart';
import 'models/company_profile.dart';
import 'services/authorization_email_delivery_service.dart';
import 'services/company_email_connection_service.dart';
import 'services/company_service.dart';
import 'work_orders/task_detail_page.dart';
import 'work_orders/work_order_helpers.dart';

enum _CalendarViewMode { month, week }

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    this.canManageAll = true,
    this.technicianId,
    this.canEditWorkOrders = false,
    this.canCloseWorkOrders = true,
  });

  final bool canManageAll;
  final String? technicianId;
  final bool canEditWorkOrders;
  final bool canCloseWorkOrders;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> allWorkOrders = [];
  List<Map<String, dynamic>> plannedDayAssets = [];
  Map<String, Map<String, dynamic>> assetsById = {};
  Map<String, String> technicianNamesById = {};
  DateTime visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String selectedTechnicianFilter = 'todos';
  _CalendarViewMode viewMode = _CalendarViewMode.month;
  bool isLoading = true;
  bool plannedDayAssetsAvailable = false;
  String? errorMessage;
  final Map<String, _AuthorizationConfirmationState>
  _authorizationConfirmationsByDay = {};

  @override
  void initState() {
    super.initState();
    loadCalendar();
  }

  Future<void> loadCalendar() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final workOrdersQuery = widget.canManageAll
          ? supabase.from('work_orders').select()
          : widget.technicianId == null
          ? Future.value(<dynamic>[])
          : supabase
                .from('work_orders')
                .select()
                .eq('technician_id', widget.technicianId as Object);

      final results = await Future.wait([
        workOrdersQuery,
        supabase
            .from('assets')
            .select(
              'id, name, location_id, entry_authorization_email, entry_authorization_subject, entry_authorization_template',
            ),
        supabase.from('technicians').select('id, name').order('name'),
        _loadPlannedDayAssets(),
      ]);

      if (!mounted) return;

      final loadedOrders = List<Map<String, dynamic>>.from(results[0] as List);
      final loadedAssets = List<Map<String, dynamic>>.from(results[1] as List);
      final loadedTechnicians = List<Map<String, dynamic>>.from(
        results[2] as List,
      );
      final plannedDayAssetsResult =
          results[3] as _PlannedDayAssetsLoadResult;

      setState(() {
        allWorkOrders = loadedOrders;
        plannedDayAssets = plannedDayAssetsResult.items;
        plannedDayAssetsAvailable = plannedDayAssetsResult.isAvailable;
        assetsById = {
          for (final asset in loadedAssets)
            asset['id']?.toString() ?? '': asset,
        };
        technicianNamesById = {
          for (final technician in loadedTechnicians)
            technician['id']?.toString() ?? '':
                technician['name']?.toString() ?? '',
        };
        if (!widget.canManageAll && widget.technicianId != null) {
          selectedTechnicianFilter = widget.technicianId!;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar o calendario.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  bool _matchesTechnician(Map<String, dynamic> workOrder) {
    if (!widget.canManageAll || selectedTechnicianFilter == 'todos') {
      return true;
    }
    return workOrder['technician_id']?.toString() == selectedTechnicianFilter;
  }

  bool _matchesPlannedAsset(Map<String, dynamic> plannedAsset) {
    if (!widget.canManageAll || selectedTechnicianFilter == 'todos') {
      return true;
    }
    return plannedAsset['technician_id']?.toString() == selectedTechnicianFilter;
  }

  List<Map<String, dynamic>> get filteredWorkOrders =>
      allWorkOrders.where(_matchesTechnician).toList();

  List<Map<String, dynamic>> get allOpenWorkOrders =>
      allWorkOrders.where((workOrder) {
        final status = workOrder['status']?.toString().toLowerCase() ?? '';
        return status != 'concluido';
      }).toList();

  List<Map<String, dynamic>> get openWorkOrders =>
      allOpenWorkOrders.where(_matchesTechnician).toList();

  List<Map<String, dynamic>> get scheduledWorkOrders =>
      filteredWorkOrders.where((workOrder) {
        return parseDateValue(workOrderScheduledFor(workOrder)) != null;
      }).toList();

  List<Map<String, dynamic>> get filteredPlannedDayAssets =>
      plannedDayAssets.where(_matchesPlannedAsset).toList();

  List<Map<String, dynamic>> get unscheduledOpenWorkOrders =>
      openWorkOrders.where((workOrder) {
          return parseDateValue(workOrderScheduledFor(workOrder)) == null;
        }).toList()
        ..sort((a, b) => workOrderTitle(a).compareTo(workOrderTitle(b)));

  List<Map<String, dynamic>> ordersForDay(DateTime day) {
    final key = _dateKey(day);
    final items = scheduledWorkOrders.where((workOrder) {
      final scheduled = parseDateValue(workOrderScheduledFor(workOrder));
      return scheduled != null && _dateKey(scheduled) == key;
    }).toList();
    items.sort((a, b) {
      final aDate = parseDateValue(workOrderScheduledFor(a))!;
      final bDate = parseDateValue(workOrderScheduledFor(b))!;
      return aDate.compareTo(bDate);
    });
    return items;
  }

  List<Map<String, dynamic>> get ordersForSelectedDate =>
      ordersForDay(selectedDate);

  List<Map<String, dynamic>> plannedDayAssetsForDay(DateTime day) {
    final key = _dateKey(day);
    final items = filteredPlannedDayAssets.where((plannedAsset) {
      final plannedFor = parseDateValue(plannedAsset['planned_for']);
      return plannedFor != null && _dateKey(plannedFor) == key;
    }).toList();
    items.sort((a, b) {
      final assetA =
          assetsById[a['asset_id']?.toString() ?? '']?['name']?.toString() ??
          '';
      final assetB =
          assetsById[b['asset_id']?.toString() ?? '']?['name']?.toString() ??
          '';
      return assetA.compareTo(assetB);
    });
    return items;
  }

  List<Map<String, dynamic>> get plannedAssetsForSelectedDate =>
      plannedDayAssetsForDay(selectedDate);

  Map<String, int> get orderCountsByDay {
    final counts = <String, int>{};
    for (final workOrder in scheduledWorkOrders) {
      final scheduled = parseDateValue(workOrderScheduledFor(workOrder));
      if (scheduled == null) continue;
      counts[_dateKey(scheduled)] = (counts[_dateKey(scheduled)] ?? 0) + 1;
    }
    for (final plannedAsset in filteredPlannedDayAssets) {
      final plannedFor = parseDateValue(plannedAsset['planned_for']);
      if (plannedFor == null) continue;
      counts[_dateKey(plannedFor)] = (counts[_dateKey(plannedFor)] ?? 0) + 1;
    }
    return counts;
  }

  DateTime get weekStart {
    final base = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    return base.subtract(Duration(days: base.weekday - 1));
  }

  List<DateTime> get weekDays =>
      List.generate(7, (index) => weekStart.add(Duration(days: index)));

  Future<_PlannedDayAssetsLoadResult> _loadPlannedDayAssets() async {
    try {
      final data = await supabase.from('planned_day_assets').select();
      return _PlannedDayAssetsLoadResult(
        isAvailable: true,
        items: List<Map<String, dynamic>>.from(data),
      );
    } on PostgrestException catch (error) {
      if (_isMissingPlannedDayAssetsTableError(error)) {
        return const _PlannedDayAssetsLoadResult(
          isAvailable: false,
          items: <Map<String, dynamic>>[],
        );
      }
      rethrow;
    }
  }

  Future<void> openWorkOrderDetail(Map<String, dynamic> workOrder) async {
    final previousDayKey = _workOrderDayKey(workOrder);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          task: workOrder,
          asset:
              assetsById[workOrder['asset_id']?.toString() ?? ''] ??
              {'id': workOrder['asset_id'], 'name': workOrder['asset_name']},
          canManageAll: widget.canManageAll,
          canEditFullOrder: widget.canManageAll || widget.canEditWorkOrders,
          canCloseWorkOrder: widget.canManageAll || widget.canCloseWorkOrders,
          technicianName:
              technicianNamesById[workOrder['technician_id']?.toString() ?? ''],
        ),
      ),
    );
    if (changed == true) {
      await loadCalendar();
      if (!mounted) return;

      final updatedWorkOrder = _findWorkOrderById(workOrder['id']);
      if (!_didAffectAuthorizationSummary(workOrder, updatedWorkOrder)) {
        return;
      }

      final impactedDayKeys = <String>{};
      final updatedDayKey = _workOrderDayKey(updatedWorkOrder);
      if (previousDayKey != null &&
          _authorizationConfirmationsByDay.containsKey(previousDayKey)) {
        impactedDayKeys.add(previousDayKey);
      }
      if (updatedDayKey != null &&
          _authorizationConfirmationsByDay.containsKey(updatedDayKey)) {
        impactedDayKeys.add(updatedDayKey);
      }
      _showAuthorizationChangeWarning(impactedDayKeys);
    }
  }

  Future<void> _scheduleWorkOrder(
    Map<String, dynamic> workOrder,
    DateTime targetDay,
  ) async {
    String? technicianId = workOrder['technician_id']?.toString();
    if (widget.canManageAll && selectedTechnicianFilter != 'todos') {
      technicianId = selectedTechnicianFilter;
    }
    if (widget.canManageAll &&
        selectedTechnicianFilter == 'todos' &&
        (technicianId == null || technicianId.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolhe primeiro um tecnico no filtro.')),
      );
      return;
    }

    final existingScheduled = parseDateValue(workOrderScheduledFor(workOrder));
    final plannedDate = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      existingScheduled?.hour ?? 9,
      existingScheduled?.minute ?? 0,
    );

    try {
      await supabase
          .from('work_orders')
          .update({
            'technician_id': technicianId,
            'scheduled_for': plannedDate.toIso8601String(),
          })
          .eq('id', workOrder['id']);
      if (!mounted) return;
      await loadCalendar();
      if (!mounted) return;

      final impactedDayKeys = <String>{};
      final previousDayKey = existingScheduled == null
          ? null
          : _dateKey(existingScheduled);
      final targetDayKey = _dateKey(targetDay);
      if (previousDayKey != null &&
          _authorizationConfirmationsByDay.containsKey(previousDayKey)) {
        impactedDayKeys.add(previousDayKey);
      }
      if (_authorizationConfirmationsByDay.containsKey(targetDayKey)) {
        impactedDayKeys.add(targetDayKey);
      }
      _showAuthorizationChangeWarning(impactedDayKeys);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel remarcar a ordem.')),
      );
    }
  }

  Map<String, Set<dynamic>> _plannedOrderIdsForDayByTechnician(DateTime day) {
    final key = _dateKey(day);
    final selectedIdsByTechnician = <String, Set<dynamic>>{};

    for (final workOrder in allOpenWorkOrders) {
      final scheduled = parseDateValue(workOrderScheduledFor(workOrder));
      final technicianId = workOrder['technician_id']?.toString();
      if (scheduled == null ||
          technicianId == null ||
          technicianId.isEmpty ||
          _dateKey(scheduled) != key) {
        continue;
      }

      selectedIdsByTechnician.putIfAbsent(technicianId, () => <dynamic>{}).add(
        workOrder['id'],
      );
    }

    return selectedIdsByTechnician;
  }

  Map<String, Set<String>> _plannedExtraAssetIdsForDayByTechnician(
    DateTime day,
  ) {
    final key = _dateKey(day);
    final assetIdsByTechnician = <String, Set<String>>{};

    for (final plannedAsset in plannedDayAssets) {
      final plannedFor = parseDateValue(plannedAsset['planned_for']);
      final technicianId = plannedAsset['technician_id']?.toString();
      final assetId = plannedAsset['asset_id']?.toString();
      if (plannedFor == null ||
          technicianId == null ||
          technicianId.isEmpty ||
          assetId == null ||
          assetId.isEmpty ||
          _dateKey(plannedFor) != key) {
        continue;
      }

      assetIdsByTechnician.putIfAbsent(technicianId, () => <String>{}).add(
        assetId,
      );
    }

    return assetIdsByTechnician;
  }

  String _initialPlanTechnicianIdForSelectedDay() {
    if (selectedTechnicianFilter != 'todos' &&
        technicianNamesById.containsKey(selectedTechnicianFilter)) {
      return selectedTechnicianFilter;
    }

    for (final workOrder in ordersForSelectedDate) {
      final technicianId = workOrder['technician_id']?.toString();
      if (technicianId != null &&
          technicianId.isNotEmpty &&
          technicianNamesById.containsKey(technicianId)) {
        return technicianId;
      }
    }

    for (final plannedAsset in plannedAssetsForSelectedDate) {
      final technicianId = plannedAsset['technician_id']?.toString();
      if (technicianId != null &&
          technicianId.isNotEmpty &&
          technicianNamesById.containsKey(technicianId)) {
        return technicianId;
      }
    }

    return technicianNamesById.keys.first;
  }

  String _plannedDateStorageValue(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }

  Future<void> planSelectedDay() async {
    if (!widget.canManageAll || technicianNamesById.isEmpty) return;
    final selectedOrderIdsByTechnician = _plannedOrderIdsForDayByTechnician(
      selectedDate,
    );
    final selectedExtraAssetIdsByTechnician =
        _plannedExtraAssetIdsForDayByTechnician(selectedDate);

    final selectionResult = await Navigator.of(context)
        .push<_PlanDaySelectionResult>(
          MaterialPageRoute(
            builder: (_) => _PlanDaySelectionPage(
              selectedDate: selectedDate,
              technicianNamesById: technicianNamesById,
              openWorkOrders: allOpenWorkOrders,
              assetsById: assetsById,
              initiallySelectedOrderIdsByTechnician:
                  selectedOrderIdsByTechnician,
              initiallySelectedAssetIdsByTechnician:
                  selectedExtraAssetIdsByTechnician,
              supportsAssetOnlyPlanning: plannedDayAssetsAvailable,
              initialTechnicianId: _initialPlanTechnicianIdForSelectedDay(),
            ),
          ),
        );

    if (selectionResult == null || !mounted) {
      return;
    }

    try {
      final existingSelectedOrderIds =
          selectedOrderIdsByTechnician[selectionResult.technicianId] ??
          const <dynamic>{};
      final selectedWorkOrders = selectionResult.selectedOrderIds
          .map(
            (id) => allOpenWorkOrders.firstWhere(
              (item) => item['id'] == id,
            ),
          )
          .toList();
      final selectedAssetIds = Set<String>.from(selectionResult.selectedAssetIds);
      final selectedOrderAssetIds = selectedWorkOrders
          .map((workOrder) => workOrder['asset_id']?.toString() ?? '')
          .where((assetId) => assetId.isNotEmpty)
          .toSet();
      final extraAssetIds = selectedAssetIds.difference(selectedOrderAssetIds);
      final workOrderIdsToClear = existingSelectedOrderIds.difference(
        selectionResult.selectedOrderIds,
      );

      await Future.wait(
        [
          ...selectionResult.selectedOrderIds.map((id) async {
            final workOrder = allOpenWorkOrders.firstWhere(
              (item) => item['id'] == id,
            );
            final existingScheduled = parseDateValue(
              workOrderScheduledFor(workOrder),
            );
            final plannedDate = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              existingScheduled?.hour ?? 9,
              existingScheduled?.minute ?? 0,
            );

            await supabase
                .from('work_orders')
                .update({
                  'technician_id': selectionResult.technicianId,
                  'scheduled_for': plannedDate.toIso8601String(),
                })
                .eq('id', id);
          }),
          ...workOrderIdsToClear.map((id) async {
            await supabase
                .from('work_orders')
                .update({'scheduled_for': null})
                .eq('id', id);
          }),
        ],
      );

      if (plannedDayAssetsAvailable) {
        final plannedDateValue = _plannedDateStorageValue(selectedDate);
        await supabase
            .from('planned_day_assets')
            .delete()
            .eq('technician_id', selectionResult.technicianId)
            .eq('planned_for', plannedDateValue);

        if (extraAssetIds.isNotEmpty) {
          await supabase.from('planned_day_assets').insert(
            extraAssetIds
                .map(
                  (assetId) => {
                    'technician_id': selectionResult.technicianId,
                    'asset_id': assetId,
                    'planned_for': plannedDateValue,
                  },
                )
                .toList(),
          );
        }
      }

      final emailDrafts = await _buildInterventionEmailDrafts(
        plannedDate: selectedDate,
        technicianId: selectionResult.technicianId,
        selectedWorkOrders: selectedWorkOrders,
        selectedAssetIds: selectedAssetIds,
      );
      final isClearingPlan =
          selectedWorkOrders.isEmpty && selectedAssetIds.isEmpty;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClearingPlan
                ? 'Planeamento limpo para ${formatDateOnlyValue(selectedDate)}.'
                : 'Dia ${formatDateOnlyValue(selectedDate)} planeado para ${technicianNamesById[selectionResult.technicianId] ?? 'tecnico'}.',
          ),
        ),
      );
      await loadCalendar();
      if (!mounted) return;
      if (isClearingPlan) {
        return;
      }
      if (emailDrafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Planeamento concluido. Nenhum dos ativos selecionados tem email de intervencao configurado.',
            ),
          ),
        );
        return;
      }
      final confirmedDrafts = await _confirmAuthorizationDraftSelection(
        plannedDate: selectedDate,
        drafts: emailDrafts,
      );
      if (!mounted || confirmedDrafts == null) return;
      if (confirmedDrafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Planeamento guardado sem ativos confirmados para autorizacao por email.',
            ),
          ),
        );
        return;
      }

      _rememberAuthorizationConfirmation(selectedDate, confirmedDrafts);
      final deliveryPreviewState =
          await _prepareAuthorizationDeliveryPreviewState(
            plannedDate: selectedDate,
            drafts: confirmedDrafts,
          );
      if (!mounted) return;
      final deliverySnackBarMessage = deliveryPreviewState?.snackBarMessage;
      if (deliverySnackBarMessage != null &&
          deliverySnackBarMessage.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deliverySnackBarMessage)),
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _InterventionEmailPreviewPage(
            plannedDate: selectedDate,
            drafts: confirmedDrafts,
            deliveryState: deliveryPreviewState,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel planear o dia de trabalho.'),
        ),
      );
    }
  }

  Future<List<_InterventionEmailDraft>> _buildInterventionEmailDrafts({
    required DateTime plannedDate,
    required String technicianId,
    required List<Map<String, dynamic>> selectedWorkOrders,
    required Set<String> selectedAssetIds,
  }) async {
    CompanyProfile? companyProfile;
    CompanyEmailConnection? authorizationConnection;
    try {
      companyProfile = await CompanyService.instance.fetchCompanyProfile();
      final connectionId = companyProfile?.authorizationEmailConnectionId
          ?.trim();
      if (connectionId != null && connectionId.isNotEmpty) {
        authorizationConnection = await CompanyEmailConnectionService.instance
            .fetchConnectionById(connectionId);
      }
    } catch (_) {
      companyProfile = null;
      authorizationConnection = null;
    }

    final signature = companyProfile?.authorizationEmailSignature?.trim() ?? '';
    final configuredSenderEmail =
        companyProfile?.authorizationSenderEmail?.trim() ?? '';
    final replyToEmail = configuredSenderEmail.isNotEmpty
        ? configuredSenderEmail
        : authorizationConnection?.email.trim() ?? '';
    final sendMode =
        companyProfile?.authorizationEmailSendMode?.trim().toLowerCase() ==
            'automatico'
        ? 'automatico'
        : 'manual';
    final provider =
        companyProfile?.resolvedAuthorizationEmailProvider ?? 'manual';
    final providerLabel =
        authorizationConnection?.providerLabel ??
        _authorizationEmailProviderLabel(provider);
    final connectionLabel = authorizationConnection?.identityLabel;
    final connectionStatusLabel = authorizationConnection?.statusLabel;
    final connectionId = authorizationConnection?.id.trim();
    final automaticDeliveryReady =
        sendMode == 'automatico' &&
        provider != 'manual' &&
        authorizationConnection != null &&
        authorizationConnection.isConnected;
    final deliveryNote = _buildAuthorizationDeliveryNote(
      sendMode: sendMode,
      provider: provider,
      providerLabel: providerLabel,
      connection: authorizationConnection,
    );
    final groupedByAsset = <String, List<Map<String, dynamic>>>{};

    for (final workOrder in selectedWorkOrders) {
      final assetId = workOrder['asset_id']?.toString() ?? '';
      if (assetId.isEmpty) continue;
      groupedByAsset.putIfAbsent(assetId, () => []).add(workOrder);
    }

    final drafts = <_InterventionEmailDraft>[];

    final coverageAssetIds = <String>{
      ...selectedAssetIds,
      ...groupedByAsset.keys,
    }.toList()
      ..sort((a, b) {
        final assetNameA = assetsById[a]?['name']?.toString().trim() ?? '';
        final assetNameB = assetsById[b]?['name']?.toString().trim() ?? '';
        return assetNameA.compareTo(assetNameB);
      });

    for (final assetId in coverageAssetIds) {
      final asset = assetsById[assetId];
      if (asset == null) continue;

      final recipient =
          asset['entry_authorization_email']?.toString().trim() ?? '';
      if (recipient.isEmpty) continue;

      final assetName = asset['name']?.toString().trim().isNotEmpty == true
          ? asset['name'].toString()
          : 'Ativo';
      final technicianName = technicianNamesById[technicianId] ?? 'Tecnico';
      final orders = (groupedByAsset[assetId] ?? <Map<String, dynamic>>[])
        ..sort((a, b) => workOrderTitle(a).compareTo(workOrderTitle(b)));
      final orderLines = orders.isEmpty
          ? '- Visita planeada sem ordem associada'
          : orders
                .map(
                  (workOrder) =>
                      '- ${workOrderTitle(workOrder)}${workOrderReference(workOrder).trim().isEmpty ? '' : ' (${workOrderReference(workOrder)})'}',
                )
                .join('\n');
      final template =
          asset['entry_authorization_template']?.toString().trim() ?? '';
      final defaultBody =
          'Bom dia,\n\nSolicitamos autorizacao para intervencao no ativo $assetName na data ${formatDateOnlyValue(plannedDate)}.\n\nOrdens planeadas:\n$orderLines';
      final bodyBase = template.isEmpty ? defaultBody : template;
      final body = _replaceEmailTokens(
        bodyBase,
        assetName: assetName,
        plannedDate: plannedDate,
        technicianName: technicianName,
        orderLines: orderLines,
      );
      final finalBody = signature.isEmpty ? body : '$body\n\n$signature';
      final subject =
          (asset['entry_authorization_subject']?.toString().trim().isNotEmpty ==
              true)
          ? _replaceEmailTokens(
              asset['entry_authorization_subject'].toString().trim(),
              assetName: assetName,
              plannedDate: plannedDate,
              technicianName: technicianName,
              orderLines: orderLines,
            )
          : 'Intervencao planeada para ${formatDateOnlyValue(plannedDate)} - $assetName';

      drafts.add(
        _InterventionEmailDraft(
          assetId: assetId,
          assetName: assetName,
          recipientEmail: recipient,
          replyToEmail: replyToEmail,
          sendMode: sendMode,
          provider: provider,
          providerLabel: providerLabel,
          connectionId: connectionId,
          connectionLabel: connectionLabel,
          connectionStatusLabel: connectionStatusLabel,
          automaticDeliveryReady: automaticDeliveryReady,
          deliveryNote: deliveryNote,
          subject: subject,
          body: finalBody,
          workOrderCount: orders.length,
        ),
      );
    }

    drafts.sort((a, b) => a.assetName.compareTo(b.assetName));
    return drafts;
  }

  Future<List<_InterventionEmailDraft>?> _confirmAuthorizationDraftSelection({
    required DateTime plannedDate,
    required List<_InterventionEmailDraft> drafts,
  }) async {
    final selectedAssetIds = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _AuthorizationAssetConfirmationDialog(
        plannedDate: plannedDate,
        drafts: drafts,
      ),
    );
    if (selectedAssetIds == null) return null;
    return drafts
        .where((draft) => selectedAssetIds.contains(draft.assetId))
        .toList();
  }

  Future<_AuthorizationEmailDeliveryPreviewState?>
  _prepareAuthorizationDeliveryPreviewState({
    required DateTime plannedDate,
    required List<_InterventionEmailDraft> drafts,
  }) async {
    final wantsAutomaticDelivery = drafts.any(
      (draft) => draft.requestsAutomaticDelivery,
    );
    if (!wantsAutomaticDelivery) {
      return null;
    }

    final readyDrafts = drafts
        .where(
          (draft) =>
              draft.requestsAutomaticDelivery && draft.automaticDeliveryReady,
        )
        .toList();
    if (readyDrafts.isEmpty) {
      return _AuthorizationEmailDeliveryPreviewState(
        automaticModeRequested: true,
        attemptedAutomaticSend: false,
        sentCount: 0,
        failedCount: 0,
        summaryMessage: _buildAutomaticDeliveryUnavailableMessage(drafts.first),
        snackBarMessage:
            'Planeamento guardado. O envio automatico nao avancou e os emails ficaram em pre-visualizacao.',
        resultsByAssetId: const <String, AuthorizationEmailDeliveryItemResult>{},
      );
    }

    final connectionId = readyDrafts
        .map((draft) => draft.connectionId?.trim())
        .whereType<String>()
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );

    try {
      final result = await AuthorizationEmailDeliveryService.instance.sendDrafts(
        connectionId: connectionId.isEmpty ? null : connectionId,
        plannedDate: plannedDate,
        drafts: readyDrafts
            .map(
              (draft) => AuthorizationEmailDeliveryDraftPayload(
                assetId: draft.assetId,
                recipientEmail: draft.recipientEmail,
                subject: draft.subject,
                body: draft.body,
              ),
            )
            .toList(),
      );

      final resultsByAssetId = <String, AuthorizationEmailDeliveryItemResult>{};
      for (final item in result.results) {
        final assetId = item.assetId?.trim();
        if (assetId == null || assetId.isEmpty) continue;
        resultsByAssetId[assetId] = item;
      }

      return _AuthorizationEmailDeliveryPreviewState(
        automaticModeRequested: true,
        attemptedAutomaticSend: true,
        sentCount: result.sentCount,
        failedCount: result.failedCount,
        summaryMessage: _buildAutomaticDeliverySummaryMessage(
          sentCount: result.sentCount,
          failedCount: result.failedCount,
          totalDrafts: readyDrafts.length,
        ),
        snackBarMessage: _buildAutomaticDeliverySnackBarMessage(
          sentCount: result.sentCount,
          failedCount: result.failedCount,
          totalDrafts: readyDrafts.length,
        ),
        resultsByAssetId: resultsByAssetId,
      );
    } catch (error) {
      final message = _normalizeAuthorizationDeliveryError(error);
      final resultsByAssetId = <String, AuthorizationEmailDeliveryItemResult>{};
      for (final draft in readyDrafts) {
        resultsByAssetId[draft.assetId] = AuthorizationEmailDeliveryItemResult(
          assetId: draft.assetId,
          recipientEmail: draft.recipientEmail,
          subject: draft.subject,
          status: 'failed',
          providerMessageId: null,
          errorMessage: message,
        );
      }

      return _AuthorizationEmailDeliveryPreviewState(
        automaticModeRequested: true,
        attemptedAutomaticSend: true,
        sentCount: 0,
        failedCount: readyDrafts.length,
        summaryMessage:
            'O envio automatico falhou antes de concluir. Os emails continuam disponiveis para revisao manual. Motivo: $message',
        snackBarMessage:
            'O envio automatico falhou. Os emails ficaram disponiveis para revisao manual.',
        resultsByAssetId: resultsByAssetId,
      );
    }
  }

  String _buildAutomaticDeliveryUnavailableMessage(
    _InterventionEmailDraft draft,
  ) {
    if (draft.provider == 'manual') {
      return 'O modo "Automatico apos planear" esta ativo, mas a empresa continua sem integracao de envio ligada. Os emails ficaram preparados para revisao manual.';
    }

    if (draft.connectionLabel?.trim().isNotEmpty != true) {
      return 'O modo "Automatico apos planear" esta ativo, mas ainda nao existe uma conta ligada pronta para envio. Os emails ficaram preparados para revisao manual.';
    }

    if (draft.connectionStatusLabel?.trim().isNotEmpty == true) {
      return 'O modo "Automatico apos planear" esta ativo, mas a conta ${draft.connectionLabel} ainda nao esta pronta (${draft.connectionStatusLabel!.toLowerCase()}). Os emails ficaram preparados para revisao manual.';
    }

    return 'O modo "Automatico apos planear" esta ativo, mas a conta ligada ainda nao esta pronta para envio. Os emails ficaram preparados para revisao manual.';
  }

  String _buildAutomaticDeliverySummaryMessage({
    required int sentCount,
    required int failedCount,
    required int totalDrafts,
  }) {
    if (failedCount <= 0) {
      return 'Foram enviados automaticamente $sentCount emails de autorizacao. Podes rever abaixo o conteudo final enviado.';
    }

    if (sentCount <= 0) {
      return 'Nenhum dos $totalDrafts emails foi enviado automaticamente. Reve abaixo o detalhe do erro em cada ativo.';
    }

    return 'Foram enviados automaticamente $sentCount de $totalDrafts emails. Os restantes $failedCount ficaram com erro e aparecem sinalizados abaixo.';
  }

  String _buildAutomaticDeliverySnackBarMessage({
    required int sentCount,
    required int failedCount,
    required int totalDrafts,
  }) {
    if (failedCount <= 0) {
      return 'Envio automatico concluido para $sentCount email(s).';
    }

    if (sentCount <= 0) {
      return 'O envio automatico falhou para $totalDrafts email(s).';
    }

    return 'Envio automatico parcial: $sentCount enviado(s), $failedCount com erro.';
  }

  String _normalizeAuthorizationDeliveryError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception:')) {
      return raw.substring('Exception:'.length).trim();
    }
    return raw;
  }

  void _rememberAuthorizationConfirmation(
    DateTime plannedDate,
    List<_InterventionEmailDraft> drafts,
  ) {
    final assetNames = drafts.map((draft) => draft.assetName).toList()..sort();
    setState(() {
      _authorizationConfirmationsByDay[_dateKey(
        plannedDate,
      )] = _AuthorizationConfirmationState(
        assetIds: drafts.map((draft) => draft.assetId).toSet(),
        assetNames: assetNames,
      );
    });
  }

  Map<String, dynamic>? _findWorkOrderById(dynamic id) {
    for (final workOrder in allWorkOrders) {
      if (workOrder['id'] == id) {
        return workOrder;
      }
    }
    return null;
  }

  String? _workOrderDayKey(Map<String, dynamic>? workOrder) {
    if (workOrder == null) return null;
    final scheduled = parseDateValue(workOrderScheduledFor(workOrder));
    if (scheduled == null) return null;
    return _dateKey(scheduled);
  }

  bool _didAffectAuthorizationSummary(
    Map<String, dynamic> previousWorkOrder,
    Map<String, dynamic>? updatedWorkOrder,
  ) {
    if (updatedWorkOrder == null) return true;
    return workOrderScheduledFor(previousWorkOrder)?.toString() !=
            workOrderScheduledFor(updatedWorkOrder)?.toString() ||
        previousWorkOrder['asset_id']?.toString() !=
            updatedWorkOrder['asset_id']?.toString() ||
        previousWorkOrder['technician_id']?.toString() !=
            updatedWorkOrder['technician_id']?.toString() ||
        workOrderTitle(previousWorkOrder) != workOrderTitle(updatedWorkOrder) ||
        workOrderReference(previousWorkOrder) !=
            workOrderReference(updatedWorkOrder);
  }

  void _showAuthorizationChangeWarning(Set<String> impactedDayKeys) {
    if (!mounted || impactedDayKeys.isEmpty) return;

    final impactedDays =
        impactedDayKeys.map(DateTime.tryParse).whereType<DateTime>().toList()
          ..sort((a, b) => a.compareTo(b));

    final labels = impactedDays.map(formatDateOnlyValue).toList();
    final dayText = labels.length == 1
        ? labels.first
        : '${labels.take(labels.length - 1).join(', ')} e ${labels.last}';
    final intro = labels.length == 1
        ? 'O dia $dayText ja tinha autorizacoes confirmadas.'
        : 'Os dias $dayText ja tinham autorizacoes confirmadas.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          '$intro Esta alteracao nao gera novo envio automatico de email; reve manualmente as autorizacoes.',
        ),
      ),
    );
  }

  String _replaceEmailTokens(
    String value, {
    required String assetName,
    required DateTime plannedDate,
    required String technicianName,
    required String orderLines,
  }) {
    return value
        .replaceAll('{{ativo}}', assetName)
        .replaceAll('{{data_intervencao}}', formatDateOnlyValue(plannedDate))
        .replaceAll('{{tecnico}}', technicianName)
        .replaceAll('{{ordens}}', orderLines);
  }

  String _authorizationEmailProviderLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'Google';
      case 'microsoft':
        return 'Microsoft';
      default:
        return 'Manual';
    }
  }

  String _buildAuthorizationDeliveryNote({
    required String sendMode,
    required String provider,
    required String providerLabel,
    required CompanyEmailConnection? connection,
  }) {
    if (sendMode != 'automatico') {
      if (provider == 'manual') {
        return 'Modo manual ativo. O planeamento prepara o rascunho e o envio continua a ser confirmado fora da integracao direta.';
      }

      if (connection == null) {
        return 'Modo manual ativo. O fornecedor $providerLabel esta escolhido, mas ainda nao existe uma conta ligada pronta para envio automatico.';
      }

      if (!connection.isConnected) {
        return 'Modo manual ativo. A conta ${connection.identityLabel} ainda nao esta pronta (${connection.statusLabel.toLowerCase()}).';
      }

      return 'Modo manual ativo. A conta ${connection.identityLabel} esta pronta, mas os emails ficam apenas em pre-visualizacao ate ativares "Automatico apos planear".';
    }

    if (provider == 'manual') {
      return 'Modo automatico escolhido sem integracao de envio ligada. Os emails ficam preparados para revisao manual.';
    }

    if (connection == null) {
      return 'Modo automatico ativo, mas ainda nao existe uma conta $providerLabel ligada a esta empresa. Os emails ficam preparados para revisao manual.';
    }

    if (!connection.isConnected) {
      return 'Modo automatico ativo, mas a conta ${connection.identityLabel} ainda nao esta pronta (${connection.statusLabel.toLowerCase()}).';
    }

    return 'Modo automatico ativo. O email sera enviado pelo backend assim que o planeamento for confirmado.';
  }

  bool _isMissingPlannedDayAssetsTableError(PostgrestException error) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains('planned_day_assets') &&
        (message.contains('does not exist') ||
            message.contains('relation') ||
            message.contains('schema cache') ||
            message.contains('could not find'));
  }

  void previousPeriod() {
    setState(() {
      if (viewMode == _CalendarViewMode.month) {
        visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1);
      } else {
        selectedDate = selectedDate.subtract(const Duration(days: 7));
        visibleMonth = DateTime(selectedDate.year, selectedDate.month);
      }
    });
  }

  void nextPeriod() {
    setState(() {
      if (viewMode == _CalendarViewMode.month) {
        visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1);
      } else {
        selectedDate = selectedDate.add(const Duration(days: 7));
        visibleMonth = DateTime(selectedDate.year, selectedDate.month);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    final items = ordersForSelectedDate;
    final plannedAssets = plannedAssetsForSelectedDate;
    final totalPlannedEntries = items.length + plannedAssets.length;
    final hasEditablePlan =
        items.isNotEmpty || plannedAssets.isNotEmpty;
    final compact = MediaQuery.sizeOf(context).width < 430;
    final authorizationConfirmation =
        _authorizationConfirmationsByDay[_dateKey(selectedDate)];

    return RefreshIndicator(
      onRefresh: loadCalendar,
      child: ListView(
        padding: EdgeInsets.all(compact ? 12 : 16),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: Column(
                children: [
                  if (widget.canManageAll) ...[
                    if (compact)
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedTechnicianFilter,
                            decoration: const InputDecoration(
                              labelText: 'Ver planeamento de',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: 'todos',
                                child: Text('Toda a equipa'),
                              ),
                              ...technicianNamesById.entries.map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => selectedTechnicianFilter = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SegmentedButton<_CalendarViewMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: _CalendarViewMode.month,
                                    label: Text('Mes'),
                                    icon: Icon(Icons.calendar_view_month),
                                  ),
                                  ButtonSegment(
                                    value: _CalendarViewMode.week,
                                    label: Text('Semana'),
                                    icon: Icon(Icons.view_week),
                                  ),
                                ],
                                selected: {viewMode},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    viewMode = selection.first;
                                    visibleMonth = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                    );
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedTechnicianFilter,
                              decoration: const InputDecoration(
                                labelText: 'Ver planeamento de',
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'todos',
                                  child: Text('Toda a equipa'),
                                ),
                                ...technicianNamesById.entries.map(
                                  (entry) => DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(
                                  () => selectedTechnicianFilter = value,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SegmentedButton<_CalendarViewMode>(
                            segments: const [
                              ButtonSegment(
                                value: _CalendarViewMode.month,
                                label: Text('Mes'),
                                icon: Icon(Icons.calendar_view_month),
                              ),
                              ButtonSegment(
                                value: _CalendarViewMode.week,
                                label: Text('Semana'),
                                icon: Icon(Icons.view_week),
                              ),
                            ],
                            selected: {viewMode},
                            onSelectionChanged: (selection) {
                              setState(() {
                                viewMode = selection.first;
                                visibleMonth = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      IconButton(
                        onPressed: previousPeriod,
                        visualDensity: compact
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          viewMode == _CalendarViewMode.month
                              ? _monthLabel(visibleMonth)
                              : _weekLabel(weekStart),
                          textAlign: TextAlign.center,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: compact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: nextPeriod,
                        visualDensity: compact
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (viewMode == _CalendarViewMode.month)
                    _CalendarGrid(
                      visibleMonth: visibleMonth,
                      selectedDate: selectedDate,
                      countsByDay: orderCountsByDay,
                      compact: compact,
                      onSelectDay: (date) {
                        setState(() {
                          selectedDate = date;
                          visibleMonth = DateTime(date.year, date.month);
                        });
                      },
                    )
                  else
                    _WeekPlanner(
                      weekDays: weekDays,
                      selectedDate: selectedDate,
                      unscheduledOrders: unscheduledOpenWorkOrders,
                      ordersForDay: ordersForDay,
                      onSelectDay: (date) {
                        setState(() {
                          selectedDate = date;
                          visibleMonth = DateTime(date.year, date.month);
                        });
                      },
                      onOpenWorkOrder: openWorkOrderDetail,
                      onDropOrderOnDay: widget.canManageAll
                          ? _scheduleWorkOrder
                          : null,
                      technicianNamesById: technicianNamesById,
                      assetsById: assetsById,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _CalendarInfoChip(
                    label: 'Planeadas no dia',
                    value: totalPlannedEntries.toString(),
                    compact: compact,
                  ),
                  _CalendarInfoChip(
                    label: 'Em aberto sem planeamento',
                    value: unscheduledOpenWorkOrders.length.toString(),
                    compact: compact,
                  ),
                  _CalendarInfoChip(
                    label: 'Tecnico',
                    value: selectedTechnicianFilter == 'todos'
                        ? 'Toda a equipa'
                        : (technicianNamesById[selectedTechnicianFilter] ??
                              'Tecnico'),
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
          if (widget.canManageAll) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: planSelectedDay,
                icon: const Icon(Icons.edit_calendar),
                label: Text(
                  '${hasEditablePlan ? 'Editar' : 'Planear'} dia ${formatDateOnlyValue(selectedDate)}',
                ),
              ),
            ),
          ],
          if (authorizationConfirmation != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(
                context,
              ).colorScheme.errorContainer.withOpacity(0.45),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.warning_amber_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Autorizacoes ja confirmadas para este dia',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Foram confirmados ${authorizationConfirmation.assetIds.length} ativos em ${formatDateOnlyValue(selectedDate)}. Se alterares o plano agora, nao existe novo envio automatico de email.',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ativos: ${authorizationConfirmation.assetSummary}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agenda de ${formatDateOnlyValue(selectedDate)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (totalPlannedEntries == 0)
                    const Text('Nao existem itens planeados para este dia.')
                  else ...[
                    ...items.map((workOrder) {
                      final scheduled = parseDateValue(
                        workOrderScheduledFor(workOrder),
                      );
                      final asset =
                          assetsById[workOrder['asset_id']?.toString() ?? ''];
                      final technicianName =
                          technicianNamesById[workOrder['technician_id']
                                  ?.toString() ??
                              ''];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            child: Text(
                              scheduled == null
                                  ? '?'
                                  : scheduled.hour.toString().padLeft(2, '0'),
                            ),
                          ),
                          title: Text(workOrderTitle(workOrder)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((asset?['name']?.toString() ?? '')
                                    .isNotEmpty)
                                  Text('Ativo: ${asset!['name']}'),
                                if (technicianName?.isNotEmpty == true)
                                  Text('Tecnico: $technicianName'),
                                Text(
                                  scheduled == null
                                      ? 'Sem hora definida'
                                      : 'Hora: ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openWorkOrderDetail(workOrder),
                        ),
                      );
                    }),
                    if (plannedAssets.isNotEmpty) ...[
                      if (items.isNotEmpty) const SizedBox(height: 8),
                      Text(
                        'Ativos planeados sem ordem associada',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ...plannedAssets.map((plannedAsset) {
                        final asset =
                            assetsById[plannedAsset['asset_id']?.toString() ??
                                    ''];
                        final technicianName =
                            technicianNamesById[plannedAsset['technician_id']
                                    ?.toString() ??
                                ''];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const CircleAvatar(
                              child: Icon(Icons.domain_outlined),
                            ),
                            title: Text(
                              asset?['name']?.toString().trim().isNotEmpty == true
                                  ? asset!['name'].toString()
                                  : 'Ativo',
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Planeado sem ordem associada',
                                  ),
                                  if (technicianName?.isNotEmpty == true)
                                    Text('Tecnico: $technicianName'),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String();
  }

  String _monthLabel(DateTime month) {
    const names = [
      'Janeiro',
      'Fevereiro',
      'Marco',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${formatDateOnlyValue(start)} - ${formatDateOnlyValue(end)}';
  }
}

class _PlanDaySelectionResult {
  const _PlanDaySelectionResult({
    required this.technicianId,
    required this.selectedOrderIds,
    required this.selectedAssetIds,
  });

  final String technicianId;
  final Set<dynamic> selectedOrderIds;
  final Set<String> selectedAssetIds;
}

class _PlanDayAssetEntry {
  const _PlanDayAssetEntry({
    required this.assetId,
    required this.assetName,
    required this.workOrders,
  });

  final String assetId;
  final String assetName;
  final List<Map<String, dynamic>> workOrders;
}

class _PlanDayAssetSelectionResult {
  const _PlanDayAssetSelectionResult({
    required this.selectedOrderIds,
    required this.includeAssetWithoutOrders,
  });

  final Set<dynamic> selectedOrderIds;
  final bool includeAssetWithoutOrders;
}

class _PlanDaySelectionPage extends StatefulWidget {
  const _PlanDaySelectionPage({
    required this.selectedDate,
    required this.technicianNamesById,
    required this.openWorkOrders,
    required this.assetsById,
    required this.initiallySelectedOrderIdsByTechnician,
    required this.initiallySelectedAssetIdsByTechnician,
    required this.supportsAssetOnlyPlanning,
    required this.initialTechnicianId,
  });

  final DateTime selectedDate;
  final Map<String, String> technicianNamesById;
  final List<Map<String, dynamic>> openWorkOrders;
  final Map<String, Map<String, dynamic>> assetsById;
  final Map<String, Set<dynamic>> initiallySelectedOrderIdsByTechnician;
  final Map<String, Set<String>> initiallySelectedAssetIdsByTechnician;
  final bool supportsAssetOnlyPlanning;
  final String initialTechnicianId;

  @override
  State<_PlanDaySelectionPage> createState() => _PlanDaySelectionPageState();
}

class _PlanDaySelectionPageState extends State<_PlanDaySelectionPage> {
  late String technicianId = widget.initialTechnicianId;
  final Set<dynamic> selectedOrderIds = <dynamic>{};
  final Set<String> explicitlySelectedAssetIds = <String>{};
  String query = '';

  @override
  void initState() {
    super.initState();
    _applySelectionForTechnician(technicianId);
  }

  Map<String, List<Map<String, dynamic>>> get openOrdersByAsset {
    final groupedByAsset = <String, List<Map<String, dynamic>>>{};
    for (final workOrder in widget.openWorkOrders) {
      final assetId = workOrder['asset_id']?.toString() ?? '';
      if (assetId.isEmpty) {
        continue;
      }
      groupedByAsset.putIfAbsent(assetId, () => []).add(workOrder);
    }
    return groupedByAsset;
  }

  Set<String> get coveredAssetIds {
    final covered = <String>{...explicitlySelectedAssetIds};
    for (final workOrder in widget.openWorkOrders) {
      if (!selectedOrderIds.contains(workOrder['id'])) {
        continue;
      }
      final assetId = workOrder['asset_id']?.toString() ?? '';
      if (assetId.isNotEmpty) {
        covered.add(assetId);
      }
    }
    return covered;
  }

  bool _hasExistingPlanForTechnician(String technicianId) {
    return (widget.initiallySelectedOrderIdsByTechnician[technicianId]
                ?.isNotEmpty ??
            false) ||
        (widget.initiallySelectedAssetIdsByTechnician[technicianId]
                ?.isNotEmpty ??
            false);
  }

  bool get canSaveCurrentPlan {
    return selectedOrderIds.isNotEmpty ||
        coveredAssetIds.isNotEmpty ||
        _hasExistingPlanForTechnician(technicianId);
  }

  List<_PlanDayAssetEntry> get assetEntries {
    final normalizedQuery = query.toLowerCase();
    final entries = <_PlanDayAssetEntry>[];

    for (final entry in widget.assetsById.entries) {
      final assetId = entry.key;
      final assetName = _assetName(assetId);
      final workOrders = List<Map<String, dynamic>>.from(
        openOrdersByAsset[assetId] ?? const <Map<String, dynamic>>[],
      );
      final orderSearchText = workOrders
          .map(
            (workOrder) =>
                '${workOrderTitle(workOrder)} ${workOrderReference(workOrder)}',
          )
          .join(' ')
          .toLowerCase();

      if (normalizedQuery.isNotEmpty &&
          !assetName.toLowerCase().contains(normalizedQuery) &&
          !orderSearchText.contains(normalizedQuery)) {
        continue;
      }

      entries.add(
        _PlanDayAssetEntry(
          assetId: assetId,
          assetName: assetName,
          workOrders: workOrders,
        ),
      );
    }

    entries.sort((a, b) => a.assetName.compareTo(b.assetName));
    return entries;
  }

  String _assetName(String assetId) {
    final name = widget.assetsById[assetId]?['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Ativo sem nome' : name;
  }

  int _selectedCountForAsset(List<Map<String, dynamic>> workOrders) {
    return workOrders
        .where((workOrder) => selectedOrderIds.contains(workOrder['id']))
        .length;
  }

  void _applySelectionForTechnician(String nextTechnicianId) {
    selectedOrderIds
      ..clear()
      ..addAll(
        widget.initiallySelectedOrderIdsByTechnician[nextTechnicianId] ??
            const <dynamic>{},
      );
    explicitlySelectedAssetIds
      ..clear()
      ..addAll(
        widget.initiallySelectedAssetIdsByTechnician[nextTechnicianId] ??
            const <String>{},
      );
  }

  Future<void> _openAssetOrders({
    required String assetId,
    required String assetName,
    required List<Map<String, dynamic>> workOrders,
  }) async {
    final updatedSelection = await Navigator.of(
      context,
    ).push<_PlanDayAssetSelectionResult>(
      MaterialPageRoute(
        builder: (_) => _PlanDayAssetOrdersPage(
          assetName: assetName,
          workOrders: workOrders,
          initiallySelectedIds: selectedOrderIds,
          initiallyIncludeAssetWithoutOrders:
              explicitlySelectedAssetIds.contains(assetId),
          supportsAssetOnlyPlanning: widget.supportsAssetOnlyPlanning,
        ),
      ),
    );

    if (updatedSelection == null || !mounted) return;

    setState(() {
      for (final workOrder in workOrders) {
        selectedOrderIds.remove(workOrder['id']);
      }
      selectedOrderIds.addAll(updatedSelection.selectedOrderIds);
      if (updatedSelection.includeAssetWithoutOrders) {
        explicitlySelectedAssetIds.add(assetId);
      } else {
        explicitlySelectedAssetIds.remove(assetId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = assetEntries;
    final coveredCount = coveredAssetIds.length;
    final existingPlan = _hasExistingPlanForTechnician(technicianId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Planear dia ${formatDateOnlyValue(widget.selectedDate)}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: technicianId,
                decoration: const InputDecoration(labelText: 'Tecnico'),
                items: widget.technicianNamesById.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    technicianId = value;
                    _applySelectionForTechnician(value);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Pesquisar por ativo, titulo ou referencia',
                ),
                onChanged: (value) => setState(() => query = value.trim()),
              ),
              const SizedBox(height: 12),
              Text(
                selectedOrderIds.isEmpty && coveredCount == 0
                    ? (existingPlan
                          ? 'Este tecnico ja tem um planeamento neste dia. Podes ajusta-lo abaixo.'
                          : 'Escolhe ativos e ordens para este dia.')
                    : '${selectedOrderIds.length} ordens e $coveredCount ativos preparados para o dia.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text('Nenhum ativo encontrado para este filtro.'),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final assetId = entry.assetId;
                          final workOrders = entry.workOrders;
                          final assetName = entry.assetName;
                          final selectedCount = _selectedCountForAsset(
                            workOrders,
                          );
                          final assetCovered = coveredAssetIds.contains(assetId);
                          final subtitle = selectedCount > 0
                              ? '$selectedCount de ${workOrders.length} ordens selecionadas'
                              : assetCovered
                              ? 'Ativo planeado sem ordem associada'
                              : workOrders.isEmpty
                              ? 'Sem ordens em aberto'
                              : '${workOrders.length} ordens em aberto';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  '${workOrders.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                assetName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(subtitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openAssetOrders(
                                assetId: assetId,
                                assetName: assetName,
                                workOrders: workOrders,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: !canSaveCurrentPlan
                        ? null
                        : () => Navigator.of(context).pop(
                            _PlanDaySelectionResult(
                              technicianId: technicianId,
                              selectedOrderIds: Set<dynamic>.from(
                                selectedOrderIds,
                              ),
                              selectedAssetIds: Set<String>.from(
                                coveredAssetIds,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.event_available),
                    label: Text(
                      existingPlan
                          ? 'Guardar planeamento'
                          : 'Planear dia',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanDayAssetOrdersPage extends StatefulWidget {
  const _PlanDayAssetOrdersPage({
    required this.assetName,
    required this.workOrders,
    required this.initiallySelectedIds,
    required this.initiallyIncludeAssetWithoutOrders,
    required this.supportsAssetOnlyPlanning,
  });

  final String assetName;
  final List<Map<String, dynamic>> workOrders;
  final Set<dynamic> initiallySelectedIds;
  final bool initiallyIncludeAssetWithoutOrders;
  final bool supportsAssetOnlyPlanning;

  @override
  State<_PlanDayAssetOrdersPage> createState() =>
      _PlanDayAssetOrdersPageState();
}

class _PlanDayAssetOrdersPageState extends State<_PlanDayAssetOrdersPage> {
  late final Set<dynamic> localSelection = <dynamic>{
    ...widget.initiallySelectedIds.where(
      (id) => widget.workOrders.any((workOrder) => workOrder['id'] == id),
    ),
  };
  late bool includeAssetWithoutOrders =
      widget.initiallyIncludeAssetWithoutOrders;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        widget.workOrders.isNotEmpty &&
        localSelection.length == widget.workOrders.length;
    final partiallySelected =
        localSelection.isNotEmpty &&
        localSelection.length < widget.workOrders.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.assetName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.supportsAssetOnlyPlanning)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir ativo no planeamento do dia'),
                  subtitle: Text(
                    widget.workOrders.isEmpty
                        ? 'Este ativo fica registado no dia mesmo sem ordens em aberto.'
                        : 'Usa esta opcao para manter o ativo no plano mesmo sem selecionar ordens deste ativo.',
                  ),
                  value: includeAssetWithoutOrders,
                  onChanged: (value) {
                    setState(() {
                      includeAssetWithoutOrders = value;
                    });
                  },
                ),
              const SizedBox(height: 8),
              if (widget.workOrders.isNotEmpty)
                CheckboxListTile(
                  value: allSelected
                      ? true
                      : partiallySelected
                      ? null
                      : false,
                  tristate: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Selecionar todas as ordens deste ativo'),
                  subtitle: Text('${widget.workOrders.length} ordens em aberto'),
                  onChanged: (value) {
                    setState(() {
                      if (allSelected || value == false) {
                        localSelection.clear();
                      } else {
                        for (final workOrder in widget.workOrders) {
                          localSelection.add(workOrder['id']);
                        }
                      }
                    });
                  },
                ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.workOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'Este ativo nao tem ordens em aberto. Podes ainda assim inclui-lo no planeamento do dia.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.workOrders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final workOrder = widget.workOrders[index];
                          final scheduled = parseDateValue(
                            workOrderScheduledFor(workOrder),
                          );
                          return CheckboxListTile(
                            value: localSelection.contains(workOrder['id']),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  localSelection.add(workOrder['id']);
                                } else {
                                  localSelection.remove(workOrder['id']);
                                }
                              });
                            },
                            title: Text(workOrderTitle(workOrder)),
                            subtitle: Text(
                              scheduled == null
                                  ? 'Sem planeamento'
                                  : formatDateValue(scheduled),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(
                      _PlanDayAssetSelectionResult(
                        selectedOrderIds: Set<dynamic>.from(localSelection),
                        includeAssetWithoutOrders: includeAssetWithoutOrders,
                      ),
                    ),
                    child: const Text('Voltar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(
                      _PlanDayAssetSelectionResult(
                        selectedOrderIds: Set<dynamic>.from(localSelection),
                        includeAssetWithoutOrders: includeAssetWithoutOrders,
                      ),
                    ),
                    child: Text(
                      'Aplicar ${localSelection.length} ordens',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterventionEmailDraft {
  const _InterventionEmailDraft({
    required this.assetId,
    required this.assetName,
    required this.recipientEmail,
    required this.replyToEmail,
    required this.sendMode,
    required this.provider,
    required this.providerLabel,
    required this.connectionId,
    required this.connectionLabel,
    required this.connectionStatusLabel,
    required this.automaticDeliveryReady,
    required this.deliveryNote,
    required this.subject,
    required this.body,
    required this.workOrderCount,
  });

  final String assetId;
  final String assetName;
  final String recipientEmail;
  final String replyToEmail;
  final String sendMode;
  final String provider;
  final String providerLabel;
  final String? connectionId;
  final String? connectionLabel;
  final String? connectionStatusLabel;
  final bool automaticDeliveryReady;
  final String deliveryNote;
  final String subject;
  final String body;
  final int workOrderCount;

  bool get requestsAutomaticDelivery => sendMode == 'automatico';

  String get workOrderSummaryLabel {
    if (workOrderCount == 0) {
      return 'Sem ordem associada';
    }
    return '$workOrderCount ordens';
  }
}

class _AuthorizationConfirmationState {
  const _AuthorizationConfirmationState({
    required this.assetIds,
    required this.assetNames,
  });

  final Set<String> assetIds;
  final List<String> assetNames;

  String get assetSummary {
    if (assetNames.isEmpty) {
      return 'sem ativos';
    }
    if (assetNames.length <= 3) {
      return assetNames.join(', ');
    }
    return '${assetNames.take(3).join(', ')} e mais ${assetNames.length - 3}';
  }
}

class _AuthorizationEmailDeliveryPreviewState {
  const _AuthorizationEmailDeliveryPreviewState({
    required this.automaticModeRequested,
    required this.attemptedAutomaticSend,
    required this.sentCount,
    required this.failedCount,
    required this.summaryMessage,
    required this.snackBarMessage,
    required this.resultsByAssetId,
  });

  final bool automaticModeRequested;
  final bool attemptedAutomaticSend;
  final int sentCount;
  final int failedCount;
  final String summaryMessage;
  final String? snackBarMessage;
  final Map<String, AuthorizationEmailDeliveryItemResult> resultsByAssetId;

  AuthorizationEmailDeliveryItemResult? resultForAsset(String assetId) {
    return resultsByAssetId[assetId];
  }
}

class _AuthorizationAssetConfirmationDialog extends StatefulWidget {
  const _AuthorizationAssetConfirmationDialog({
    required this.plannedDate,
    required this.drafts,
  });

  final DateTime plannedDate;
  final List<_InterventionEmailDraft> drafts;

  @override
  State<_AuthorizationAssetConfirmationDialog> createState() =>
      _AuthorizationAssetConfirmationDialogState();
}

class _AuthorizationAssetConfirmationDialogState
    extends State<_AuthorizationAssetConfirmationDialog> {
  late final Set<String> selectedAssetIds = widget.drafts
      .map((draft) => draft.assetId)
      .toSet();

  bool get allSelected =>
      widget.drafts.isNotEmpty &&
      selectedAssetIds.length == widget.drafts.length;

  bool get partiallySelected =>
      selectedAssetIds.isNotEmpty &&
      selectedAssetIds.length < widget.drafts.length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar ativos para autorizacao'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirma os ativos para os quais vao ser preparados os emails de autorizacao do dia ${formatDateOnlyValue(widget.plannedDate)}.',
            ),
            const SizedBox(height: 8),
            Text(
              'Se mudares o planeamento depois desta confirmacao, nao existe novo envio automatico.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: allSelected
                  ? true
                  : partiallySelected
                  ? null
                  : false,
              tristate: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Selecionar todos os ativos'),
              subtitle: Text(
                '${widget.drafts.length} ativos com email configurado',
              ),
              onChanged: (value) {
                setState(() {
                  if (allSelected || value == false) {
                    selectedAssetIds.clear();
                  } else {
                    selectedAssetIds
                      ..clear()
                      ..addAll(widget.drafts.map((draft) => draft.assetId));
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.drafts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final draft = widget.drafts[index];
                  return CheckboxListTile(
                    value: selectedAssetIds.contains(draft.assetId),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(draft.assetName),
                    subtitle: Text(
                      '${draft.recipientEmail} | ${draft.workOrderSummaryLabel}',
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedAssetIds.add(draft.assetId);
                        } else {
                          selectedAssetIds.remove(draft.assetId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Agora nao'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(Set<String>.from(selectedAssetIds)),
          child: Text(
            selectedAssetIds.isEmpty
                ? 'Guardar sem emails'
                : 'Continuar com ${selectedAssetIds.length}',
          ),
        ),
      ],
    );
  }
}

class _InterventionEmailPreviewPage extends StatelessWidget {
  const _InterventionEmailPreviewPage({
    required this.plannedDate,
    required this.drafts,
    this.deliveryState,
  });

  final DateTime plannedDate;
  final List<_InterventionEmailDraft> drafts;
  final _AuthorizationEmailDeliveryPreviewState? deliveryState;

  @override
  Widget build(BuildContext context) {
    final summaryTitle =
        deliveryState?.attemptedAutomaticSend == true
        ? 'Resumo do envio'
        : 'Pre-visualizacao dos emails';
    final summaryText =
        deliveryState?.summaryMessage ??
        'Foram preparados ${drafts.length} emails para a data ${formatDateOnlyValue(plannedDate)}. Podes rever e copiar o conteudo antes de enviar manualmente, se precisares.';

    return Scaffold(
      appBar: AppBar(title: const Text('Emails de intervencao')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summaryTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summaryText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (deliveryState?.automaticModeRequested == true) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            deliveryState!.attemptedAutomaticSend
                                ? 'Envio automatico tentado'
                                : 'Envio automatico adiado',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (deliveryState!.attemptedAutomaticSend)
                          Chip(
                            label: Text('${deliveryState!.sentCount} enviados'),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (deliveryState!.attemptedAutomaticSend &&
                            deliveryState!.failedCount > 0)
                          Chip(
                            label: Text(
                              '${deliveryState!.failedCount} com erro',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...drafts.map((draft) {
            final deliveryResult = deliveryState?.resultForAsset(draft.assetId);
            final fullText =
                'Para: ${draft.recipientEmail}${draft.replyToEmail.isNotEmpty ? '\nResposta para: ${draft.replyToEmail}' : ''}\nAssunto: ${draft.subject}\n\n${draft.body}';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            draft.assetName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Chip(
                          label: Text(draft.workOrderSummaryLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText('Para: ${draft.recipientEmail}'),
                    if (draft.replyToEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SelectableText('Resposta para: ${draft.replyToEmail}'),
                    ],
                    const SizedBox(height: 4),
                    SelectableText(
                      'Modo: ${draft.sendMode == 'automatico' ? 'Automatico apos planear' : 'Manual com confirmacao'}',
                    ),
                    const SizedBox(height: 4),
                    SelectableText('Fornecedor: ${draft.providerLabel}'),
                    if (draft.connectionLabel?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      SelectableText('Conta ligada: ${draft.connectionLabel}'),
                    ],
                    if (draft.connectionStatusLabel?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      SelectableText(
                        'Estado da conta: ${draft.connectionStatusLabel}',
                      ),
                    ],
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
                      child: Text(
                        draft.deliveryNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (deliveryResult != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              deliveryResult.isSent
                                  ? 'Enviado automaticamente'
                                  : 'Erro no envio',
                            ),
                            backgroundColor: deliveryResult.isSent
                                ? Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer
                                : Theme.of(context).colorScheme.errorContainer,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (deliveryResult.providerMessageId?.trim().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          'ID do provider: ${deliveryResult.providerMessageId!.trim()}',
                        ),
                      ],
                      if (deliveryResult.errorMessage?.trim().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Erro de envio: ${deliveryResult.errorMessage!.trim()}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Assunto',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(draft.subject),
                    const SizedBox(height: 12),
                    Text(
                      'Mensagem',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(draft.body),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: fullText),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Email de ${draft.assetName} copiado para a area de transferencia.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copiar email'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlannedDayAssetsLoadResult {
  const _PlannedDayAssetsLoadResult({
    required this.isAvailable,
    required this.items,
  });

  final bool isAvailable;
  final List<Map<String, dynamic>> items;
}

class _CalendarInfoChip extends StatelessWidget {
  const _CalendarInfoChip({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 110 : 132),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            value,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _WeekPlanner extends StatelessWidget {
  const _WeekPlanner({
    required this.weekDays,
    required this.selectedDate,
    required this.unscheduledOrders,
    required this.ordersForDay,
    required this.onSelectDay,
    required this.onOpenWorkOrder,
    required this.onDropOrderOnDay,
    required this.technicianNamesById,
    required this.assetsById,
  });

  final List<DateTime> weekDays;
  final DateTime selectedDate;
  final List<Map<String, dynamic>> unscheduledOrders;
  final List<Map<String, dynamic>> Function(DateTime day) ordersForDay;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<Map<String, dynamic>> onOpenWorkOrder;
  final Future<void> Function(Map<String, dynamic>, DateTime)? onDropOrderOnDay;
  final Map<String, String> technicianNamesById;
  final Map<String, Map<String, dynamic>> assetsById;

  @override
  Widget build(BuildContext context) {
    final columns = <Widget>[
      _PlannerColumn(
        title: 'Nao planeadas',
        subtitle: '${unscheduledOrders.length} ordens',
        items: unscheduledOrders,
        isSelected: false,
        labelBuilder: null,
        onOpenWorkOrder: onOpenWorkOrder,
        technicianNamesById: technicianNamesById,
        assetsById: assetsById,
        onAccept: null,
      ),
      ...weekDays.map((day) {
        return _PlannerColumn(
          title: _weekDayLabel(day),
          subtitle: formatDateOnlyValue(day),
          items: ordersForDay(day),
          isSelected: DateUtils.isSameDay(day, selectedDate),
          labelBuilder: (workOrder) {
            final scheduled = parseDateValue(workOrderScheduledFor(workOrder));
            if (scheduled == null) return 'Sem hora';
            return '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
          },
          onOpenWorkOrder: onOpenWorkOrder,
          technicianNamesById: technicianNamesById,
          assetsById: assetsById,
          onAccept: onDropOrderOnDay == null
              ? null
              : (workOrder) => onDropOrderOnDay!(workOrder, day),
          onTapHeader: () => onSelectDay(day),
        );
      }),
    ];

    return SizedBox(
      height: 360,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: columns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            SizedBox(width: 260, child: columns[index]),
      ),
    );
  }

  static String _weekDayLabel(DateTime day) {
    const names = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
    return names[day.weekday - 1];
  }
}

class _PlannerColumn extends StatelessWidget {
  const _PlannerColumn({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.isSelected,
    required this.labelBuilder,
    required this.onOpenWorkOrder,
    required this.technicianNamesById,
    required this.assetsById,
    required this.onAccept,
    this.onTapHeader,
  });

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> items;
  final bool isSelected;
  final String Function(Map<String, dynamic>)? labelBuilder;
  final ValueChanged<Map<String, dynamic>> onOpenWorkOrder;
  final Map<String, String> technicianNamesById;
  final Map<String, Map<String, dynamic>> assetsById;
  final Future<void> Function(Map<String, dynamic>)? onAccept;
  final VoidCallback? onTapHeader;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTapHeader,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Sem ordens'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final workOrder = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PlannerWorkOrderCard(
                          workOrder: workOrder,
                          assetName:
                              assetsById[workOrder['asset_id']?.toString() ??
                                      '']?['name']
                                  ?.toString() ??
                              '-',
                          technicianName:
                              technicianNamesById[workOrder['technician_id']
                                      ?.toString() ??
                                  ''],
                          label: labelBuilder == null
                              ? null
                              : labelBuilder!(workOrder),
                          onOpen: () => onOpenWorkOrder(workOrder),
                          draggable: onAccept != null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (onAccept == null) return content;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) async {
        await onAccept!(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: candidateData.isEmpty
                ? null
                : [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.18),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: content,
        );
      },
    );
  }
}

class _PlannerWorkOrderCard extends StatelessWidget {
  const _PlannerWorkOrderCard({
    required this.workOrder,
    required this.assetName,
    required this.technicianName,
    required this.label,
    required this.onOpen,
    required this.draggable,
  });

  final Map<String, dynamic> workOrder;
  final String assetName;
  final String? technicianName;
  final String? label;
  final VoidCallback onOpen;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workOrderTitle(workOrder),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                assetName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (technicianName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  technicianName!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (label?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  label!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!draggable) return card;

    return LongPressDraggable<Map<String, dynamic>>(
      data: workOrder,
      feedback: SizedBox(
        width: 220,
        child: Opacity(opacity: 0.95, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.countsByDay,
    required this.compact,
    required this.onSelectDay,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Map<String, int> countsByDay;
  final bool compact;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    final leadingOffset = firstDayOfMonth.weekday - 1;
    final totalCells = ((leadingOffset + daysInMonth + 6) ~/ 7) * 7;
    final weekLabels = const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

    return Column(
      children: [
        Row(
          children: weekLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: compact ? 4 : 8,
            crossAxisSpacing: compact ? 4 : 8,
            childAspectRatio: compact ? 1.08 : 0.95,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingOffset + 1;
            if (index < leadingOffset || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              visibleMonth.year,
              visibleMonth.month,
              dayNumber,
            );
            final isSelected = DateUtils.isSameDay(date, selectedDate);
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            final count =
                countsByDay[DateTime(
                  date.year,
                  date.month,
                  date.day,
                ).toIso8601String()] ??
                0;

            return InkWell(
              onTap: () => onSelectDay(date),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
                      : Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 5 : 8),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          '$dayNumber',
                          style:
                              (compact
                                      ? Theme.of(context).textTheme.bodyMedium
                                      : Theme.of(context).textTheme.titleSmall)
                                  ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (count > 0 && compact)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$count',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      if (count > 0 && !compact)
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count plan.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
