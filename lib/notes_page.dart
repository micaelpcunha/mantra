import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'models/app_note.dart';
import 'services/note_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    this.isTechnicianView = false,
    this.isSimulation = false,
  });

  final bool isTechnicianView;
  final bool isSimulation;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NoteService _noteService = NoteService.instance;
  final TextEditingController _titleController = TextEditingController();
  final Map<String, TextEditingController> _blockControllers = {};

  bool isLoading = true;
  bool isSaving = false;
  bool isLoadingImages = false;
  bool isGeneratingPdf = false;
  bool isDirty = false;
  String? draggingBlockId;
  int? dragHoverIndex;
  String? errorMessage;

  List<AppNote> notes = [];
  AppNote? selectedNote;
  List<AppNoteBlock> draftBlocks = const [];
  Map<String, String> resolvedImages = const {};

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    loadNotes();
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_markDirty)
      ..dispose();
    for (final controller in _blockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!mounted || selectedNote == null || isDirty) return;
    setState(() {
      isDirty = true;
    });
  }

  Future<void> loadNotes({String? preferredNoteId}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedNotes = await _noteService.fetchMyNotes();
      if (!mounted) return;

      final nextSelected = _findPreferredNote(
            loadedNotes,
            preferredNoteId ?? selectedNote?.id,
          ) ??
          (loadedNotes.isNotEmpty ? loadedNotes.first : null);

      setState(() {
        notes = loadedNotes;
        selectedNote = nextSelected;
        isDirty = false;
      });
      _syncDraftWithSelected();
      await _refreshResolvedImages();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Nao foi possivel carregar as notas. Confirma se a tabela `notes` e o bucket `note-images` ja existem no Supabase.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  AppNote? _findPreferredNote(List<AppNote> items, String? preferredId) {
    if (preferredId == null) return null;
    for (final note in items) {
      if (note.id == preferredId) return note;
    }
    return null;
  }

  void _syncDraftWithSelected() {
    final note = selectedNote;
    _titleController.text = note?.title ?? '';
    draftBlocks = note?.blocks.map((block) => block.copyWith()).toList() ?? const [];

    final currentIds = draftBlocks.map((block) => block.id).toSet();
    final removedIds = _blockControllers.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in removedIds) {
      _blockControllers.remove(id)?.dispose();
    }

    for (final block in draftBlocks.where((item) => item.isText)) {
      final controller = _blockControllers.putIfAbsent(
        block.id,
        () => TextEditingController(),
      );
      controller.text = block.text;
      controller.removeListener(_markDirty);
      controller.addListener(_markDirty);
    }
  }

  AppNote? get _draftNote {
    final note = selectedNote;
    if (note == null) return null;

    final normalizedBlocks = draftBlocks.map((block) {
      if (!block.isText) return block;
      final text = _blockControllers[block.id]?.text ?? block.text;
      return block.copyWith(text: text);
    }).toList();

    return note.copyWith(
      title: _titleController.text,
      blocks: normalizedBlocks,
    );
  }

  Future<void> _selectNote(AppNote note) async {
    if (selectedNote?.id == note.id) return;
    await _saveCurrentNote(silent: true);
    if (!mounted) return;
    setState(() {
      selectedNote = note;
      isDirty = false;
    });
    _syncDraftWithSelected();
    await _refreshResolvedImages();
  }

  Future<void> _createNote() async {
    await _saveCurrentNote(silent: true);
    try {
      final created = await _noteService.createNote();
      if (!mounted) return;
      setState(() {
        notes = [created, ...notes];
        selectedNote = created;
        isDirty = false;
      });
      _syncDraftWithSelected();
      await _refreshResolvedImages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel criar a nota.')),
      );
    }
  }

  Future<void> _saveCurrentNote({bool silent = false}) async {
    final draft = _draftNote;
    if (draft == null || !isDirty || isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final saved = await _noteService.updateNote(draft);
      if (!mounted) return;
      setState(() {
        selectedNote = saved;
        notes = notes
            .map((note) => note.id == saved.id ? saved : note)
            .toList()
          ..sort(
            (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
          );
        isDirty = false;
      });
      _syncDraftWithSelected();
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota guardada.')),
        );
      }
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel guardar a nota.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _deleteSelectedNote() async {
    final note = selectedNote;
    if (note == null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Apagar nota'),
            content: Text('Queres mesmo apagar "${note.displayTitle}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apagar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await _noteService.deleteNote(note.id);
      if (!mounted) return;
      final updatedNotes = notes.where((item) => item.id != note.id).toList();
      setState(() {
        notes = updatedNotes;
        selectedNote = updatedNotes.isNotEmpty ? updatedNotes.first : null;
        isDirty = false;
      });
      _syncDraftWithSelected();
      await _refreshResolvedImages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel apagar a nota.')),
      );
    }
  }

  void _insertTextBlock(int index) {
    final newBlock = AppNoteBlock.text();
    setState(() {
      draftBlocks = [
        ...draftBlocks.take(index),
        newBlock,
        ...draftBlocks.skip(index),
      ];
      _blockControllers[newBlock.id] = TextEditingController()..addListener(_markDirty);
      isDirty = true;
    });
  }

  Future<void> _insertImageBlocks(int index) async {
    try {
      final uploadedPaths = await _noteService.uploadNoteImages();
      if (uploadedPaths.isEmpty) return;

      final newBlocks = uploadedPaths.map(AppNoteBlock.image).toList();
      setState(() {
        draftBlocks = [
          ...draftBlocks.take(index),
          ...newBlocks,
          ...draftBlocks.skip(index),
        ];
        isDirty = true;
      });
      await _saveCurrentNote(silent: true);
      await _refreshResolvedImages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel carregar as imagens da nota.')),
      );
    }
  }

  void _moveBlockToIndex(String blockId, int targetIndex) {
    final oldIndex = draftBlocks.indexWhere((block) => block.id == blockId);
    if (oldIndex < 0) return;

    final blocks = [...draftBlocks];
    final movedBlock = blocks.removeAt(oldIndex);

    var normalizedTargetIndex = targetIndex;
    if (oldIndex < normalizedTargetIndex) {
      normalizedTargetIndex -= 1;
    }
    normalizedTargetIndex = normalizedTargetIndex.clamp(0, blocks.length);

    if (oldIndex == normalizedTargetIndex) {
      setState(() {
        draggingBlockId = null;
        dragHoverIndex = null;
      });
      return;
    }

    blocks.insert(normalizedTargetIndex, movedBlock);

    setState(() {
      draftBlocks = blocks;
      isDirty = true;
      draggingBlockId = null;
      dragHoverIndex = null;
    });
  }

  Future<void> _removeBlock(int index) async {
    if (draftBlocks.length == 1) {
      setState(() {
        draftBlocks = [AppNoteBlock.text()];
        isDirty = true;
      });
      return;
    }

    final block = draftBlocks[index];
    setState(() {
      draftBlocks = [
        ...draftBlocks.take(index),
        ...draftBlocks.skip(index + 1),
      ];
      isDirty = true;
    });

    if (block.isText) {
      _blockControllers.remove(block.id)?.dispose();
    }
  }

  void _moveBlockByOffset(int index, int offset) {
    final targetIndex = index + offset;
    if (targetIndex < 0 || targetIndex >= draftBlocks.length) return;

    final blocks = [...draftBlocks];
    final movedBlock = blocks.removeAt(index);
    blocks.insert(targetIndex, movedBlock);

    setState(() {
      draftBlocks = blocks;
      isDirty = true;
    });
  }

  Future<void> _refreshResolvedImages() async {
    final note = _draftNote;
    if (note == null) {
      setState(() {
        resolvedImages = const {};
      });
      return;
    }

    setState(() {
      isLoadingImages = true;
    });

    try {
      final urls = await _noteService.resolveImageUrls(note);
      if (!mounted) return;
      setState(() {
        resolvedImages = {for (final entry in urls) entry.key: entry.value};
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        resolvedImages = const {};
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingImages = false;
      });
    }
  }

  Future<Uint8List> _buildPdfBytes(AppNote note) async {
    final pdf = pw.Document();
    final blocks = <pw.Widget>[];

    for (final block in note.blocks) {
      if (block.isImage) {
        final imageUrl = resolvedImages[block.imagePath];
        blocks.add(await _buildPdfImageBlock(imageUrl));
      } else {
        blocks.add(_buildPdfTextBlock(block.text));
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(28),
        ),
        build: (context) => [
          pw.Text(
            note.displayTitle,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Atualizada em ${_formatDateTime(note.updatedAt ?? note.createdAt)}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.SizedBox(height: 18),
          ...blocks,
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfTextBlock(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'Bloco de texto vazio',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blueGrey600,
            ),
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Text(
        normalized,
        style: const pw.TextStyle(
          fontSize: 12,
          lineSpacing: 4,
        ),
      ),
    );
  }

  Future<pw.Widget> _buildPdfImageBlock(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey100),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            'Imagem indisponivel',
            style: const pw.TextStyle(color: PdfColors.blueGrey600),
          ),
        ),
      );
    }

    try {
      final provider = await networkImage(imageUrl).timeout(
        const Duration(seconds: 4),
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey100),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Image(
            provider,
            fit: pw.BoxFit.contain,
          ),
        ),
      );
    } catch (_) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey100),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            'Imagem indisponivel',
            style: const pw.TextStyle(color: PdfColors.blueGrey600),
          ),
        ),
      );
    }
  }

  Future<void> _previewPdf() async {
    final note = _draftNote;
    if (note == null) return;
    setState(() {
      isGeneratingPdf = true;
    });

    try {
      await _saveCurrentNote(silent: true);
      final bytes = await _buildPdfBytes(selectedNote ?? note);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${_sanitizeFileName((selectedNote ?? note).displayTitle)}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel gerar a pre-visualizacao do PDF.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isGeneratingPdf = false;
      });
    }
  }

  Future<void> _sharePdf() async {
    final note = _draftNote;
    if (note == null) return;
    setState(() {
      isGeneratingPdf = true;
    });

    try {
      await _saveCurrentNote(silent: true);
      final currentNote = selectedNote ?? note;
      final bytes = await _buildPdfBytes(currentNote);
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: '${_sanitizeFileName(currentNote.displayTitle)}.pdf',
      );

      if (!mounted) return;
      await Share.shareXFiles(
        [file],
        subject: currentNote.displayTitle,
        text: currentNote.displayTitle,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel preparar o PDF da nota.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isGeneratingPdf = false;
      });
    }
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'sem data';
    final date = value.toLocal();
    final two = (int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSimulation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 44),
                const SizedBox(height: 12),
                Text(
                  'As notas sao pessoais da conta autenticada e nao entram na simulacao de tecnico.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Para validar esta area como tecnico, entra com uma conta de tecnico real.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sticky_note_2_outlined, size: 40),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => loadNotes(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = selectedNote;
    final width = MediaQuery.of(context).size.width;
    final wideLayout = width >= 1040;
    final compactLayout = width < 760;

    if (notes.isEmpty || selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sticky_note_2_outlined, size: 44),
              const SizedBox(height: 12),
              Text(
                widget.isTechnicianView
                    ? 'Ainda nao tens notas. Cria a primeira para guardar procedimentos, apontamentos e imagens de apoio.'
                    : 'Ainda nao tens notas. Cria a primeira para guardar blocos de texto e imagem na ordem que quiseres.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _createNote,
                icon: const Icon(Icons.add),
                label: const Text('Criar nota'),
              ),
            ],
          ),
        ),
      );
    }

    final noteList = _buildNotesList(wideLayout: wideLayout);
    final editor = _buildEditor(
      context,
      selected,
      compactLayout: compactLayout,
    );

    return wideLayout
        ? Row(
            children: [
              SizedBox(
                width: 320,
                child: noteList,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: editor),
            ],
          )
        : Column(
            children: [
              SizedBox(
                height: 156,
                child: noteList,
              ),
              const Divider(height: 1),
              Expanded(child: editor),
            ],
          );
  }

  Widget _buildNotesList({required bool wideLayout}) {
    final list = ListView.separated(
      scrollDirection: wideLayout ? Axis.vertical : Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: notes.length + 1,
      separatorBuilder: (_, __) => SizedBox(
        width: wideLayout ? 0 : 12,
        height: wideLayout ? 12 : 0,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return wideLayout
              ? FilledButton.icon(
                  onPressed: _createNote,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova nota'),
                )
              : SizedBox(
                  width: 220,
                  child: FilledButton.icon(
                    onPressed: _createNote,
                    icon: const Icon(Icons.add),
                    label: const Text('Nova nota'),
                  ),
                );
        }

        final note = notes[index - 1];
        final selected = note.id == selectedNote?.id;
        final preview = note.previewText.replaceAll('\n', ' ');

        return SizedBox(
          width: wideLayout ? null : 240,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _selectNote(note),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE4EFE9)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? const Color(0xFF4E7A6A) : const Color(0xFFD7DFD7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    note.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preview.isEmpty ? 'Sem conteudo ainda.' : preview,
                    maxLines: wideLayout ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${note.imageCount} imagens · ${_formatDateTime(note.updatedAt ?? note.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Container(
      color: Colors.white.withOpacity(0.36),
      child: list,
    );
  }

  Widget _buildEditor(
    BuildContext context,
    AppNote note, {
    required bool compactLayout,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeaderActions(note, compactLayout: compactLayout),
        const SizedBox(height: 18),
        TextField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Titulo da nota',
            hintText: 'Ex.: Procedimento da bomba norte',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          compactLayout
              ? 'Usa os botoes abaixo para adicionar conteudo. Em ecras pequenos, a ordem pode ser ajustada com as setas de cada bloco.'
              : 'Segura na pega de um bloco e larga na zona entre blocos onde queres coloca-lo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        _buildInsertBar(0),
        const SizedBox(height: 12),
        for (var index = 0; index < draftBlocks.length; index++) ...[
          _buildBlockCard(
            index,
            draftBlocks[index],
            compactLayout: compactLayout,
          ),
          const SizedBox(height: 10),
          _buildInsertBar(index + 1),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 6),
        _NoteMetaCard(
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          imageCount: draftBlocks.where((block) => block.isImage).length,
          isDirty: isDirty,
        ),
      ],
    );
  }

  Widget _buildHeaderActions(AppNote note, {required bool compactLayout}) {
    final title = widget.isTechnicianView ? 'Notas pessoais' : 'Notas pessoais';
    final subtitle = widget.isTechnicianView
        ? 'Apontamentos, procedimentos e imagens de uso pessoal.'
        : 'Blocos pessoais com texto, imagens e exportacao em PDF.';

    if (compactLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : () => _saveCurrentNote(),
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isGeneratingPdf ? null : _sharePdf,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => loadNotes(preferredNoteId: note.id),
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
              ),
              OutlinedButton.icon(
                onPressed: isGeneratingPdf ? null : _previewPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Prever'),
              ),
              OutlinedButton.icon(
                onPressed: _deleteSelectedNote,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar'),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => loadNotes(preferredNoteId: note.id),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
            OutlinedButton.icon(
              onPressed: isSaving ? null : () => _saveCurrentNote(),
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
            OutlinedButton.icon(
              onPressed: isGeneratingPdf ? null : _previewPdf,
              icon: isGeneratingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Prever PDF'),
            ),
            FilledButton.icon(
              onPressed: isGeneratingPdf ? null : _sharePdf,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Partilhar PDF'),
            ),
            OutlinedButton.icon(
              onPressed: _deleteSelectedNote,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Apagar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsertBar(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<String>(
          onWillAcceptWithDetails: (details) {
            setState(() {
              dragHoverIndex = index;
            });
            return true;
          },
          onLeave: (_) {
            if (dragHoverIndex == index) {
              setState(() {
                dragHoverIndex = null;
              });
            }
          },
          onAcceptWithDetails: (details) {
            _moveBlockToIndex(details.data, index);
          },
          builder: (context, candidateData, rejectedData) {
            final isActive =
                dragHoverIndex == index || candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFE4EFE9)
                    : const Color(0xFFF8FAF7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF4E7A6A)
                      : const Color(0xFFD7DFD7),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_vert,
                    size: 18,
                    color: isActive
                        ? const Color(0xFF29465B)
                        : const Color(0xFF5F6B72),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Largar bloco aqui' : 'Zona para largar bloco',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _insertTextBlock(index),
              icon: const Icon(Icons.subject_outlined),
              label: const Text('Texto aqui'),
            ),
            OutlinedButton.icon(
              onPressed: () => _insertImageBlocks(index),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Imagem aqui'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlockCard(
    int index,
    AppNoteBlock block, {
    required bool compactLayout,
  }) {
    final isDragging = draggingBlockId == block.id;

    return Opacity(
      opacity: isDragging ? 0.35 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.66),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7DFD7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    block.isText ? 'Bloco de texto' : 'Bloco de imagem',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (compactLayout) ...[
                  IconButton(
                    onPressed: index == 0 ? null : () => _moveBlockByOffset(index, -1),
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: 'Mover para cima',
                  ),
                  IconButton(
                    onPressed: index == draftBlocks.length - 1
                        ? null
                        : () => _moveBlockByOffset(index, 1),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: 'Mover para baixo',
                  ),
                ] else
                  LongPressDraggable<String>(
                    data: block.id,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    onDragStarted: () {
                      setState(() {
                        draggingBlockId = block.id;
                      });
                    },
                    onDragEnd: (_) {
                      setState(() {
                        draggingBlockId = null;
                        dragHoverIndex = null;
                      });
                    },
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF4E7A6A)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.drag_indicator, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                block.isText ? 'Bloco de texto' : 'Bloco de imagem',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4EF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD7DFD7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_indicator, size: 18),
                            SizedBox(width: 4),
                            Text('Segurar para mover'),
                          ],
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => _removeBlock(index),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remover bloco',
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (block.isText)
              _buildTextBlockEditor(block)
            else
              _buildImageBlockEditor(block),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBlockEditor(AppNoteBlock block) {
    final controller = _blockControllers.putIfAbsent(
      block.id,
      () => TextEditingController(text: block.text)..addListener(_markDirty),
    );

    if (controller.text != block.text) {
      controller.text = block.text;
    }

    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      onChanged: (value) {
        final index = draftBlocks.indexWhere((item) => item.id == block.id);
        if (index < 0) return;
        setState(() {
          draftBlocks = [
            ...draftBlocks.take(index),
            draftBlocks[index].copyWith(text: value),
            ...draftBlocks.skip(index + 1),
          ];
          isDirty = true;
        });
      },
      decoration: const InputDecoration(
        labelText: 'Texto',
        alignLabelWithHint: true,
        hintText: 'Escreve o conteudo deste bloco.',
      ),
    );
  }

  Widget _buildImageBlockEditor(AppNoteBlock block) {
    final imageUrl = resolvedImages[block.imagePath];

    if (isLoadingImages && imageUrl == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: imageUrl == null
            ? Container(
                color: const Color(0xFFF1F4EF),
                alignment: Alignment.center,
                child: const Text('Imagem indisponivel'),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF1F4EF),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}

class _NoteMetaCard extends StatelessWidget {
  const _NoteMetaCard({
    required this.createdAt,
    required this.updatedAt,
    required this.imageCount,
    required this.isDirty,
  });

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int imageCount;
  final bool isDirty;

  String _format(DateTime? value) {
    if (value == null) return 'sem data';
    final local = value.toLocal();
    final two = (int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.64),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7DFD7)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          Text('Criada: ${_format(createdAt)}'),
          Text('Atualizada: ${_format(updatedAt)}'),
          Text('Imagens: $imageCount'),
          Text(isDirty ? 'Alteracoes por guardar' : 'Tudo guardado'),
        ],
      ),
    );
  }
}
