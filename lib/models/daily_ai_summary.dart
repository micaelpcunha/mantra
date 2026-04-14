class DailyAiSummaryStats {
  const DailyAiSummaryStats({
    required this.plannedAssetsCount,
    required this.plannedTechniciansCount,
    required this.touchedOrdersCount,
    required this.createdOrdersCount,
    required this.completedOrdersCount,
    required this.openOrdersCount,
    required this.urgentOpenOrdersCount,
    required this.plannedWithoutActivityCount,
  });

  final int plannedAssetsCount;
  final int plannedTechniciansCount;
  final int touchedOrdersCount;
  final int createdOrdersCount;
  final int completedOrdersCount;
  final int openOrdersCount;
  final int urgentOpenOrdersCount;
  final int plannedWithoutActivityCount;

  factory DailyAiSummaryStats.fromMap(Map<String, dynamic> map) {
    return DailyAiSummaryStats(
      plannedAssetsCount: _readInt(map['planned_assets_count']) ?? 0,
      plannedTechniciansCount:
          _readInt(map['planned_technicians_count']) ?? 0,
      touchedOrdersCount: _readInt(map['touched_orders_count']) ?? 0,
      createdOrdersCount: _readInt(map['created_orders_count']) ?? 0,
      completedOrdersCount: _readInt(map['completed_orders_count']) ?? 0,
      openOrdersCount: _readInt(map['open_orders_count']) ?? 0,
      urgentOpenOrdersCount: _readInt(map['urgent_open_orders_count']) ?? 0,
      plannedWithoutActivityCount:
          _readInt(map['planned_without_activity_count']) ?? 0,
    );
  }
}

class DailyAiSummary {
  const DailyAiSummary({
    required this.id,
    required this.summaryDate,
    required this.status,
    required this.headline,
    required this.completed,
    required this.unfinished,
    required this.blocked,
    required this.attentionTomorrow,
    required this.summaryText,
    required this.generationMode,
    required this.sourceStats,
    this.generatedAt,
    this.model,
    this.note,
    this.errorMessage,
  });

  final String id;
  final DateTime? summaryDate;
  final String status;
  final String headline;
  final List<String> completed;
  final List<String> unfinished;
  final List<String> blocked;
  final List<String> attentionTomorrow;
  final String summaryText;
  final String generationMode;
  final DailyAiSummaryStats sourceStats;
  final DateTime? generatedAt;
  final String? model;
  final String? note;
  final String? errorMessage;

  bool get isReady => status == 'ready';

  String get generationModeLabel {
    switch (generationMode) {
      case 'openai':
        return 'IA';
      case 'heuristic':
      default:
        return 'Analise local';
    }
  }

  factory DailyAiSummary.fromMap(Map<String, dynamic> map) {
    final payload = _readMap(map['summary_payload']);
    final sourceStatsMap = _readMap(map['source_stats']);

    return DailyAiSummary(
      id: map['id']?.toString() ?? '',
      summaryDate: DateTime.tryParse(map['summary_date']?.toString() ?? ''),
      status: _readNonEmpty(map['status']) ?? 'ready',
      headline: _readNonEmpty(payload['headline']) ?? '',
      completed: _readStringList(payload['completed']),
      unfinished: _readStringList(payload['unfinished']),
      blocked: _readStringList(payload['blocked']),
      attentionTomorrow: _readStringList(payload['attention_tomorrow']),
      summaryText: _readNonEmpty(map['summary_text']) ?? '',
      generationMode: _readNonEmpty(map['generation_mode']) ?? 'heuristic',
      sourceStats: DailyAiSummaryStats.fromMap(sourceStatsMap),
      generatedAt: DateTime.tryParse(map['generated_at']?.toString() ?? ''),
      model: _readNonEmpty(map['model']),
      note: _readNonEmpty(payload['note']),
      errorMessage: _readNonEmpty(map['error_message']),
    );
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

String? _readNonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
