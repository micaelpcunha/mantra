import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/storage_service.dart';
import 'work_order_helpers.dart';

class WorkOrderPdfOptions {
  const WorkOrderPdfOptions({
    this.includeSummary = true,
    this.includeDescription = true,
    this.includeAssignment = true,
    this.includeDatesAndType = true,
    this.includeRequirements = true,
    this.includeMeasurement = true,
    this.includeObservations = true,
    this.includeProcedure = true,
    this.includePhoto = true,
    this.includeAttachments = true,
  });

  final bool includeSummary;
  final bool includeDescription;
  final bool includeAssignment;
  final bool includeDatesAndType;
  final bool includeRequirements;
  final bool includeMeasurement;
  final bool includeObservations;
  final bool includeProcedure;
  final bool includePhoto;
  final bool includeAttachments;

  bool get hasSelection =>
      includeSummary ||
      includeDescription ||
      includeAssignment ||
      includeDatesAndType ||
      includeRequirements ||
      includeMeasurement ||
      includeObservations ||
      includeProcedure ||
      includePhoto ||
      includeAttachments;

  WorkOrderPdfOptions copyWith({
    bool? includeSummary,
    bool? includeDescription,
    bool? includeAssignment,
    bool? includeDatesAndType,
    bool? includeRequirements,
    bool? includeMeasurement,
    bool? includeObservations,
    bool? includeProcedure,
    bool? includePhoto,
    bool? includeAttachments,
  }) {
    return WorkOrderPdfOptions(
      includeSummary: includeSummary ?? this.includeSummary,
      includeDescription: includeDescription ?? this.includeDescription,
      includeAssignment: includeAssignment ?? this.includeAssignment,
      includeDatesAndType: includeDatesAndType ?? this.includeDatesAndType,
      includeRequirements: includeRequirements ?? this.includeRequirements,
      includeMeasurement: includeMeasurement ?? this.includeMeasurement,
      includeObservations: includeObservations ?? this.includeObservations,
      includeProcedure: includeProcedure ?? this.includeProcedure,
      includePhoto: includePhoto ?? this.includePhoto,
      includeAttachments: includeAttachments ?? this.includeAttachments,
    );
  }
}

class WorkOrderPdfService {
  WorkOrderPdfService._();

  static final WorkOrderPdfService instance = WorkOrderPdfService._();

