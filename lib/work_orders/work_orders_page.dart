import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/client_scope_service.dart';
import '../services/work_order_offline_service.dart';
import 'task_detail_page.dart';
import 'work_order_helpers.dart';

class WorkOrdersPage extends StatefulWidget {
  const WorkOrdersPage({
    super.key,
    this.userProfile,
    this.canManageAll = true,
    this.technicianId,
    this.canEditWorkOrders = false,
    this.canCloseWorkOrders = true,
  });

  final UserProfile? userProfile;
  final bool canManageAll;
  final String? technicianId;
  final bool canEditWorkOrders;
  final bool canCloseWorkOrders;

  @override
  State<WorkOrdersPage> createState() => _WorkOrdersPageState();
}

class _WorkOrdersPageState extends State<WorkOrdersPage> {
  final searchController = TextEditingController();

  List<Map<String, dynamic>> workOrders = [];
  Map<String, String> technicianNamesById = {};
  Map<String, Map<String, dynamic>> assetsById = {};
  Map<String, String> locationNamesById = {};
  StreamSubscription<WorkOrderOfflineEvent>? _offlineSubscription;
  bool isLoading = true;
  bool isUsingOfflineCache = false;
  String? errorMessage;
  String selectedStatus = 'todos';
  String selectedTechnician = 'todos';
  String selectedOrderType = 'todas';
  DateTime? lastSyncedAt;
  int pendingChangesCount = 0;

  @override
  void initState() {
    super.initState();
    fetchWorkOrders();
    _offlineSubscription = WorkOrderOfflineService.instance.events.listen((_) {
      if (!mounted) return;
      fetchWorkOrders(showLoader: false);
    });
  }

  @override
  void dispose() {
    _offlineSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchWorkOrders({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final snapshot = await WorkOrderOfflineService.instance
          .loadVisibleWorkOrders(
            userProfile: widget.userProfile,
            canManageAll: widget.canManageAll,
            technicianId: widget.technicianId,
          );

      setState(() {
        workOrders = snapshot.workOrders
            .where(
              (order) => ClientScopeService.canAccessWorkOrder(
                widget.userProfile,
                order,
                assetsById: snapshot.assetsById,
              ),
            )
            .toList();
        technicianNamesById = snapshot.technicianNamesById;
        assetsById = snapshot.assetsById;
        locationNamesById = snapshot.locationNamesById;
        isUsingOfflineCache = snapshot.usedOfflineCache;
        lastSyncedAt = snapshot.lastSyncedAt;
        pendingChangesCount = snapshot.pendingChangesCount;
        errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar as ordens de trabalho.';
      });
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> openWorkOrderDetail(Map<String, dynamic> workOrder) async {
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
          locationName: workOrder['location_name']?.toString(),
          userProfile: widget.userProfile,
        ),
      ),
    );

    if (changed == true) {
      await fetchWorkOrders();
    }
  }

  List<Map<String, dynamic>> get filteredWorkOrders {
    final query = searchController.text.trim().toLowerCase();

    return workOrders.where((workOrder) {
      final status = workOrder['status']?.toString() ?? '';
      final technicianId = workOrder['technician_id']?.toString() ?? '';
      final title = workOrderTitle(workOrder).toLowerCase();
      final reference = workOrderReference(workOrder).toLowerCase();
      final description = workOrderDescription(workOrder).toLowerCase();
      final orderType = workOrderType(workOrder);

      final matchesStatus =
          selectedStatus == 'todos' || status == selectedStatus;
      final matchesTechnician =
          selectedTechnician == 'todos' || technicianId == selectedTechnician;
      final matchesOrderType =
          selectedOrderType == 'todas' || orderType == selectedOrderType;
      final matchesQuery =
          query.isEmpty ||
          title.contains(query) ||
          reference.contains(query) ||
          description.contains(query);

      return matchesStatus &&
          matchesTechnician &&
          matchesOrderType &&
          matchesQuery;
    }).toList();
  }

