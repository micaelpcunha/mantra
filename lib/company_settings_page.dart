import 'package:flutter/material.dart';

import 'models/company_email_connection.dart';
import 'models/company_profile.dart';
import 'services/company_email_connection_service.dart';
import 'services/company_service.dart';
import 'services/email_provider_auth_service.dart';
import 'services/storage_service.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final nameController = TextEditingController();
  final legalNameController = TextEditingController();
  final taxIdController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final websiteController = TextEditingController();
  final addressController = TextEditingController();
  final postalCodeController = TextEditingController();
  final cityController = TextEditingController();
  final countryController = TextEditingController();
  final notesController = TextEditingController();
  final authorizationSenderEmailController = TextEditingController();
  final authorizationEmailSignatureController = TextEditingController();

  String authorizationEmailSendMode = 'manual';
  String authorizationEmailProvider = 'manual';
  String? authorizationEmailConnectionId;

  CompanyProfile? companyProfile;
  List<CompanyEmailConnection> emailConnections = const [];
  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingLogo = false;
  bool isUploadingCover = false;
  bool isRefreshingEmailConnections = false;
  bool isLinkingEmailProvider = false;
  String? deletingEmailConnectionId;
  bool emailConnectionsAvailable = false;
  String? logoStorageValue;
  String? coverPhotoStorageValue;
  String? logoPreviewUrl;
  String? coverPreviewUrl;
  final Set<String> _companyMediaToDeleteOnSave = <String>{};

  @override
  void initState() {
    super.initState();
    loadCompanyProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    legalNameController.dispose();
    taxIdController.dispose();
    emailController.dispose();
    phoneController.dispose();
    websiteController.dispose();
    addressController.dispose();
    postalCodeController.dispose();
    cityController.dispose();
    countryController.dispose();
    notesController.dispose();
    authorizationSenderEmailController.dispose();
    authorizationEmailSignatureController.dispose();
    super.dispose();
  }

  List<CompanyEmailConnection> get providerEmailConnections {
    final provider = _normalizeEmailProvider(authorizationEmailProvider);
    if (provider == 'manual') return const <CompanyEmailConnection>[];

    return emailConnections
        .where((connection) => connection.provider == provider)
        .toList();
  }

  CompanyEmailConnection? get selectedEmailConnection {
    final connectionId = _sanitizeConnectionId(authorizationEmailConnectionId);
    if (connectionId == null) return null;

    for (final connection in emailConnections) {
      if (connection.id == connectionId) {
        return connection;
      }
    }

    return null;
  }

  Future<void> _refreshEmailConnections({
    bool showFeedback = false,
    bool preserveLoadingState = false,
  }) async {
    if (!preserveLoadingState) {
      setState(() {
        isRefreshingEmailConnections = true;
      });
    }

    try {
      final connectionsTableAvailable = await CompanyEmailConnectionService
          .instance
          .isAvailable();
      final connections = connectionsTableAvailable
          ? await CompanyEmailConnectionService.instance.fetchConnections()
          : const <CompanyEmailConnection>[];
      if (!mounted) return;

      final normalizedProvider = _normalizeEmailProvider(
        authorizationEmailProvider,
      );
      final normalizedConnectionId = _sanitizeConnectionId(
        authorizationEmailConnectionId,
      );

      setState(() {
        emailConnectionsAvailable = connectionsTableAvailable;
        emailConnections = connections;
        authorizationEmailConnectionId =
            _isValidConnectionSelection(
              connectionId: normalizedConnectionId,
              provider: normalizedProvider,
              connections: connections,
            )
            ? normalizedConnectionId
            : null;
      });

      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lista de contas ligadas atualizada.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel atualizar as contas ligadas: $e'),
        ),
      );
    } finally {
      if (!mounted || preserveLoadingState) return;
      setState(() {
        isRefreshingEmailConnections = false;
      });
    }
  }

  Future<void> _startProviderAuthorization() async {
    final provider = _normalizeEmailProvider(authorizationEmailProvider);
    if (provider == 'manual') {
      return;
    }

    setState(() {
      isLinkingEmailProvider = true;
    });

    try {
      await EmailProviderAuthService.instance.launchAuthorization(
        provider: provider,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Autenticacao ${_providerLabel(provider)} iniciada no browser. Quando terminares, volta aqui e carrega em "Atualizar contas".',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nao foi possivel iniciar a ligacao ${_providerLabel(provider)}: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLinkingEmailProvider = false;
      });
    }
  }

  Future<void> _deleteEmailConnection(CompanyEmailConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conta ligada'),
        content: Text(
          'Queres eliminar a conta ${connection.identityLabel} das contas ligadas desta empresa?',
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
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      deletingEmailConnectionId = connection.id;
    });

    try {
      final previousSenderEmail = authorizationSenderEmailController.text
          .trim();
      final deleteResult = await CompanyEmailConnectionService.instance
          .deleteConnection(
            connection: connection,
            activeConnectionId: authorizationEmailConnectionId,
            authorizationSenderEmail: previousSenderEmail,
          );
      final refreshedProfile = await CompanyService.instance
          .fetchCompanyProfile();
      final refreshedConnections = await CompanyEmailConnectionService.instance
          .fetchConnections();
      final refreshedProvider = deleteResult.deletedActiveConnection
          ? _normalizeEmailProvider(
              refreshedProfile?.authorizationEmailProvider,
            )
          : _normalizeEmailProvider(
              refreshedProfile?.authorizationEmailProvider ??
                  authorizationEmailProvider,
            );
      final refreshedConnectionId = deleteResult.deletedActiveConnection
          ? _sanitizeConnectionId(
              refreshedProfile?.authorizationEmailConnectionId,
            )
          : _sanitizeConnectionId(
              refreshedProfile?.authorizationEmailConnectionId ??
                  authorizationEmailConnectionId,
            );
      final refreshedSendMode = deleteResult.deletedActiveConnection
          ? _normalizeEmailSendMode(
              refreshedProfile?.authorizationEmailSendMode,
            )
          : _normalizeEmailSendMode(
              refreshedProfile?.authorizationEmailSendMode ??
                  authorizationEmailSendMode,
            );
      final refreshedSenderEmail =
          refreshedProfile?.authorizationSenderEmail?.trim() ?? '';
      final clearedSenderEmail =
          previousSenderEmail.isNotEmpty &&
          refreshedSenderEmail.isEmpty &&
          previousSenderEmail.trim().toLowerCase() ==
              connection.email.trim().toLowerCase();

      if (!mounted) return;

      authorizationSenderEmailController.text =
          refreshedProfile?.authorizationSenderEmail ?? '';
      authorizationEmailSignatureController.text =
          refreshedProfile?.authorizationEmailSignature ??
          authorizationEmailSignatureController.text;

      setState(() {
        companyProfile = refreshedProfile;
        authorizationEmailSendMode = refreshedSendMode;
        authorizationEmailProvider = refreshedProvider;
        authorizationEmailConnectionId =
            _isValidConnectionSelection(
              connectionId: refreshedConnectionId,
              provider: refreshedProvider,
              connections: refreshedConnections,
            )
            ? refreshedConnectionId
            : null;
        emailConnectionsAvailable = true;
        emailConnections = refreshedConnections;
      });

      final removedEverywhereText = deleteResult.deletedActiveConnection
          ? clearedSenderEmail
                ? 'Conta ligada eliminada, remetente ativo removido da empresa e email de resposta limpo.'
                : 'Conta ligada eliminada e remetente ativo removido da empresa.'
          : 'Conta ligada eliminada com sucesso.';
      final cleanupDetail = deleteResult.usedServerCleanup
          ? ' A ligacao e as credenciais OAuth foram limpas no backend.'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$removedEverywhereText$cleanupDetail')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel eliminar a conta ligada: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        deletingEmailConnectionId = null;
      });
    }
  }

  Future<void> loadCompanyProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final profile = await CompanyService.instance.fetchCompanyProfile();
      final connectionsTableAvailable = await CompanyEmailConnectionService
          .instance
          .isAvailable();
      final connections = connectionsTableAvailable
          ? await CompanyEmailConnectionService.instance.fetchConnections()
          : const <CompanyEmailConnection>[];
      final resolvedLogoUrl = await _resolveCompanyMediaUrl(profile?.logoUrl);
      final resolvedCoverUrl = await _resolveCompanyMediaUrl(
        profile?.coverPhotoUrl,
      );

      if (!mounted) return;

      nameController.text = profile?.name ?? '';
      legalNameController.text = profile?.legalName ?? '';
      taxIdController.text = profile?.taxId ?? '';
      emailController.text = profile?.email ?? '';
      phoneController.text = profile?.phone ?? '';
      websiteController.text = profile?.website ?? '';
      addressController.text = profile?.address ?? '';
      postalCodeController.text = profile?.postalCode ?? '';
      cityController.text = profile?.city ?? '';
      countryController.text = profile?.country ?? '';
      notesController.text = profile?.notes ?? '';
      authorizationSenderEmailController.text =
          profile?.authorizationSenderEmail ?? '';
      authorizationEmailSignatureController.text =
          profile?.authorizationEmailSignature ?? '';

      final loadedProvider = _normalizeEmailProvider(
        profile?.authorizationEmailProvider,
      );
      final loadedConnectionId = _sanitizeConnectionId(
        profile?.authorizationEmailConnectionId,
      );

      setState(() {
        companyProfile = profile;
        authorizationEmailSendMode = _normalizeEmailSendMode(
          profile?.authorizationEmailSendMode,
        );
        authorizationEmailProvider = loadedProvider;
        authorizationEmailConnectionId =
            _isValidConnectionSelection(
              connectionId: loadedConnectionId,
              provider: loadedProvider,
              connections: connections,
            )
            ? loadedConnectionId
            : null;
        emailConnectionsAvailable = connectionsTableAvailable;
        emailConnections = connections;
        logoStorageValue = profile?.logoUrl;
        coverPhotoStorageValue = profile?.coverPhotoUrl;
        logoPreviewUrl = resolvedLogoUrl;
        coverPreviewUrl = resolvedCoverUrl;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel carregar os dados da empresa: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> save() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome da empresa e obrigatorio.')),
      );
      return;
    }

    final senderEmail = authorizationSenderEmailController.text.trim();
    if (senderEmail.isNotEmpty && !_isValidEmail(senderEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O email de resposta configurado nao e valido.'),
        ),
      );
      return;
    }

    final normalizedProvider = _normalizeEmailProvider(
      authorizationEmailProvider,
    );
    final normalizedConnectionId = normalizedProvider == 'manual'
        ? null
        : _sanitizeConnectionId(authorizationEmailConnectionId);
    final selectedConnection = _findConnectionById(normalizedConnectionId);

    if (normalizedConnectionId != null && selectedConnection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A conta de email escolhida ja nao esta disponivel nesta empresa.',
          ),
        ),
      );
      return;
    }

    if (selectedConnection != null &&
        selectedConnection.provider != normalizedProvider) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A conta ligada escolhida nao corresponde ao fornecedor selecionado.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final pendingCompanyMediaDeletes = List<String>.from(
        _companyMediaToDeleteOnSave,
      );
      final saved = await CompanyService.instance.upsertCompanyProfile(
        existingId: companyProfile?.id,
        payload: {
          'name': nameController.text.trim(),
          'legal_name': _nullableText(legalNameController),
          'tax_id': _nullableText(taxIdController),
          'email': _nullableText(emailController),
          'phone': _nullableText(phoneController),
          'website': _nullableText(websiteController),
          'address': _nullableText(addressController),
          'postal_code': _nullableText(postalCodeController),
          'city': _nullableText(cityController),
          'country': _nullableText(countryController),
          'logo_url': logoStorageValue,
          'cover_photo_url': coverPhotoStorageValue,
          'notes': _nullableText(notesController),
          'authorization_email_send_mode': authorizationEmailSendMode,
          'authorization_email_provider': normalizedProvider,
          'authorization_email_connection_id': normalizedConnectionId,
          'authorization_email_signature': _nullableText(
            authorizationEmailSignatureController,
          ),
          'authorization_sender_email': _nullableText(
            authorizationSenderEmailController,
          ),
        },
      );

      if (!mounted) return;

      final savedProvider = _normalizeEmailProvider(
        saved.authorizationEmailProvider,
      );
      final savedConnectionId = _sanitizeConnectionId(
        saved.authorizationEmailConnectionId,
      );

      setState(() {
        companyProfile = saved;
        authorizationEmailSendMode = _normalizeEmailSendMode(
          saved.authorizationEmailSendMode,
        );
        authorizationEmailProvider = savedProvider;
        authorizationEmailConnectionId =
            _isValidConnectionSelection(
              connectionId: savedConnectionId,
              provider: savedProvider,
              connections: emailConnections,
            )
            ? savedConnectionId
            : null;
        logoStorageValue = saved.logoUrl;
        coverPhotoStorageValue = saved.coverPhotoUrl;
      });
      await _cleanupCompanyMediaAfterSave(
        savedLogoValue: saved.logoUrl,
        savedCoverValue: saved.coverPhotoUrl,
        pendingDeletes: pendingCompanyMediaDeletes,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados da empresa atualizados com sucesso.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel guardar os dados da empresa: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> uploadLogo() async {
    setState(() {
      isUploadingLogo = true;
    });
    try {
      final storedValue = await StorageService.instance
          .pickAndUploadCompanyLogo();
      if (!mounted || storedValue == null) return;
      final previewUrl = await _resolveCompanyMediaUrl(storedValue);
      if (!mounted) return;
      _queueCompanyMediaDeletion(logoStorageValue);
      setState(() {
        logoStorageValue = storedValue;
        logoPreviewUrl = previewUrl;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel carregar o logotipo: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isUploadingLogo = false;
      });
    }
  }

  Future<void> uploadCoverPhoto() async {
    setState(() {
      isUploadingCover = true;
    });
    try {
      final storedValue = await StorageService.instance
          .pickAndUploadCompanyCoverPhoto();
      if (!mounted || storedValue == null) return;
      final previewUrl = await _resolveCompanyMediaUrl(storedValue);
      if (!mounted) return;
      _queueCompanyMediaDeletion(coverPhotoStorageValue);
      setState(() {
        coverPhotoStorageValue = storedValue;
        coverPreviewUrl = previewUrl;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel carregar a imagem de capa: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isUploadingCover = false;
      });
    }
  }

  Future<void> removeLogo() async {
    final currentValue = logoStorageValue?.trim();
    if (currentValue == null || currentValue.isEmpty) return;

    _queueCompanyMediaDeletion(currentValue);
    setState(() {
      logoStorageValue = null;
      logoPreviewUrl = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logotipo removido do rascunho. Guarda para confirmar.'),
      ),
    );
  }

  Future<void> removeCoverPhoto() async {
    final currentValue = coverPhotoStorageValue?.trim();
    if (currentValue == null || currentValue.isEmpty) return;

    _queueCompanyMediaDeletion(currentValue);
    setState(() {
      coverPhotoStorageValue = null;
      coverPreviewUrl = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Imagem de capa removida do rascunho. Guarda para confirmar.',
        ),
      ),
    );
  }

  void _queueCompanyMediaDeletion(String? storedValue) {
    final value = storedValue?.trim();
    if (value == null || value.isEmpty) return;
    _companyMediaToDeleteOnSave.add(value);
  }

  Future<void> _cleanupCompanyMediaAfterSave({
    required String? savedLogoValue,
    required String? savedCoverValue,
    required List<String> pendingDeletes,
  }) async {
    final finalValues = <String>{
      if (savedLogoValue?.trim().isNotEmpty == true) savedLogoValue!.trim(),
      if (savedCoverValue?.trim().isNotEmpty == true) savedCoverValue!.trim(),
    };
    final deletions = pendingDeletes
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && !finalValues.contains(value))
        .toList();

    if (deletions.isEmpty) {
      _companyMediaToDeleteOnSave.clear();
      return;
    }

    try {
      await StorageService.instance.deleteStoredObjects(
        bucket: 'company-media',
        storedValues: deletions,
      );
      _companyMediaToDeleteOnSave.removeAll(deletions);
    } catch (_) {
      // Keep the save flow successful even if storage cleanup fails.
    }
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<String?> _resolveCompanyMediaUrl(String? storedValue) async {
    final value = storedValue?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = await StorageService.instance.resolveFileUri(
      bucket: 'company-media',
      storedValue: value,
    );
    return uri?.toString() ?? value;
  }

  String _normalizeEmailSendMode(String? value) =>
      value?.trim().toLowerCase() == 'automatico' ? 'automatico' : 'manual';

  String _normalizeEmailProvider(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'google':
        return 'google';
      case 'microsoft':
        return 'microsoft';
      default:
        return 'manual';
    }
  }

  String? _sanitizeConnectionId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  bool _isValidConnectionSelection({
    required String? connectionId,
    required String provider,
    required List<CompanyEmailConnection> connections,
  }) {
    if (connectionId == null) return false;
    return connections.any(
      (connection) =>
          connection.id == connectionId && connection.provider == provider,
    );
  }

  CompanyEmailConnection? _findConnectionById(String? connectionId) {
    if (connectionId == null) return null;
    for (final connection in emailConnections) {
      if (connection.id == connectionId) return connection;
    }
    return null;
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'Google / Gmail';
      case 'microsoft':
        return 'Microsoft / Hotmail / Outlook';
      default:
        return 'Manual';
    }
  }

  IconData _providerIcon(String provider) {
    switch (provider) {
      case 'google':
        return Icons.alternate_email;
      case 'microsoft':
        return Icons.mail_outline;
      default:
        return Icons.drafts_outlined;
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  Widget _buildEmailConnectionStateBox({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedConnectionSummary(BuildContext context) {
    final connection = selectedEmailConnection;
    if (connection == null) {
      return const SizedBox.shrink();
    }

    final metaLabels = <String>[
      connection.statusLabel,
      if (connection.connectedAt != null)
        'Ligada em ${_formatDateTime(connection.connectedAt)}',
      if (connection.lastSyncAt != null)
        'Ultima sync ${_formatDateTime(connection.lastSyncAt)}',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_providerIcon(connection.provider)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  connection.identityLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metaLabels
                .map(
                  (label) => Chip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          if (connection.lastError?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Ultimo erro: ${connection.lastError!.trim()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailConnectionSelector(BuildContext context) {
    if (!emailConnectionsAvailable) {
      return _buildEmailConnectionStateBox(
        context: context,
        icon: Icons.storage_outlined,
        title: 'Base de contas ligadas ainda nao aplicada',
        description:
            'Executa o script SUPABASE_EMAIL_PROVIDER_FOUNDATION.sql para ativar a tabela company_email_connections e guardar a conta autenticada por empresa.',
      );
    }

    if (providerEmailConnections.isEmpty) {
      return _buildEmailConnectionStateBox(
        context: context,
        icon: Icons.link_off,
        title: 'Sem contas ligadas para este fornecedor',
        description:
            'Liga uma conta com OAuth para a poderes usar no envio automatico a partir do planeamento.',
      );
    }

    final selectedValue =
        providerEmailConnections.any(
          (connection) => connection.id == authorizationEmailConnectionId,
        )
        ? authorizationEmailConnectionId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: selectedValue,
          decoration: const InputDecoration(
            labelText: 'Conta ligada para envio',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sem conta ligada ativa'),
            ),
            ...providerEmailConnections.map(
              (connection) => DropdownMenuItem<String?>(
                value: connection.id,
                child: Text(connection.identityLabel),
              ),
            ),
          ],
          onChanged: isSaving
              ? null
              : (value) {
                  setState(() {
                    authorizationEmailConnectionId = _sanitizeConnectionId(
                      value,
                    );
                  });
                },
        ),
        _buildSelectedConnectionSummary(context),
      ],
    );
  }

  Widget _buildEmailConnectionCard(
    BuildContext context,
    CompanyEmailConnection connection,
  ) {
    final isSelected = connection.id == authorizationEmailConnectionId;
    final metaLabels = <String>[
      _providerLabel(connection.provider),
      connection.statusLabel,
      if (connection.connectedAt != null)
        'Ligada em ${_formatDateTime(connection.connectedAt)}',
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.25)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_providerIcon(connection.provider)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.identityLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connection.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Chip(
                  label: const Text('Em uso'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metaLabels
                .map(
                  (label) => Chip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          if (connection.lastError?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Ultimo erro: ${connection.lastError!.trim()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isSelected)
                TextButton.icon(
                  onPressed: isSaving
                      ? null
                      : () {
                          setState(() {
                            authorizationEmailSendMode = 'manual';
                            authorizationEmailProvider = 'manual';
                            authorizationEmailConnectionId = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Conta ativa removida do rascunho. Guarda para confirmar.',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Deixar de usar'),
                ),
              TextButton.icon(
                onPressed:
                    isSaving || deletingEmailConnectionId == connection.id
                    ? null
                    : () => _deleteEmailConnection(connection),
                icon: deletingEmailConnectionId == connection.id
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Eliminar conta ligada'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSettingsCard(BuildContext context) {
    final effectiveSenderEmail =
        authorizationSenderEmailController.text.trim().isNotEmpty
        ? authorizationSenderEmailController.text.trim()
        : selectedEmailConnection?.email;
    final senderHint = authorizationEmailProvider == 'google'
        ? 'o-teu-email@gmail.com'
        : authorizationEmailProvider == 'microsoft'
        ? 'o-teu-email@outlook.com'
        : 'o-teu-email@empresa.pt';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email de autorizacoes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Configura como os pedidos de autorizacao de entrada vao ser preparados e, quando existir uma conta ligada, enviados automaticamente pelo backend.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: authorizationEmailSendMode,
              decoration: const InputDecoration(labelText: 'Modo de envio'),
              items: const [
                DropdownMenuItem(
                  value: 'manual',
                  child: Text('Manual com confirmacao'),
                ),
                DropdownMenuItem(
                  value: 'automatico',
                  child: Text('Automatico apos planear'),
                ),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        authorizationEmailSendMode = value;
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: authorizationEmailProvider,
              decoration: const InputDecoration(labelText: 'Conta de envio'),
              items: const [
                DropdownMenuItem(
                  value: 'manual',
                  child: Text('Manual sem integracao'),
                ),
                DropdownMenuItem(
                  value: 'google',
                  child: Text('Google / Gmail'),
                ),
                DropdownMenuItem(
                  value: 'microsoft',
                  child: Text('Microsoft / Hotmail / Outlook'),
                ),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      final provider = _normalizeEmailProvider(value);
                      final compatibleConnections = emailConnections
                          .where(
                            (connection) => connection.provider == provider,
                          )
                          .toList();

                      setState(() {
                        authorizationEmailProvider = provider;
                        if (provider == 'manual') {
                          authorizationEmailConnectionId = null;
                        } else if (!compatibleConnections.any(
                          (connection) =>
                              connection.id == authorizationEmailConnectionId,
                        )) {
                          authorizationEmailConnectionId =
                              compatibleConnections.length == 1
                              ? compatibleConnections.first.id
                              : null;
                        }
                      });
                    },
            ),
            const SizedBox(height: 12),
            if (authorizationEmailProvider == 'manual')
              _buildEmailConnectionStateBox(
                context: context,
                icon: Icons.drafts_outlined,
                title: 'Modo manual ativo',
                description:
                    'A app prepara o rascunho e o envio continua a ser revisto fora da integracao direta.',
              )
            else
              _buildEmailConnectionSelector(context),
            if (authorizationEmailProvider != 'manual') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: isSaving || isLinkingEmailProvider
                        ? null
                        : _startProviderAuthorization,
                    icon: isLinkingEmailProvider
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      selectedEmailConnection == null
                          ? 'Ligar ${_providerLabel(authorizationEmailProvider)}'
                          : 'Ligar outra conta',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isSaving || isRefreshingEmailConnections
                        ? null
                        : () => _refreshEmailConnections(showFeedback: true),
                    icon: isRefreshingEmailConnections
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Atualizar contas'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Depois de aparecer a conta ligada nesta lista, guarda a empresa para fixar o fornecedor e a conta ativa.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: authorizationSenderEmailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Email de resposta (opcional)',
                hintText: senderHint,
                helperText: authorizationEmailProvider == 'manual'
                    ? 'Se preencheres este campo, os rascunhos mostram este email como referencia de resposta.'
                    : 'Se preencheres este campo, os emails enviados usam este endereco no Reply-To. Se deixares vazio, usam a conta ligada.',
                helperMaxLines: 2,
              ),
            ),
            if (effectiveSenderEmail?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Email de resposta efetivo: ${effectiveSenderEmail!.trim()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: authorizationEmailSignatureController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Assinatura global do email',
                hintText:
                    'Com os melhores cumprimentos,\nNome\nEmpresa\nContacto',
              ),
            ),
            if (emailConnectionsAvailable && emailConnections.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Contas ligadas',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              ...emailConnections.map(
                (connection) => _buildEmailConnectionCard(context, connection),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Google usa Gmail API e Microsoft usa Graph. Com uma conta ligada e o modo automatico ativo, o envio e feito no backend; no modo manual, a app continua a preparar o conteudo para revisao.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dados da empresa')),
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
                    'Imagem e identidade',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.12),
                        ),
                        child: coverPreviewUrl?.isNotEmpty == true
                            ? Image.network(
                                coverPreviewUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.apartment, size: 48),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.landscape_outlined, size: 48),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploadingCover || isSaving
                            ? null
                            : uploadCoverPhoto,
                        icon: isUploadingCover
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          coverPreviewUrl?.isNotEmpty == true
                              ? 'Substituir capa'
                              : 'Carregar capa',
                        ),
                      ),
                      if (coverPhotoStorageValue?.trim().isNotEmpty == true)
                        TextButton.icon(
                          onPressed: isUploadingCover || isSaving
                              ? null
                              : removeCoverPhoto,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover capa'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.blue.withOpacity(0.12),
                        backgroundImage: logoPreviewUrl?.isNotEmpty == true
                            ? NetworkImage(logoPreviewUrl!)
                            : null,
                        onBackgroundImageError:
                            logoPreviewUrl?.isNotEmpty == true
                            ? (_, __) {}
                            : null,
                        child: logoPreviewUrl?.isNotEmpty == true
                            ? null
                            : const Icon(
                                Icons.business,
                                size: 34,
                                color: Colors.blue,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: isUploadingLogo || isSaving
                                  ? null
                                  : uploadLogo,
                              icon: isUploadingLogo
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.photo_camera_outlined),
                              label: Text(
                                logoPreviewUrl?.isNotEmpty == true
                                    ? 'Substituir logotipo'
                                    : 'Carregar logotipo',
                              ),
                            ),
                            if (logoStorageValue?.trim().isNotEmpty == true)
                              TextButton.icon(
                                onPressed: isUploadingLogo || isSaving
                                    ? null
                                    : removeLogo,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remover logotipo'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildEmailSettingsCard(context),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dados gerais',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome comercial',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: legalNameController,
                    decoration: const InputDecoration(labelText: 'Nome legal'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taxIdController,
                    decoration: const InputDecoration(labelText: 'NIF'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: websiteController,
                    decoration: const InputDecoration(labelText: 'Website'),
                    keyboardType: TextInputType.url,
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
                    'Morada e observacoes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Morada'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: postalCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Codigo postal',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: cityController,
                          decoration: const InputDecoration(
                            labelText: 'Cidade',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Pais'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas internas ou descricao',
                    ),
                    maxLines: 4,
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
            label: const Text('Guardar dados da empresa'),
          ),
        ],
      ),
    );
  }
}
