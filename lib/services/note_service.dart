import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_note.dart';
import 'company_scope_service.dart';
import 'storage_service.dart';

class NoteService {
  NoteService._();

  static final NoteService instance = NoteService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AppNote>> fetchMyNotes() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sessao invalida.');
    }

    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(AppNote.fromMap)
        .toList();
  }

  Future<AppNote> createNote({
    String title = 'Nova nota',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sessao invalida.');
    }

    final payload = await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'notes',
      payload: {
        'user_id': userId,
        'title': title,
        'content_blocks': [
          AppNoteBlock.text().toMap(),
        ],
      },
    );

    final response = await _client
        .from('notes')
        .insert(payload)
        .select()
        .single();

    return AppNote.fromMap(response);
  }

  Future<AppNote> updateNote(AppNote note) async {
    final response = await _client
        .from('notes')
        .update(note.toUpdateMap())
        .eq('id', note.id)
        .select()
        .single();

    return AppNote.fromMap(response);
  }

  Future<void> deleteNote(String noteId) async {
    await _client.from('notes').delete().eq('id', noteId);
  }

  Future<List<String>> uploadNoteImages() async {
    return StorageService.instance.pickAndUploadNoteImages();
  }

  Future<List<MapEntry<String, String>>> resolveImageUrls(AppNote note) async {
    final urls = await Future.wait(
      note.blocks
          .where((block) => block.isImage && block.imagePath.trim().isNotEmpty)
          .map(
        (block) async => MapEntry(
          block.imagePath,
          await StorageService.instance.resolveFileUri(
            bucket: 'note-images',
            storedValue: block.imagePath,
          ),
        ),
      ),
    );

    return urls
        .where((entry) => entry.value != null)
        .map((entry) => MapEntry(entry.key, entry.value!.toString()))
        .toList();
  }
}
