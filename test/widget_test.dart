import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pamsho_notes/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('note JSON round trip keeps note fields', () {
    final n = Note('a', 'Title', 'Body', DateTime(2026, 11, 4));
    final copy = Note.from(n.json());
    expect(copy.id, n.id);
    expect(copy.title, n.title);
    expect(copy.body, n.body);
    expect(copy.updated, n.updated);
  });

  test('store supports save, bin, restore and permanent delete', () async {
    final store = NotesStore();
    await store.load();
    final note = Note('test-1', 'Test title', 'Test body', DateTime(2026, 11, 4));
    await store.upsert(note);
    expect(store.notes, hasLength(1));
    await store.trash(note);
    expect(store.notes, isEmpty);
    expect(store.bin, hasLength(1));
    await store.restore(note);
    expect(store.notes, hasLength(1));
    expect(store.bin, isEmpty);
    await store.trash(note);
    await store.erase(note);
    expect(store.bin, isEmpty);
    store.dispose();
  });

  test('pinned notes stay above regular notes and survive storage reload', () async {
    final store = NotesStore();
    await store.load();
    final older = Note('older', 'Older', 'First', DateTime(2026, 11, 1));
    final newer = Note('newer', 'Newer', 'Second', DateTime(2026, 11, 4));
    await store.upsert(older);
    await store.upsert(newer);
    await store.togglePin(older);
    expect(store.notes.first.id, 'older');
    final reloaded = NotesStore();
    await reloaded.load();
    expect(reloaded.notes.first.pinned, isTrue);
    expect(reloaded.notes.first.id, 'older');
    store.dispose();
    reloaded.dispose();
  });

  test('note category defaults safely and survives storage reload', () async {
    final store = NotesStore();
    await store.load();
    final note = Note('work-1', 'Project', 'Plan', DateTime(2026, 11, 4), category: 'Work');
    await store.upsert(note);
    final reloaded = NotesStore();
    await reloaded.load();
    expect(reloaded.notes.single.category, 'Work');
    final legacy = Note.from({
      'id': 'legacy', 'title': 'Old', 'body': 'Note',
      'updated': DateTime(2026, 11, 1).toIso8601String(),
    });
    expect(legacy.category, 'General');
    store.dispose();
    reloaded.dispose();
  });

  test('backup restores active notes, Bin and note metadata', () async {
    final source = NotesStore();
    await source.load();
    final pinned = Note('backup-1', 'Pinned', 'Keep me', DateTime(2026, 11, 4), pinned: true, category: 'Work', colorValue: 0xFFDCEBFF);
    final deleted = Note('backup-2', 'Deleted', 'Restore me', DateTime(2026, 11, 3), category: 'Personal');
    await source.upsert(pinned);
    await source.upsert(deleted);
    await source.trash(deleted);
    final payload = jsonEncode(source.backupData());

    final destination = NotesStore();
    await destination.load();
    await destination.upsert(Note('old', 'Old device note', '', DateTime(2026, 11, 2)));
    await destination.importBackup(payload);

    expect(destination.notes, hasLength(1));
    expect(destination.notes.single.id, 'backup-1');
    expect(destination.notes.single.pinned, isTrue);
    expect(destination.notes.single.category, 'Work');
    expect(destination.notes.single.colorValue, 0xFFDCEBFF);
    expect(destination.bin.single.id, 'backup-2');
    source.dispose();
    destination.dispose();
  });

  test('invalid backup is rejected without overwriting existing notes', () async {
    final store = NotesStore();
    await store.load();
    await store.upsert(Note('safe', 'Keep this', '', DateTime(2026, 11, 4)));
    await expectLater(
      store.importBackup('{"format":"wrong","version":1,"notes":[],"bin":[]}'),
      throwsFormatException,
    );
    expect(store.notes.single.id, 'safe');
    store.dispose();
  });

  testWidgets('home screen opens with Easy Simple Notes branding', (tester) async {
    await tester.pumpWidget(const NotesApp(enableAds: false));
    await tester.pumpAndSettle();
    expect(find.text('Easy Simple Notes'), findsOneWidget);
    expect(find.text('All notes'), findsOneWidget);
  });
}
