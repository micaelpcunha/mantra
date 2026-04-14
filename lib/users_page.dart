import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/company_scope_service.dart';
import 'services/managed_account_service.dart';
import 'services/storage_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> profiles = [];
  Map<String, String> technicianNamesById = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase.from('profiles').select().order('email'),
        supabase.from('technicians').select('id, name').order('name'),
      ]);

      if (!mounted) return;

      final loadedProfiles = List<Map<String, dynamic>>.from(
        results[0] as List,
      );
      final loadedTechnicians = List<Map<String, dynamic>>.from(
        results[1] as List,
      );

      setState(() {
        profiles = loadedProfiles;
        technicianNamesById = {
          for (final technician in loadedTechnicians)
            technician['id']?.toString() ?? '':
                technician['name']?.toString() ?? '',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar os utilizadores.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> openUser(Map<String, dynamic> profile) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddUserPage(profile: profile)),
    );

    if (changed == true) {
      await fetchUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (profiles.isEmpty) {
      return const Center(child: Text('Sem utilizadores'));
    }

    return RefreshIndicator(
      onRefresh: fetchUsers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Utilizadores',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${profiles.length} registados',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...profiles.map((profile) {
            final role = profile['role']?.toString() ?? 'admin';
            final technicianId = profile['technician_id']?.toString() ?? '';
            final technicianName = technicianNamesById[technicianId] ?? '';
            final email = profile['email']?.toString() ?? '';
            final fullName = profile['full_name']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: role == 'admin'
                      ? Colors.indigo.withOpacity(0.12)
                      : role == 'client'
                      ? Colors.orange.withOpacity(0.12)
                      : Colors.teal.withOpacity(0.12),
                  child: Icon(
                    role == 'admin'
                        ? Icons.admin_panel_settings
                        : role == 'client'
                        ? Icons.business_center_outlined
                        : Icons.person_outline,
                    color: role == 'admin'
                        ? Colors.indigo
                        : role == 'client'
                        ? Colors.orange
                        : Colors.teal,
                  ),
                ),
                title: Text(fullName.isEmpty ? email : fullName),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty) Text(email),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              role == 'admin'
                                  ? 'Administrador'
                                  : role == 'client'
                                  ? 'Cliente'
                                  : 'Tecnico',
                            ),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                          ),
                          if (technicianName.isNotEmpty)
                            Chip(
                              label: Text(technicianName),
                              avatar: const Icon(Icons.build, size: 18),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide.none,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openUser(profile),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key, this.profile});

  final Map<String, dynamic>? profile;

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final supabase = Supabase.instance.client;
  final idController = TextEditingController();
  final emailController = TextEditingController();
  final fullNameController = TextEditingController();
  final passwordController = TextEditingController();

  List<Map<String, dynamic>> technicians = [];
  List<Map<String, dynamic>> assets = [];
  List<Map<String, dynamic>> locations = [];
  String role = 'admin';
  String? selectedTechnicianId;
  bool canAccessAssets = true;
  bool canAccessLocations = true;
  bool canAccessWorkOrders = true;
  bool canClientViewDescription = true;
  bool canClientViewComments = true;
  bool canClientViewPhotos = true;
  bool canClientViewAttachments = true;
  bool canClientViewScheduling = true;
  bool canClientViewTechnician = true;
  bool canClientViewLocation = true;
  final Set<String> selectedAssetIds = {};
  final Set<String> selectedLocationIds = {};
  bool isLoadingTechnicians = true;
  bool isSaving = false;
  bool isDeleting = false;
  bool isResolvingExistingProfile = false;
  bool obscurePassword = true;

  bool get isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    idController.text = widget.profile?['id']?.toString() ?? '';
    emailController.text = widget.profile?['email']?.toString() ?? '';
    fullNameController.text = widget.profile?['full_name']?.toString() ?? '';
    role = widget.profile?['role']?.toString() ?? 'admin';
    selectedTechnicianId = widget.profile?['technician_id']?.toString();
    canAccessAssets = widget.profile?['can_access_assets'] != false;
    canAccessLocations = widget.profile?['can_access_locations'] != false;
    canAccessWorkOrders = widget.profile?['can_access_work_orders'] != false;
    canClientViewDescription =
        widget.profile?['can_client_view_description'] != false;
    canClientViewComments =
        widget.profile?['can_client_view_comments'] != false;
    canClientViewPhotos = widget.profile?['can_client_view_photos'] != false;
    canClientViewAttachments =
        widget.profile?['can_client_view_attachments'] != false;
    canClientViewScheduling =
        widget.profile?['can_client_view_scheduling'] != false;
    canClientViewTechnician =
        widget.profile?['can_client_view_technician'] != false;
    canClientViewLocation =
        widget.profile?['can_client_view_location'] != false;
    selectedAssetIds.addAll(
      List<String>.from(
        (widget.profile?['client_asset_ids'] as List?) ?? const [],
      ),
    );
    selectedLocationIds.addAll(
      List<String>.from(
        (widget.profile?['client_location_ids'] as List?) ?? const [],
      ),
    );
    loadTechnicians();
  }

  @override
  void dispose() {
    idController.dispose();
    emailController.dispose();
    fullNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loadTechnicians() async {
    try {
      final results = await Future.wait([
        supabase.from('technicians').select('id, name').order('name'),
        supabase.from('assets').select('id, name, location_id').order('name'),
        supabase.from('locations').select('id, name').order('name'),
      ]);

      if (!mounted) return;
      setState(() {
        technicians = List<Map<String, dynamic>>.from(results[0] as List);
        assets = List<Map<String, dynamic>>.from(results[1] as List);
        locations = List<Map<String, dynamic>>.from(results[2] as List);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel carregar os tecnicos.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingTechnicians = false;
      });
    }
  }

  Future<void> save() async {
    final email = emailController.text.trim().toLowerCase();
    var id = idController.text.trim();
    String? createdUserId;

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('O email e obrigatorio.')));
      return;
    }

    if (role == 'technician' &&
        (selectedTechnicianId == null ||
            selectedTechnicianId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolhe o tecnico associado.')),
      );
      return;
    }

    if (id.isEmpty) {
      setState(() {
        isResolvingExistingProfile = true;
      });

      try {
        final existingProfile = await _findExistingProfileByEmail(email);
        id = existingProfile?['id']?.toString().trim() ?? '';

        if (id.isNotEmpty) {
          final resolvedFullName = existingProfile == null
              ? ''
              : existingProfile['full_name']?.toString() ?? '';
          idController.text = id;
          if (fullNameController.text.trim().isEmpty) {
            fullNameController.text = resolvedFullName;
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            isResolvingExistingProfile = false;
          });
        }
      }
    }

    if (!mounted) return;

    if (id.isEmpty) {
      final password = passwordController.text.trim();
      if (password.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Define uma password com pelo menos 8 caracteres.'),
          ),
        );
        return;
      }
    }

    final payload = {
      'id': id,
      'email': email,
      'role': role,
      'full_name': fullNameController.text.trim().isEmpty
          ? null
          : fullNameController.text.trim(),
      'technician_id': role == 'technician' ? selectedTechnicianId : null,
      'can_access_assets': role == 'client' ? canAccessAssets : true,
      'can_access_locations': role == 'client' ? canAccessLocations : true,
      'can_access_work_orders': role == 'client' ? canAccessWorkOrders : true,
      'can_client_view_description': role == 'client'
          ? canClientViewDescription
          : true,
      'can_client_view_comments': role == 'client'
          ? canClientViewComments
          : true,
      'can_client_view_photos': role == 'client' ? canClientViewPhotos : true,
      'can_client_view_attachments': role == 'client'
          ? canClientViewAttachments
          : true,
      'can_client_view_scheduling': role == 'client'
          ? canClientViewScheduling
          : true,
      'can_client_view_technician': role == 'client'
          ? canClientViewTechnician
          : true,
      'can_client_view_location': role == 'client'
          ? canClientViewLocation
          : true,
      'client_asset_ids': role == 'client'
          ? selectedAssetIds.toList()
          : <String>[],
      'client_location_ids': role == 'client'
          ? selectedLocationIds.toList()
          : <String>[],
    };

    setState(() {
      isSaving = true;
    });

    try {
      if (id.isEmpty) {
        final createdUserIdValue = await ManagedAccountService.instance
            .createAuthUser(
              email: email,
              password: passwordController.text.trim(),
              role: role,
              fullName: fullNameController.text.trim(),
              technicianId: role == 'technician' ? selectedTechnicianId : null,
            );
        createdUserId = createdUserIdValue;
        id = createdUserIdValue;
        idController.text = createdUserIdValue;
      }

      final scopedPayload = await CompanyScopeService.instance
          .attachCurrentCompanyId(
            table: 'profiles',
            payload: {...payload, 'id': id},
          );
      await supabase.from('profiles').upsert(scopedPayload);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (createdUserId != null) {
        await _rollbackCreatedUser(createdUserId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (createdUserId != null) {
        await _rollbackCreatedUser(createdUserId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel guardar o utilizador.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _findExistingProfileByEmail(
    String email,
  ) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) return null;

    final profile = await supabase
        .from('profiles')
        .select('id, email, full_name')
        .eq('email', normalizedEmail)
        .maybeSingle();

    if (profile == null) return null;
    return Map<String, dynamic>.from(profile);
  }

  Future<void> _rollbackCreatedUser(String userId) async {
    try {
      await ManagedAccountService.instance.deleteAuthUser(userId: userId);
    } catch (_) {
      // Keep the original save error visible; cleanup can be reviewed later.
    }
  }

  Future<Map<String, String?>> _loadTechnicianStoredFiles(
    String technicianId,
  ) async {
    final technician = await supabase
        .from('technicians')
        .select('profile_photo_url, document_url')
        .eq('id', technicianId)
        .maybeSingle();

    if (technician == null) {
      return const {'profile_photo_url': null, 'document_url': null};
    }

    final technicianData = Map<String, dynamic>.from(technician);
    return {
      'profile_photo_url': technicianData['profile_photo_url']?.toString(),
      'document_url': technicianData['document_url']?.toString(),
    };
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

  String _countLabel(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  List<String> _buildTechnicianDeleteWarningLines(
    TechnicianDeleteImpact impact,
  ) {
    final lines = <String>[
      'Este tecnico vai perder o acesso e a ficha tecnica tambem sera removida.',
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

  String _buildTechnicianDeleteSuccessMessage(TechnicianDeleteImpact impact) {
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
      return 'Utilizador e tecnico eliminados com sucesso.';
    }

    return 'Utilizador e tecnico eliminados. ${parts.join(', ')}.';
  }

  Future<void> deleteUser() async {
    final existingProfile = widget.profile;
    final userId = existingProfile?['id']?.toString().trim() ?? '';
    final targetRole = existingProfile?['role']?.toString().trim() ?? role;
    final targetTechnicianId =
        existingProfile?['technician_id']?.toString().trim() ??
        selectedTechnicianId?.trim() ??
        '';

    if (userId.isEmpty) {
      return;
    }

    if (userId == supabase.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao podes eliminar o teu proprio acesso.'),
        ),
      );
      return;
    }

    TechnicianDeleteImpact? technicianDeleteImpact;
    if (targetRole == 'technician' && targetTechnicianId.isNotEmpty) {
      setState(() {
        isDeleting = true;
      });

      try {
        technicianDeleteImpact = await ManagedAccountService.instance
            .previewTechnicianDeleteImpact(technicianId: targetTechnicianId);
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
            content: Text(
              'Nao foi possivel preparar a eliminacao do utilizador.',
            ),
          ),
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isTechnicianUser =
            targetRole == 'technician' && targetTechnicianId.isNotEmpty;

        return AlertDialog(
          title: const Text('Eliminar utilizador'),
          content: isTechnicianUser
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      _buildTechnicianDeleteWarningLines(
                            technicianDeleteImpact!,
                          )
                          .map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(line),
                            ),
                          )
                          .toList(),
                )
              : const Text(
                  'Este utilizador vai perder o acesso a aplicacao. Queres continuar?',
                ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowAlignment: OverflowBarAlignment.end,
          buttonPadding: EdgeInsets.zero,
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

    setState(() {
      isDeleting = true;
    });

    try {
      String? cleanupWarning;

      if (targetRole == 'technician' && targetTechnicianId.isNotEmpty) {
        final technicianStoredFiles = await _loadTechnicianStoredFiles(
          targetTechnicianId,
        );
        final deleteResult = await ManagedAccountService.instance
            .deleteTechnicianBundle(technicianId: targetTechnicianId);
        try {
          await _cleanupTechnicianFiles(
            profilePhotoStoredValue: technicianStoredFiles['profile_photo_url'],
            documentStoredValue: technicianStoredFiles['document_url'],
          );
        } catch (_) {
          cleanupWarning =
              'O utilizador foi eliminado, mas alguns ficheiros do tecnico ficaram por remover.';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_buildTechnicianDeleteSuccessMessage(deleteResult)),
          ),
        );
      } else {
        await ManagedAccountService.instance.deleteAuthUser(userId: userId);
      }

      if (!mounted) return;
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
        const SnackBar(
          content: Text('Nao foi possivel eliminar o utilizador.'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isDeleting = false;
      });
    }
  }

  Future<void> pickAssignments({
    required String title,
    required List<Map<String, dynamic>> items,
    required Set<String> selectedIds,
  }) async {
    final tempSelection = Set<String>.from(selectedIds);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: items.isEmpty
                    ? const Text('Sem registos disponiveis.')
                    : ListView(
                        shrinkWrap: true,
                        children: items.map((item) {
                          final id = item['id']?.toString() ?? '';
                          final name = item['name']?.toString() ?? 'Sem nome';
                          final checked = tempSelection.contains(id);

                          return CheckboxListTile(
                            value: checked,
                            title: Text(name),
                            onChanged: id.isEmpty
                                ? null
                                : (value) {
                                    setModalState(() {
                                      if (value == true) {
                                        tempSelection.add(id);
                                      } else {
                                        tempSelection.remove(id);
                                      }
                                    });
                                  },
                          );
                        }).toList(),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      selectedIds
        ..clear()
        ..addAll(tempSelection);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar utilizador' : 'Novo utilizador'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: isSaving || isDeleting ? null : deleteUser,
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
          if (!isEditing) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conta de acesso',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A app cria automaticamente o acesso quando guardares.',
                    ),
                    const Text(
                      'Se esse email ja existir, o perfil atual e reaproveitado.',
                    ),
                    const Text(
                      'Para tecnicos, usa este ecran para ligar o acesso a um tecnico ja existente.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
                        labelText: 'ID do utilizador',
                        hintText: 'UUID do auth.users',
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
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isResolvingExistingProfile
                                  ? 'A verificar se este email ja existe...'
                                  : 'Se o email ainda nao existir, o acesso sera criado automaticamente.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password temporaria',
                        helperText: 'Minimo de 8 caracteres.',
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
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Perfil'),
                    items: const [
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Administrador'),
                      ),
                      DropdownMenuItem(
                        value: 'technician',
                        child: Text('Tecnico'),
                      ),
                      DropdownMenuItem(value: 'client', child: Text('Cliente')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        role = value;
                        if (role != 'technician') {
                          selectedTechnicianId = null;
                        }
                        if (role != 'client') {
                          selectedAssetIds.clear();
                          selectedLocationIds.clear();
                        }
                      });
                    },
                  ),
                  if (role == 'technician') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: selectedTechnicianId,
                      decoration: const InputDecoration(
                        labelText: 'Tecnico associado',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sem tecnico associado'),
                        ),
                        ...technicians.map((technician) {
                          return DropdownMenuItem<String?>(
                            value: technician['id']?.toString(),
                            child: Text(technician['name']?.toString() ?? ''),
                          );
                        }),
                      ],
                      onChanged: isLoadingTechnicians
                          ? null
                          : (value) {
                              setState(() {
                                selectedTechnicianId = value;
                              });
                            },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (role == 'client') ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acesso do cliente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: canAccessWorkOrders,
                      onChanged: (value) =>
                          setState(() => canAccessWorkOrders = value),
                      title: const Text('Ver ordens de trabalho'),
                    ),
                    SwitchListTile(
                      value: canAccessAssets,
                      onChanged: (value) =>
                          setState(() => canAccessAssets = value),
                      title: const Text('Ver ativos'),
                    ),
                    SwitchListTile(
                      value: canAccessLocations,
                      onChanged: (value) =>
                          setState(() => canAccessLocations = value),
                      title: const Text('Ver localizacoes'),
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
                      'Campos visiveis ao cliente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: canClientViewDescription,
                      onChanged: (value) =>
                          setState(() => canClientViewDescription = value),
                      title: const Text('Ver descricao da ordem'),
                    ),
                    SwitchListTile(
                      value: canClientViewComments,
                      onChanged: (value) =>
                          setState(() => canClientViewComments = value),
                      title: const Text('Ver observacoes'),
                    ),
                    SwitchListTile(
                      value: canClientViewPhotos,
                      onChanged: (value) =>
                          setState(() => canClientViewPhotos = value),
                      title: const Text('Ver fotografias'),
                    ),
                    SwitchListTile(
                      value: canClientViewAttachments,
                      onChanged: (value) =>
                          setState(() => canClientViewAttachments = value),
                      title: const Text('Ver anexos'),
                    ),
                    SwitchListTile(
                      value: canClientViewScheduling,
                      onChanged: (value) =>
                          setState(() => canClientViewScheduling = value),
                      title: const Text('Ver planeamento'),
                    ),
                    SwitchListTile(
                      value: canClientViewTechnician,
                      onChanged: (value) =>
                          setState(() => canClientViewTechnician = value),
                      title: const Text('Ver tecnico'),
                    ),
                    SwitchListTile(
                      value: canClientViewLocation,
                      onChanged: (value) =>
                          setState(() => canClientViewLocation = value),
                      title: const Text('Ver localizacao'),
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
                      'Ambito de acesso',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se nao escolheres ativos nem localizacoes, o cliente fica sem filtro especifico.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => pickAssignments(
                            title: 'Ativos visiveis para o cliente',
                            items: assets,
                            selectedIds: selectedAssetIds,
                          ),
                          icon: const Icon(
                            Icons.precision_manufacturing_outlined,
                          ),
                          label: Text('Ativos (${selectedAssetIds.length})'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => pickAssignments(
                            title: 'Localizacoes visiveis para o cliente',
                            items: locations,
                            selectedIds: selectedLocationIds,
                          ),
                          icon: const Icon(Icons.place_outlined),
                          label: Text(
                            'Localizacoes (${selectedLocationIds.length})',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isSaving || isDeleting ? null : save,
            icon: isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              isEditing ? 'Atualizar utilizador' : 'Guardar utilizador',
            ),
          ),
        ],
      ),
    );
  }
}
