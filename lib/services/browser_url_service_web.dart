import 'dart:html' as html;

void clearAuthCallbackUrl() {
  final uri = Uri.base;
  final cleanPath = uri.path.isEmpty ? '/' : uri.path;
  html.window.history.replaceState(null, html.document.title, cleanPath);
}
