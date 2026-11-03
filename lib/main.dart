import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PamshoNotesApp());
}

class PamshoNotesApp extends StatelessWidget {
  const PamshoNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17212B);
    const accent = Color(0xFF426BEB);
    return MaterialApp(
      title: 'Pamsho Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FB),
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const NotesHomePage(),
    );
  }
}

class Note {
  const Note({required this.id, required this.title, required this.body, required this.updatedAt});
  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;

  Map<String, Object> toMap() => {
    'id': id, 'title': title, 'body': body, 'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as String,
    title: map['title'] as String,
    body: map['body'] as String,
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});
  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  static const _storageKey = 'pamsho_notes_v1';
  List<Note> _notes = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    final loaded = <Note>[];
    for (final item in raw) {
      try {
        final decoded = Uri.decodeComponent(item);
        final parts = decoded.split('|');
        if (parts.length == 4) {
          loaded.add(Note(id: parts[0], title: parts[1], body: parts[2], updatedAt: DateTime.parse(parts[3])));
        }
      } catch (_) {
        // Ignore an unreadable old entry rather than preventing the app from opening.
      }
    }
    if (!mounted) return;
    setState(() {
      _notes = loaded..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _notes.map((n) => Uri.encodeComponent('${n.id}|${n.title}|${n.body}|${n.updatedAt.toIso8601String()}')).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> _upsertNote(Note note) async {
    if (!mounted) return;
    setState(() {
      _notes.removeWhere((n) => n.id == note.id);
      _notes.add(note);
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
    await _persist();
  }

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.of(context).push<Note>(
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note, onAutoSave: _upsertNote)),
    );
    if (result != null) await _upsertNote(result);
  }

  Future<void> _deleteNote(Note note) async {
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _notes.where((n) => ('${n.title} ${n.body}').toLowerCase().contains(_query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pamsho Notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 23)),
          Text('Your thoughts, neatly saved', style: TextStyle(fontSize: 12, color: Color(0xFF788392))),
        ]),
        actions: [
          IconButton(tooltip: 'About', onPressed: () => showAboutDialog(context: context, applicationName: 'Pamsho Notes', applicationVersion: '1.0.0', applicationLegalese: 'Simple notes, fast save.'), icon: const Icon(Icons.info_outline)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(hintText: 'Search your notes', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 22),
            Row(children: [
              const Text('All notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF17212B))),
              const Spacer(),
              Text('${_notes.length} ${_notes.length == 1 ? 'note' : 'notes'}', style: const TextStyle(color: Color(0xFF788392), fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                  ? _EmptyState(searching: _query.isNotEmpty, onCreate: () => _openEditor())
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = visible[index];
                        return Dismissible(
                          key: ValueKey(note.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteNote(note),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 22),
                            decoration: BoxDecoration(color: const Color(0xFFFFE8E8), borderRadius: BorderRadius.circular(18)),
                            child: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _openEditor(note: note),
                              child: Padding(
                                padding: const EdgeInsets.all(17),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(note.title.isEmpty ? 'Untitled note' : note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF17212B))),
                                  if (note.body.isNotEmpty) ...[
                                    const SizedBox(height: 7),
                                    Text(note.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.4, color: Color(0xFF687586))),
                                  ],
                                  const SizedBox(height: 12),
                                  Text(_formatDate(note.updatedAt), style: const TextStyle(fontSize: 11, color: Color(0xFF9AA4B1))),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching, required this.onCreate});
  final bool searching;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 76, height: 76, decoration: BoxDecoration(color: const Color(0xFFE8EEFF), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.sticky_note_2_outlined, size: 36, color: Color(0xFF426BEB))),
      const SizedBox(height: 18),
      Text(searching ? 'No matching notes' : 'Nothing here yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(searching ? 'Try another search.' : 'Create your first note and keep ideas close.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF788392))),
      if (!searching) ...[
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create a note')),
      ],
    ]),
  );
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note, required this.onAutoSave});
  final Note? note;
  final Future<void> Function(Note) onAutoSave;
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  Timer? _saveTimer;
  late final String _noteId;
  bool _saving = false;
  bool _saved = false;

  bool get _hasContent => _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _noteId = widget.note?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _title.addListener(_scheduleAutoSave);
    _body.addListener(_scheduleAutoSave);
  }

  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    if (!_hasContent) return;
    setState(() { _saving = true; _saved = false; });
    _saveTimer = Timer(const Duration(milliseconds: 650), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!_hasContent) return;
    final note = Note(id: _noteId, title: _title.text.trim(), body: _body.text.trim(), updatedAt: DateTime.now());
    await widget.onAutoSave(note);
    if (mounted) setState(() { _saving = false; _saved = true; });
  }

  Future<void> _finish() async {
    _saveTimer?.cancel();
    if (_hasContent) await _autoSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) { if (!didPop) _finish(); },
    child: Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F6),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _finish),
        title: Text(widget.note == null ? 'New note' : 'Edit note', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(child: Text(_saving ? 'Saving…' : (_saved ? 'Saved' : 'Auto-save on'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF788392), fontWeight: FontWeight.w600))),
        )],
      ),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(children: [
          TextField(controller: _title, textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF253044)),
            decoration: const InputDecoration(hintText: 'Title', filled: false)),
          const SizedBox(height: 12),
          Expanded(child: TextField(controller: _body, expands: true, maxLines: null, minLines: null,
            textCapitalization: TextCapitalization.sentences, textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(height: 1.55, color: Color(0xFF354052)),
            decoration: const InputDecoration(hintText: 'Start writing...', filled: false))),
        ]),
      )),
    ),
  );
}
