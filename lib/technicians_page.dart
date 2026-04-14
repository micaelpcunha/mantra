import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/company_scope_service.dart';
import 'services/managed_account_service.dart';
import 'services/storage_service.dart';

class TechniciansPage extends StatefulWidget {
  const TechniciansPage({super.key});

  @override
  State<TechniciansPage> createState() => _TechniciansPageState();
}

class _TechniciansPageState extends State<TechniciansPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> technicians = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchTechnicians();
  }

  Future<void> fetchTechnicians() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await supabase.from('technicians').select().order('name');

      if (!mounted) return;

      setState(() {
        technicians = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar os tecnicos.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> openTechnician(Map<String, dynamic> technician) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TechnicianDetailPage(technician: technician),
      ),
    );
    if (changed == true) {
      await fetchTechnicians();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tecnicos')),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (errorMessage != null) {
            return Center(child: Text(errorMessage!));
          }

          if (technicians.isEmpty) {
            return const Center(child: Text('Sem tecnicos'));
          }

          return RefreshIndicator(
            onRefresh: fetchTechnicians,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Tecnicos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${technicians.length} registados',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ...technicians.map((technician) {
                  final email = technician['email']?.toString() ?? '';
                  final contact = technician['contact']?.toString() ?? '';
                  final address = technician['address']?.toString() ?? '';
                  final photoUrl =
                      technician['profile_photo_url']?.toString() ?? '';
                  final hasDocument =
                      (technician['document_url']?.toString() ?? '').isNotEmpty;
                  final canAccessAssets =
                      technician['can_access_assets'] != false;
                  final canAccessLocations =
                      technician['can_access_locations'] != false;
                  final canAccessWorkOrders =
                      technician['can_access_work_orders'] != false;
                  final canCreateWorkOrders =
                      technician['can_create_work_orders'] == true;
                  final canViewAllWorkOrders =
                      technician['can_view_all_work_orders'] == true;
                  final canEditAssetDevices =
                      technician['can_edit_asset_devices'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey.withOpacity(0.12),
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? const Icon(Icons.build, color: Colors.blueGrey)
                            : null,
                      ),
                      title: Text(technician['name']?.toString() ?? 'Sem nome'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (contact.isNotEmpty)
                                  Chip(
                                    label: Text(contact),
                                    avatar: const Icon(Icons.phone, size: 18),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                  ),
                                if (email.isNotEmpty)
                                  Chip(
                                    label: Text(email),
                                    avatar: const Icon(
                                      Icons.mail_outline,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                  ),
                                if (hasDocument)
                                  const Chip(
                                    label: Text('Documento'),
                                    avatar: Icon(Icons.attach_file, size: 18),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (canCreateWorkOrders)
                                  const Chip(
                                    label: Text('Pode criar ordens'),
                                    avatar: Icon(Icons.add_task, size: 18),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (canViewAllWorkOrders)
                                  const Chip(
                                    label: Text('Ve todas as ordens'),
                                    avatar: Icon(Icons.visibility, size: 18),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (canEditAssetDevices)
                                  const Chip(
                                    label: Text('Edita dispositivos'),
                                    avatar: Icon(
                                      Icons.memory_outlined,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (canAccessAssets)
                                  const Chip(
                                    label: Text('Ativos'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (canAccessLocations)
                                  const Chip(
                                    label: Text('Localizacoes'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (canAccessWorkOrders)
                                  const Chip(
                                    label: Text('Ordens'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if (address.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openTechnician(technician),
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

class TechnicianDetailPage extends StatefulWidget {
  const TechnicianDetailPage({super.key, required this.technician});

  final Map<String, dynamic> technician;

  @override
  State<TechnicianDetailPage> createState() => _TechnicianDetailPageState();
}

class _TechnicianDetailPageState extends State<TechnicianDetailPage> {
  final supabase = Supabase.instance.client;
  late Map<String, dynamic> technician;
  Map<String, dynamic>? linkedProfile;
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    technician = Map<String, dynamic>.from(widget.technician);
    refreshTechnician();
  }

  Future<void> refreshTechnician() async {
    final results = await Future.wait([
      supabase
          .from('technicians')
          .select()
          .eq('id', technician['id'])
          .maybeSingle(),
      supabase
          .from('profiles')
          .select('id, email, full_name, role, technician_id')
          .eq('technician_id', technician['id'])
          .maybeSingle(),
    ]);

    final data = results[0];
    final profile = results[1];
    if (!mounted || data == null) return;

    setState(() {
      technician = Map<String, dynamic>.from(data as Map);
      linkedProfile = profile == null
          ? null
          : Map<String, dynamic>.from(profile as Map);
    });
  }

  Future<void> _cleanupTechnicianFiles({
    String? profilePhotoStoredValue,
    String? documentStoredValue,
  }) async {
    await StorageService.instance.deleteStoredObject(
      bucket: 'technician-profile-photos',
      storedValue: profilePhotoStoredValue,
    );
    await StorageService.instance.deleteStoredObject(
      bucket: 'technician-documents',
      storedValue: documentStoredValue,
    );
  }

  Future<void> openEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTechnicianPage(technician: technician),
      ),
    );

    if (changed == true) {
      await refreshTechnician();
    }
  }

  String _countLabel(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  List<String> _buildDeleteWarningLines(TechnicianDeleteImpact impact) {
    final lines = <String>[
      impact.removesLinkedAccess
          ? 'A ficha tecnica e o acesso associado serao removidos.'
          : 'A ficha tecnica sera removida.',
    ];

    if (impact.workOrderCount > 0) {
      lines.add(
        '${_countLabel(impact.workOrderCount, 'ordem vai', 'ordens vao')} ficar sem tecnico atribuido.',
      );
    }

    if (impact.defaultAssetCount > 0) {
      lines.add(
        '${_countLabel(impact.defaultAssetCount, 'ativo vai', 'ativos vao')} ficar sem tecnico predefinido.',
      );
    }

    if (impact.plannedDayAssetCount > 0) {
      lines.add(
        '${_countLabel(impact.plannedDayAssetCount, 'planeamento diario sera', 'planeamentos diarios serao')} removido${impact.plannedDayAssetCount == 1 ? '' : 's'}.',
      );
    }

    if (!impact.hasImpact) {
      lines.add(
        'Nao existem ordens, ativos predefinidos nem planeamentos para limpar.',
      );
    }

    lines.add('Queres continuar?');
    return lines;
  }

  String _buildDeleteSuccessMessage(TechnicianDeleteImpact impact) {
    final parts = <String>[];

    if (impact.workOrderCount > 0) {
      parts.add(
        '${_countLabel(impact.workOrderCount, 'ordem ficou', 'ordens ficaram')} sem tecnico atribuido',
      );
    }

    if (impact.defaultAssetCount > 0) {
      parts.add(
        '${_countLabel(impact.defaultAssetCount, 'ativo ficou', 'ativos ficaram')} sem tecnico predefinido',
      );
    }

    if (impact.plannedDayAssetCount > 0) {
      parts.add(
        '${_countLabel(impact.plannedDayAssetCount, 'planeamento diario foi removido', 'planeamentos diarios foram removidos')}',
      );
    }

    if (parts.isEmpty) {
      return 'Tecnico eliminado com sucesso.';
    }

    return 'Tecnico eliminado. ${parts.join(', ')}.';
  }

  Future<void> deleteTechnician() async {
    final technicianId = technician['id']?.toString().trim() ?? '';
    if (technicianId.isEmpty) return;

    setState(() {
      isDeleting = true;
    });

    TechnicianDeleteImpact deleteImpact;
    try {
      deleteImpact = await ManagedAccountService.instance
          .previewTechnicianDeleteImpact(technicianId: technicianId);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        isDeleting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel preparar a eliminacao do tecnico.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar tecnico'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildDeleteWarningLines(deleteImpact)
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(line),
                  ),
                )
                .toList(),
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

    if (confirmed != true) {
      if (!mounted) return;
      setState(() {
        isDeleting = false;
      });
      return;
    }

    try {
      final profilePhotoStoredValue = technician['profile_photo_url']
          ?.toString();
      final documentStoredValue = technician['document_url']?.toString();
      String? cleanupWarning;

      final deleteResult = await ManagedAccountService.instance
          .deleteTechnicianBundle(technicianId: technicianId);
      try {
        await _cleanupTechnicianFiles(
          profilePhotoStoredValue: profilePhotoStoredValue,
          documentStoredValue: documentStoredValue,
        );
      } catch (_) {
        cleanupWarning =
            'O tecnico foi eliminado, mas alguns ficheiros associados ficaram por remover.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_buildDeleteSuccessMessage(deleteResult))),
      );
      if (cleanupWarning != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanupWarning)));
      }
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel eliminar o tecnico.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isDeleting = false;
      });
    }
  }

  Future<void> openUrl(String value) async {
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openTechnicianDocument(String value) async {
    final uri = await StorageService.instance.resolveFileUri(
      bucket: 'technician-documents',
      storedValue: value,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  @override
  Widget build(BuildContext context) {
    final photoUrl = technician['profile_photo_url']?.toString() ?? '';
    final documentUrl = technician['document_url']?.toString() ?? '';
    final contact = technician['contact']?.toString() ?? '';
    final address = technician['address']?.toString() ?? '';
    final canAccessAssets = technician['can_access_assets'] != false;
    final canAccessLocations = technician['can_access_locations'] != false;
    final canAccessWorkOrders = technician['can_access_work_orders'] != false;
    final canCreateWorkOrders = technician['can_create_work_orders'] == true;
    final canViewAllWorkOrders = technician['can_view_all_work_orders'] == true;
    final canEditAssetDevices = technician['can_edit_asset_devices'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(technician['name']?.toString() ?? 'Tecnico'),
        actions: [
          IconButton(
            onPressed: openEdit,
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
          ),
          IconButton(
            onPressed: isDeleting ? null : deleteTechnician,
            icon: isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.blueGrey.withOpacity(0.12),
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? const Icon(
                            Icons.build,
                            size: 36,
                            color: Colors.blueGrey,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    technician['name']?.toString() ?? 'Sem nome',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          infoTile(
            icon: Icons.phone_outlined,
            label: 'Contacto',
            value: contact,
          ),
          infoTile(
            icon: Icons.mail_outline,
            label: 'Email',
            value: technician['email']?.toString() ?? '',
          ),
          infoTile(icon: Icons.home_outlined, label: 'Morada', value: address),
          infoTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Permissoes',
            value: [
              if (canAccessAssets) 'Ativos',
              if (canAccessLocations) 'Localizacoes',
              if (canAccessWorkOrders) 'Ordens',
              if (canCreateWorkOrders) 'Criar ordens',
              if (canViewAllWorkOrders) 'Ver todas as ordens',
              if (canEditAssetDevices) 'Editar dispositivos',
            ].join(' | '),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Documento do perfil'),
              subtitle: Text(
                documentUrl.isEmpty ? 'Sem documento' : documentUrl,
              ),
              trailing: documentUrl.isEmpty
                  ? null
                  : const Icon(Icons.open_in_new),
              onTap: documentUrl.isEmpty
                  ? null
                  : () => openTechnicianDocument(documentUrl),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Acesso a aplicacao'),
              subtitle: Text(
                linkedProfile == null
                    ? 'Sem acesso associado'
                    : linkedProfile?['email']?.toString() ?? 'Acesso associado',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddTechnicianPage extends StatefulWidget {
  const AddTechnicianPage({super.key, this.technician});

  final Map<String, dynamic>? technician;

  @override
  State<AddTechnicianPage> createState() => _AddTechnicianPageState();
}

class _AddTechnicianPageState extends State<AddTechnicianPage> {
  final supabase = Supabase.instance.client;
  final idController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();
  bool isSaving = false;
  String? profilePhotoUrl;
  String? documentUrl;
  late final String? initialProfilePhotoUrl;
  late final String? initialDocumentUrl;
  bool createLoginAccess = true;
  bool obscurePassword = true;
  bool canAccessAssets = true;
  bool canAccessLocations = true;
  bool canAccessWorkOrders = true;
  bool canCreateWorkOrders = false;
  bool canViewAllWorkOrders = false;
  bool canCloseWorkOrders = true;
  bool canEditWorkOrders = false;
  bool canEditAssets = false;
  bool canEditAssetDevices = false;
  bool canEditLocations = false;
  bool canViewAlerts = false;
  bool canManageTechnicians = false;
  bool canManageUsers = false;

  bool get isEditing => widget.technician != null;

  @override
  void initState() {
    super.initState();
    idController.text = widget.technician?['id']?.toString() ?? '';
    nameController.text = widget.technician?['name']?.toString() ?? '';
    emailController.text = widget.technician?['email']?.toString() ?? '';
    contactController.text = widget.technician?['contact']?.toString() ?? '';
    addressController.text = widget.technician?['address']?.toString() ?? '';
    profilePhotoUrl = widget.technician?['profile_photo_url']?.toString();
    documentUrl = widget.technician?['document_url']?.toString();
    initialProfilePhotoUrl = profilePhotoUrl;
    initialDocumentUrl = documentUrl;
    canAccessAssets = widget.technician?['can_access_assets'] != false;
    canAccessLocations = widget.technician?['can_access_locations'] != false;
    canAccessWorkOrders = widget.technician?['can_access_work_orders'] != false;
    canCreateWorkOrders = widget.technician?['can_create_work_orders'] == true;
    canViewAllWorkOrders =
        widget.technician?['can_view_all_work_orders'] == true;
    canCloseWorkOrders = widget.technician?['can_close_work_orders'] != false;
    canEditWorkOrders = widget.technician?['can_edit_work_orders'] == true;
    canEditAssets = widget.technician?['can_edit_assets'] == true;
    canEditAssetDevices = widget.technician?['can_edit_asset_devices'] == true;
    canEditLocations = widget.technician?['can_edit_locations'] == true;
    canViewAlerts = widget.technician?['can_view_alerts'] == true;
    canManageTechnicians = widget.technician?['can_manage_technicians'] == true;
    canManageUsers = widget.technician?['can_manage_users'] == true;
    createLoginAccess = !isEditing;
  }

  @override
  void dispose() {
    idController.dispose();
    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    addressController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> uploadProfilePhoto() async {
    try {
      final url = await StorageService.instance
          .pickAndUploadTechnicianProfilePhoto();
      if (!mounted || url == null) return;
      setState(() {
        profilePhotoUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografia de perfil carregada com sucesso.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao carregar a fotografia de perfil: $e')),
      );
    }
  }

  Future<void> uploadDocument() async {
    try {
      final url = await StorageService.instance
          .pickAndUploadTechnicianDocument();
      if (!mounted || url == null) return;
      setState(() {
        documentUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento carregado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao carregar o documento: $e')),
      );
    }
  }

  Future<void> openDocument() async {
    if (documentUrl == null || documentUrl!.isEmpty) return;
    final uri = await StorageService.instance.resolveFileUri(
      bucket: 'technician-documents',
      storedValue: documentUrl!,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _normalizedStoredValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _cleanupTechnicianFiles({
    String? profilePhotoStoredValue,
    String? documentStoredValue,
  }) async {
    await StorageService.instance.deleteStoredObject(
      bucket: 'technician-profile-photos',
      storedValue: profilePhotoStoredValue,
    );
    await StorageService.instance.deleteStoredObject(
      bucket: 'technician-documents',
      storedValue: documentStoredValue,
    );
  }

  Future<void> _cleanupPendingUploads() async {
    final currentProfilePhoto = _normalizedStoredValue(profilePhotoUrl);
    final currentDocument = _normalizedStoredValue(documentUrl);
    final initialProfilePhoto = _normalizedStoredValue(initialProfilePhotoUrl);
    final initialDocument = _normalizedStoredValue(initialDocumentUrl);

    await _cleanupTechnicianFiles(
      profilePhotoStoredValue: currentProfilePhoto != initialProfilePhoto
          ? currentProfilePhoto
          : null,
      documentStoredValue: currentDocument != initialDocument
          ? currentDocument
          : null,
    );
  }

  Future<void> _cleanupSupersededStoredFiles() async {
    final currentProfilePhoto = _normalizedStoredValue(profilePhotoUrl);
    final currentDocument = _normalizedStoredValue(documentUrl);
    final initialProfilePhoto = _normalizedStoredValue(initialProfilePhotoUrl);
    final initialDocument = _normalizedStoredValue(initialDocumentUrl);

    await _cleanupTechnicianFiles(
      profilePhotoStoredValue: initialProfilePhoto != currentProfilePhoto
          ? initialProfilePhoto
          : null,
      documentStoredValue: initialDocument != currentDocument
          ? initialDocument
          : null,
    );
  }

  Future<void> save() async {
    final id = idController.text.trim();
    final name = nameController.text.trim();
    final normalizedEmail = emailController.text.trim().toLowerCase();
    String? createdTechnicianId;
    String? createdUserId;
    String? cleanupWarning;

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('O nome e obrigatorio.')));
      return;
    }

    if (!isEditing && createLoginAccess) {
      if (normalizedEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indica o email do tecnico para criar o acesso.'),
          ),
        );
        return;
      }

      if (passwordController.text.trim().length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Define uma password com pelo menos 8 caracteres.'),
          ),
        );
        return;
      }
    }

    final payload = {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'email': normalizedEmail.isEmpty ? null : normalizedEmail,
      'contact': contactController.text.trim().isEmpty
          ? null
          : contactController.text.trim(),
      'address': addressController.text.trim().isEmpty
          ? null
          : addressController.text.trim(),
      'profile_photo_url': profilePhotoUrl,
      'document_url': documentUrl,
      'can_access_assets': canAccessAssets,
      'can_access_locations': canAccessLocations,
      'can_access_work_orders': canAccessWorkOrders,
      'can_create_work_orders': canCreateWorkOrders,
      'can_view_all_work_orders': canViewAllWorkOrders,
      'can_close_work_orders': canCloseWorkOrders,
      'can_edit_work_orders': canEditWorkOrders,
      'can_edit_assets': canEditAssets,
      'can_edit_asset_devices': canEditAssetDevices,
      'can_edit_locations': canEditLocations,
      'can_view_alerts': canViewAlerts,
      'can_manage_technicians': canManageTechnicians,
      'can_manage_users': canManageUsers,
    };

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditing) {
        await _updateTechnician(payload);
      } else {
        final createdTechnicianIdValue = await _createTechnician(payload);
        createdTechnicianId = createdTechnicianIdValue;

        if (createLoginAccess) {
          final createdUserIdValue = await ManagedAccountService.instance
              .createAuthUser(
                email: normalizedEmail,
                password: passwordController.text.trim(),
                role: 'technician',
                fullName: name,
                technicianId: createdTechnicianIdValue,
              );
          createdUserId = createdUserIdValue;

          await _upsertTechnicianProfile(
            userId: createdUserIdValue,
            technicianId: createdTechnicianIdValue,
            email: normalizedEmail,
            fullName: name,
          );
        }
      }

      try {
        await _cleanupSupersededStoredFiles();
      } catch (_) {
        cleanupWarning =
            'O tecnico foi guardado, mas alguns ficheiros antigos ficaram por remover.';
      }

      if (!mounted) return;
      if (cleanupWarning != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanupWarning)));
      }
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      await _rollbackCreate(
        createdUserId: createdUserId,
        createdTechnicianId: createdTechnicianId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      await _rollbackCreate(
        createdUserId: createdUserId,
        createdTechnicianId: createdTechnicianId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel guardar o tecnico.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _rollbackCreate({
    String? createdUserId,
    String? createdTechnicianId,
  }) async {
    if (createdUserId != null) {
      try {
        await ManagedAccountService.instance.deleteAuthUser(
          userId: createdUserId,
        );
      } catch (_) {
        // Keep the original save error visible.
      }
    }

    if (createdTechnicianId != null) {
      try {
        await supabase
            .from('technicians')
            .delete()
            .eq('id', createdTechnicianId);
      } catch (_) {
        // Keep the original save error visible.
      }
    }

    try {
      await _cleanupPendingUploads();
    } catch (_) {
      // Keep the original save error visible.
    }
  }

  Future<void> _upsertTechnicianProfile({
    required String userId,
    required String technicianId,
    required String email,
    required String fullName,
  }) async {
    final scopedPayload = await CompanyScopeService.instance
        .attachCurrentCompanyId(
          table: 'profiles',
          payload: {
            'id': userId,
            'email': email,
            'full_name': fullName,
            'role': 'technician',
            'technician_id': technicianId,
            'can_access_assets': canAccessAssets,
            'can_access_locations': canAccessLocations,
            'can_access_work_orders': canAccessWorkOrders,
            'can_create_work_orders': canCreateWorkOrders,
            'can_view_all_work_orders': canViewAllWorkOrders,
            'can_close_work_orders': canCloseWorkOrders,
            'can_edit_work_orders': canEditWorkOrders,
            'can_edit_assets': canEditAssets,
            'can_edit_asset_devices': canEditAssetDevices,
            'can_edit_locations': canEditLocations,
            'can_view_alerts': canViewAlerts,
            'can_manage_technicians': canManageTechnicians,
            'can_manage_users': canManageUsers,
            'can_client_view_description': true,
            'can_client_view_comments': true,
            'can_client_view_photos': true,
            'can_client_view_attachments': true,
            'can_client_view_scheduling': true,
            'can_client_view_technician': true,
            'can_client_view_location': true,
            'client_asset_ids': <String>[],
            'client_location_ids': <String>[],
          },
        );

    await supabase.from('profiles').upsert(scopedPayload);
  }

  Future<String> _createTechnician(Map<String, dynamic> payload) async {
    final scopedPayload = await CompanyScopeService.instance
        .attachCurrentCompanyId(table: 'technicians', payload: payload);
    final inserted = await supabase
        .from('technicians')
        .insert(scopedPayload)
        .select('id')
        .single();
    final technicianId = inserted['id']?.toString().trim() ?? '';
    if (technicianId.isEmpty) {
      throw StateError('Nao foi recebido o ID do tecnico criado.');
    }
    return technicianId;
  }

  Future<void> _updateTechnician(Map<String, dynamic> payload) async {
    await supabase
        .from('technicians')
        .update({
          'name': payload['name'],
          'email': payload['email'],
          'contact': payload['contact'],
          'address': payload['address'],
          'profile_photo_url': payload['profile_photo_url'],
          'document_url': payload['document_url'],
          'can_access_assets': payload['can_access_assets'],
          'can_access_locations': payload['can_access_locations'],
          'can_access_work_orders': payload['can_access_work_orders'],
          'can_create_work_orders': payload['can_create_work_orders'],
          'can_view_all_work_orders': payload['can_view_all_work_orders'],
          'can_close_work_orders': payload['can_close_work_orders'],
          'can_edit_work_orders': payload['can_edit_work_orders'],
          'can_edit_assets': payload['can_edit_assets'],
          'can_edit_asset_devices': payload['can_edit_asset_devices'],
          'can_edit_locations': payload['can_edit_locations'],
          'can_view_alerts': payload['can_view_alerts'],
          'can_manage_technicians': payload['can_manage_technicians'],
          'can_manage_users': payload['can_manage_users'],
        })
        .eq('id', widget.technician!['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tecnico' : 'Novo Tecnico'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blueGrey.withOpacity(0.12),
                    backgroundImage: profilePhotoUrl?.isNotEmpty == true
                        ? NetworkImage(profilePhotoUrl!)
                        : null,
                    child: profilePhotoUrl?.isNotEmpty == true
                        ? null
                        : const Icon(
                            Icons.build,
                            size: 36,
                            color: Colors.blueGrey,
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : uploadProfilePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      profilePhotoUrl?.isNotEmpty == true
                          ? 'Substituir fotografia'
                          : 'Carregar fotografia de perfil',
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
                children: [
                  if (isEditing) ...[
                    TextField(
                      controller: idController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'ID tecnico',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD7DFD7)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'O ID tecnico sera gerado automaticamente ao guardar.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Contacto'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Morada'),
                  ),
                  const SizedBox(height: 12),
                  if (!isEditing) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Criar acesso a aplicacao'),
                      subtitle: const Text(
                        'Se ativares, o tecnico fica pronto a entrar na app assim que guardares.',
                      ),
                      value: createLoginAccess,
                      onChanged: (value) {
                        setState(() {
                          createLoginAccess = value;
                        });
                      },
                    ),
                    if (createLoginAccess) ...[
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password temporaria',
                          helperText: 'O email acima sera usado como login.',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F8F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD7DFD7)),
                        ),
                        child: const Text(
                          'Podes criar o acesso mais tarde na area Utilizadores.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD7DFD7)),
                      ),
                      child: const Text(
                        'Para gerir o acesso deste tecnico, usa Utilizadores ou elimina o tecnico na ficha de detalhe.',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Acesso a ativos'),
                    value: canAccessAssets,
                    onChanged: (value) {
                      setState(() {
                        canAccessAssets = value;
                        if (!canAccessAssets) {
                          canEditAssets = false;
                          canEditAssetDevices = false;
                        }
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Acesso a localizacoes'),
                    value: canAccessLocations,
                    onChanged: (value) {
                      setState(() {
                        canAccessLocations = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Acesso a ordens de trabalho'),
                    value: canAccessWorkOrders,
                    onChanged: (value) {
                      setState(() {
                        canAccessWorkOrders = value;
                        if (!canAccessWorkOrders) {
                          canCreateWorkOrders = false;
                          canViewAllWorkOrders = false;
                        }
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode criar ordens de trabalho'),
                    subtitle: const Text(
                      'Permite a este tecnico abrir novas ordens',
                    ),
                    value: canCreateWorkOrders,
                    onChanged: canAccessWorkOrders
                        ? (value) {
                            setState(() {
                              canCreateWorkOrders = value;
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode ver todas as ordens'),
                    subtitle: const Text(
                      'Se desligado, ve apenas as ordens atribuidas',
                    ),
                    value: canViewAllWorkOrders,
                    onChanged: canAccessWorkOrders
                        ? (value) {
                            setState(() {
                              canViewAllWorkOrders = value;
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode fechar ordens'),
                    subtitle: const Text(
                      'Permite marcar ordens como concluidas',
                    ),
                    value: canCloseWorkOrders,
                    onChanged: canAccessWorkOrders
                        ? (value) {
                            setState(() {
                              canCloseWorkOrders = value;
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode editar ordens completas'),
                    subtitle: const Text(
                      'Permite editar os campos completos da ordem',
                    ),
                    value: canEditWorkOrders,
                    onChanged: canAccessWorkOrders
                        ? (value) {
                            setState(() {
                              canEditWorkOrders = value;
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode editar ativos'),
                    value: canEditAssets,
                    onChanged: canAccessAssets
                        ? (value) {
                            setState(() {
                              canEditAssets = value;
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode criar e editar dispositivos'),
                    subtitle: const Text(
                      'Permite gerir dispositivos dentro dos ativos, incluindo QR e documentacao.',
                    ),
                    value: canEditAssetDevices,
                    onChanged: canAccessAssets
                        ? (value) {
                            setState(() {
                              canEditAssetDevices = value;
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode editar localizacoes'),
                    value: canEditLocations,
                    onChanged: canAccessLocations
                        ? (value) {
                            setState(() {
                              canEditLocations = value;
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode ver alertas'),
                    value: canViewAlerts,
                    onChanged: (value) {
                      setState(() {
                        canViewAlerts = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode gerir tecnicos'),
                    value: canManageTechnicians,
                    onChanged: (value) {
                      setState(() {
                        canManageTechnicians = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pode gerir utilizadores'),
                    value: canManageUsers,
                    onChanged: (value) {
                      setState(() {
                        canManageUsers = value;
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
                    'Documento do perfil',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : uploadDocument,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      documentUrl?.isNotEmpty == true
                          ? 'Substituir documento'
                          : 'Carregar documento',
                    ),
                  ),
                  if (documentUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      documentUrl!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: openDocument,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir'),
                        ),
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () {
                                  setState(() {
                                    documentUrl = null;
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
            label: Text(isEditing ? 'Atualizar tecnico' : 'Guardar tecnico'),
          ),
        ],
      ),
    );
  }
}
