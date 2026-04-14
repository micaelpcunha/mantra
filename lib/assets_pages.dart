import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'asset_devices_page.dart';
import 'models/user_profile.dart';
import 'qr/asset_qr_support.dart';
import 'services/asset_device_service.dart';
import 'services/company_scope_service.dart';
import 'services/client_scope_service.dart';
import 'services/storage_service.dart';
import 'work_orders/add_work_order_page.dart';
import 'work_orders/task_detail_page.dart';
import 'work_orders/work_order_helpers.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({
    super.key,
    this.userProfile,
    this.canManageAll = true,
    this.canEditAssets = false,
    this.canEditAssetDevices = false,
    this.canEditWorkOrders = false,
    this.canCloseWorkOrders = true,
  });

  final UserProfile? userProfile;
  final bool canManageAll;
  final bool canEditAssets;
  final bool canEditAssetDevices;
  final bool canEditWorkOrders;
  final bool canCloseWorkOrders;

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> assets = [];
  Map<String, String> locationNamesById = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchAssets();
  }

  Future<void> fetchAssets() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase.from('assets').select(),
        supabase.from('locations').select('id, name'),
      ]);

      if (!mounted) return;

      final data = List<Map<String, dynamic>>.from(results[0] as List);
      final locations = List<Map<String, dynamic>>.from(results[1] as List);
      final visibleAssets = data
          .where(
            (asset) =>
                ClientScopeService.canAccessAsset(widget.userProfile, asset),
          )
          .toList();

      setState(() {
        assets = visibleAssets;
        locationNamesById = {
          for (final location in locations)
            location['id']?.toString() ?? '':
                location['name']?.toString() ?? '',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar os ativos.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Color assetStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
      case 'operacional':
        return Colors.green;
      case 'manutencao':
      case 'em manutencao':
        return Colors.orange;
      case 'avariado':
      case 'inativo':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  String? assetPhotoUrl(Map<String, dynamic> asset) {
    return asset['profile_photo_url']?.toString();
  }

  String? assetQrValue(Map<String, dynamic> asset) {
    return AssetQrSupport.qrValueFromAsset(asset);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (assets.isEmpty) {
      return const Center(child: Text('Sem ativos'));
    }

    return RefreshIndicator(
      onRefresh: fetchAssets,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ativos', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '${assets.length} registados',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...assets.map((asset) {
            final status = asset['status']?.toString() ?? '';
            final color = assetStatusColor(status);
            final locationName =
                locationNamesById[asset['location_id']?.toString()] ?? '';
            final photoUrl = assetPhotoUrl(asset);
            final qrValue = assetQrValue(asset);
            final requiresMaintenanceQr =
                AssetQrSupport.requiresQrForMaintenance(asset);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: _AssetAvatar(photoUrl: photoUrl, color: color),
                title: Text(asset['name']?.toString() ?? ''),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(status.isEmpty ? 'Sem estado' : status),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: color.withOpacity(0.12),
                      ),
                      if (locationName.isNotEmpty)
                        Chip(
                          label: Text(locationName),
                          avatar: const Icon(Icons.place, size: 18),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                      if (qrValue != null && qrValue.isNotEmpty)
                        const Chip(
                          label: Text('QR associado'),
                          avatar: Icon(Icons.qr_code, size: 18),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                      if (requiresMaintenanceQr)
                        const Chip(
                          label: Text('QR obrigatorio na manutencao'),
                          avatar: Icon(Icons.verified_user, size: 18),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AssetDetailPage(
                        asset: asset,
                        userProfile: widget.userProfile,
                        canManageAll: widget.canManageAll,
                        canEditAssets: widget.canEditAssets,
                        canEditAssetDevices: widget.canEditAssetDevices,
                        canEditWorkOrders: widget.canEditWorkOrders,
                        canCloseWorkOrders: widget.canCloseWorkOrders,
                      ),
                    ),
                  );

                  if (!mounted) return;
                  await fetchAssets();
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AssetDetailPage extends StatefulWidget {
  const AssetDetailPage({
    super.key,
    required this.asset,
    this.userProfile,
    this.canManageAll = true,
    this.canEditAssets = false,
    this.canEditAssetDevices = false,
    this.canEditWorkOrders = false,
    this.canCloseWorkOrders = true,
  });

  final Map<String, dynamic> asset;
  final UserProfile? userProfile;
  final bool canManageAll;
  final bool canEditAssets;
  final bool canEditAssetDevices;
  final bool canEditWorkOrders;
  final bool canCloseWorkOrders;

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> assetDevices = [];
  late Map<String, dynamic> currentAsset;
  bool isLoading = true;
  bool isUploadingPhoto = false;
  bool assetDevicesFeatureAvailable = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    currentAsset = Map<String, dynamic>.from(widget.asset);
    fetchTasks();
  }

  String? get assetPhotoUrl {
    return currentAsset['profile_photo_url']?.toString();
  }

  bool get canEditAssetProfile => widget.canManageAll || widget.canEditAssets;
  bool get canEditDevices => widget.canManageAll || widget.canEditAssetDevices;
  String? get qrValue => AssetQrSupport.qrValueFromAsset(currentAsset);
  bool get requiresQrForMaintenance =>
      AssetQrSupport.requiresQrForMaintenance(currentAsset);

  Future<void> fetchTasks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await supabase
          .from('work_orders')
          .select()
          .eq('asset_id', widget.asset['id'])
          .order('id');
      final deviceLoadResult = await _loadAssetDevices();

      if (!mounted) return;

      setState(() {
        tasks = List<Map<String, dynamic>>.from(data);
        assetDevices = deviceLoadResult.devices;
        assetDevicesFeatureAvailable = deviceLoadResult.isAvailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar as tarefas deste ativo.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddWorkOrderPage(asset: currentAsset)),
    );
    await fetchTasks();
  }

  Future<void> openTaskDetail(Map<String, dynamic> task) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          task: task,
          asset: currentAsset,
          userProfile: widget.userProfile,
          canManageAll: widget.canManageAll,
          canEditFullOrder: widget.canManageAll || widget.canEditWorkOrders,
          canCloseWorkOrder: widget.canManageAll || widget.canCloseWorkOrders,
        ),
      ),
    );

    if (changed == true) {
      await fetchTasks();
    }
  }

  Future<void> openEditAsset() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddAssetPage(asset: currentAsset)),
    );

    if (changed != true || !mounted) return;

    final refreshedAsset = await supabase
        .from('assets')
        .select()
        .eq('id', currentAsset['id'])
        .maybeSingle();

    if (!mounted || refreshedAsset == null) return;

    setState(() {
      currentAsset = Map<String, dynamic>.from(refreshedAsset);
    });
  }

  Future<_AssetDeviceLoadResult> _loadAssetDevices() async {
    try {
      final devices = await AssetDeviceService.instance.fetchDevicesForAsset(
        widget.asset['id'],
      );
      return _AssetDeviceLoadResult(devices: devices, isAvailable: true);
    } on PostgrestException catch (error) {
      if (AssetDeviceService.instance.isMissingTableError(error)) {
        return const _AssetDeviceLoadResult(devices: [], isAvailable: false);
      }
      rethrow;
    }
  }

  Future<void> openDevicesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDevicesPage(
          asset: currentAsset,
          canEditDevices: canEditDevices,
          canDeleteDevices: widget.canManageAll,
        ),
      ),
    );

    if (!mounted) return;
    await fetchTasks();
  }

  Future<void> uploadProfilePhoto() async {
    setState(() {
      isUploadingPhoto = true;
    });

    try {
      final previousPhoto = assetPhotoUrl;
      final url = await StorageService.instance
          .pickAndUploadAssetProfilePhoto();
      if (!mounted || url == null) return;

      await _saveAssetPhoto(url);
      if (!mounted) return;

      setState(() {
        currentAsset = {...currentAsset, 'profile_photo_url': url};
      });
      await _deleteAssetPhotoFromStorage(previousPhoto, keepValue: url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografia do ativo carregada com sucesso.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel carregar a fotografia do ativo: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isUploadingPhoto = false;
      });
    }
  }

  Future<void> removeProfilePhoto() async {
    final previousPhoto = assetPhotoUrl?.trim();
    if (previousPhoto == null || previousPhoto.isEmpty) return;

    setState(() {
      isUploadingPhoto = true;
    });

    try {
      await _saveAssetPhoto(null);
      if (!mounted) return;

      setState(() {
        currentAsset = {...currentAsset, 'profile_photo_url': null};
      });
      await _deleteAssetPhotoFromStorage(previousPhoto);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografia do ativo removida com sucesso.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel remover a fotografia do ativo: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isUploadingPhoto = false;
      });
    }
  }

  Future<void> _saveAssetPhoto(String? url) async {
    await supabase
        .from('assets')
        .update({'profile_photo_url': url})
        .eq('id', currentAsset['id']);
  }

  Future<void> _deleteAssetPhotoFromStorage(
    String? storedValue, {
    String? keepValue,
  }) async {
    final normalizedStoredValue = storedValue?.trim();
    if (normalizedStoredValue == null || normalizedStoredValue.isEmpty) {
      return;
    }

    final normalizedKeepValue = keepValue?.trim();
    if (normalizedKeepValue != null &&
        normalizedKeepValue.isNotEmpty &&
        normalizedKeepValue == normalizedStoredValue) {
      return;
    }

    try {
      await StorageService.instance.deleteStoredObject(
        bucket: 'asset-profile-photos',
        storedValue: normalizedStoredValue,
      );
    } catch (_) {
      // Keep the asset update successful even if storage cleanup fails.
    }
  }

  Future<void> generateQrCode() async {
    final generatedQrValue = AssetQrSupport.generateValue(
      assetId: currentAsset['id'],
      assetName: currentAsset['name']?.toString(),
    );

    await _saveQrValue(generatedQrValue);
  }

  Future<void> scanAndAssociateQrCode() async {
    final scannedQrValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AssetQrScannerPage()),
    );

    if (!mounted || scannedQrValue == null || scannedQrValue.trim().isEmpty) {
      return;
    }

    await _saveQrValue(scannedQrValue.trim());
  }

  Future<void> _saveQrValue(String value) async {
    try {
      await AssetQrSupport.saveQrValue(
        supabase: supabase,
        assetId: currentAsset['id'],
        qrValue: value,
      );

      if (!mounted) return;

      setState(() {
        currentAsset = AssetQrSupport.copyWithQrValue(currentAsset, value);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo QR associado ao ativo.')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel associar o codigo QR: $e')),
      );
    }
  }

  Future<void> updateRequiresQrForMaintenance(bool value) async {
    try {
      await AssetQrSupport.saveRequiresQrForMaintenance(
        supabase: supabase,
        assetId: currentAsset['id'],
        value: value,
      );

      if (!mounted) return;

      setState(() {
        currentAsset = AssetQrSupport.copyWithRequiresQrForMaintenance(
          currentAsset,
          value,
        );
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nao foi possivel atualizar a obrigatoriedade do QR: $e',
          ),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get openTasks {
    final filtered = tasks.where((task) {
      final status = task['status']?.toString().toLowerCase() ?? '';
      return status != 'concluido';
    }).toList();

    filtered.sort((a, b) {
      final aDate =
          parseDateValue(workOrderUpdatedAt(a)) ??
          parseDateValue(a['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          parseDateValue(workOrderUpdatedAt(b)) ??
          parseDateValue(b['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  List<Map<String, dynamic>> get completedTasks {
    final filtered = tasks.where((task) {
      final status = task['status']?.toString().toLowerCase() ?? '';
      return status == 'concluido';
    }).toList();

    filtered.sort((a, b) {
      final aDate =
          parseDateValue(workOrderUpdatedAt(a)) ??
          parseDateValue(a['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          parseDateValue(workOrderUpdatedAt(b)) ??
          parseDateValue(b['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Color taskStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'concluido':
        return Colors.green;
      case 'em curso':
        return Colors.orange;
      case 'pendente':
      default:
        return Colors.blueGrey;
    }
  }

  Color assetStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
      case 'operacional':
        return Colors.green;
      case 'manutencao':
      case 'em manutencao':
        return Colors.orange;
      case 'avariado':
      case 'inativo':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  String get assetDevicesSummary {
    if (!assetDevicesFeatureAvailable) {
      return 'Os dispositivos ainda nao estao ativados nesta base de dados.';
    }
    if (assetDevices.isEmpty) {
      return 'Ainda nao existem dispositivos registados neste ativo.';
    }
    if (assetDevices.length == 1) {
      return '1 dispositivo registado.';
    }
    return '${assetDevices.length} dispositivos registados.';
  }

  Widget buildTaskList({
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 240, child: Center(child: Text(emptyMessage))),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final task = items[index];
        final status = task['status']?.toString() ?? '';
        final color = taskStatusColor(status);
        final lastUpdate = formatDateValue(
          workOrderUpdatedAt(task) ?? task['created_at'],
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(Icons.assignment, color: color),
            ),
            title: Text(workOrderTitle(task)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (workOrderReference(task).isNotEmpty)
                    Text('Ref.: ${workOrderReference(task)}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(status.isEmpty ? '-' : status),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: color.withOpacity(0.12),
                      ),
                      Chip(
                        label: Text('Atualizada: $lastUpdate'),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTaskDetail(task),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(currentAsset['name']?.toString() ?? 'Ativo'),
          actions: [
            if (canEditAssetProfile)
              IconButton(
                onPressed: openEditAsset,
                icon: const Icon(Icons.edit),
                tooltip: 'Editar ativo',
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Em aberto (${openTasks.length})'),
              Tab(text: 'Concluidas (${completedTasks.length})'),
            ],
          ),
        ),
        floatingActionButton: (widget.canManageAll || widget.canEditWorkOrders)
            ? FloatingActionButton(
                onPressed: openAddTask,
                child: const Icon(Icons.add),
              )
            : null,
        body: Builder(
          builder: (context) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (errorMessage != null) {
              return Center(child: Text(errorMessage!));
            }

            final status = currentAsset['status']?.toString() ?? '';
            final statusColor = assetStatusColor(status);

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _AssetAvatar(
                                photoUrl: assetPhotoUrl,
                                color: statusColor,
                                radius: 42,
                                iconSize: 36,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                currentAsset['name']?.toString() ?? 'Ativo',
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      status.isEmpty ? 'Sem estado' : status,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                    backgroundColor: statusColor.withOpacity(
                                      0.12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dispositivos',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(assetDevicesSummary),
                                    if (assetDevicesFeatureAvailable &&
                                        assetDevices.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: assetDevices
                                            .take(3)
                                            .map(
                                              (device) => Chip(
                                                label: Text(
                                                  device['name']?.toString() ??
                                                      'Dispositivo',
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                side: BorderSide.none,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      if (assetDevices.length > 3) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'E mais ${assetDevices.length - 3}.',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: openDevicesPage,
                                      icon: const Icon(Icons.memory_outlined),
                                      label: Text(
                                        canEditDevices
                                            ? 'Gerir dispositivos'
                                            : 'Ver dispositivos',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canEditAssetProfile) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: isUploadingPhoto
                                          ? null
                                          : uploadProfilePhoto,
                                      icon: const Icon(
                                        Icons.photo_camera_outlined,
                                      ),
                                      label: Text(
                                        assetPhotoUrl?.isNotEmpty == true
                                            ? 'Substituir foto do ativo'
                                            : 'Carregar foto do ativo',
                                      ),
                                    ),
                                    if (assetPhotoUrl?.trim().isNotEmpty ==
                                        true)
                                      TextButton.icon(
                                        onPressed: isUploadingPhoto
                                            ? null
                                            : removeProfilePhoto,
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text(
                                          'Remover foto do ativo',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: RefreshIndicator(
                onRefresh: fetchTasks,
                child: TabBarView(
                  children: [
                    buildTaskList(
                      items: openTasks,
                      emptyMessage: 'Sem tarefas em aberto',
                    ),
                    buildTaskList(
                      items: completedTasks,
                      emptyMessage: 'Sem tarefas concluidas',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AddAssetPage extends StatefulWidget {
  const AddAssetPage({super.key, this.asset});

  final Map<String, dynamic>? asset;

  bool get isEditing => asset != null;

  @override
  State<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends State<AddAssetPage> {
  final supabase = Supabase.instance.client;
  final nameController = TextEditingController();
  final statusController = TextEditingController();
  final qrController = TextEditingController();
  final entryAuthorizationEmailController = TextEditingController();
  final entryAuthorizationSubjectController = TextEditingController();
  final entryAuthorizationTemplateController = TextEditingController();
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> technicians = [];
  dynamic selectedLocationId;
  String? selectedDefaultTechnicianId;
  String? profilePhotoUrl;
  final Set<String> _assetPhotosToDeleteOnSave = <String>{};
  bool requiresQrScanForMaintenance = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final existingAsset = widget.asset;
    if (existingAsset != null) {
      nameController.text = existingAsset['name']?.toString() ?? '';
      statusController.text = existingAsset['status']?.toString() ?? '';
      qrController.text = AssetQrSupport.qrValueFromAsset(existingAsset) ?? '';
      selectedLocationId = existingAsset['location_id'];
      selectedDefaultTechnicianId = existingAsset['default_technician_id']
          ?.toString();
      profilePhotoUrl = existingAsset['profile_photo_url']?.toString();
      entryAuthorizationEmailController.text =
          existingAsset['entry_authorization_email']?.toString() ?? '';
      entryAuthorizationSubjectController.text =
          existingAsset['entry_authorization_subject']?.toString() ?? '';
      entryAuthorizationTemplateController.text =
          existingAsset['entry_authorization_template']?.toString() ?? '';
      requiresQrScanForMaintenance = AssetQrSupport.requiresQrForMaintenance(
        existingAsset,
      );
    }
    loadLocations();
    loadTechnicians();
  }

  @override
  void dispose() {
    nameController.dispose();
    statusController.dispose();
    qrController.dispose();
    entryAuthorizationEmailController.dispose();
    entryAuthorizationSubjectController.dispose();
    entryAuthorizationTemplateController.dispose();
    super.dispose();
  }

  Future<void> loadLocations() async {
    try {
      final data = await supabase.from('locations').select().order('name');

      if (!mounted) return;

      setState(() {
        locations = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar as localizacoes.'),
        ),
      );
    }
  }

  Future<void> loadTechnicians() async {
    try {
      final data = await supabase
          .from('technicians')
          .select('id, name')
          .order('name');

      if (!mounted) return;

      final loadedTechnicians = List<Map<String, dynamic>>.from(data);
      final hasSelectedTechnician = loadedTechnicians.any(
        (technician) =>
            technician['id']?.toString() == selectedDefaultTechnicianId,
      );

      setState(() {
        technicians = loadedTechnicians;
        if (!hasSelectedTechnician) {
          selectedDefaultTechnicianId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel carregar os tecnicos.')),
      );
    }
  }

  Future<void> save() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome do ativo e obrigatorio.')),
      );
      return;
    }

    final authorizationEmail = entryAuthorizationEmailController.text.trim();
    if (authorizationEmail.isNotEmpty && !_isValidEmail(authorizationEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O email de autorizacao de entrada nao e valido.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await _saveAsset();
      await _cleanupAssetPhotosAfterSave(
        finalPhotoValue: profilePhotoUrl,
        pendingDeletes: List<String>.from(_assetPhotosToDeleteOnSave),
      );

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
        const SnackBar(content: Text('Nao foi possivel guardar o ativo.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> uploadProfilePhoto() async {
    try {
      final previousPhoto = profilePhotoUrl;
      final url = await StorageService.instance
          .pickAndUploadAssetProfilePhoto();
      if (!mounted || url == null) return;

      _queueAssetPhotoDeletion(previousPhoto);
      setState(() {
        profilePhotoUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografia do ativo carregada com sucesso.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel carregar a fotografia do ativo: $e'),
        ),
      );
    }
  }

  void removeProfilePhoto() {
    final currentPhoto = profilePhotoUrl?.trim();
    if (currentPhoto == null || currentPhoto.isEmpty) return;

    _queueAssetPhotoDeletion(currentPhoto);
    setState(() {
      profilePhotoUrl = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Fotografia removida do rascunho. Guarda para confirmar.'
              : 'Fotografia removida do novo ativo.',
        ),
      ),
    );
  }

  void _queueAssetPhotoDeletion(String? storedValue) {
    final value = storedValue?.trim();
    if (value == null || value.isEmpty) return;
    _assetPhotosToDeleteOnSave.add(value);
  }

  Future<void> _cleanupAssetPhotosAfterSave({
    required String? finalPhotoValue,
    required List<String> pendingDeletes,
  }) async {
    final normalizedFinalValue = finalPhotoValue?.trim();
    final deletions = pendingDeletes
        .map((value) => value.trim())
        .where(
          (value) =>
              value.isNotEmpty &&
              (normalizedFinalValue == null || normalizedFinalValue != value),
        )
        .toList();

    if (deletions.isEmpty) {
      _assetPhotosToDeleteOnSave.clear();
      return;
    }

    try {
      await StorageService.instance.deleteStoredObjects(
        bucket: 'asset-profile-photos',
        storedValues: deletions,
      );
      _assetPhotosToDeleteOnSave.removeAll(deletions);
    } catch (_) {
      // Keep the asset save successful even if storage cleanup fails.
    }
  }

  Future<void> scanExistingQrCode() async {
    final scannedQrValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AssetQrScannerPage()),
    );

    if (!mounted || scannedQrValue == null || scannedQrValue.trim().isEmpty) {
      return;
    }

    setState(() {
      qrController.text = scannedQrValue.trim();
    });
  }

  void generateQrCodeValue() {
    final generated = AssetQrSupport.generateValue(
      assetName: nameController.text.trim(),
    );

    setState(() {
      qrController.text = generated;
    });
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  Future<void> _saveAsset() async {
    final payload = {
      'name': nameController.text.trim(),
      'status': statusController.text.trim(),
      'location_id': selectedLocationId,
      'default_technician_id': selectedDefaultTechnicianId,
      'profile_photo_url': profilePhotoUrl,
      'qr_code': qrController.text.trim().isEmpty
          ? null
          : qrController.text.trim(),
      'requires_qr_scan_for_maintenance': requiresQrScanForMaintenance,
      'entry_authorization_email':
          entryAuthorizationEmailController.text.trim().isEmpty
          ? null
          : entryAuthorizationEmailController.text.trim(),
      'entry_authorization_subject':
          entryAuthorizationSubjectController.text.trim().isEmpty
          ? null
          : entryAuthorizationSubjectController.text.trim(),
      'entry_authorization_template':
          entryAuthorizationTemplateController.text.trim().isEmpty
          ? null
          : entryAuthorizationTemplateController.text.trim(),
    };

    if (widget.isEditing) {
      await _updateAsset(payload);
      return;
    }

    await _createAsset(payload);
  }

  Future<void> _createAsset(Map<String, dynamic> payload) async {
    final scopedPayload = await CompanyScopeService.instance
        .attachCurrentCompanyId(table: 'assets', payload: payload);
    await supabase.from('assets').insert(scopedPayload);
  }

  Future<void> _updateAsset(Map<String, dynamic> payload) async {
    final assetId = widget.asset!['id'];
    await supabase.from('assets').update(payload).eq('id', assetId);
  }

  @override
  Widget build(BuildContext context) {
    final technicianDropdownValue =
        technicians.any(
          (technician) =>
              technician['id']?.toString() == selectedDefaultTechnicianId,
        )
        ? selectedDefaultTechnicianId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Ativo' : 'Novo Ativo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _AssetAvatar(
                    photoUrl: profilePhotoUrl,
                    color: Colors.blueGrey,
                    radius: 40,
                    iconSize: 34,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : uploadProfilePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      profilePhotoUrl?.isNotEmpty == true
                          ? 'Substituir foto do ativo'
                          : 'Carregar foto do ativo',
                    ),
                  ),
                  if (profilePhotoUrl?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isSaving ? null : removeProfilePhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remover foto do ativo'),
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
                    'Dados do ativo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: statusController,
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<dynamic>(
                    value: selectedLocationId,
                    decoration: const InputDecoration(labelText: 'Localizacao'),
                    items: [
                      const DropdownMenuItem<dynamic>(
                        value: null,
                        child: Text('Sem localizacao'),
                      ),
                      ...locations.map((location) {
                        return DropdownMenuItem<dynamic>(
                          value: location['id'],
                          child: Text(location['name']?.toString() ?? ''),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedLocationId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: technicianDropdownValue,
                    decoration: const InputDecoration(
                      labelText: 'Tecnico predefinido',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem tecnico predefinido'),
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
                        selectedDefaultTechnicianId = value;
                      });
                    },
                  ),
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
                    'Envio de email de intervencao',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configura para quem vai o email e qual o texto base a usar quando uma intervencao for planeada para este ativo.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: entryAuthorizationEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email destinatario',
                      hintText: 'exemplo@cliente.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: entryAuthorizationSubjectController,
                    decoration: const InputDecoration(
                      labelText: 'Assunto do email',
                      hintText: 'Pedido de autorizacao para intervencao',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: entryAuthorizationTemplateController,
                    minLines: 5,
                    maxLines: 9,
                    decoration: const InputDecoration(
                      labelText: 'Texto base do email',
                      hintText:
                          'Bom dia,\n\nSolicitamos autorizacao para intervencao no ativo acima na data planeada.\n\nCom os melhores cumprimentos,',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A data planeada da intervencao sera inserida automaticamente no email final.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                    'QR e validacao',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configura o codigo QR do ativo e se a manutencao deve exigir leitura desse codigo.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qrController,
                    decoration: const InputDecoration(
                      labelText: 'Codigo QR',
                      hintText: 'Valor gravado no QR do ativo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isSaving ? null : generateQrCodeValue,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Gerar QR'),
                      ),
                      OutlinedButton.icon(
                        onPressed: isSaving ? null : scanExistingQrCode,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Ler QR existente'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: requiresQrScanForMaintenance,
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setState(() {
                              requiresQrScanForMaintenance = value;
                            });
                          },
                    title: const Text('Obrigar leitura de QR na manutencao'),
                    subtitle: const Text(
                      'Quando ativo, o tecnico precisa validar o QR antes de atualizar a manutencao deste ativo.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isSaving ? null : save,
            icon: const Icon(Icons.save),
            label: Text(
              isSaving
                  ? 'A guardar...'
                  : widget.isEditing
                  ? 'Atualizar ativo'
                  : 'Guardar ativo',
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetAvatar extends StatelessWidget {
  const _AssetAvatar({
    required this.photoUrl,
    required this.color,
    this.radius = 24,
    this.iconSize = 24,
  });

  final String? photoUrl;
  final Color color;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl?.isNotEmpty == true;

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.12),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      onBackgroundImageError: hasPhoto ? (_, __) {} : null,
      child: hasPhoto
          ? null
          : Icon(Icons.precision_manufacturing, color: color, size: iconSize),
    );
  }
}

class _AssetDeviceLoadResult {
  const _AssetDeviceLoadResult({
    required this.devices,
    required this.isAvailable,
  });

  final List<Map<String, dynamic>> devices;
  final bool isAvailable;
}
