import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailProviderAuthService {
  EmailProviderAuthService._();

  static final EmailProviderAuthService instance = EmailProviderAuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _extractFunctionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errorText = details['error']?.toString().trim();
      if (errorText != null && errorText.isNotEmpty) {
        return errorText;
      }
    }

    final detailsText = details?.toString().trim();
    if (detailsText != null && detailsText.isNotEmpty) {
      return detailsText;
    }

    final reason = error.reasonPhrase?.trim();
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }

    return error.toString();
  }

  Exception _mapFunctionException(FunctionException error) {
    final message = _extractFunctionErrorMessage(error);
    final normalizedMessage = message.toLowerCase();

    if (error.status == 401 && normalizedMessage.contains('invalid jwt')) {
      return Exception(
        'A sessao autenticada nao foi aceite pelo backend OAuth. Faz novo deploy das Edge Functions com `verify_jwt = false` e, se o erro continuar, termina sessao e volta a entrar na app.',
      );
    }

    return Exception(message);
  }

  Future<Uri> createAuthorizationUri({
    required String provider,
    String? returnTo,
  }) async {
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'email-provider-start',
        body: {
          'provider': provider,
          if (returnTo != null && returnTo.trim().isNotEmpty)
            'return_to': returnTo.trim(),
        },
      );
    } on FunctionException catch (error) {
      throw _mapFunctionException(error);
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Resposta invalida do backend OAuth.');
    }

    final authorizationUrl = data['authorization_url']?.toString().trim() ?? '';
    if (authorizationUrl.isEmpty) {
      final error = data['error']?.toString().trim();
      if (error != null && error.isNotEmpty) {
        throw Exception(error);
      }
      throw Exception('O backend OAuth nao devolveu um link de autorizacao.');
    }

    return Uri.parse(authorizationUrl);
  }

  Future<void> launchAuthorization({
    required String provider,
    String? returnTo,
  }) async {
    final uri = await createAuthorizationUri(
      provider: provider,
      returnTo: returnTo,
    );

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched) {
      throw Exception('Nao foi possivel abrir o browser para autenticar.');
    }
  }
}
