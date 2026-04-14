import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/branding.dart';
import 'l10n/app_localizations.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final fullNameController = TextEditingController();
  final companyNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isRegisterMode = false;

  @override
  void dispose() {
    fullNameController.dispose();
    companyNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text;
    final l10n = AppLocalizations.of(context);

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche o email e a palavra-passe.')),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O email introduzido nao e valido.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final res = await AuthService.instance.signIn(
        email: email,
        password: password,
      );

      if (!mounted || res.session == null) return;
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loginError)));
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> register() async {
    FocusScope.of(context).unfocus();

    final fullName = fullNameController.text.trim();
    final companyName = companyNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (fullName.isEmpty) {
      _showMessage('Preenche o nome completo.');
      return;
    }

    if (companyName.isEmpty) {
      _showMessage('Preenche o nome da empresa.');
      return;
    }

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Preenche todos os campos obrigatorios.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('O email introduzido nao e valido.');
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
      final res = await AuthService.instance.signUp(
        email: email,
        password: password,
        fullName: fullName,
        companyName: companyName,
      );

      if (!mounted) return;

      _showMessage(
        res.session == null
            ? 'Conta criada. Confirma o email e depois entra para terminares a configuracao da empresa.'
            : 'Conta criada. Vamos terminar a configuracao da empresa.',
      );

      if (res.session == null) {
        setState(() {
          isRegisterMode = false;
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Nao foi possivel criar a conta: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final recoveryEmailController = TextEditingController(
      text: emailController.text.trim(),
    );
    var isSubmitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submitRecovery() async {
                final email = recoveryEmailController.text.trim();
                var dialogClosed = false;

                if (email.isEmpty) {
                  _showMessage('Indica o email da conta.');
                  return;
                }

                if (!_isValidEmail(email)) {
                  _showMessage('O email introduzido nao e valido.');
                  return;
                }

                setDialogState(() {
                  isSubmitting = true;
                });

                try {
                  await AuthService.instance.sendPasswordRecoveryEmail(
                    email: email,
                  );

                  if (!mounted) return;
                  if (dialogContext.mounted) {
                    dialogClosed = true;
                    Navigator.of(dialogContext).pop();
                  }
                  _showMessage(
                    'Enviamos um email de recuperacao. Abre o link para definires uma nova palavra-passe.',
                  );
                } on AuthException catch (error) {
                  if (!mounted) return;
                  _showMessage(error.message);
                } catch (_) {
                  if (!mounted) return;
                  _showMessage(
                    'Nao foi possivel enviar o email de recuperacao.',
                  );
                } finally {
                  if (!dialogClosed && dialogContext.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: const Text('Recuperar palavra-passe'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vamos enviar um email com um link seguro para redefinires a palavra-passe.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: recoveryEmailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isSubmitting) {
                          submitRecovery();
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
                    onPressed: isSubmitting ? null : submitRecovery,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enviar email'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      recoveryEmailController.dispose();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 12),
                  Text(
                    isRegisterMode
                        ? 'Cria a tua conta e entra logo numa nova empresa.'
                        : 'Plataforma multiempresa para manutencao e operacoes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    isRegisterMode = false;
                                  });
                                },
                          child: const Text('Entrar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    isRegisterMode = true;
                                  });
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: isRegisterMode
                                ? theme.colorScheme.primary
                                : null,
                            foregroundColor: isRegisterMode
                                ? Colors.white
                                : null,
                          ),
                          child: const Text('Criar conta'),
                        ),
                      ),
                    ],
                  ),
                  if (!isRegisterMode)
                    const SizedBox(height: 20)
                  else
                    const SizedBox(height: 16),
                  if (isRegisterMode) ...[
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da empresa',
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(labelText: l10n.password),
                    obscureText: true,
                    textInputAction: isRegisterMode
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) {
                      if (!isLoading && !isRegisterMode) {
                        login();
                      }
                    },
                  ),
                  if (!isRegisterMode) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading ? null : _showForgotPasswordDialog,
                        child: const Text('Esqueceste-te da palavra-passe?'),
                      ),
                    ),
                  ],
                  if (isRegisterMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar palavra-passe',
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          register();
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : (isRegisterMode ? register : login),
                      child: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isRegisterMode ? 'Criar conta' : l10n.login),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRegisterMode
                        ? 'A conta nova vai entrar numa empresa nova e fica pronta para terminares a configuracao a seguir.'
                        : 'Se ainda nao tens acesso, usa "Criar conta".',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
