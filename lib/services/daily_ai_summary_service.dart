import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_ai_summary.dart';

class DailyAiSummaryGenerationResult {
  const DailyAiSummaryGenerationResult({
    required this.summary,
    this.infoMessage,
  });

  final DailyAiSummary summary;
  final String? infoMessage;
}

class DailyAiSummaryService {
  DailyAiSummaryService._();

  static final DailyAiSummaryService instance = DailyAiSummaryService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<DailyAiSummary?> fetchSummaryForDate({
    required DateTime summaryDate,
  }) async {
    try {
      final data = await _client
          .from('daily_ai_summaries')
          .select()
          .eq('summary_date', _formatDateOnly(summaryDate))
          .maybeSingle();

      if (data == null) return null;
      return DailyAiSummary.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (error) {
      if (_isMissingBackendError(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<DailyAiSummaryGenerationResult> generateSummary({
    required DateTime summaryDate,
  }) async {
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'daily-operations-summary',
        body: {'summary_date': _formatDateOnly(summaryDate)},
      );
    } on FunctionException catch (error) {
      throw _mapFunctionException(error);
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Resposta invalida do backend do resumo diario.');
    }

    final payload = Map<String, dynamic>.from(data);
    final errorMessage =
        _readNonEmpty(payload['error']) ?? _readNonEmpty(payload['message']);
    if (errorMessage != null && payload['summary'] == null) {
      throw Exception(errorMessage);
    }

    final summaryPayload = payload['summary'];
    if (summaryPayload is! Map) {
      throw Exception('O backend nao devolveu um resumo valido.');
    }

    return DailyAiSummaryGenerationResult(
      summary: DailyAiSummary.fromMap(Map<String, dynamic>.from(summaryPayload)),
      infoMessage:
          _readNonEmpty(payload['warning']) ?? _readNonEmpty(payload['message']),
    );
  }

  Exception _mapFunctionException(FunctionException error) {
    final message = _extractFunctionErrorMessage(error);
    final normalizedMessage = message.toLowerCase();

    if (error.status == 404 ||
        normalizedMessage.contains('daily-operations-summary')) {
      return Exception(
        'A Edge Function do resumo diario ainda nao esta publicada no Supabase.',
      );
    }

    if (error.status == 401 && normalizedMessage.contains('invalid jwt')) {
      return Exception(
        'A sessao autenticada ja nao foi aceite para gerar o resumo. Entra novamente na app e tenta de novo.',
      );
    }

    return Exception(message);
  }

  String _extractFunctionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = _readNonEmpty(details['message']);
      if (message != null) return message;

      final errorText = _readNonEmpty(details['error']);
      if (errorText != null) return errorText;
    }

    final detailsText = _readNonEmpty(details);
    if (detailsText != null) return detailsText;

    final reason = _readNonEmpty(error.reasonPhrase);
    if (reason != null) return reason;

    return 'Nao foi possivel gerar o resumo diario.';
  }

  bool _isMissingBackendError(PostgrestException error) {
    final text =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return text.contains('daily_ai_summaries') &&
        (text.contains('relation') ||
            text.contains('schema cache') ||
            text.contains('could not find'));
  }
}

String _formatDateOnly(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _readNonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
