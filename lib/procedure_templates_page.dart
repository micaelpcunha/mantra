import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/procedure_template.dart';
import 'services/asset_device_service.dart';
import 'services/procedure_template_service.dart';

class ProcedureTemplatesPage extends StatefulWidget {
  const ProcedureTemplatesPage({super.key});

  @override
  State<ProcedureTemplatesPage> createState() => _ProcedureTemplatesPageState();
}

class _ProcedureTemplatesPageState extends State<ProcedureTemplatesPage> {
  final supabase = Supabase.instance.client;

  List<ProcedureTemplate> templates = const [];
  List<Map<String, dynamic>> assets = const [];
  bool isLoading = true;
  bool tableAvailable = true;
  bool assetAssociationAvailable = false;

  @override
  void initState() {
    super.initState();
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    setState(() {
      isLoading = true;
    });

    try {
      final available = await ProcedureTemplateService.instance.isAvailable();
      final supportsAssetAssociation = await ProcedureTemplateService.instance
          .supportsAssetAssociation();
      final loadedTemplates = available
          ? await ProcedureTemplateService.instance.fetchTemplates()
          : const <ProcedureTemplate>[];
      final loadedAssets = supportsAssetAssociation
          ? List<Map<String, dynamic>>.from(
              await supabase.from('assets').select('id, name').order('name'),
            )
          : const <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        tableAvailable = available;
        assetAssociationAvailable = supportsAssetAssociation;
        templates = loadedTemplates;
        assets = loadedAssets;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel carregar os procedimentos: $error'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> openEditor({ProcedureTemplate? template}) async {
    final result = await Navigator.of(context).push<_ProcedureTemplateDraft>(
      MaterialPageRoute(
        builder: (_) => _ProcedureTemplateEditorPage(
          template: template,
          assets: assets,
          assetAssociationAvailable: assetAssociationAvailable,
        ),
      ),
    );

    if (result == null) return;

    try {
      if (template == null) {
        await ProcedureTemplateService.instance.createTemplate(
          name: result.name,
          description: result.description,
          steps: result.steps,
          isActive: result.isActive,
          assetId: result.assetId,
          assetDeviceId: result.assetDeviceId,
          assetDeviceName: result.assetDeviceName,
        );
      } else {
        await ProcedureTemplateService.instance.updateTemplate(
          templateId: template.id,
          name: result.name,
          description: result.description,
          steps: result.steps,
          isActive: result.isActive,
          assetId: result.assetId,
          assetDeviceId: result.assetDeviceId,
          assetDeviceName: result.assetDeviceName,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            template == null
                ? 'Procedimento criado com sucesso.'
                : 'Procedimento atualizado com sucesso.',
          ),
        ),
      );
      await loadTemplates();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel guardar o procedimento: $error'),
        ),
      );
    }
  }

  Future<void> deleteTemplate(ProcedureTemplate template) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar procedimento'),
          content: Text('Queres eliminar "${template.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await ProcedureTemplateService.instance.deleteTemplate(template.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Procedimento eliminado com sucesso.')),
      );
      await loadTemplates();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel eliminar o procedimento: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetNamesById = {
      for (final asset in assets)
        asset['id']?.toString() ?? '': asset['name']?.toString() ?? '',
    };

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Procedimentos')),
      floatingActionButton: tableAvailable
          ? FloatingActionButton.extended(
              onPressed: () => openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Novo procedimento'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: loadTemplates,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Procedimentos reutilizaveis',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cria aqui os procedimentos base com os trabalhos a executar. Cada passo pode ficar obrigatorio ou opcional e pode ter uma fotografia propria durante a execucao.',
                    ),
                    if (assetAssociationAvailable) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Opcionalmente, podes ligar o template a um ativo e a um dispositivo especifico desse ativo.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!tableAvailable) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Falta ativar o schema dos procedimentos.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Executa o script SUPABASE_WORK_ORDER_PROCEDURES.sql no Supabase para ativar os templates de procedimentos e o checklist nas ordens.',
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (templates.isEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.playlist_add_check_circle_outlined),
                      const SizedBox(height: 12),
                      const Text(
                        'Ainda nao existem procedimentos configurados.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Criar primeiro procedimento'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ...templates.map((template) {
                final previewSteps = template.steps.take(4).toList();
                final requiredSteps = template.steps
                    .where((step) => step.isRequired)
                    .length;
                final photoSteps = template.steps
                    .where((step) => step.requiresPhoto)
                    .length;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    template.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(
                                        label: Text(
                                          '${template.stepCount} passos',
                                        ),
                                      ),
                                      if (requiredSteps > 0)
                                        Chip(
                                          label: Text(
                                            '$requiredSteps obrigatorios',
                                          ),
                                        ),
                                      if (photoSteps > 0)
                                        Chip(
                                          label: Text(
                                            '$photoSteps com fotografia',
                                          ),
                                        ),
                                      if ((template.assetId ?? '').isNotEmpty)
                                        Chip(
                                          label: Text(
                                            'Ativo: ${assetNamesById[template.assetId] ?? 'especifico'}',
                                          ),
                                        ),
                                      if ((template.assetDeviceName ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        Chip(
                                          avatar: const Icon(
                                            Icons.memory_outlined,
                                            size: 16,
                                          ),
                                          label: Text(
                                            'Dispositivo: ${template.assetDeviceName!.trim()}',
                                          ),
                                        ),
                                      Chip(
                                        label: Text(
                                          template.isActive
                                              ? 'Ativo'
                                              : 'Inativo',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  openEditor(template: template);
                                  return;
                                }
                                if (value == 'delete') {
                                  deleteTemplate(template);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if ((template.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(template.description!.trim()),
                        ],
                        const SizedBox(height: 12),
                        ...previewSteps.map(
                          (step) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_box_outline_blank,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(step.title),
                                      if (step.isRequired ||
                                          step.requiresPhoto) ...[
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            if (step.isRequired)
                                              const Chip(
                                                label: Text('Obrigatorio'),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            if (step.requiresPhoto)
                                              const Chip(
                                                avatar: Icon(
                                                  Icons.photo_camera_outlined,
                                                  size: 16,
                                                ),
                                                label: Text('Fotografia'),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (template.steps.length > previewSteps.length)
                          Text(
                            'E mais ${template.steps.length - previewSteps.length} passos...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProcedureTemplateDraft {
  const _ProcedureTemplateDraft({
    required this.name,
    required this.description,
    required this.steps,
    required this.isActive,
    this.assetId,
    this.assetDeviceId,
    this.assetDeviceName,
  });

  final String name;
  final String? description;
  final List<ProcedureChecklistItem> steps;
  final bool isActive;
  final String? assetId;
  final String? assetDeviceId;
  final String? assetDeviceName;
}

class _ProcedureTemplateEditorPage extends StatefulWidget {
  const _ProcedureTemplateEditorPage({
    this.template,
    required this.assets,
    required this.assetAssociationAvailable,
  });

  final ProcedureTemplate? template;
  final List<Map<String, dynamic>> assets;
  final bool assetAssociationAvailable;

  @override
  State<_ProcedureTemplateEditorPage> createState() =>
      _ProcedureTemplateEditorPageState();
}

class _ProcedureTemplateEditorPageState
    extends State<_ProcedureTemplateEditorPage> {
  static const String _legacyAssetDeviceDropdownValue =
      '__legacy_template_asset_device__';

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  late bool isActive = widget.template?.isActive ?? true;
  final List<_EditableProcedureStep> steps = [];
  List<Map<String, dynamic>> assetDevices = const [];
  bool isLoadingAssetDevices = false;
  String? selectedAssetId;
  String? selectedAssetDeviceId;
  String selectedAssetDeviceName = '';

  bool get isEditing => widget.template != null;

  String? get _normalizedAssetDeviceId {
    final value = selectedAssetDeviceId?.trim() ?? '';
    if (value.isEmpty || value == _legacyAssetDeviceDropdownValue) {
      return null;
    }
    return value;
  }

  String? get _normalizedAssetDeviceName {
    final value = selectedAssetDeviceName.trim();
    return value.isEmpty ? null : value;
  }

  bool get _hasSelectedAssetDeviceInList {
    final deviceId = _normalizedAssetDeviceId;
    if (deviceId == null) {
      return false;
    }

    for (final device in assetDevices) {
      if (device['id']?.toString() == deviceId) {
        return true;
      }
    }

    return false;
  }

  Map<String, dynamic>? get _selectedAssetDeviceDetails {
    final deviceId = _normalizedAssetDeviceId;
    if (deviceId == null) {
      return null;
    }

    for (final device in assetDevices) {
      if (device['id']?.toString() == deviceId) {
        return device;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.template?.name ?? '';
    descriptionController.text = widget.template?.description ?? '';
    selectedAssetId = widget.template?.assetId;
    selectedAssetDeviceId = widget.template?.assetDeviceId;
    selectedAssetDeviceName = widget.template?.assetDeviceName ?? '';

    final initialSteps =
        widget.template?.steps ?? const <ProcedureChecklistItem>[];
    if (initialSteps.isEmpty) {
      steps.add(_EditableProcedureStep.create());
    } else {
      steps.addAll(initialSteps.map(_EditableProcedureStep.fromItem));
    }

    if (widget.assetAssociationAvailable && selectedAssetId != null) {
      loadAssetDevices();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    for (final step in steps) {
      step.dispose();
    }
    super.dispose();
  }

  void addStep() {
    setState(() {
      steps.add(_EditableProcedureStep.create());
    });
  }

  void removeStep(int index) {
    if (steps.length == 1) {
      steps[index].controller.clear();
      steps[index].requiresPhoto = false;
      steps[index].isRequired = true;
      setState(() {});
      return;
    }

    final step = steps.removeAt(index);
    step.dispose();
    setState(() {});
  }

  void moveStep(int from, int to) {
    if (to < 0 || to >= steps.length) return;
    final step = steps.removeAt(from);
    steps.insert(to, step);
    setState(() {});
  }

  void save() {
    if (!formKey.currentState!.validate()) return;

    final normalizedSteps = steps
        .map(
          (step) => ProcedureChecklistItem(
            id: step.id,
            title: step.controller.text.trim(),
            requiresPhoto: step.requiresPhoto,
            isRequired: step.isRequired,
          ),
        )
        .where((step) => step.title.isNotEmpty)
        .toList();

    if (normalizedSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adiciona pelo menos um passo ao procedimento.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _ProcedureTemplateDraft(
        name: nameController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        steps: normalizedSteps,
        isActive: isActive,
        assetId: widget.assetAssociationAvailable ? selectedAssetId : null,
        assetDeviceId: widget.assetAssociationAvailable
            ? _normalizedAssetDeviceId
            : null,
        assetDeviceName: widget.assetAssociationAvailable
            ? _normalizedAssetDeviceName
            : null,
      ),
    );
  }

  String? get _selectedAssetDeviceDropdownValue {
    final deviceId = _normalizedAssetDeviceId;
    if (deviceId != null && _hasSelectedAssetDeviceInList) return deviceId;
    if (_normalizedAssetDeviceName != null) {
      return _legacyAssetDeviceDropdownValue;
    }
    return null;
  }

  Future<void> loadAssetDevices() async {
    final assetId = selectedAssetId;
    if (assetId == null || assetId.isEmpty) {
      setState(() {
        assetDevices = const [];
        isLoadingAssetDevices = false;
      });
      return;
    }

    setState(() {
      isLoadingAssetDevices = true;
    });

    try {
      final devices = await AssetDeviceService.instance.fetchDevicesForAsset(
        assetId,
      );
      final currentDeviceId = _normalizedAssetDeviceId;
      final hasCurrentDevice =
          currentDeviceId != null &&
          devices.any((device) => device['id']?.toString() == currentDeviceId);
      if (!mounted) return;

      setState(() {
        assetDevices = devices;
        if (!hasCurrentDevice) {
          selectedAssetDeviceId = null;
        }
        isLoadingAssetDevices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        assetDevices = const [];
        isLoadingAssetDevices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar procedimento' : 'Novo procedimento'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Indica o nome do procedimento.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nome do procedimento',
                        hintText: 'Ex: Manutencao preventiva mensal',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descricao',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Procedimento ativo'),
                      subtitle: const Text(
                        'Os procedimentos inativos deixam de aparecer na criacao de ordens, mas o historico das ordens antigas mantem-se.',
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setState(() {
                          isActive = value;
                        });
                      },
                    ),
                    if (widget.assetAssociationAvailable) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: selectedAssetId,
                        decoration: const InputDecoration(
                          labelText: 'Ativo associado',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Template generico'),
                          ),
                          ...widget.assets.map((asset) {
                            return DropdownMenuItem<String?>(
                              value: asset['id']?.toString(),
                              child: Text(asset['name']?.toString() ?? 'Ativo'),
                            );
                          }),
                        ],
                        onChanged: (value) async {
                          setState(() {
                            selectedAssetId = value;
                            selectedAssetDeviceId = null;
                            selectedAssetDeviceName = '';
                          });
                          await loadAssetDevices();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (isLoadingAssetDevices)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<String?>(
                          value: _selectedAssetDeviceDropdownValue,
                          decoration: const InputDecoration(
                            labelText: 'Dispositivo associado',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sem dispositivo'),
                            ),
                          ...assetDevices.map((device) {
                              return DropdownMenuItem<String?>(
                                value: device['id']?.toString(),
                                child: Text(
                                  device['name']?.toString() ?? 'Dispositivo',
                                ),
                              );
                            }),
                            if (!_hasSelectedAssetDeviceInList &&
                                _normalizedAssetDeviceName != null)
                              DropdownMenuItem<String?>(
                                value: _legacyAssetDeviceDropdownValue,
                                child: Text(
                                  '${_normalizedAssetDeviceName!} (historico)',
                                ),
                              ),
                          ],
                          onChanged: selectedAssetId == null
                              ? null
                              : (value) {
                                  if (value == _legacyAssetDeviceDropdownValue) {
                                    return;
                                  }
                                  if (value == null) {
                                    setState(() {
                                      selectedAssetDeviceId = null;
                                      selectedAssetDeviceName = '';
                                    });
                                    return;
                                  }

                                  Map<String, dynamic>? matchedDevice;
                                  for (final device in assetDevices) {
                                    if (device['id']?.toString() == value) {
                                      matchedDevice = device;
                                      break;
                                    }
                                  }

                                  setState(() {
                                    selectedAssetDeviceId = value;
                                    selectedAssetDeviceName =
                                        matchedDevice?['name']
                                            ?.toString()
                                            .trim() ??
                                        '';
                                  });
                                },
                        ),
                      if (_selectedAssetDeviceDetails != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if ((_selectedAssetDeviceDetails!['manufacturer_reference']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ??
                                    false))
                              Chip(
                                label: Text(
                                  'Ref. fabricante: ${_selectedAssetDeviceDetails!['manufacturer_reference']?.toString().trim()}',
                                ),
                              ),
                            if ((_selectedAssetDeviceDetails!['internal_reference']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ??
                                    false))
                              Chip(
                                label: Text(
                                  'Ref. interna: ${_selectedAssetDeviceDetails!['internal_reference']?.toString().trim()}',
                                ),
                              ),
                            if ((_selectedAssetDeviceDetails!['qr_code']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ??
                                    false))
                              const Chip(label: Text('Tem QR proprio')),
                          ],
                        ),
                      ],
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Passos do procedimento',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: addStep,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar passo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Em cada passo podes escolher se e obrigatorio e se deve ter uma fotografia propria na execucao.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(steps.length, (index) {
                      final step = steps[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text('${index + 1}'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: step.controller,
                                      decoration: InputDecoration(
                                        labelText: 'Passo ${index + 1}',
                                        hintText:
                                            'Ex: Verificar pressao do circuito',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    selected: step.isRequired,
                                    label: const Text('Obrigatorio'),
                                    onSelected: (value) {
                                      setState(() {
                                        step.isRequired = value;
                                      });
                                    },
                                  ),
                                  FilterChip(
                                    selected: step.requiresPhoto,
                                    avatar: const Icon(
                                      Icons.photo_camera_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Fotografia'),
                                    onSelected: (value) {
                                      setState(() {
                                        step.requiresPhoto = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: index == 0
                                        ? null
                                        : () => moveStep(index, index - 1),
                                    icon: const Icon(Icons.arrow_upward),
                                    label: const Text('Subir'),
                                  ),
                                  TextButton.icon(
                                    onPressed: index == steps.length - 1
                                        ? null
                                        : () => moveStep(index, index + 1),
                                    icon: const Icon(Icons.arrow_downward),
                                    label: const Text('Descer'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => removeStep(index),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Remover'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save),
              label: Text(
                isEditing ? 'Atualizar procedimento' : 'Guardar procedimento',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableProcedureStep {
  _EditableProcedureStep({
    required this.id,
    required this.controller,
    this.requiresPhoto = false,
    this.isRequired = true,
  });

  final String id;
  final TextEditingController controller;
  bool requiresPhoto;
  bool isRequired;

  factory _EditableProcedureStep.create() {
    return _EditableProcedureStep(
      id: 'step_${DateTime.now().microsecondsSinceEpoch}',
      controller: TextEditingController(),
    );
  }

  factory _EditableProcedureStep.fromItem(ProcedureChecklistItem item) {
    return _EditableProcedureStep(
      id: item.id,
      controller: TextEditingController(text: item.title),
      requiresPhoto: item.requiresPhoto,
      isRequired: item.isRequired,
    );
  }

  void dispose() {
    controller.dispose();
  }
}
