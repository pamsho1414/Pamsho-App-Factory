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

  testWidgets('home screen opens with Easy Simple Notes branding', (tester) async {
    await tester.pumpWidget(const NotesApp());
    await tester.pumpAndSettle();
    expect(find.text('Easy Simple Notes'), findsOneWidget);
    expect(find.text('All notes'), findsOneWidget);
  });
}
