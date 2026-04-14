import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/branding.dart';
import 'services/account_setup_service.dart';
import 'services/auth_service.dart';

class AccountSetupPage extends StatefulWidget {
  const AccountSetupPage({
    super.key,
    required this.email,
    required this.onCompleted,
    this.initialFullName,
    this.initialCompanyName,
  });

  final String? email;
  final String? initialFullName;
  final String? initialCompanyName;
  final Future<void> Function() onCompleted;

  @override
  State<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends State<AccountSetupPage> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _companyNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.initialFullName ?? '',
    );
    _companyNameController = TextEditingController(
      text: widget.initialCompanyName ?? '',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final fullName = _fullNameController.text.trim();
    final companyName = _companyNameController.text.trim();

    if (fullName.isEmpty) {
      _showMessage('Indica o nome completo.');
      return;
    }

    if (companyName.isEmpty) {
      _showMessage('Indica o nome da empresa.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AccountSetupService.instance.bootstrapNewCompany(
        fullName: fullName,
        companyName: companyName,
      );
      if (!mounted) return;
      await widget.onCompleted();
    } on FunctionException catch (error) {
      if (!mounted) return;
      final message =
          AccountSetupService.instance.isBootstrapFunctionMissing(error)
          ? 'Falta publicar a function account-bootstrap no Supabase para concluir este registo.'
          : AccountSetupService.instance.extractFunctionErrorMessage(error);
      _showMessage(message);
    } on AuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Nao foi possivel concluir a criacao da empresa: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 140,
                        child: Image.asset(
                          productLogoAsset,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Falta criar a tua empresa',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A conta ja esta criada. Agora vamos liga-la a uma nova empresa para entrares na app.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (widget.email != null &&
                          widget.email!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            widget.email!.trim(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                        ),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _companyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da empresa',
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isSaving) {
                            _submit();
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Criar empresa e continuar'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                await _signOut();
                              },
                        child: const Text('Entrar com outra conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
