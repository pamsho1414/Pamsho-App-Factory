import 'package:flutter_test/flutter_test.dart';
import 'package:pamsho_notes/main.dart';

void main() {
  test('note JSON round trip keeps note fields', () {
    final n = Note('a', 'Title', 'Body', DateTime(2026, 11, 4));
    final copy = Note.from(n.json());
    expect(copy.id, n.id);
    expect(copy.title, n.title);
    expect(copy.body, n.body);
    expect(copy.updated, n.updated);
  });
}
