import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'assets_pages.dart';
import 'models/user_profile.dart';
import 'services/company_scope_service.dart';
import 'services/client_scope_service.dart';
import 'services/storage_service.dart';
import 'work_orders/task_detail_page.dart';
import 'work_orders/work_order_helpers.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({
    super.key,
    this.userProfile,
    this.canManageAll = true,
    this.canEditLocations = false,
    this.canEditAssets = false,
    this.canEditAssetDevices = false,
    this.canEditWorkOrders = false,
    this.canCloseWorkOrders = true,
  });

  final UserProfile? userProfile;
  final bool canManageAll;
  final bool canEditLocations;
  final bool canEditAssets;
  final bool canEditAssetDevices;
  final bool canEditWorkOrders;
  final bool canCloseWorkOrders;

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> locations = [];
  Map<String, int> assetsByLocationId = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase.from('locations').select().order('name'),
        supabase.from('assets').select('id, location_id'),
      ]);

      if (!mounted) return;

      final loadedLocations = List<Map<String, dynamic>>.from(
        results[0] as List,
      );
      final loadedAssets = List<Map<String, dynamic>>.from(results[1] as List);
      final visibleAssets = loadedAssets
          .where(
            (asset) =>
                ClientScopeService.canAccessAsset(widget.userProfile, asset),
          )
          .toList();
      final visibleLocations = loadedLocations
          .where(
            (location) => ClientScopeService.canAccessLocation(
              widget.userProfile,
              location,
              assets: visibleAssets,
            ),
          )
          .toList();
      final counts = <String, int>{};

      for (final asset in visibleAssets) {
        final locationId = asset['location_id']?.toString();
        if (locationId == null || locationId.isEmpty) continue;
        counts[locationId] = (counts[locationId] ?? 0) + 1;
      }

      setState(() {
        locations = visibleLocations;
        assetsByLocationId = counts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar as localizacoes.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> openLocationAssets(Map<String, dynamic> location) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationAssetsPage(
          location: location,
          userProfile: widget.userProfile,
          canManageAll: widget.canManageAll,
          canEditLocations: widget.canEditLocations,
          canEditAssets: widget.canEditAssets,
          canEditAssetDevices: widget.canEditAssetDevices,
          canEditWorkOrders: widget.canEditWorkOrders,
          canCloseWorkOrders: widget.canCloseWorkOrders,
        ),
      ),
    );
    await fetchLocations();
  }

  String? locationPhotoUrl(Map<String, dynamic> location) {
    return location['photo_url']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (locations.isEmpty) {
      return const Center(child: Text('Sem localizacoes'));
    }

    return RefreshIndicator(
      onRefresh: fetchLocations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Localizacoes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${locations.length} registadas',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...locations.map((location) {
            final count =
                assetsByLocationId[location['id']?.toString() ?? ''] ?? 0;
            final photoUrl = locationPhotoUrl(location);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: _LocationAvatar(photoUrl: photoUrl),
                title: Text(location['name']?.toString() ?? 'Sem nome'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text('$count ativos'),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor: Colors.teal.withOpacity(0.12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openLocationAssets(location),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class LocationAssetsPage extends StatefulWidget {
  const LocationAssetsPage({
    super.key,
    required this.location,
    this.userProfile,
    this.canManageAll = true,
    this.canEditLocations = false,
    this.canEditAssets = false,
    this.canEditAssetDevices = false,
    this.canEditWorkOrders = false,
    this.canCloseWorkOrders = true,
  });

  final Map<String, dynamic> location;
  final UserProfile? userProfile;
  final bool canManageAll;
  final bool canEditLocations;
  final bool canEditAssets;
  final bool canEditAssetDevices;
  final bool canEditWorkOrders;
  final bool canCloseWorkOrders;

  @override
  State<LocationAssetsPage> createState() => _LocationAssetsPageState();
}

class _LocationAssetsPageState extends State<LocationAssetsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> assets = [];
  List<Map<String, dynamic>> pendingWorkOrders = [];
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
      final assetData = await supabase
          .from('assets')
          .select()
          .eq('location_id', widget.location['id'])
          .order('name');

      final loadedAssets = List<Map<String, dynamic>>.from(assetData);
      final assetIds = loadedAssets
          .map((asset) => asset['id'])
          .where((id) => id != null)
          .toList();
      final assetNamesById = {
        for (final asset in loadedAssets)
          asset['id']?.toString() ?? '': asset['name']?.toString() ?? '',
      };

      final loadedPendingOrders = <Map<String, dynamic>>[];
      if (assetIds.isNotEmpty) {
        final workOrdersData = await supabase
            .from('work_orders')
            .select()
            .inFilter('asset_id', assetIds)
            .neq('status', 'concluido')
            .order('created_at', ascending: false);

        for (final item in List<Map<String, dynamic>>.from(workOrdersData)) {
          loadedPendingOrders.add({
            ...item,
            'asset_name':
                assetNamesById[item['asset_id']?.toString() ?? ''] ?? '-',
          });
        }
      }

      if (!mounted) return;

      setState(() {
        assets = loadedAssets;
        pendingWorkOrders = loadedPendingOrders;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar os ativos desta localizacao.';
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

  Color taskStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'em curso':
        return Colors.orange;
      case 'pendente':
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> openWorkOrderDetail(Map<String, dynamic> workOrder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          task: workOrder,
          asset: {'id': workOrder['asset_id'], 'name': workOrder['asset_name']},
          userProfile: widget.userProfile,
          canManageAll: widget.canManageAll,
          canEditFullOrder: widget.canManageAll || widget.canEditWorkOrders,
          canCloseWorkOrder: widget.canManageAll || widget.canCloseWorkOrders,
        ),
      ),
    );
    await fetchAssets();
  }

  Future<void> openEditLocation() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationPage(location: widget.location),
      ),
    );

    if (changed != true || !mounted) return;
    await fetchAssets();
    if (!mounted) return;
    Navigator.pop(context);
  }

  String? get locationPhotoUrl {
    return widget.location['photo_url']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location['name']?.toString() ?? 'Localizacao'),
        actions: [
          if (widget.canManageAll || widget.canEditLocations)
            IconButton(
              onPressed: openEditLocation,
              icon: const Icon(Icons.edit),
              tooltip: 'Editar localizacao',
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (errorMessage != null) {
            return Center(child: Text(errorMessage!));
          }

          return RefreshIndicator(
            onRefresh: fetchAssets,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _LocationAvatar(
                          photoUrl: locationPhotoUrl,
                          radius: 28,
                          iconSize: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.location['name']?.toString() ??
                                'Localizacao',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
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
                          'Ordens por concluir',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (pendingWorkOrders.isEmpty)
                          const Text(
                            'Nao existem ordens por concluir nesta localizacao.',
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Ativo')),
                                DataColumn(label: Text('Ordem')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Atualizada')),
                              ],
                              rows: pendingWorkOrders.map((workOrder) {
                                final status =
                                    workOrder['status']?.toString() ?? '-';
                                final color = taskStatusColor(status);

                                return DataRow(
                                  onSelectChanged: (_) =>
                                      openWorkOrderDetail(workOrder),
                                  cells: [
                                    DataCell(
                                      Text(
                                        workOrder['asset_name']?.toString() ??
                                            '-',
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 220,
                                        child: Text(
                                          workOrderTitle(workOrder),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Chip(
                                        label: Text(status),
                                        visualDensity: VisualDensity.compact,
                                        side: BorderSide.none,
                                        backgroundColor: color.withOpacity(
                                          0.12,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        formatDateValue(
                                          workOrderUpdatedAt(workOrder) ??
                                              workOrder['created_at'],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${assets.length} ativos nesta localizacao',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (assets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Sem ativos nesta localizacao')),
                  )
                else
                  ...assets.map((asset) {
                    final status = asset['status']?.toString() ?? '';
                    final color = assetStatusColor(status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.12),
                          child: Icon(
                            Icons.precision_manufacturing,
                            color: color,
                          ),
                        ),
                        title: Text(asset['name']?.toString() ?? ''),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  status.isEmpty ? 'Sem estado' : status,
                                ),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                                backgroundColor: color.withOpacity(0.12),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
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
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AddLocationPage extends StatefulWidget {
  const AddLocationPage({super.key, this.location});

  final Map<String, dynamic>? location;

  bool get isEditing => location != null;

  @override
  State<AddLocationPage> createState() => _AddLocationPageState();
}

class _AddLocationPageState extends State<AddLocationPage> {
  final supabase = Supabase.instance.client;
  final nameController = TextEditingController();
  String? locationPhotoUrl;
  final Set<String> _locationPhotosToDeleteOnSave = <String>{};
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final existingLocation = widget.location;
    if (existingLocation != null) {
      nameController.text = existingLocation['name']?.toString() ?? '';
      locationPhotoUrl = existingLocation['photo_url']?.toString();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final payload = {
      'name': nameController.text.trim(),
      'photo_url': locationPhotoUrl,
    };

    if ((payload['name'] as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome da localizacao e obrigatorio.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    if (widget.isEditing) {
      await _updateLocation(payload);
    } else {
      await _createLocation(payload);
    }
    await _cleanupLocationPhotosAfterSave(
      finalPhotoValue: locationPhotoUrl,
      pendingDeletes: List<String>.from(_locationPhotosToDeleteOnSave),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _createLocation(Map<String, dynamic> payload) async {
    final scopedPayload = await CompanyScopeService.instance
        .attachCurrentCompanyId(table: 'locations', payload: payload);
    await supabase.from('locations').insert(scopedPayload);
  }

  Future<void> _updateLocation(Map<String, dynamic> payload) async {
    final locationId = widget.location!['id'];
    await supabase.from('locations').update(payload).eq('id', locationId);
  }

  Future<void> uploadLocationPhoto() async {
    try {
      final previousPhoto = locationPhotoUrl;
      final url = await StorageService.instance.pickAndUploadLocationPhoto();
      if (!mounted || url == null) return;

      _queueLocationPhotoDeletion(previousPhoto);
      setState(() {
        locationPhotoUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografia da localizacao carregada com sucesso.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nao foi possivel carregar a fotografia da localizacao: $e',
          ),
        ),
      );
    }
  }

  void removeLocationPhoto() {
    final currentPhoto = locationPhotoUrl?.trim();
    if (currentPhoto == null || currentPhoto.isEmpty) return;

    _queueLocationPhotoDeletion(currentPhoto);
    setState(() {
      locationPhotoUrl = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Fotografia removida do rascunho. Guarda para confirmar.'
              : 'Fotografia removida da nova localizacao.',
        ),
      ),
    );
  }

  void _queueLocationPhotoDeletion(String? storedValue) {
    final value = storedValue?.trim();
    if (value == null || value.isEmpty) return;
    _locationPhotosToDeleteOnSave.add(value);
  }

  Future<void> _cleanupLocationPhotosAfterSave({
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
      _locationPhotosToDeleteOnSave.clear();
      return;
    }

    try {
      await StorageService.instance.deleteStoredObjects(
        bucket: 'location-photos',
        storedValues: deletions,
      );
      _locationPhotosToDeleteOnSave.removeAll(deletions);
    } catch (_) {
      // Keep the location save successful even if storage cleanup fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Editar Localizacao' : 'Nova Localizacao',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _LocationAvatar(
                    photoUrl: locationPhotoUrl,
                    radius: 40,
                    iconSize: 34,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : uploadLocationPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      locationPhotoUrl?.isNotEmpty == true
                          ? 'Substituir foto da localizacao'
                          : 'Carregar foto da localizacao',
                    ),
                  ),
                  if (locationPhotoUrl?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isSaving ? null : removeLocationPhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remover foto da localizacao'),
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
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
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
            label: Text(
              widget.isEditing
                  ? 'Atualizar localizacao'
                  : 'Guardar localizacao',
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationAvatar extends StatelessWidget {
  const _LocationAvatar({
    required this.photoUrl,
    this.radius = 24,
    this.iconSize = 24,
  });

  final String? photoUrl;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl?.isNotEmpty == true;

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.teal.withOpacity(0.12),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      onBackgroundImageError: hasPhoto ? (_, __) {} : null,
      child: hasPhoto
          ? null
          : Icon(Icons.place, color: Colors.teal, size: iconSize),
    );
  }
}