  Widget buildStatusChip(String status) {
    final color = switch (status) {
      'concluido' => Colors.green,
      'em curso' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return Chip(
      label: Text(status),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withOpacity(0.12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredWorkOrders;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    return RefreshIndicator(
      onRefresh: fetchWorkOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Pesquisar por titulo, ref. ou descricao',
            ),
          ),
          if (isUsingOfflineCache ||
              pendingChangesCount > 0 ||
              lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isUsingOfflineCache)
                            const Chip(
                              avatar: Icon(Icons.cloud_off, size: 18),
                              label: Text('Modo offline'),
                            ),
                          if (pendingChangesCount > 0)
                            Chip(
                              avatar: const Icon(Icons.sync_problem, size: 18),
                              label: Text(
                                '$pendingChangesCount alteracoes por sincronizar',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isUsingOfflineCache)
                        const Text(
                          'Estas a ver a ultima copia local das ordens. As alteracoes do tecnico ficam guardadas e seguem automaticamente quando a ligacao voltar.',
                        )
                      else if (pendingChangesCount > 0)
                        const Text(
                          'As alteracoes pendentes continuam guardadas na app e vao ser enviadas assim que houver ligacao.',
                        ),
                      if (lastSyncedAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Ultima sincronizacao: ${formatDateValue(lastSyncedAt!.toIso8601String())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => fetchWorkOrders(showLoader: false),
                        icon: const Icon(Icons.sync),
                        label: const Text('Tentar sincronizar agora'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: selectedStatus == 'todos',
                  onSelected: (_) {
                    setState(() {
                      selectedStatus = 'todos';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pendentes'),
                  selected: selectedStatus == 'pendente',
                  onSelected: (_) {
                    setState(() {
                      selectedStatus = 'pendente';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Em curso'),
                  selected: selectedStatus == 'em curso',
                  onSelected: (_) {
                    setState(() {
                      selectedStatus = 'em curso';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Concluidas'),
                  selected: selectedStatus == 'concluido',
                  onSelected: (_) {
                    setState(() {
                      selectedStatus = 'concluido';
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas as ordens'),
                  selected: selectedOrderType == 'todas',
                  onSelected: (_) {
                    setState(() {
                      selectedOrderType = 'todas';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Preventivas'),
                  selected: selectedOrderType == 'preventiva',
                  onSelected: (_) {
                    setState(() {
                      selectedOrderType = 'preventiva';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Corretivas'),
                  selected: selectedOrderType == 'corretiva',
                  onSelected: (_) {
                    setState(() {
                      selectedOrderType = 'corretiva';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Medicoes e verificacoes'),
                  selected: selectedOrderType == 'medicoes_verificacoes',
                  onSelected: (_) {
                    setState(() {
                      selectedOrderType = 'medicoes_verificacoes';
                    });
                  },
                ),
              ],
            ),
          ),
          if (widget.canManageAll) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedTechnician,
              decoration: const InputDecoration(
                labelText: 'Filtrar por tecnico',
              ),
              items: [
                const DropdownMenuItem(
                  value: 'todos',
                  child: Text('Todos os tecnicos'),
                ),
                ...technicianNamesById.entries
                    .where((entry) => entry.key.isNotEmpty)
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedTechnician = value;
                });
              },
            ),
          ],
          const SizedBox(height: 16),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  selectedOrderType == 'preventiva'
                      ? 'Nao ha ordens preventivas para os filtros selecionados.'
                      : selectedOrderType == 'corretiva'
                      ? 'Nao ha ordens corretivas para os filtros selecionados.'
                      : selectedOrderType == 'medicoes_verificacoes'
                      ? 'Nao ha ordens de medicoes e verificacoes para os filtros selecionados.'
                      : 'Nao ha ordens para os filtros selecionados.',
                ),
              ),
            )
          else
            ...items.map((workOrder) {
              final technicianId = workOrder['technician_id']?.toString() ?? '';
              final technicianName = technicianNamesById[technicianId];
              final hasPhoto = workOrderPhotoUrl(workOrder).isNotEmpty;
              final hasAttachment = workOrderAttachmentUrl(
                workOrder,
              ).isNotEmpty;
              final scheduledFor = workOrderScheduledFor(workOrder);
              final locationName = workOrder['location_name']?.toString() ?? '';
              final showDescription =
                  widget.userProfile?.isClient != true ||
                  widget.userProfile?.canClientViewDescription == true;
              final showTechnician =
                  widget.userProfile?.isClient != true ||
                  widget.userProfile?.canClientViewTechnician == true;
              final showLocation =
                  widget.userProfile?.isClient != true ||
                  widget.userProfile?.canClientViewLocation == true;
              final showScheduling =
                  widget.userProfile?.isClient != true ||
                  widget.userProfile?.canClientViewScheduling == true;
              final showPhotos =
                  widget.userProfile?.isClient != true ||
                  widget.userProfile?.canClientViewPhotos == true;
              final showAttachments =
                  widget.userProfile?.isClient != true ||
                  widget.userProfile?.canClientViewAttachments == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    child: Text(
                      workOrderReference(workOrder).isNotEmpty
                          ? workOrderReference(workOrder)[0].toUpperCase()
                          : '#',
                    ),
                  ),
                  title: Text(workOrderTitle(workOrder)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (workOrderReference(workOrder).isNotEmpty)
                          Text('Ref.: ${workOrderReference(workOrder)}'),
                        if ((workOrder['asset_name']?.toString() ?? '')
                            .isNotEmpty)
                          Text('Ativo: ${workOrder['asset_name']}'),
                        if (showDescription)
                          Text(
                            workOrderDescription(workOrder).isEmpty
                                ? 'Sem descricao'
                                : workOrderDescription(workOrder),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            buildStatusChip(
                              workOrder['status']?.toString() ?? '-',
                            ),
                            Chip(
                              label: Text(
                                workOrderTypeLabel(workOrderType(workOrder)),
                              ),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide.none,
                            ),
                            if (workOrder['_offline_pending'] == true)
                              const Chip(
                                label: Text('Por sincronizar'),
                                avatar: Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                              ),
                            if (showScheduling && scheduledFor != null)
                              Chip(
                                label: Text(
                                  'Planeada: ${formatDateOnlyValue(scheduledFor)}',
                                ),
                                avatar: const Icon(Icons.event, size: 18),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                              ),
                            if (isPreventiveOrder(workOrder) &&
                                workOrderRecurrenceInterval(workOrder) != null)
                              Chip(
                                label: Text(recurrenceSummary(workOrder)),
                                avatar: const Icon(Icons.repeat, size: 18),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                              ),
                            if (widget.canManageAll && showTechnician)
                              Chip(
                                label: Text(
                                  technicianName?.isNotEmpty == true
                                      ? technicianName!
                                      : 'Sem tecnico',
                                ),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                              ),
                            if (showLocation && locationName.isNotEmpty)
                              Chip(
                                label: Text(locationName),
                                avatar: const Icon(Icons.place, size: 18),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                              ),
                            if (showPhotos && hasPhoto)
                              const Chip(
                                label: Text('Foto'),
                                avatar: Icon(Icons.photo, size: 18),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (showAttachments && hasAttachment)
                              const Chip(
                                label: Text('Anexo'),
                                avatar: Icon(Icons.attach_file, size: 18),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Criada: ${formatDateValue(workOrder['created_at'])}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openWorkOrderDetail(workOrder),
                ),
              );
            }),
        ],
      ),
    );
  }
}