  Future<Uint8List> buildPdf({
    required Map<String, dynamic> task,
    required Map<String, dynamic> asset,
    required String? technicianName,
    required String? locationName,
    required WorkOrderPdfOptions options,
  }) async {
    final document = pw.Document();
    final attachmentUri = options.includeAttachments
        ? await _resolvePrivateFileUri(workOrderAttachmentUrl(task))
        : null;
    final audioNoteUri = options.includeAttachments
        ? await _resolvePrivateFileUri(workOrderAudioNoteUrl(task))
        : null;
    final photoBlock = options.includePhoto
        ? await _buildPhotoBlock(workOrderPhotoUrl(task))
        : null;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            workOrderTitle(task),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Gerado em ${formatDateValue(DateTime.now().toIso8601String())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 18),
          if (options.includeSummary)
            _buildSection(
              title: 'Resumo',
              children: [
                _buildFieldGrid([
                  _PdfField('Estado', task['status']?.toString() ?? '-'),
                  _PdfField(
                    'Referencia',
                    workOrderReference(task).trim().isEmpty
                        ? '-'
                        : workOrderReference(task).trim(),
                  ),
                  _PdfField(
                    'Ativo',
                    asset['name']?.toString().trim().isEmpty ?? true
                        ? 'Sem ativo'
                        : asset['name']!.toString().trim(),
                  ),
                  _PdfField(
                    'Equipamento',
                    workOrderAssetDeviceName(task).trim().isEmpty
                        ? 'Sem equipamento'
                        : workOrderAssetDeviceName(task).trim(),
                  ),
                ]),
              ],
            ),
          if (options.includeDescription)
            _buildSection(
              title: 'Descricao',
              children: [
                _buildParagraph(
                  workOrderDescription(task).trim().isEmpty
                      ? 'Sem descricao.'
                      : workOrderDescription(task).trim(),
                ),
              ],
            ),
          if (options.includeAssignment)
            _buildSection(
              title: 'Atribuicao',
              children: [
                _buildFieldGrid([
                  _PdfField(
                    'Tecnico',
                    technicianName?.trim().isNotEmpty == true
                        ? technicianName!.trim()
                        : 'Sem tecnico',
                  ),
                  _PdfField(
                    'Localizacao',
                    locationName?.trim().isNotEmpty == true
                        ? locationName!.trim()
                        : 'Sem localizacao',
                  ),
                ]),
              ],
            ),
          if (options.includeDatesAndType)
            _buildSection(
              title: 'Datas e tipo',
              children: [
                _buildFieldGrid([
                  _PdfField(
                    'Tipo de ordem',
                    workOrderTypeLabel(workOrderType(task)),
                  ),
                  _PdfField(
                    'Data de criacao',
                    formatDateValue(task['created_at']),
                  ),
                  _PdfField(
                    'Data planeada',
                    formatDateOnlyValue(workOrderScheduledFor(task)),
                  ),
                  _PdfField(
                    'Ultima alteracao',
                    formatDateValue(workOrderUpdatedAt(task)),
                  ),
                  if (isPreventiveOrder(task))
                    _PdfField('Recorrencia', recurrenceSummary(task)),
                ]),
              ],
            ),
          if (options.includeRequirements &&
              (supportsWorkOrderRequirements(task) ||
                  AssetQrSupportLabel.fromAsset(asset).isNotEmpty))
            _buildSection(
              title: 'Requisitos',
              children: [
                _buildParagraph(
                  [
                        if (workOrderRequiresPhoto(task))
                          'Fotografia obrigatoria',
                        if (workOrderRequiresMeasurement(task))
                          'Medicao obrigatoria',
                        if (AssetQrSupportLabel.fromAsset(asset).isNotEmpty)
                          AssetQrSupportLabel.fromAsset(asset),
                      ].isEmpty
                      ? 'Sem requisitos especiais.'
                      : [
                          if (workOrderRequiresPhoto(task))
                            'Fotografia obrigatoria',
                          if (workOrderRequiresMeasurement(task))
                            'Medicao obrigatoria',
                          if (AssetQrSupportLabel.fromAsset(asset).isNotEmpty)
                            AssetQrSupportLabel.fromAsset(asset),
                        ].join(' | '),
                ),
              ],
            ),
          if (options.includeMeasurement)
            _buildSection(
              title: 'Medicao',
              children: [
                _buildParagraph(
                  workOrderMeasurement(task).trim().isEmpty
                      ? 'Sem medicao registada.'
                      : workOrderMeasurement(task).trim(),
                ),
              ],
            ),
          if (options.includeObservations)
            _buildSection(
              title: 'Observacoes',
              children: [
                _buildParagraph(
                  workOrderObservations(task).trim().isEmpty
                      ? 'Sem observacoes.'
                      : workOrderObservations(task).trim(),
                ),
              ],
            ),
          if (options.includeProcedure) ..._buildProcedureSection(task),
          if (options.includePhoto && photoBlock != null)
            _buildSection(title: 'Fotografia', children: [photoBlock]),
          if (options.includeAttachments)
            _buildSection(
              title: 'Anexos e referencias',
              children: [
                _buildLinkLine(
                  label: 'Anexo',
                  uri: attachmentUri,
                  fallbackText: workOrderAttachmentUrl(task).trim().isEmpty
                      ? 'Sem anexo.'
                      : 'Anexo associado, mas sem URL disponivel.',
                ),
                pw.SizedBox(height: 8),
                _buildLinkLine(
                  label: 'Nota audio',
                  uri: audioNoteUri,
                  fallbackText: workOrderAudioNoteUrl(task).trim().isEmpty
                      ? 'Sem nota audio.'
                      : 'Nota audio associada, mas sem URL disponivel.',
                ),
              ],
            ),
        ],
      ),
    );

    return Uint8List.fromList(await document.save());
  }

  Future<Uri?> _resolvePrivateFileUri(String storedValue) async {
    final value = storedValue.trim();
    if (value.isEmpty) return null;
    try {
      return await StorageService.instance.resolveFileUri(
        bucket: 'work-order-attachments',
        storedValue: value,
      );
    } catch (_) {
      return null;
    }
  }

  Future<pw.Widget> _buildPhotoBlock(String photoUrl) async {
    if (photoUrl.trim().isEmpty) {
      return _buildParagraph('Sem fotografia associada.');
    }

    try {
      final provider = await networkImage(
        photoUrl,
      ).timeout(const Duration(seconds: 4));
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFD7DFD7)),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Image(provider, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'URL original: $photoUrl',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      );
    } catch (_) {
      return _buildParagraph(
        'Existe uma fotografia associada, mas nao foi possivel incorpora-la no PDF.\n$photoUrl',
      );
    }
  }

  List<pw.Widget> _buildProcedureSection(Map<String, dynamic> task) {
    final steps = workOrderProcedureSteps(task);
    if (steps.isEmpty) {
      return [
        _buildSection(
          title: 'Procedimento',
          children: [_buildParagraph('Sem procedimento associado.')],
        ),
      ];
    }

    final rows = <List<String>>[
      ['Passo', 'Estado', 'Regras'],
      ...steps.map((step) {
        return [
          step.title.trim().isEmpty ? 'Sem titulo' : step.title.trim(),
          step.isChecked ? 'Concluido' : 'Por fazer',
          [
                if (step.isRequired) 'Obrigatorio',
                if (step.requiresPhoto) 'Fotografia',
                if (step.hasPhoto) 'Com foto',
              ].isEmpty
              ? '-'
              : [
                  if (step.isRequired) 'Obrigatorio',
                  if (step.requiresPhoto) 'Fotografia',
                  if (step.hasPhoto) 'Com foto',
                ].join(' | '),
        ];
      }),
    ];

    return [
      _buildSection(
        title: workOrderProcedureName(task).trim().isEmpty
            ? 'Procedimento'
            : workOrderProcedureName(task).trim(),
        children: [
          pw.TableHelper.fromTextArray(
            headers: rows.first,
            data: rows.skip(1).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE5ECE6),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
          ),
        ],
      ),
    ];
  }

  pw.Widget _buildSection({
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _buildFieldGrid(List<_PdfField> fields) {
    final validFields = fields
        .where((field) => field.value.trim().isNotEmpty)
        .toList();
    if (validFields.isEmpty) {
      return _buildParagraph('Sem dados disponiveis.');
    }

    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: validFields.map(_buildFieldCard).toList(),
    );
  }

  pw.Widget _buildFieldCard(_PdfField field) {
    return pw.Container(
      width: 240,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD7DFD7)),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(field.label, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(
            field.value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildParagraph(String text) {
    return pw.Text(
      text.trim().isEmpty ? '-' : text.trim(),
      style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
    );
  }

  pw.Widget _buildLinkLine({
    required String label,
    required Uri? uri,
    required String fallbackText,
  }) {
    if (uri == null) {
      return pw.Text(
        '$label: $fallbackText',
        style: const pw.TextStyle(fontSize: 10),
      );
    }

    return pw.UrlLink(
      destination: uri.toString(),
      child: pw.Text(
        '$label: ${uri.toString()}',
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColors.blue,
          decoration: pw.TextDecoration.underline,
        ),
      ),
    );
  }
}

class _PdfField {
  const _PdfField(this.label, this.value);

  final String label;
  final String value;
}

class AssetQrSupportLabel {
  static String fromAsset(Map<String, dynamic> asset) {
    final requiresQr = asset['requires_qr_scan_for_maintenance'] == true;
    if (!requiresQr) return '';
    return 'Leitura de QR obrigatoria';
  }
}
