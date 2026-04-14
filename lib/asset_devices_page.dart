import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'qr/asset_qr_support.dart';
import 'services/asset_device_service.dart';
import 'services/storage_service.dart';

class AssetDevicesPage extends StatefulWidget {
  const AssetDevicesPage({
    super.key,
    required this.asset,
    this.canEditDevices = false,
    this.canDeleteDevices = false,
  });

  final Map<String, dynamic> asset;
  final bool canEditDevices;
  final bool canDeleteDevices;

  @override
  State<AssetDevicesPage> createState() => _AssetDevicesPageState();
}

class _AssetDevicesPageState extends State<AssetDevicesPage> {
  List<Map<String, dynamic>> devices = [];
  bool isLoading = true;
  bool isFeatureAvailable = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await AssetDeviceService.instance.fetchDevicesForAsset(
        widget.asset['id'],
      );

      if (!mounted) return;
      setState(() {
        devices = data;
        isFeatureAvailable = true;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      if (AssetDeviceService.instance.isMissingTableError(error)) {
        setState(() {
          devices = [];
          isFeatureAvailable = false;
        });
        return;
      }

      setState(() {
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar os dispositivos.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> openDeviceEditor({Map<String, dynamic>? device}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAssetDevicePage(
          asset: widget.asset,
          device: device,
          canEdit: widget.canEditDevices,
          canDelete: widget.canDeleteDevices,
        ),
      ),
    );

    if (changed == true) {
      await fetchDevices();
    }
  }

  String? _trimmedValue(dynamic value) {
    final trimmed = value?.toString().trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  List<_AssetDeviceDocument> _documentationFromRow(
    Map<String, dynamic> device,
  ) {
    return _AssetDeviceDocument.readAll(device['documentation']);
  }

  Widget _buildFeatureUnavailableState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_outlined, size: 42),
                const SizedBox(height: 12),
                Text(
                  'Os dispositivos ainda nao estao ativados nesta base de dados.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aplica o script SUPABASE_ASSET_DEVICES.sql para poderes criar dispositivos com QR e documentacao.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final description = _trimmedValue(device['description']);
    final manufacturerReference = _trimmedValue(
      device['manufacturer_reference'],
    );
    final internalReference = _trimmedValue(device['internal_reference']);
    final qrValue = _trimmedValue(device['qr_code']);
    final documentation = _documentationFromRow(device);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.withOpacity(0.12),
          child: const Icon(Icons.memory_outlined, color: Colors.blueGrey),
        ),
        title: Text(device['name']?.toString() ?? 'Dispositivo'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (qrValue != null)
                    const Chip(
                      label: Text('QR associado'),
                      avatar: Icon(Icons.qr_code, size: 18),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                  if (documentation.isNotEmpty)
                    Chip(
                      label: Text(
                        '${documentation.length} doc${documentation.length == 1 ? '' : 's'}',
                      ),
                      avatar: const Icon(Icons.folder_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (manufacturerReference != null ||
                  internalReference != null) ...[
                const SizedBox(height: 8),
                if (manufacturerReference != null)
                  Text('Ref. fabricante: $manufacturerReference'),
                if (internalReference != null)
                  Text('Ref. interna: $internalReference'),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openDeviceEditor(device: device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetName = widget.asset['name']?.toString() ?? 'Ativo';

    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos')),
      floatingActionButton: isFeatureAvailable && widget.canEditDevices
          ? FloatingActionButton(
              onPressed: () => openDeviceEditor(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!isFeatureAvailable) {
            return _buildFeatureUnavailableState(context);
          }

          if (errorMessage != null) {
            return Center(child: Text(errorMessage!));
          }

          return RefreshIndicator(
            onRefresh: fetchDevices,
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
                          assetName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          devices.isEmpty
                              ? 'Sem dispositivos registados neste ativo.'
                              : '${devices.length} dispositivo${devices.length == 1 ? '' : 's'} registado${devices.length == 1 ? '' : 's'} neste ativo.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (devices.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.memory_outlined, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Ainda nao existem dispositivos dentro deste ativo.',
                            textAlign: TextAlign.center,
                          ),
                          if (widget.canEditDevices) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => openDeviceEditor(),
                              icon: const Icon(Icons.add),
                              label: const Text('Criar primeiro dispositivo'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  ...devices.map(_buildDeviceCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AddAssetDevicePage extends StatefulWidget {
  const AddAssetDevicePage({
    super.key,
    required this.asset,
    this.device,
    this.canEdit = true,
    this.canDelete = false,
  });

  final Map<String, dynamic> asset;
  final Map<String, dynamic>? device;
  final bool canEdit;
  final bool canDelete;

  bool get isEditing => device != null;

  @override
  State<AddAssetDevicePage> createState() => _AddAssetDevicePageState();
}

class _AddAssetDevicePageState extends State<AddAssetDevicePage> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final manufacturerReferenceController = TextEditingController();
  final internalReferenceController = TextEditingController();
  final qrController = TextEditingController();

  late List<_AssetDeviceDocument> documentation;
  late final List<_AssetDeviceDocument> initialDocumentation;
  bool isSaving = false;
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    final existingDevice = widget.device;
    if (existingDevice != null) {
      nameController.text = existingDevice['name']?.toString() ?? '';
      descriptionController.text =
          existingDevice['description']?.toString() ?? '';
      manufacturerReferenceController.text =
          existingDevice['manufacturer_reference']?.toString() ?? '';
      internalReferenceController.text =
          existingDevice['internal_reference']?.toString() ?? '';
      qrController.text = existingDevice['qr_code']?.toString() ?? '';
    }

    documentation = _AssetDeviceDocument.readAll(
      widget.device?['documentation'],
    );
    initialDocumentation = documentation
        .map(
          (entry) => _AssetDeviceDocument(
            path: entry.path,
            fileName: entry.fileName,
            contentType: entry.contentType,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    manufacturerReferenceController.dispose();
    internalReferenceController.dispose();
    qrController.dispose();
    super.dispose();
  }

  String? get currentQrValue {
    final trimmed = qrController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> save() async {
    if (!widget.canEdit) return;

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome do dispositivo e obrigatorio.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final payload = {
      'name': nameController.text.trim(),
      'description': _nullableTrimmed(descriptionController.text),
      'manufacturer_reference': _nullableTrimmed(
        manufacturerReferenceController.text,
      ),
      'internal_reference': _nullableTrimmed(internalReferenceController.text),
      'qr_code': _nullableTrimmed(qrController.text),
      'documentation': documentation.map((entry) => entry.toMap()).toList(),
    };

    String? cleanupWarning;

    try {
      if (widget.isEditing) {
        await AssetDeviceService.instance.updateDevice(
          deviceId: widget.device!['id'],
          payload: payload,
        );
      } else {
        await AssetDeviceService.instance.createDevice(
          assetId: widget.asset['id'],
          payload: payload,
        );
      }

      try {
        await _cleanupRemovedDocumentation();
      } catch (_) {
        cleanupWarning =
            'O dispositivo foi guardado, mas alguns documentos removidos ficaram no armazenamento.';
      }

      if (!mounted) return;
      if (cleanupWarning != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanupWarning)));
      }
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Nao foi possivel atualizar o dispositivo.'
                : 'Nao foi possivel guardar o dispositivo.',
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> delete() async {
    if (!widget.canDelete || !widget.isEditing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar dispositivo'),
          content: Text(
            'Queres eliminar o dispositivo "${widget.device!['name']?.toString() ?? 'sem nome'}"?',
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

    if (confirmed != true) return;

    setState(() {
      isDeleting = true;
    });

    String? cleanupWarning;

    try {
      await AssetDeviceService.instance.deleteDevice(
        deviceId: widget.device!['id'],
      );

      try {
        await StorageService.instance.deleteStoredObjects(
          bucket: 'company-media',
          storedValues: documentation.map((entry) => entry.path),
        );
      } catch (_) {
        cleanupWarning =
            'O dispositivo foi eliminado, mas alguns documentos ficaram no armazenamento.';
      }

      if (!mounted) return;
      if (cleanupWarning != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanupWarning)));
      }
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel eliminar o dispositivo.'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isDeleting = false;
      });
    }
  }

  Future<void> addDocumentation() async {
    if (!widget.canEdit) return;

    final assetId = widget.asset['id']?.toString().trim() ?? '';
    if (assetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nao foi possivel identificar o ativo deste dispositivo.',
          ),
        ),
      );
      return;
    }

    try {
      final uploadedEntries = await StorageService.instance
          .pickAndUploadAssetDeviceDocumentation(assetId: assetId);

      if (!mounted || uploadedEntries.isEmpty) return;

      setState(() {
        documentation = [
          ...documentation,
          ...uploadedEntries.map(_AssetDeviceDocument.fromMap),
        ];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel anexar a documentacao: $error'),
        ),
      );
    }
  }

  Future<void> openDocumentation(_AssetDeviceDocument entry) async {
    final uri = await StorageService.instance.resolveFileUri(
      bucket: 'company-media',
      storedValue: entry.path,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _cleanupRemovedDocumentation() async {
    final initialPaths = initialDocumentation
        .map((entry) => entry.path)
        .toSet();
    final currentPaths = documentation.map((entry) => entry.path).toSet();
    final removedPaths = initialPaths.difference(currentPaths);

    if (removedPaths.isEmpty) return;

    await StorageService.instance.deleteStoredObjects(
      bucket: 'company-media',
      storedValues: removedPaths,
    );
  }

  void removeDocumentation(_AssetDeviceDocument entry) {
    setState(() {
      documentation = documentation
          .where((item) => item.path != entry.path)
          .toList();
    });
  }

  void generateQrCodeValue() {
    final generated = AssetQrSupport.generateDeviceValue(
      deviceId: widget.device?['id'],
      assetName: widget.asset['name']?.toString(),
      deviceName: nameController.text.trim(),
    );

    setState(() {
      qrController.text = generated;
    });
  }

  Future<void> scanExistingQrCode() async {
    final scannedQrValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AssetQrScannerPage()),
    );

    if (!mounted || scannedQrValue == null || scannedQrValue.trim().isEmpty) {
      return;
    }

    setState(() {
      qrController.text = scannedQrValue.trim();
    });
  }

  String? _nullableTrimmed(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final assetName = widget.asset['name']?.toString() ?? 'Ativo';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? (widget.canEdit ? 'Editar dispositivo' : 'Dispositivo')
              : 'Novo dispositivo',
        ),
      ),
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
                    'Ativo pai',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(assetName),
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
                    'Dados do dispositivo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    enabled: widget.canEdit && !isSaving && !isDeleting,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    enabled: widget.canEdit && !isSaving && !isDeleting,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Descricao'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: manufacturerReferenceController,
                    enabled: widget.canEdit && !isSaving && !isDeleting,
                    decoration: const InputDecoration(
                      labelText: 'Ref. de fabricante',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: internalReferenceController,
                    enabled: widget.canEdit && !isSaving && !isDeleting,
                    decoration: const InputDecoration(
                      labelText: 'Referencia interna',
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
                    'QR do dispositivo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cada dispositivo pode ter um QR proprio para identificacao rapida no terreno.',
                  ),
                  const SizedBox(height: 12),
                  AssetQrCard(
                    qrValue: currentQrValue,
                    canEdit: widget.canEdit && !isSaving && !isDeleting,
                    onGenerate: generateQrCodeValue,
                    onScan: scanExistingQrCode,
                    emptyMessage:
                        'Este dispositivo ainda nao tem codigo QR associado.',
                    generateLabel: currentQrValue?.isNotEmpty == true
                        ? 'Gerar novo QR do dispositivo'
                        : 'Gerar QR do dispositivo',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qrController,
                    enabled: widget.canEdit && !isSaving && !isDeleting,
                    decoration: const InputDecoration(
                      labelText: 'Codigo QR',
                      hintText: 'Valor gravado no QR do dispositivo',
                    ),
                    onChanged: (_) {
                      setState(() {});
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
                    'Documentacao',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Podes anexar fotografias ou PDF para deixar fichas tecnicas, imagens de detalhe ou manuais ligados ao dispositivo.',
                  ),
                  if (widget.canEdit) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isSaving || isDeleting
                          ? null
                          : addDocumentation,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Anexar fotografias ou PDF'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (documentation.isEmpty)
                    const Text('Sem documentacao anexada.')
                  else
                    ...documentation.map(
                      (entry) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            entry.isPdf
                                ? Icons.picture_as_pdf_outlined
                                : Icons.image_outlined,
                          ),
                          title: Text(entry.fileName),
                          subtitle: Text(entry.isPdf ? 'PDF' : 'Fotografia'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => openDocumentation(entry),
                                icon: const Icon(Icons.open_in_new),
                                tooltip: 'Abrir',
                              ),
                              if (widget.canEdit)
                                IconButton(
                                  onPressed: () => removeDocumentation(entry),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remover',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.canEdit) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isSaving || isDeleting ? null : save,
              icon: const Icon(Icons.save),
              label: Text(
                isSaving
                    ? 'A guardar...'
                    : widget.isEditing
                    ? 'Atualizar dispositivo'
                    : 'Guardar dispositivo',
              ),
            ),
          ],
          if (widget.canDelete && widget.isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isSaving || isDeleting ? null : delete,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                isDeleting ? 'A eliminar...' : 'Eliminar dispositivo',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssetDeviceDocument {
  const _AssetDeviceDocument({
    required this.path,
    required this.fileName,
    required this.contentType,
  });

  final String path;
  final String fileName;
  final String contentType;

  bool get isPdf => contentType == 'application/pdf';

  Map<String, dynamic> toMap() {
    return {'path': path, 'file_name': fileName, 'content_type': contentType};
  }

  static _AssetDeviceDocument fromMap(Map<String, dynamic> map) {
    final path = map['path']?.toString().trim() ?? '';
    final fileName = map['file_name']?.toString().trim();
    final contentType = map['content_type']?.toString().trim();

    return _AssetDeviceDocument(
      path: path,
      fileName: fileName == null || fileName.isEmpty
          ? _fallbackFileName(path)
          : fileName,
      contentType: contentType == null || contentType.isEmpty
          ? _fallbackContentType(fileName ?? path)
          : contentType,
    );
  }

  static List<_AssetDeviceDocument> readAll(dynamic value) {
    if (value is! List) return const [];

    final items = <_AssetDeviceDocument>[];
    for (final entry in value) {
      if (entry is Map) {
        final mapped = Map<String, dynamic>.from(entry);
        final path = mapped['path']?.toString().trim() ?? '';
        if (path.isEmpty) continue;
        items.add(fromMap(mapped));
      }
    }
    return items;
  }

  static String _fallbackFileName(String path) {
    final segments = path.split('/');
    final candidate = segments.isEmpty ? path : segments.last;
    return candidate.trim().isEmpty ? 'documento' : candidate;
  }

  static String _fallbackContentType(String value) {
    final normalized = value.toLowerCase();
    if (normalized.endsWith('.pdf')) {
      return 'application/pdf';
    }
    return 'image/jpeg';
  }
}
