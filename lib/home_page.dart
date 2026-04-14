import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerts_page.dart';
import 'assets_pages.dart';
import 'calendar_page.dart';
import 'company_settings_page.dart';
import 'dashboard_page.dart';
import 'config/branding.dart';
import 'l10n/app_localizations.dart';
import 'locations_page.dart';
import 'main.dart';
import 'models/company_profile.dart';
import 'models/technician.dart';
import 'models/user_profile.dart';
import 'notes_page.dart';
import 'procedure_templates_page.dart';
import 'reports_page.dart';
import 'services/auth_service.dart';
import 'services/company_service.dart';
import 'services/profile_service.dart';
import 'services/storage_service.dart';
import 'services/technician_service.dart';
import 'services/work_order_offline_service.dart';
import 'settings_page.dart';
import 'technicians_page.dart';
import 'users_page.dart';
import 'work_orders/add_work_order_page.dart';
import 'work_orders/work_orders_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

const String _developerCreditText = 'created and developed by Micael Cunha';

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ScrollController _sideNavScrollController = ScrollController();
  final ScrollController _bottomNavScrollController = ScrollController();
  int currentIndex = 0;
  UserProfile? profile;
  CompanyProfile? companyProfile;
  String? companyLogoUrl;
  bool isLoadingProfile = true;
  AppRole? rolePreviewOverride;
  List<Technician> technicians = [];
  String? technicianPreviewOverrideId;
  int assetsPageVersion = 0;
  int locationsPageVersion = 0;
  int techniciansPageVersion = 0;
  int usersPageVersion = 0;
  int workOrdersPageVersion = 0;

  UserProfile get effectiveProfile => rolePreviewOverride == null
      ? profile!
      : profile!.copyWith(role: rolePreviewOverride);

  String? get effectiveTechnicianId =>
      technicianPreviewOverrideId ?? profile?.technicianId;

  bool get isPreviewingTechnician => rolePreviewOverride == AppRole.technician;

  Technician? get _effectiveTechnician =>
      technicians.cast<Technician?>().firstWhere(
        (technician) => technician?.id == effectiveTechnicianId,
        orElse: () => null,
      );

  bool get effectiveCanCreateWorkOrders {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canCreateWorkOrders ?? false;
    }
    return _effectiveTechnician?.canCreateWorkOrders == true ||
        profile?.canCreateWorkOrders == true;
  }

  bool get effectiveCanAccessAssets {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canAccessAssets ?? false;
    }
    return _effectiveTechnician?.canAccessAssets != false &&
        profile?.canAccessAssets != false;
  }

  bool get effectiveCanAccessLocations {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canAccessLocations ?? false;
    }
    return _effectiveTechnician?.canAccessLocations != false &&
        profile?.canAccessLocations != false;
  }

  bool get effectiveCanAccessWorkOrders {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canAccessWorkOrders ?? false;
    }
    return _effectiveTechnician?.canAccessWorkOrders != false &&
        profile?.canAccessWorkOrders != false;
  }

  bool get effectiveCanViewAllWorkOrders {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canViewAllWorkOrders ?? false;
    }
    return _effectiveTechnician?.canViewAllWorkOrders == true ||
        profile?.canViewAllWorkOrders == true;
  }

  bool get effectiveCanCloseWorkOrders {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canCloseWorkOrders ?? false;
    }
    return _effectiveTechnician?.canCloseWorkOrders != false &&
        profile?.canCloseWorkOrders != false;
  }

  bool get effectiveCanEditWorkOrders {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canEditWorkOrders ?? false;
    }
    return _effectiveTechnician?.canEditWorkOrders == true ||
        profile?.canEditWorkOrders == true;
  }

  bool get effectiveCanEditAssets {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canEditAssets ?? false;
    }
    return _effectiveTechnician?.canEditAssets == true ||
        profile?.canEditAssets == true;
  }

  bool get effectiveCanEditAssetDevices {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canEditAssetDevices ?? false;
    }
    return _effectiveTechnician?.canEditAssetDevices == true ||
        profile?.canEditAssetDevices == true;
  }

  bool get effectiveCanEditLocations {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canEditLocations ?? false;
    }
    return _effectiveTechnician?.canEditLocations == true ||
        profile?.canEditLocations == true;
  }

  bool get effectiveCanViewAlerts {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canViewAlerts ?? false;
    }
    return _effectiveTechnician?.canViewAlerts == true ||
        profile?.canViewAlerts == true;
  }

  bool get effectiveCanManageTechnicians {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canManageTechnicians ?? false;
    }
    return _effectiveTechnician?.canManageTechnicians == true ||
        profile?.canManageTechnicians == true;
  }

  bool get effectiveCanManageUsers {
    if (effectiveProfile.isAdmin) return true;
    if (isPreviewingTechnician) {
      return _effectiveTechnician?.canManageUsers ?? false;
    }
    return _effectiveTechnician?.canManageUsers == true ||
        profile?.canManageUsers == true;
  }

  bool get effectiveCanAccessSettings => true;

  bool get canUseRolePreview => profile?.isAdmin == true;

  bool get isPreviewingAsTechnician =>
      canUseRolePreview && rolePreviewOverride == AppRole.technician;

  List<_ShellDestination> get destinations => [
    _ShellDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      page: DashboardPage(
        userProfile: effectiveProfile,
        canAccessAssets: effectiveCanAccessAssets,
        canAccessLocations: effectiveCanAccessLocations,
        canAccessWorkOrders: effectiveCanAccessWorkOrders,
        canAccessAlerts: effectiveCanViewAlerts,
        canAccessSettings: effectiveCanAccessSettings,
        canCreateWorkOrders: effectiveCanCreateWorkOrders,
        onOpenAssets: () =>
            setState(() => currentIndex = _indexForLabel('Ativos') ?? 0),
        onOpenLocations: () =>
            setState(() => currentIndex = _indexForLabel('Localizacoes') ?? 0),
        onOpenWorkOrders: () =>
            setState(() => currentIndex = _workOrdersIndex ?? 0),
        onOpenAlerts: () =>
            setState(() => currentIndex = _indexForLabel('Alertas') ?? 0),
        onOpenSettings: () =>
            setState(() => currentIndex = _indexForLabel('Definicoes') ?? 0),
        onCreateWorkOrder: openAddWorkOrder,
      ),
    ),
    if (effectiveCanAccessAssets)
      _ShellDestination(
        label: 'Ativos',
        icon: Icons.precision_manufacturing_outlined,
        selectedIcon: Icons.precision_manufacturing,
        page: AssetsPage(
          key: ValueKey('assets-$assetsPageVersion'),
          userProfile: effectiveProfile,
          canManageAll: effectiveProfile.isAdmin,
          canEditAssets: effectiveCanEditAssets,
          canEditAssetDevices: effectiveCanEditAssetDevices,
          canEditWorkOrders: effectiveCanEditWorkOrders,
          canCloseWorkOrders: effectiveCanCloseWorkOrders,
        ),
      ),
    if (effectiveCanAccessLocations)
      _ShellDestination(
        label: 'Localizacoes',
        icon: Icons.place_outlined,
        selectedIcon: Icons.place,
        page: LocationsPage(
          key: ValueKey('locations-$locationsPageVersion'),
          userProfile: effectiveProfile,
          canManageAll: effectiveProfile.isAdmin,
          canEditLocations: effectiveCanEditLocations,
          canEditAssets: effectiveCanEditAssets,
          canEditAssetDevices: effectiveCanEditAssetDevices,
          canEditWorkOrders: effectiveCanEditWorkOrders,
          canCloseWorkOrders: effectiveCanCloseWorkOrders,
        ),
      ),
    if (effectiveCanAccessWorkOrders)
      _ShellDestination(
        label: effectiveCanViewAllWorkOrders ? 'Ordens' : 'Minhas ordens',
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        page: WorkOrdersPage(
          key: ValueKey('work-orders-$workOrdersPageVersion'),
          userProfile: effectiveProfile,
          canManageAll: effectiveCanViewAllWorkOrders,
          technicianId: effectiveCanViewAllWorkOrders
              ? null
              : effectiveTechnicianId,
          canEditWorkOrders: effectiveCanEditWorkOrders,
          canCloseWorkOrders: effectiveCanCloseWorkOrders,
        ),
      ),
    if (effectiveCanAccessWorkOrders && !effectiveProfile.isClient)
      _ShellDestination(
        label: 'Calendario',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        page: CalendarPage(
          canManageAll: effectiveCanViewAllWorkOrders,
          technicianId: effectiveCanViewAllWorkOrders
              ? null
              : effectiveTechnicianId,
          canEditWorkOrders: effectiveCanEditWorkOrders,
          canCloseWorkOrders: effectiveCanCloseWorkOrders,
        ),
      ),
    if (effectiveCanViewAlerts)
      const _ShellDestination(
        label: 'Alertas',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        page: AlertsPage(),
      ),
    if (!effectiveProfile.isClient)
      _ShellDestination(
        label: 'Notas',
        icon: Icons.sticky_note_2_outlined,
        selectedIcon: Icons.sticky_note_2,
        page: NotesPage(
          isTechnicianView: effectiveProfile.isTechnician,
          isSimulation: isPreviewingAsTechnician,
        ),
      ),
    if (effectiveProfile.isAdmin)
      const _ShellDestination(
        label: 'Relatorios',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        page: ReportsPage(),
      ),
    if (effectiveCanAccessSettings)
      _ShellDestination(
        label: 'Definicoes',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        page: SettingsPage(
          canManageCompany: effectiveProfile.isAdmin,
          canManageProcedures: effectiveProfile.isAdmin,
          canManageAssets: effectiveCanEditAssets,
          canManageLocations: effectiveCanEditLocations,
          canManageTechnicians: effectiveCanManageTechnicians,
          canManageUsers: effectiveCanManageUsers,
          onManageCompany: openCompanySettings,
          onManageProcedures: openManageProcedures,
          onCreateAsset: openAddAsset,
          onCreateLocation: openAddLocation,
          onCreateTechnician: openAddTechnician,
          onCreateUser: openAddUser,
          onManageAssets: () => setState(
            () => currentIndex = _indexForLabel('Ativos') ?? currentIndex,
          ),
          onManageLocations: () => setState(
            () => currentIndex = _indexForLabel('Localizacoes') ?? currentIndex,
          ),
          onManageTechnicians: openManageTechnicians,
          onManageUsers: openManageUsers,
        ),
      ),
  ];

  int? _indexForLabel(String label) {
    for (var index = 0; index < destinations.length; index++) {
      if (destinations[index].label == label) return index;
    }
    return null;
  }

  int? get _workOrdersIndex =>
      _indexForLabel('Ordens') ?? _indexForLabel('Minhas ordens');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WorkOrderOfflineService.instance.startAutoSync();
    loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WorkOrderOfflineService.instance.stopAutoSync();
    _sideNavScrollController.dispose();
    _bottomNavScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WorkOrderOfflineService.instance.startAutoSync();
      WorkOrderOfflineService.instance.syncPendingChanges();
    }
  }

  Future<void> loadProfile() async {
    setState(() {
      isLoadingProfile = true;
    });

    try {
      UserProfile? loadedProfile;
      CompanyProfile? loadedCompanyProfile;
      List<Technician> loadedTechnicians = const [];
      String? resolvedCompanyLogoUrl;

      try {
        loadedProfile = await ProfileService.instance.getCurrentUserProfile();
      } catch (_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileLoadError)));
      }

      if (loadedProfile != null) {
        try {
          loadedCompanyProfile = await CompanyService.instance
              .fetchCompanyProfile();
        } catch (_) {
          loadedCompanyProfile = null;
        }

        if (loadedProfile.isAdmin) {
          try {
            loadedTechnicians = await TechnicianService.instance
                .fetchTechnicians();
          } catch (_) {
            loadedTechnicians = const [];
          }
        }

        resolvedCompanyLogoUrl = await _resolveCompanyLogoUrl(
          loadedCompanyProfile?.logoUrl,
        );
      }

      if (!mounted) return;
      if (loadedProfile != null) {
        setState(() {
          profile = loadedProfile;
          companyProfile = loadedCompanyProfile;
          companyLogoUrl = resolvedCompanyLogoUrl;
          technicians = loadedTechnicians;
        });
      }
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingProfile = false;
      });
    }
  }

  Future<void> logout() async {
    await AuthService.instance.signOut();
  }

  Future<String?> _resolveCompanyLogoUrl(String? storedValue) async {
    final value = storedValue?.trim();
    if (value == null || value.isEmpty) return null;

    try {
      final uri = await StorageService.instance.resolveFileUri(
        bucket: 'company-media',
        storedValue: value,
      );
      return uri?.toString() ?? value;
    } catch (_) {
      return value;
    }
  }

  Future<void> openAddWorkOrder() async {
    final l10n = AppLocalizations.of(context);
    final assetsData = await Supabase.instance.client
        .from('assets')
        .select()
        .order('name');

    if (!mounted) return;

    final assets = List<Map<String, dynamic>>.from(assetsData);
    if (assets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noAssetsForWorkOrder)));
      return;
    }

    final selectedAsset = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.chooseAsset),
          children: assets.map((asset) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, asset),
              child: Text(asset['name']?.toString() ?? l10n.noNamedAsset),
            );
          }).toList(),
        );
      },
    );

    if (selectedAsset == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddWorkOrderPage(asset: selectedAsset)),
    );
    if (!mounted) return;
    setState(() {
      workOrdersPageVersion++;
      assetsPageVersion++;
      locationsPageVersion++;
    });
  }

  Future<void> openAddAsset() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAssetPage()),
    );
    if (!mounted) return;
    setState(() {
      assetsPageVersion++;
      locationsPageVersion++;
    });
  }

  Future<void> openAddLocation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddLocationPage()),
    );
    if (!mounted) return;
    setState(() {
      locationsPageVersion++;
      assetsPageVersion++;
    });
  }

  Future<void> openAddTechnician() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTechnicianPage()),
    );
    if (!mounted) return;
    setState(() {
      techniciansPageVersion++;
    });
  }

  Future<void> openAddUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddUserPage()),
    );
    if (!mounted) return;
    setState(() {
      usersPageVersion++;
    });
  }

  Future<void> openManageTechnicians() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TechniciansPage(
          key: ValueKey('technicians-$techniciansPageVersion'),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      techniciansPageVersion++;
    });
  }

  Future<void> openManageUsers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsersPage(key: ValueKey('users-$usersPageVersion')),
      ),
    );
    if (!mounted) return;
    setState(() {
      usersPageVersion++;
    });
  }

  Future<void> openCompanySettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompanySettingsPage()),
    );
  }

  Future<void> openManageProcedures() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProcedureTemplatesPage()),
    );
  }

  Future<void> openRoleSwitcher() async {
    if (!canUseRolePreview) return;

    final l10n = AppLocalizations.of(context);
    final selectedRole = await showDialog<AppRole>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.testView),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(l10n.administrator),
                onTap: () => Navigator.pop(context, AppRole.admin),
              ),
              ListTile(
                leading: const Icon(Icons.build),
                title: Text(l10n.technician),
                onTap: () => Navigator.pop(context, AppRole.technician),
              ),
            ],
          ),
        );
      },
    );

    if (selectedRole == null) return;

    setState(() {
      rolePreviewOverride = selectedRole;
      currentIndex = 0;
      if (selectedRole == AppRole.admin) {
        technicianPreviewOverrideId = null;
      } else {
        technicianPreviewOverrideId ??=
            profile?.technicianId ??
            (technicians.isNotEmpty ? technicians.first.id : null);
      }
    });
  }

  Future<void> openLanguageSwitcher() async {
    final l10n = AppLocalizations.of(context);
    final selectedLocale = await showDialog<Locale>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l10n.portuguese),
                onTap: () => Navigator.pop(context, const Locale('pt')),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l10n.english),
                onTap: () => Navigator.pop(context, const Locale('en')),
              ),
            ],
          ),
        );
      },
    );

    if (selectedLocale == null || !mounted) return;
    MyApp.of(context).setLocale(selectedLocale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isLoadingProfile || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (destinations.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            effectiveProfile.isAdmin
                ? l10n.appTitle
                : effectiveProfile.isClient
                ? 'Cliente'
                : l10n.technician,
          ),
          actions: _topActions(l10n),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Este utilizador nao tem acessos atribuidos.'),
          ),
        ),
      );
    }

    if (currentIndex >= destinations.length) {
      currentIndex = 0;
    }

    final wideLayout = MediaQuery.of(context).size.width >= 1120;
    final currentDestination = destinations[currentIndex];
    final currentFabVisible =
        currentDestination.label == 'Ordens' ||
        currentDestination.label == 'Minhas ordens';
    final brandTitle = _brandTitle(l10n);
    final brandSubtitle = _brandSubtitle();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F7F4), Color(0xFFEDF1EB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Row(
            children: [
              if (wideLayout)
                _buildSideNavigation(
                  context,
                  l10n,
                  brandTitle: brandTitle,
                  brandSubtitle: brandSubtitle,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: currentDestination.label,
                      subtitle: _subtitleFor(currentDestination.label),
                      actions: _topActions(l10n),
                    ),
                    if (!wideLayout && isPreviewingAsTechnician)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _buildTechnicianSimulationField(l10n),
                      ),
                    if (wideLayout && isPreviewingAsTechnician)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _buildTechnicianSimulationField(l10n),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          wideLayout ? 24 : 16,
                          0,
                          wideLayout ? 24 : 16,
                          16,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.84),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFD7DFD7)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: currentDestination.page,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wideLayout
            ? null
            : _buildBottomNavigationBar(context),
        floatingActionButton: currentFabVisible && effectiveCanCreateWorkOrders
            ? FloatingActionButton.extended(
                onPressed: openAddWorkOrder,
                icon: const Icon(Icons.add_task),
                label: Text(l10n.newWorkOrder),
              )
            : null,
      ),
    );
  }

  Widget _buildSideNavigation(
    BuildContext context,
    AppLocalizations l10n, {
    required String brandTitle,
    required String brandSubtitle,
  }) {
    return Container(
      width: 292,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF233240),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16202A).withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 188,
                height: 54,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  productLogoAsset,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: companyLogoUrl?.isNotEmpty == true
                    ? Image.network(
                        companyLogoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.apartment, color: Colors.white),
                      )
                    : const Icon(Icons.apartment, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      brandSubtitle,
                      style: TextStyle(color: Color(0xFFB7C4CF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isPreviewingAsTechnician)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SideInfoCard(
                title: 'Vista de simulacao',
                value: _effectiveTechnician?.name ?? l10n.technician,
              ),
            ),
          Expanded(
            child: RawScrollbar(
              controller: _sideNavScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              radius: const Radius.circular(999),
              thickness: 8,
              mainAxisMargin: 10,
              crossAxisMargin: 2,
              child: ListView.separated(
                controller: _sideNavScrollController,
                padding: const EdgeInsets.only(right: 6),
                itemCount: destinations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  final selected = index == currentIndex;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        currentIndex = index;
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? destination.selectedIcon
                                : destination.icon,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              destination.label,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SideInfoCard(
            title: 'Utilizador',
            value: effectiveProfile.isAdmin
                ? l10n.administrator
                : effectiveProfile.isClient
                ? 'Cliente'
                : l10n.technician,
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              _developerCreditText,
              textAlign: TextAlign.right,
              style: TextStyle(color: Color(0xFFA5B4C7), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.96),
          border: const Border(top: BorderSide(color: Color(0xFFD7DFD7))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16202A).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                SingleChildScrollView(
                  controller: _bottomNavScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(10, 8, 28, 8),
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < destinations.length;
                        index++
                      ) ...[
                        _BottomNavItem(
                          label: destinations[index].label,
                          icon: index == currentIndex
                              ? destinations[index].selectedIcon
                              : destinations[index].icon,
                          selected: index == currentIndex,
                          onTap: () {
                            setState(() {
                              currentIndex = index;
                            });
                          },
                        ),
                        if (index != destinations.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            colorScheme.surface,
                            colorScheme.surface.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            colorScheme.surface.withOpacity(0),
                            colorScheme.surface,
                          ],
                        ),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE9E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Color(0xFF29465B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                _developerCreditText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF64748B).withOpacity(0.92),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianSimulationField(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonFormField<String>(
        value: effectiveTechnicianId,
        decoration: InputDecoration(labelText: l10n.technicianInSimulation),
        items: technicians.map((technician) {
          return DropdownMenuItem<String>(
            value: technician.id,
            child: Text(technician.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            technicianPreviewOverrideId = value;
            currentIndex = 0;
          });
        },
      ),
    );
  }

  List<Widget> _topActions(AppLocalizations l10n) {
    return [
      IconButton(
        onPressed: openLanguageSwitcher,
        icon: const Icon(Icons.language),
        tooltip: l10n.language,
      ),
      IconButton(
        onPressed: canUseRolePreview ? openRoleSwitcher : null,
        icon: const Icon(Icons.swap_horiz),
        tooltip: l10n.changeViewForTests,
      ),
      IconButton(
        onPressed: logout,
        icon: const Icon(Icons.logout),
        tooltip: l10n.logout,
      ),
    ];
  }

  String _subtitleFor(String label) {
    if (label == 'Dashboard' && effectiveProfile.isClient) {
      return 'Acompanha o estado das ordens e ativos visiveis para o cliente.';
    }

    return switch (label) {
      'Dashboard' => 'Resumo visual da operacao e acessos rapidos.',
      'Ativos' => 'Consulta equipamentos, fichas e manutencoes associadas.',
      'Localizacoes' => 'Organiza espacos, ativos e pendencias por area.',
      'Ordens' => 'Acompanha o trabalho da equipa e o estado da manutencao.',
      'Minhas ordens' => 'Segue as ordens atribuidas ao tecnico em simulacao.',
      'Calendario' => 'Consulta intervencoes planeadas por dia e por mes.',
      'Alertas' => 'Vigiar notificacoes e acontecimentos relevantes.',
      'Notas' => 'Guarda notas pessoais com texto, imagens e partilha em PDF.',
      'Relatorios' =>
        'Analisa desempenho, volume de trabalho e qualidade de dados.',
      'Definicoes' => 'Gerir dados mestres, permissoes e configuracoes.',
      _ => '',
    };
  }

  String _brandTitle(AppLocalizations l10n) {
    final companyName = companyProfile?.name?.trim();
    if (companyName != null && companyName.isNotEmpty) {
      return companyName;
    }
    return l10n.appTitle;
  }

  String _brandSubtitle() {
    final city = companyProfile?.city?.trim();
    final country = companyProfile?.country?.trim();
    final locationParts = [
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ];

    if (locationParts.isNotEmpty) {
      return locationParts.join(' | ');
    }

    return 'Operacao e configuracao';
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showFullBrand = screenWidth >= 430;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: actions.isEmpty ? 0 : 8),
            child: SizedBox(
              width: showFullBrand ? 88 : 28,
              height: 24,
              child: Image.asset(
                showFullBrand ? productLogoAsset : productMarkAsset,
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _SideInfoCard extends StatelessWidget {
  const _SideInfoCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFFA5B4C7), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? const Color(0xFF1D2730)
        : const Color(0xFF5F6B72);

    return Material(
      color: selected ? const Color(0xFFDDE9E2) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: textColor),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
