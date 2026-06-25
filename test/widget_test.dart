// Basic smoke test for the SehatID app.

import 'package:flutter_test/flutter_test.dart';

import 'package:patient/app.dart';

void main() {
  testWidgets('App boots to splash without crashing', (tester) async {
    await tester.pumpWidget(const AppProviders(child: SehatIdApp()));
    await tester.pump();

    // The splash screen renders the brand name.
    expect(find.textContaining('Sehat'), findsWidgets);
  });
}
