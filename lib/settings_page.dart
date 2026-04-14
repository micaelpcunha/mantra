import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.canManageCompany,
    required this.canManageProcedures,
    required this.canManageAssets,
    required this.canManageLocations,
    required this.canManageTechnicians,
    required this.canManageUsers,
    required this.onManageCompany,
    required this.onManageProcedures,
    required this.onCreateAsset,
    required this.onCreateLocation,
    required this.onCreateTechnician,
    required this.onCreateUser,
    required this.onManageAssets,
    required this.onManageLocations,
    required this.onManageTechnicians,
    required this.onManageUsers,
  });

  final bool canManageCompany;
  final bool canManageProcedures;
  final bool canManageAssets;
  final bool canManageLocations;
  final bool canManageTechnicians;
  final bool canManageUsers;
  final VoidCallback onManageCompany;
  final VoidCallback onManageProcedures;
  final Future<void> Function() onCreateAsset;
  final Future<void> Function() onCreateLocation;
  final Future<void> Function() onCreateTechnician;
  final Future<void> Function() onCreateUser;
  final VoidCallback onManageAssets;
  final VoidCallback onManageLocations;
  final VoidCallback onManageTechnicians;
  final VoidCallback onManageUsers;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late User? _currentUser;
  late final StreamSubscription<AuthState> _authSubscription;

  bool get hasAdminSections =>
      widget.canManageCompany ||
      widget.canManageProcedures ||
      widget.canManageAssets ||
      widget.canManageLocations ||
      widget.canManageTechnicians ||
      widget.canManageUsers;

  String? get _currentEmail {
    final email = _currentUser?.email?.trim();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  String? get _pendingEmail {
    final email = _currentUser?.newEmail?.trim();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.instance.currentUser;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (!mounted) return;
      setState(() {
        _currentUser = data.session?.user ?? AuthService.instance.currentUser;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized);
  }

  bool _requiresReauthentication(AuthException error) {
    final code = error.code?.trim().toLowerCase();
    if (code == 'reauthentication_needed' ||
        code == 'reauth_nonce_missing' ||
        code == 'reauthentication_not_valid' ||
        code == 'otp_expired') {
      return true;
    }

    final message = error.message.toLowerCase();
    return message.contains('reauth') || message.contains('nonce');
  }

  bool _isInvalidReauthenticationCode(AuthException error) {
    final code = error.code?.trim().toLowerCase();
    return code == 'reauthentication_not_valid' || code == 'otp_expired';
  }

  String _friendlyEmailError(AuthException error) {
    switch (error.code?.trim().toLowerCase()) {
      case 'email_exists':
        return 'Ja existe uma conta com esse email.';
      case 'over_email_send_rate_limit':
        return 'Foram enviados demasiados emails num curto periodo. Tenta novamente daqui a pouco.';
      default:
        return error.message;
    }
  }

  String _friendlyPasswordError(AuthException error) {
    switch (error.code?.trim().toLowerCase()) {
      case 'same_password':
        return 'Escolhe uma palavra-passe diferente da atual.';
      case 'weak_password':
        return error.message;
      case 'over_email_send_rate_limit':
        return 'Foram enviados demasiados emails num curto periodo. Tenta novamente daqui a pouco.';
      default:
        return error.message;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showChangeEmailDialog() async {
    final emailController = TextEditingController(
      text: _pendingEmail ?? _currentEmail ?? '',
    );
    var isSubmitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submitChange() async {
                final nextEmail = emailController.text.trim();
                final normalizedNextEmail = nextEmail.toLowerCase();
                final currentEmail = _currentEmail?.trim().toLowerCase();
                final pendingEmail = _pendingEmail?.trim().toLowerCase();

                if (nextEmail.isEmpty) {
                  _showMessage('Indica o novo email de acesso.');
                  return;
                }

                if (!_isValidEmail(nextEmail)) {
                  _showMessage('O email introduzido nao e valido.');
                  return;
                }

                if (currentEmail != null &&
                    normalizedNextEmail == currentEmail &&
                    (pendingEmail == null || pendingEmail.isEmpty)) {
                  _showMessage('Esse email ja e o email de acesso atual.');
                  return;
                }

                if (pendingEmail != null &&
                    pendingEmail.isNotEmpty &&
                    normalizedNextEmail == pendingEmail) {
                  _showMessage(
                    'Ja existe um pedido pendente para mudar para esse email.',
                  );
                  return;
                }

                var dialogClosed = false;
                setDialogState(() {
                  isSubmitting = true;
                });

                try {
                  final response = await AuthService.instance.updateEmail(
                    email: nextEmail,
                  );
                  final updatedUser =
                      response.user ?? AuthService.instance.currentUser;

                  if (!mounted) return;
                  setState(() {
                    _currentUser = updatedUser;
                  });

                  if (dialogContext.mounted) {
                    dialogClosed = true;
                    Navigator.of(dialogContext).pop();
                  }

                  final activeEmail = updatedUser?.email?.trim().toLowerCase();
                  final queuedEmail = updatedUser?.newEmail?.trim();
                  if (queuedEmail != null &&
                      queuedEmail.isNotEmpty &&
                      queuedEmail.toLowerCase() != activeEmail) {
                    _showMessage(
                      'Enviamos um pedido de confirmacao para $queuedEmail. A alteracao so fica concluida depois de confirmares o email atual e o novo email.',
                    );
                  } else {
                    _showMessage('Email de acesso atualizado com sucesso.');
                  }
                } on AuthException catch (error) {
                  if (!mounted) return;
                  _showMessage(_friendlyEmailError(error));
                } catch (_) {
                  if (!mounted) return;
                  _showMessage('Nao foi possivel atualizar o email de acesso.');
                } finally {
                  if (!dialogClosed && dialogContext.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: const Text('Alterar email de acesso'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'O novo email passa a ser usado no acesso a conta. Por seguranca, o Supabase pode pedir confirmacao por email antes da alteracao ficar concluida.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Novo email',
                        hintText: 'nome@empresa.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isSubmitting) {
                          submitChange();
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: isSubmitting ? null : submitChange,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      emailController.dispose();
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final nonceController = TextEditingController();
    var isSubmitting = false;
    var requiresNonce = false;
    var nonceWasSent = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> sendSecurityCode() async {
                setDialogState(() {
                  isSubmitting = true;
                });

                try {
                  await AuthService.instance.sendPasswordReauthenticationCode();

                  if (!mounted) return;
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      requiresNonce = true;
                      nonceWasSent = true;
                    });
                  }
                  _showMessage(
                    'Enviamos um codigo de seguranca para o teu email. Introduz esse codigo para confirmar a nova palavra-passe.',
                  );
                } on AuthException catch (error) {
                  if (!mounted) return;
                  _showMessage(_friendlyPasswordError(error));
                } catch (_) {
                  if (!mounted) return;
                  _showMessage(
                    'Nao foi possivel enviar o codigo de seguranca.',
                  );
                } finally {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              Future<void> submitChange() async {
                final password = passwordController.text;
                final confirmPassword = confirmPasswordController.text;
                final nonce = nonceController.text.trim();

                if (password.isEmpty) {
                  _showMessage('Indica a nova palavra-passe.');
                  return;
                }

                if (password.length < 8) {
                  _showMessage(
                    'Define uma palavra-passe com pelo menos 8 caracteres.',
                  );
                  return;
                }

                if (password != confirmPassword) {
                  _showMessage('As palavras-passe nao coincidem.');
                  return;
                }

                if (requiresNonce && nonce.isEmpty) {
                  _showMessage(
                    'Indica o codigo de seguranca recebido por email.',
                  );
                  return;
                }

                var dialogClosed = false;
                setDialogState(() {
                  isSubmitting = true;
                });

                try {
                  await AuthService.instance.updatePassword(
                    password: password,
                    nonce: nonce.isEmpty ? null : nonce,
                  );

                  if (!mounted) return;
                  if (dialogContext.mounted) {
                    dialogClosed = true;
                    Navigator.of(dialogContext).pop();
                  }
                  _showMessage('Palavra-passe atualizada com sucesso.');
                } on AuthException catch (error) {
                  if (_requiresReauthentication(error)) {
                    if (!nonceWasSent) {
                      try {
                        await AuthService.instance
                            .sendPasswordReauthenticationCode();
                        if (!mounted) return;
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            requiresNonce = true;
                            nonceWasSent = true;
                          });
                        }
                        _showMessage(
                          'Por seguranca, enviamos um codigo para o teu email. Introduz esse codigo para concluir a alteracao da palavra-passe.',
                        );
                      } on AuthException catch (reauthError) {
                        if (!mounted) return;
                        _showMessage(_friendlyPasswordError(reauthError));
                      } catch (_) {
                        if (!mounted) return;
                        _showMessage(
                          'Nao foi possivel enviar o codigo de seguranca.',
                        );
                      }
                      return;
                    }

                    if (!mounted) return;
                    _showMessage(
                      _isInvalidReauthenticationCode(error)
                          ? 'O codigo de seguranca nao e valido ou expirou. Pede um novo codigo e tenta novamente.'
                          : _friendlyPasswordError(error),
                    );
                    return;
                  }

                  if (!mounted) return;
                  _showMessage(_friendlyPasswordError(error));
                } catch (_) {
                  if (!mounted) return;
                  _showMessage('Nao foi possivel atualizar a palavra-passe.');
                } finally {
                  if (!dialogClosed && dialogContext.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: const Text('Alterar palavra-passe'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requiresNonce
                          ? 'Introduz o codigo de seguranca enviado para o teu email e define a nova palavra-passe.'
                          : 'Define uma nova palavra-passe para esta conta. Se a sessao precisar de confirmacao adicional, enviamos um codigo de seguranca para o teu email.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Nova palavra-passe',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar palavra-passe',
                      ),
                      obscureText: true,
                    ),
                    if (requiresNonce) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: nonceController,
                        decoration: const InputDecoration(
                          labelText: 'Codigo de seguranca',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!isSubmitting) {
                            submitChange();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: isSubmitting ? null : sendSecurityCode,
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: const Text('Reenviar codigo'),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Cancelar'),
                  ),
                  if (!requiresNonce)
                    OutlinedButton(
                      onPressed: isSubmitting ? null : sendSecurityCode,
                      child: const Text('Enviar codigo'),
                    ),
                  FilledButton(
                    onPressed: isSubmitting ? null : submitChange,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      passwordController.dispose();
      confirmPasswordController.dispose();
      nonceController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Definicoes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          hasAdminSections
              ? 'Centraliza a tua conta e a gestao administrativa do sistema.'
              : 'Centraliza os dados de acesso e a seguranca da tua conta.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _AccountSettingsCard(
          currentEmail: _currentEmail,
          pendingEmail: _pendingEmail,
          onChangeEmail: _showChangeEmailDialog,
          onChangePassword: _showChangePasswordDialog,
        ),
        if (widget.canManageCompany)
          _SettingsSectionCard(
            title: 'Empresa',
            subtitle:
                'Atualizar identidade, contactos, morada, imagens e configuracao global dos emails de intervencao.',
            manageLabel: 'Gerir empresa',
            manageIcon: Icons.apartment,
            onCreate: null,
            onManage: widget.onManageCompany,
          ),
        if (widget.canManageProcedures)
          _SettingsSectionCard(
            title: 'Procedimentos',
            subtitle:
                'Criar e atualizar procedimentos reutilizaveis com checklist para associar as ordens de trabalho.',
            manageLabel: 'Gerir procedimentos',
            manageIcon: Icons.playlist_add_check_circle_outlined,
            onCreate: null,
            onManage: widget.onManageProcedures,
          ),
        if (widget.canManageAssets)
          _SettingsSectionCard(
            title: 'Ativos',
            subtitle: 'Criar, editar e rever dados, fotografias e regras QR.',
            createLabel: 'Novo ativo',
            manageLabel: 'Gerir ativos',
            createIcon: Icons.add_box_outlined,
            manageIcon: Icons.precision_manufacturing,
            onCreate: widget.onCreateAsset,
            onManage: widget.onManageAssets,
          ),
        if (widget.canManageLocations)
          _SettingsSectionCard(
            title: 'Localizacoes',
            subtitle:
                'Criar, editar e organizar localizacoes e respetivas fotos.',
            createLabel: 'Nova localizacao',
            manageLabel: 'Gerir localizacoes',
            createIcon: Icons.add_location_alt_outlined,
            manageIcon: Icons.place,
            onCreate: widget.onCreateLocation,
            onManage: widget.onManageLocations,
          ),
        if (widget.canManageTechnicians)
          _SettingsSectionCard(
            title: 'Tecnicos',
            subtitle: 'Gerir perfis, documentos e permissoes dos tecnicos.',
            createLabel: 'Novo tecnico',
            manageLabel: 'Gerir tecnicos',
            createIcon: Icons.person_add_alt_1,
            manageIcon: Icons.groups,
            onCreate: widget.onCreateTechnician,
            onManage: widget.onManageTechnicians,
          ),
        if (widget.canManageUsers)
          _SettingsSectionCard(
            title: 'Utilizadores',
            subtitle:
                'Associar contas, perfis, clientes e acessos administrativos.',
            createLabel: 'Novo utilizador',
            manageLabel: 'Gerir utilizadores',
            createIcon: Icons.manage_accounts_outlined,
            manageIcon: Icons.admin_panel_settings,
            onCreate: widget.onCreateUser,
            onManage: widget.onManageUsers,
          ),
      ],
    );
  }
}

class _AccountSettingsCard extends StatelessWidget {
  const _AccountSettingsCard({
    required this.currentEmail,
    required this.pendingEmail,
    required this.onChangeEmail,
    required this.onChangePassword,
  });

  final String? currentEmail;
  final String? pendingEmail;
  final Future<void> Function() onChangeEmail;
  final Future<void> Function() onChangePassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPendingEmail =
        pendingEmail != null &&
        pendingEmail!.isNotEmpty &&
        pendingEmail != currentEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conta', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Gerir o email usado no acesso e a palavra-passe desta conta.',
            ),
            const SizedBox(height: 16),
            Text('Email atual', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(currentEmail ?? 'Sem email disponivel'),
            if (hasPendingEmail) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule_send_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Alteracao pendente para $pendingEmail. A mudanca fica concluida quando confirmares o pedido de email.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onChangeEmail,
                  icon: const Icon(Icons.alternate_email),
                  label: const Text('Alterar email'),
                ),
                OutlinedButton.icon(
                  onPressed: onChangePassword,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Alterar palavra-passe'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.manageLabel,
    required this.manageIcon,
    this.createLabel,
    this.createIcon,
    this.onCreate,
    required this.onManage,
  });

  final String title;
  final String subtitle;
  final String? createLabel;
  final String manageLabel;
  final IconData? createIcon;
  final IconData manageIcon;
  final Future<void> Function()? onCreate;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onCreate != null &&
                    createLabel != null &&
                    createIcon != null)
                  FilledButton.icon(
                    onPressed: () {
                      onCreate!();
                    },
                    icon: Icon(createIcon),
                    label: Text(createLabel!),
                  ),
                OutlinedButton.icon(
                  onPressed: onManage,
                  icon: Icon(manageIcon),
                  label: Text(manageLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
