import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/branding.dart';
import 'services/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.onCompleted,
    required this.onCancel,
  });

  final VoidCallback onCompleted;
  final Future<void> Function() onCancel;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isSuccess = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePassword() async {
    FocusScope.of(context).unfocus();

    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Preenche a nova palavra-passe e a confirmacao.');
      return;
    }

    if (password.length < 8) {
      _showMessage('A palavra-passe tem de ter pelo menos 8 caracteres.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('As palavras-passe nao coincidem.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthService.instance.updatePassword(password: password);

      if (!mounted) return;
      setState(() {
        isSuccess = true;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Nao foi possivel atualizar a palavra-passe.');
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _cancelRecovery() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      await widget.onCancel();
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRecoverySession = AuthService.instance.currentSession != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    height: 150,
                    child: Image.asset(
                      productLogoAsset,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSuccess
                        ? 'Palavra-passe atualizada com sucesso.'
                        : hasRecoverySession
                        ? 'Define uma nova palavra-passe para voltar a entrar em seguranca.'
                        : 'Este link de recuperacao ja nao e valido.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isSuccess
                        ? 'Podes continuar diretamente para a aplicacao.'
                        : hasRecoverySession
                        ? 'Usa pelo menos 8 caracteres para proteger a conta.'
                        : 'Pede um novo email de recuperacao no ecran de login.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (isSuccess) ...[
                    FilledButton(
                      onPressed: widget.onCompleted,
                      child: const Text('Continuar'),
                    ),
                  ] else if (!hasRecoverySession) ...[
                    FilledButton.tonal(
                      onPressed: isLoading ? null : _cancelRecovery,
                      child: const Text('Voltar ao login'),
                    ),
                  ] else ...[
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Nova palavra-passe',
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nova palavra-passe',
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          _savePassword();
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isLoading ? null : _savePassword,
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar nova palavra-passe'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isLoading ? null : _cancelRecovery,
                      child: const Text('Cancelar e voltar ao login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
