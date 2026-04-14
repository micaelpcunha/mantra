class AppNoteBlock {
  const AppNoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.imagePath = '',
  });

  final String id;
  final String type;
  final String text;
  final String imagePath;

  bool get isText => type == 'text';
  bool get isImage => type == 'image';

  factory AppNoteBlock.fromMap(Map<String, dynamic> map) {
    return AppNoteBlock(
      id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: map['type']?.toString() == 'image' ? 'image' : 'text',
      text: map['text']?.toString() ?? '',
      imagePath: map['image_path']?.toString() ?? '',
    );
  }

  factory AppNoteBlock.text([String text = '']) {
    return AppNoteBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'text',
      text: text,
    );
  }

  factory AppNoteBlock.image(String imagePath) {
    return AppNoteBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'image',
      imagePath: imagePath,
    );
  }

  AppNoteBlock copyWith({
    String? id,
    String? type,
    String? text,
    String? imagePath,
  }) {
    return AppNoteBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'text': text,
      'image_path': imagePath,
    };
  }
}

class AppNote {
  const AppNote({
    required this.id,
    required this.userId,
    required this.title,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final List<AppNoteBlock> blocks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppNote.fromMap(Map<String, dynamic> map) {
    final rawBlocks = map['content_blocks'];
    final blocks = rawBlocks is List
        ? rawBlocks
            .whereType<Map>()
            .map((item) => AppNoteBlock.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : _legacyBlocks(map);

    return AppNote(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      blocks: blocks.isEmpty ? [AppNoteBlock.text()] : blocks,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  AppNote copyWith({
    String? id,
    String? userId,
    String? title,
    List<AppNoteBlock>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title.trim(),
      'content_blocks': blocks.map((block) => block.toMap()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  String get displayTitle => title.trim().isEmpty ? 'Sem titulo' : title.trim();

  String get previewText {
    for (final block in blocks) {
      if (block.isText && block.text.trim().isNotEmpty) {
        return block.text.trim();
      }
    }
    return '';
  }

  int get imageCount => blocks.where((block) => block.isImage && block.imagePath.trim().isNotEmpty).length;

  static List<AppNoteBlock> _legacyBlocks(Map<String, dynamic> map) {
    final blocks = <AppNoteBlock>[];
    final content = map['content']?.toString() ?? '';
    if (content.trim().isNotEmpty) {
      blocks.add(AppNoteBlock.text(content));
    }

    final rawImages = map['image_paths'];
    if (rawImages is List) {
      for (final image in rawImages) {
        final value = image.toString().trim();
        if (value.isNotEmpty) {
          blocks.add(AppNoteBlock.image(value));
        }
      }
    }

    return blocks;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
