import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'work_orders/task_detail_page.dart';
import 'work_orders/work_order_helpers.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> workOrders = [];
  List<Map<String, dynamic>> assets = [];
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> technicians = [];

  String periodFilter = '90';
  String statusFilter = 'todos';
  String typeFilter = 'todas';
  String technicianFilter = 'todos';
  String locationFilter = 'todas';
  String assetFilter = 'todos';
  String equipmentFilter = 'todos';
  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase
            .from('work_orders')
            .select()
            .order('created_at', ascending: false),
        supabase.from('assets').select().order('name'),
        supabase.from('locations').select().order('name'),
        supabase.from('technicians').select('id, name').order('name'),
      ]);

      if (!mounted) return;

      setState(() {
        workOrders = List<Map<String, dynamic>>.from(results[0] as List);
        assets = List<Map<String, dynamic>>.from(results[1] as List);
        locations = List<Map<String, dynamic>>.from(results[2] as List);
        technicians = List<Map<String, dynamic>>.from(results[3] as List);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar os relatorios.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime? get _periodStart {
    final now = DateTime.now();
    switch (periodFilter) {
      case '30':
        return now.subtract(const Duration(days: 30));
      case '90':
        return now.subtract(const Duration(days: 90));
      case '365':
        return now.subtract(const Duration(days: 365));
      case 'custom':
        return customStartDate;
      case 'all':
      default:
        return null;
    }
  }

  DateTime? get _periodEnd {
    if (periodFilter != 'custom' || customEndDate == null) return null;
    return DateTime(
      customEndDate!.year,
      customEndDate!.month,
      customEndDate!.day,
      23,
      59,
      59,
    );
  }

  Map<String, String> get technicianNamesById => {
    for (final technician in technicians)
      technician['id']?.toString() ?? '': technician['name']?.toString() ?? '',
  };

  Map<String, String> get locationNamesById => {
    for (final location in locations)
      location['id']?.toString() ?? '': location['name']?.toString() ?? '',
  };

  Map<String, Map<String, dynamic>> get assetsById => {
    for (final asset in assets) asset['id']?.toString() ?? '': asset,
  };

  String _equipmentFilterValueForOrder(Map<String, dynamic> order) {
    final equipmentId = workOrderAssetDeviceId(order);
    if (equipmentId != null && equipmentId.isNotEmpty) {
      return 'id:$equipmentId';
    }

    final equipmentName = workOrderAssetDeviceName(order).trim();
    if (equipmentName.isEmpty) return '';
    return 'name:${equipmentName.toLowerCase()}';
  }

  String _equipmentLabelForOrder(Map<String, dynamic> order) {
    final equipmentName = workOrderAssetDeviceName(order).trim();
    if (equipmentName.isNotEmpty) return equipmentName;

    final equipmentId = workOrderAssetDeviceId(order);
    if (equipmentId == null || equipmentId.isEmpty) {
      return 'Sem equipamento';
    }
    return 'Equipamento $equipmentId';
  }

  bool _matchesOrderFilters(
    Map<String, dynamic> order, {
    bool includeAsset = true,
    bool includeEquipment = true,
  }) {
    final periodStart = _periodStart;
    final periodEnd = _periodEnd;
    final createdAt = parseDateValue(order['created_at']);
    final status = order['status']?.toString() ?? '';
    final orderType = workOrderType(order);
    final technicianId = order['technician_id']?.toString() ?? '';
    final assetId = order['asset_id']?.toString() ?? '';
    final asset = assetsById[assetId];
    final locationId = asset?['location_id']?.toString() ?? '';
    final equipmentValue = _equipmentFilterValueForOrder(order);

    return (periodStart == null ||
            (createdAt != null && !createdAt.isBefore(periodStart))) &&
        (periodEnd == null ||
            (createdAt != null && !createdAt.isAfter(periodEnd))) &&
        (statusFilter == 'todos' || status == statusFilter) &&
        (typeFilter == 'todas' || orderType == typeFilter) &&
        (technicianFilter == 'todos' || technicianId == technicianFilter) &&
        (locationFilter == 'todas' || locationId == locationFilter) &&
        (!includeAsset || assetFilter == 'todos' || assetId == assetFilter) &&
        (!includeEquipment ||
            equipmentFilter == 'todos' ||
            equipmentValue == equipmentFilter);
  }

  List<Map<String, dynamic>> _filteredOrdersForOptions({
    bool includeAsset = true,
    bool includeEquipment = true,
  }) {
    return workOrders
        .where(
          (order) => _matchesOrderFilters(
            order,
            includeAsset: includeAsset,
            includeEquipment: includeEquipment,
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> get filteredOrders {
    return _filteredOrdersForOptions();
  }

  List<_FilterOption> get assetFilterOptions {
    final items =
        assets
            .map(
              (asset) => _FilterOption(
                value: asset['id']?.toString() ?? '',
                label: asset['name']?.toString().trim() ?? '',
              ),
            )
            .where((item) => item.value.isNotEmpty && item.label.isNotEmpty)
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );

    return [const _FilterOption(value: 'todos', label: 'Todos'), ...items];
  }

  List<_FilterOption> get equipmentFilterOptions {
    final labelsByValue = <String, String>{};
    for (final order in _filteredOrdersForOptions(includeEquipment: false)) {
      final value = _equipmentFilterValueForOrder(order);
      final label = _equipmentLabelForOrder(order);
      if (value.isEmpty || label == 'Sem equipamento') continue;
      labelsByValue.putIfAbsent(value, () => label);
    }

    final items =
        labelsByValue.entries
            .map((entry) => _FilterOption(value: entry.key, label: entry.value))
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );

    return [const _FilterOption(value: 'todos', label: 'Todos'), ...items];
  }

  void _normalizeEquipmentFilter() {
    final availableValues = equipmentFilterOptions
        .map((option) => option.value)
        .toSet();
    if (!availableValues.contains(equipmentFilter)) {
      equipmentFilter = 'todos';
    }
  }

  int get openCount => filteredOrders
      .where((order) => order['status']?.toString() != 'concluido')
      .length;

  int get completedCount => filteredOrders
      .where((order) => order['status']?.toString() == 'concluido')
      .length;

  int get overdueCount {
    final now = DateTime.now();
    return filteredOrders.where((order) {
      final scheduled = parseDateValue(workOrderScheduledFor(order));
      return scheduled != null &&
          scheduled.isBefore(now) &&
          order['status']?.toString() != 'concluido';
    }).length;
  }

  int get plannedCount => filteredOrders
      .where((order) => parseDateValue(workOrderScheduledFor(order)) != null)
      .length;

  List<Map<String, dynamic>> get measurementVerificationOrders => filteredOrders
      .where((order) => workOrderType(order) == 'medicoes_verificacoes')
      .toList();

  int get measurementVerificationCount => measurementVerificationOrders.length;

  int get measurementVerificationCompletedCount => measurementVerificationOrders
      .where((order) => order['status']?.toString() == 'concluido')
      .length;

  int get measurementVerificationWithReadingCount =>
      measurementVerificationOrders
          .where((order) => workOrderMeasurement(order).trim().isNotEmpty)
          .length;

  List<_NamedCount> _sortCounts(Map<String, int> counts) {
    final items =
        counts.entries
            .map((entry) => _NamedCount(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(8).toList();
  }

  List<_NamedCount> get ordersByTechnician {
    final counts = <String, int>{};
    for (final order in filteredOrders) {
      final label =
          technicianNamesById[order['technician_id']?.toString() ?? ''] ??
          'Sem tecnico';
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return _sortCounts(counts);
  }

  List<_NamedCount> get ordersByLocation {
    final counts = <String, int>{};
    for (final order in filteredOrders) {
      final asset = assetsById[order['asset_id']?.toString() ?? ''];
      final label =
          locationNamesById[asset?['location_id']?.toString() ?? ''] ??
          'Sem localizacao';
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return _sortCounts(counts);
  }

  List<_NamedCount> get topAssetsByOrders {
    final counts = <String, int>{};
    for (final order in filteredOrders) {
      final asset = assetsById[order['asset_id']?.toString() ?? ''];
      final label = asset?['name']?.toString() ?? 'Ativo removido';
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return _sortCounts(counts);
  }

  List<Map<String, dynamic>> get overdueOrders {
    final now = DateTime.now();
    final items =
        filteredOrders.where((order) {
          final scheduled = parseDateValue(workOrderScheduledFor(order));
          return scheduled != null &&
              scheduled.isBefore(now) &&
              order['status']?.toString() != 'concluido';
        }).toList()..sort((a, b) {
          final aDate = parseDateValue(workOrderScheduledFor(a));
          final bDate = parseDateValue(workOrderScheduledFor(b));
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

    return items.take(8).toList();
  }

  List<_NamedCount> get qualityIndicators => [
    _NamedCount(
      'Ativos sem QR',
      assets
          .where((asset) => (asset['qr_code']?.toString().trim() ?? '').isEmpty)
          .length,
    ),
    _NamedCount(
      'Ativos sem foto',
      assets
          .where(
            (asset) =>
                (asset['profile_photo_url']?.toString().trim() ?? '').isEmpty,
          )
          .length,
    ),
    _NamedCount(
      'Ordens sem tecnico',
      filteredOrders
          .where(
            (order) =>
                (order['technician_id']?.toString().trim() ?? '').isEmpty,
          )
          .length,
    ),
    _NamedCount(
      'Ordens sem data planeada',
      filteredOrders
          .where(
            (order) => parseDateValue(workOrderScheduledFor(order)) == null,
          )
          .length,
    ),
  ];

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  String get periodSummary {
    switch (periodFilter) {
      case '30':
        return 'Ultimos 30 dias';
      case '90':
        return 'Ultimos 90 dias';
      case '365':
        return 'Ultimo ano';
      case 'custom':
        if (customStartDate == null && customEndDate == null) {
          return 'Periodo personalizado';
        }
        return '${_formatDate(customStartDate)} ate ${_formatDate(customEndDate)}';
      case 'all':
      default:
        return 'Tudo';
    }
  }

  Future<void> pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(
        start: customStartDate ?? now.subtract(const Duration(days: 30)),
        end: customEndDate ?? now,
      ),
      helpText: 'Escolher periodo do relatorio',
      saveText: 'Aplicar',
    );

    if (picked == null) return;

    setState(() {
      customStartDate = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      customEndDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
      periodFilter = 'custom';
      _normalizeEquipmentFilter();
    });
  }

  Future<void> openWorkOrderDetail(Map<String, dynamic> order) async {
    final asset =
        assetsById[order['asset_id']?.toString() ?? ''] ??
        {'id': order['asset_id'], 'name': 'Ativo'};

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          task: order,
          asset: asset,
          canManageAll: true,
          canEditFullOrder: true,
          canCloseWorkOrder: true,
          technicianName:
              technicianNamesById[order['technician_id']?.toString() ?? ''],
          locationName:
              locationNamesById[asset['location_id']?.toString() ?? ''],
        ),
      ),
    );

    if (changed == true) {
      await loadReports();
    }
  }

  String buildCsvReport() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Titulo,Referencia,Estado,Tipo,Tecnico,Localizacao,Ativo,Equipamento,Data planeada,Criada em,Observacoes',
    );

    for (final order in filteredOrders) {
      final asset = assetsById[order['asset_id']?.toString() ?? ''];
      final values = [
        workOrderTitle(order),
        workOrderReference(order),
        order['status']?.toString() ?? '',
        workOrderTypeLabel(workOrderType(order)),
        technicianNamesById[order['technician_id']?.toString() ?? ''] ??
            'Sem tecnico',
        locationNamesById[asset?['location_id']?.toString() ?? ''] ??
            'Sem localizacao',
        asset?['name']?.toString() ?? 'Sem ativo',
        workOrderAssetDeviceName(order).trim().isEmpty
            ? 'Sem equipamento'
            : workOrderAssetDeviceName(order).trim(),
        _formatDate(parseDateValue(workOrderScheduledFor(order))),
        _formatDate(parseDateValue(order['created_at'])),
        workOrderObservations(order),
      ];

      buffer.writeln(values.map(_escapeCsv).join(','));
    }

    return buffer.toString();
  }

  String _escapeCsv(String value) {
    final normalized = value.replaceAll('"', '""').replaceAll('\n', ' ').trim();
    return '"$normalized"';
  }

  Future<void> copyCsvReport() async {
    final csv = buildCsvReport();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV do relatorio copiado para a area de transferencia.'),
      ),
    );
  }

  String get _reportFileSuffix =>
      '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}';

  XFile _buildShareFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) {
    return XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: mimeType,
      name: fileName,
    );
  }

  Future<void> exportCsvFile() async {
    try {
      final csv = buildCsvReport();
      final file = _buildShareFile(
        fileName: 'relatorio_$_reportFileSuffix.csv',
        bytes: utf8.encode(csv),
        mimeType: 'text/csv',
      );

      await Share.shareXFiles(
        [file],
        subject: 'Relatorio CSV',
        text: 'Relatorio exportado em CSV.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV preparado para exportacao.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel exportar o CSV: $e')),
      );
    }
  }

  Future<Uint8List> buildPdfReport() async {
    final document = pw.Document();
    final headers = [
      'Titulo',
      'Estado',
      'Tipo',
      'Tecnico',
      'Localizacao',
      'Ativo',
      'Equipamento',
      'Planeada',
    ];

    final rows = filteredOrders.map((order) {
      final asset = assetsById[order['asset_id']?.toString() ?? ''];
      return [
        workOrderTitle(order),
        order['status']?.toString() ?? '',
        workOrderTypeLabel(workOrderType(order)),
        technicianNamesById[order['technician_id']?.toString() ?? ''] ??
            'Sem tecnico',
        locationNamesById[asset?['location_id']?.toString() ?? ''] ??
            'Sem localizacao',
        asset?['name']?.toString() ?? 'Sem ativo',
        workOrderAssetDeviceName(order).trim().isEmpty
            ? 'Sem equipamento'
            : workOrderAssetDeviceName(order).trim(),
        _formatDate(parseDateValue(workOrderScheduledFor(order))),
      ];
    }).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Relatorio de manutencao',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Gerado em ${_formatDate(DateTime.now())} | Periodo: $periodSummary',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pdfMetric('Ordens', filteredOrders.length.toString()),
              _pdfMetric('Em aberto', openCount.toString()),
              _pdfMetric('Concluidas', completedCount.toString()),
              _pdfMetric('Atrasadas', overdueCount.toString()),
            ],
          ),
          pw.SizedBox(height: 18),
          if (rows.isEmpty)
            pw.Text('Nao existem ordens para os filtros selecionados.')
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
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
    );

    return Uint8List.fromList(await document.save());
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD7DFD7)),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> previewPdfReport() async {
    try {
      final bytes = await buildPdfReport();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'relatorio_$_reportFileSuffix.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel gerar o PDF: $e')),
      );
    }
  }

  Future<void> sharePdfReport() async {
    try {
      final bytes = await buildPdfReport();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'relatorio_$_reportFileSuffix.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel exportar o PDF: $e')),
      );
    }
  }

  Future<void> openPreview() async {
    if (filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao existem ordens para previsualizar.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Previsualizacao do relatorio',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${filteredOrders.length} ordens para os filtros atuais.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Titulo')),
                            DataColumn(label: Text('Estado')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Tecnico')),
                            DataColumn(label: Text('Localizacao')),
                            DataColumn(label: Text('Ativo')),
                            DataColumn(label: Text('Equipamento')),
                            DataColumn(label: Text('Planeada')),
                          ],
                          rows: filteredOrders.map((order) {
                            final asset =
                                assetsById[order['asset_id']?.toString() ?? ''];
                            return DataRow(
                              cells: [
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 220,
                                    ),
                                    child: Text(
                                      workOrderTitle(order),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    openWorkOrderDetail(order);
                                  },
                                ),
                                DataCell(
                                  Text(order['status']?.toString() ?? '-'),
                                ),
                                DataCell(
                                  Text(
                                    workOrderTypeLabel(workOrderType(order)),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    technicianNamesById[order['technician_id']
                                                ?.toString() ??
                                            ''] ??
                                        'Sem tecnico',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    locationNamesById[asset?['location_id']
                                                ?.toString() ??
                                            ''] ??
                                        'Sem localizacao',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    asset?['name']?.toString() ?? 'Sem ativo',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    workOrderAssetDeviceName(
                                          order,
                                        ).trim().isEmpty
                                        ? 'Sem equipamento'
                                        : workOrderAssetDeviceName(
                                            order,
                                          ).trim(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatDate(
                                      parseDateValue(
                                        workOrderScheduledFor(order),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    return RefreshIndicator(
      onRefresh: loadReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Relatorios', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Le indicadores, desempenho operacional e qualidade de dados.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: pickCustomDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: const Text('Periodo personalizado'),
              ),
              FilledButton.icon(
                onPressed: filteredOrders.isEmpty ? null : openPreview,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Previsualizar'),
              ),
              FilledButton.icon(
                onPressed: filteredOrders.isEmpty ? null : copyCsvReport,
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('Copiar CSV'),
              ),
              OutlinedButton.icon(
                onPressed: filteredOrders.isEmpty ? null : exportCsvFile,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Ficheiro CSV'),
              ),
              OutlinedButton.icon(
                onPressed: filteredOrders.isEmpty ? null : previewPdfReport,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
              OutlinedButton.icon(
                onPressed: filteredOrders.isEmpty ? null : sharePdfReport,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Partilhar PDF'),
              ),
              OutlinedButton.icon(
                onPressed: loadReports,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (periodFilter == 'custom')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.event_note_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Periodo selecionado: $periodSummary',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: pickCustomDateRange,
                      child: const Text('Alterar'),
                    ),
                  ],
                ),
              ),
            ),
          if (periodFilter == 'custom') const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final columns = availableWidth >= 1400
                      ? 7
                      : availableWidth >= 1120
                      ? 5
                      : availableWidth >= 860
                      ? 3
                      : availableWidth >= 560
                      ? 2
                      : 1;
                  final itemWidth = columns == 1
                      ? availableWidth
                      : (availableWidth - ((columns - 1) * 12)) / columns;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FilterDropdown(
                        label: 'Periodo',
                        value: periodFilter,
                        width: itemWidth,
                        items: const [
                          DropdownMenuItem(
                            value: '30',
                            child: Text('Ultimos 30 dias'),
                          ),
                          DropdownMenuItem(
                            value: '90',
                            child: Text('Ultimos 90 dias'),
                          ),
                          DropdownMenuItem(
                            value: '365',
                            child: Text('Ultimo ano'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('Personalizado'),
                          ),
                          DropdownMenuItem(value: 'all', child: Text('Tudo')),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          if (value == 'custom') {
                            await pickCustomDateRange();
                            return;
                          }
                          setState(() {
                            periodFilter = value;
                            _normalizeEquipmentFilter();
                          });
                        },
                      ),
                      _FilterDropdown(
                        label: 'Estado',
                        value: statusFilter,
                        width: itemWidth,
                        items: const [
                          DropdownMenuItem(
                            value: 'todos',
                            child: Text('Todos'),
                          ),
                          DropdownMenuItem(
                            value: 'pendente',
                            child: Text('Pendente'),
                          ),
                          DropdownMenuItem(
                            value: 'em curso',
                            child: Text('Em curso'),
                          ),
                          DropdownMenuItem(
                            value: 'concluido',
                            child: Text('Concluido'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          statusFilter = value!;
                          _normalizeEquipmentFilter();
                        }),
                      ),
                      _FilterDropdown(
                        label: 'Tipo',
                        value: typeFilter,
                        width: itemWidth,
                        items: const [
                          DropdownMenuItem(
                            value: 'todas',
                            child: Text('Todas'),
                          ),
                          DropdownMenuItem(
                            value: 'preventiva',
                            child: Text('Preventiva'),
                          ),
                          DropdownMenuItem(
                            value: 'corretiva',
                            child: Text('Corretiva'),
                          ),
                          DropdownMenuItem(
                            value: 'medicoes_verificacoes',
                            child: Text('Medicoes e verificacoes'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          typeFilter = value!;
                          _normalizeEquipmentFilter();
                        }),
                      ),
                      _FilterDropdown(
                        label: 'Tecnico',
                        value: technicianFilter,
                        width: itemWidth,
                        items: [
                          const DropdownMenuItem(
                            value: 'todos',
                            child: Text('Todos'),
                          ),
                          ...technicians.map(
                            (technician) => DropdownMenuItem(
                              value: technician['id']?.toString() ?? '',
                              child: Text(
                                technician['name']?.toString() ?? 'Sem nome',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          technicianFilter = value!;
                          _normalizeEquipmentFilter();
                        }),
                      ),
                      _FilterDropdown(
                        label: 'Localizacao',
                        value: locationFilter,
                        width: itemWidth,
                        items: [
                          const DropdownMenuItem(
                            value: 'todas',
                            child: Text('Todas'),
                          ),
                          ...locations.map(
                            (location) => DropdownMenuItem(
                              value: location['id']?.toString() ?? '',
                              child: Text(
                                location['name']?.toString() ?? 'Sem nome',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          locationFilter = value!;
                          _normalizeEquipmentFilter();
                        }),
                      ),
                      _FilterDropdown(
                        label: 'Ativo',
                        value: assetFilter,
                        width: itemWidth,
                        items: assetFilterOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          assetFilter = value!;
                          _normalizeEquipmentFilter();
                        }),
                      ),
                      _FilterDropdown(
                        label: 'Equipamento',
                        value: equipmentFilter,
                        width: itemWidth,
                        items: equipmentFilterOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          equipmentFilter = value!;
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'Ordens no periodo',
                value: filteredOrders.length.toString(),
              ),
              _MetricCard(
                label: 'Em aberto',
                value: openCount.toString(),
                accent: Colors.orange,
              ),
              _MetricCard(
                label: 'Concluidas',
                value: completedCount.toString(),
                accent: Colors.green,
              ),
              _MetricCard(
                label: 'Atrasadas',
                value: overdueCount.toString(),
                accent: Colors.redAccent,
              ),
              _MetricCard(
                label: 'Planeadas',
                value: plannedCount.toString(),
                accent: Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medicoes e verificacoes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'KPIs dedicados para este tipo de ordem.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Ordens de medicoes/verificacoes',
                        value: measurementVerificationCount.toString(),
                        accent: Colors.teal,
                      ),
                      _MetricCard(
                        label: 'Concluidas',
                        value: measurementVerificationCompletedCount.toString(),
                        accent: Colors.green,
                      ),
                      _MetricCard(
                        label: 'Com medicao registada',
                        value: measurementVerificationWithReadingCount
                            .toString(),
                        accent: Colors.cyan,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              if (!wide) {
                return Column(
                  children: [
                    _RankingPanel(
                      title: 'Ordens por tecnico',
                      items: ordersByTechnician,
                    ),
                    const SizedBox(height: 12),
                    _RankingPanel(
                      title: 'Ordens por localizacao',
                      items: ordersByLocation,
                    ),
                    const SizedBox(height: 12),
                    _RankingPanel(
                      title: 'Ativos com mais ordens',
                      items: topAssetsByOrders,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RankingPanel(
                      title: 'Ordens por tecnico',
                      items: ordersByTechnician,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RankingPanel(
                      title: 'Ordens por localizacao',
                      items: ordersByLocation,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RankingPanel(
                      title: 'Ativos com mais ordens',
                      items: topAssetsByOrders,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final qualityPanel = _RankingPanel(
                title: 'Qualidade de dados',
                items: qualityIndicators,
              );
              final overduePanel = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ordens atrasadas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (overdueOrders.isEmpty)
                        const Text(
                          'Nao existem ordens atrasadas para os filtros selecionados.',
                        )
                      else
                        ...overdueOrders.map((order) {
                          final asset =
                              assetsById[order['asset_id']?.toString() ?? ''];
                          final assetName =
                              asset?['name']?.toString() ?? 'Sem ativo';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_outlined),
                            title: Text(workOrderTitle(order)),
                            subtitle: Text(
                              '$assetName | ${formatDateOnlyValue(workOrderScheduledFor(order))}',
                            ),
                            trailing: Text(order['status']?.toString() ?? '-'),
                          );
                        }),
                    ],
                  ),
                ),
              );

              if (!wide) {
                return Column(
                  children: [
                    qualityPanel,
                    const SizedBox(height: 12),
                    overduePanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: qualityPanel),
                  const SizedBox(width: 12),
                  Expanded(child: overduePanel),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ordens incluidas no relatorio',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${filteredOrders.length} ordens para os filtros atuais. Toca numa linha para abrir a ordem.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (filteredOrders.isEmpty)
                    const Text(
                      'Nao existem ordens para os filtros selecionados.',
                    )
                  else
                    ...filteredOrders.take(20).map((order) {
                      final asset =
                          assetsById[order['asset_id']?.toString() ?? ''];
                      final technicianName =
                          technicianNamesById[order['technician_id']
                                  ?.toString() ??
                              ''] ??
                          'Sem tecnico';
                      final locationName =
                          locationNamesById[asset?['location_id']?.toString() ??
                              ''] ??
                          'Sem localizacao';
                      final equipmentName = workOrderAssetDeviceName(
                        order,
                      ).trim();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(workOrderTitle(order)),
                        subtitle: Text(
                          '${asset?['name']?.toString() ?? 'Sem ativo'} | ${equipmentName.isEmpty ? 'Sem equipamento' : equipmentName} | $technicianName | $locationName | ${order['status']?.toString() ?? '-'}',
                        ),
                        trailing: Text(
                          _formatDate(
                            parseDateValue(workOrderScheduledFor(order)),
                          ),
                        ),
                        onTap: () => openWorkOrderDetail(order),
                      );
                    }),
                  if (filteredOrders.length > 20) ...[
                    const SizedBox(height: 8),
                    Text(
                      'A mostrar as primeiras 20 ordens. O CSV inclui todas as ordens filtradas.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.accent = const Color(0xFF1E3A8A),
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 18),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({required this.title, required this.items});

  final String title;
  final List<_NamedCount> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('Sem dados para os filtros selecionados.')
            else
              ...items.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  trailing: Text(
                    item.count.toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NamedCount {
  const _NamedCount(this.label, this.count);

  final String label;
  final int count;
}

class _FilterOption {
  const _FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}
