import 'package:supabase_flutter/supabase_flutter.dart';

class AuthorizationEmailDeliveryDraftPayload {
  const AuthorizationEmailDeliveryDraftPayload({
    required this.assetId,
    required this.recipientEmail,
    required this.subject,
    required this.body,
  });

  final String? assetId;
  final String recipientEmail;
  final String subject;
  final String body;

  Map<String, dynamic> toJson() {
    final normalizedAssetId = assetId?.trim();
    return {
      if (normalizedAssetId != null && normalizedAssetId.isNotEmpty)
        'asset_id': normalizedAssetId,
      'recipient_email': recipientEmail.trim(),
      'subject': subject.trim(),
      'body': body,
    };
  }
}

class AuthorizationEmailDeliveryItemResult {
  const AuthorizationEmailDeliveryItemResult({
    required this.assetId,
    required this.recipientEmail,
    required this.subject,
    required this.status,
    required this.providerMessageId,
    required this.errorMessage,
  });

  final String? assetId;
  final String recipientEmail;
  final String subject;
  final String status;
  final String? providerMessageId;
  final String? errorMessage;

  bool get isSent => status == 'sent';

  factory AuthorizationEmailDeliveryItemResult.fromMap(
    Map<String, dynamic> map,
  ) {
    return AuthorizationEmailDeliveryItemResult(
      assetId: _readNonEmpty(map['asset_id']),
      recipientEmail: _readNonEmpty(map['recipient_email']) ?? '',
      subject: _readNonEmpty(map['subject']) ?? '',
      status: _readNonEmpty(map['status']) ?? 'failed',
      providerMessageId: _readNonEmpty(map['provider_message_id']),
      errorMessage: _readNonEmpty(map['error_message']),
    );
  }
}

class AuthorizationEmailDeliveryResult {
  const AuthorizationEmailDeliveryResult({
    required this.connectionId,
    required this.provider,
    required this.sentCount,
    required this.failedCount,
    required this.results,
  });

  final String? connectionId;
  final String? provider;
  final int sentCount;
  final int failedCount;
  final List<AuthorizationEmailDeliveryItemResult> results;

  factory AuthorizationEmailDeliveryResult.fromMap(Map<String, dynamic> map) {
    final rawResults = map['results'];
    final parsedResults = rawResults is List
        ? rawResults
              .whereType<Map>()
              .map(
                (item) => AuthorizationEmailDeliveryItemResult.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <AuthorizationEmailDeliveryItemResult>[];

    return AuthorizationEmailDeliveryResult(
      connectionId: _readNonEmpty(map['connection_id']),
      provider: _readNonEmpty(map['provider']),
      sentCount: _readInt(map['sent_count']) ?? 0,
      failedCount: _readInt(map['failed_count']) ?? 0,
      results: parsedResults,
    );
  }
}

class AuthorizationEmailDeliveryService {
  AuthorizationEmailDeliveryService._();

  static final AuthorizationEmailDeliveryService instance =
      AuthorizationEmailDeliveryService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthorizationEmailDeliveryResult> sendDrafts({
    String? connectionId,
    DateTime? plannedDate,
    required List<AuthorizationEmailDeliveryDraftPayload> drafts,
  }) async {
    if (drafts.isEmpty) {
      throw Exception('Nao existem emails para enviar.');
    }

    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'authorization-email-send',
        body: {
          if (_readNonEmpty(connectionId) != null)
            'connection_id': connectionId!.trim(),
          if (plannedDate != null) 'planned_date': _formatDateOnly(plannedDate),
          'drafts': drafts.map((draft) => draft.toJson()).toList(),
        },
      );
    } on FunctionException catch (error) {
      throw _mapFunctionException(error);
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Resposta invalida do backend de envio de emails.');
    }

    final payload = Map<String, dynamic>.from(data);
    final errorMessage =
        _readNonEmpty(payload['error']) ?? _readNonEmpty(payload['message']);
    if (errorMessage != null) {
      throw Exception(errorMessage);
    }

    return AuthorizationEmailDeliveryResult.fromMap(payload);
  }

  Exception _mapFunctionException(FunctionException error) {
    final message = _extractFunctionErrorMessage(error);
    final normalizedMessage = message.toLowerCase();

    if (error.status == 404 ||
        normalizedMessage.contains('authorization-email-send')) {
      return Exception(
        'A Edge Function de envio automatico ainda nao esta publicada no Supabase.',
      );
    }

    if (error.status == 401 && normalizedMessage.contains('invalid jwt')) {
      return Exception(
        'A function de envio nao aceitou a sessao autenticada. Faz novo deploy do backend e volta a entrar na app se o erro continuar.',
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

    return 'Nao foi possivel enviar os emails de autorizacao.';
  }

  static String _formatDateOnly(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
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
