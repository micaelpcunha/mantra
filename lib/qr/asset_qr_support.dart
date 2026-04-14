import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetQrSupport {
  static String? qrValueFromAsset(Map<String, dynamic> asset) {
    final value = asset['qr_code']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static bool requiresQrForMaintenance(Map<String, dynamic> asset) {
    final value = asset['requires_qr_scan_for_maintenance'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'sim';
    }
    return false;
  }

  static String generateValue({dynamic assetId, String? assetName}) {
    return _generateEntityValue(
      prefix: 'ASSET',
      entityId: assetId,
      primaryName: assetName,
    );
  }

  static String generateDeviceValue({
    dynamic deviceId,
    String? assetName,
    String? deviceName,
  }) {
    return _generateEntityValue(
      prefix: 'DEVICE',
      entityId: deviceId,
      primaryName: assetName,
      secondaryName: deviceName,
    );
  }

  static String _generateEntityValue({
    required String prefix,
    dynamic entityId,
    String? primaryName,
    String? secondaryName,
  }) {
    final normalizedPrimaryName = _normalizeForQr(primaryName);
    final normalizedSecondaryName = _normalizeForQr(secondaryName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (entityId != null) {
      return '$prefix-${entityId.toString().toUpperCase()}';
    }

    final nameParts = [
      normalizedPrimaryName,
      normalizedSecondaryName,
    ].where((value) => value.isNotEmpty).join('-');

    if (nameParts.isNotEmpty) {
      return '$prefix-$nameParts-$timestamp';
    }

    return '$prefix-$timestamp';
  }

  static String _normalizeForQr(String? value) {
    return (value ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static Map<String, dynamic> copyWithQrValue(
    Map<String, dynamic> asset,
    String qrValue,
  ) {
    return {...asset, 'qr_code': qrValue};
  }

  static Map<String, dynamic> copyWithRequiresQrForMaintenance(
    Map<String, dynamic> asset,
    bool value,
  ) {
    return {...asset, 'requires_qr_scan_for_maintenance': value};
  }

  static Future<void> saveQrValue({
    required SupabaseClient supabase,
    required dynamic assetId,
    required String qrValue,
  }) async {
    await supabase
        .from('assets')
        .update({'qr_code': qrValue})
        .eq('id', assetId);
  }

  static Future<void> saveRequiresQrForMaintenance({
    required SupabaseClient supabase,
    required dynamic assetId,
    required bool value,
  }) async {
    await supabase
        .from('assets')
        .update({'requires_qr_scan_for_maintenance': value})
        .eq('id', assetId);
  }
}

class AssetQrCard extends StatelessWidget {
  const AssetQrCard({
    super.key,
    required this.qrValue,
    required this.canEdit,
    required this.onGenerate,
    required this.onScan,
    this.emptyMessage = 'Este ativo ainda nao tem codigo QR associado.',
    this.generateLabel,
    this.scanLabel = 'Ler QR existente',
  });

  final String? qrValue;
  final bool canEdit;
  final VoidCallback onGenerate;
  final VoidCallback onScan;
  final String emptyMessage;
  final String? generateLabel;
  final String scanLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (qrValue?.isNotEmpty == true) ...[
            QrImageView(
              data: qrValue!,
              size: 180,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            SelectableText(
              qrValue!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            const Icon(Icons.qr_code_2, size: 56),
            const SizedBox(height: 8),
            Text(emptyMessage, textAlign: TextAlign.center),
          ],
          if (canEdit) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    generateLabel ??
                        (qrValue?.isNotEmpty == true
                            ? 'Gerar novo QR'
                            : 'Gerar QR'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(scanLabel),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AssetQrScannerPage extends StatefulWidget {
  const AssetQrScannerPage({super.key});

  @override
  State<AssetQrScannerPage> createState() => _AssetQrScannerPageState();
}

class _AssetQrScannerPageState extends State<AssetQrScannerPage> {
  bool hasScanned = false;

  void _handleDetection(BarcodeCapture capture) {
    if (hasScanned) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        hasScanned = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ler codigo QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _handleDetection),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Aponte a camara para um QR existente para o associar ou validar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
