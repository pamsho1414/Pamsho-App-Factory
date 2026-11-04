import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pamsho_notes/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android cold start renders notes home with AdMob enabled', (tester) async {
    await tester.pumpWidget(const NotesApp(enableAds: true));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Easy Simple Notes'), findsOneWidget);
    expect(find.text('All notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
