import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_nova/main.dart';

void main() {
  testWidgets('Cyber Nova home loads', (tester) async {
    await tester.pumpWidget(const CyberNovaApp());
    expect(find.text('Cyber Nova'), findsOneWidget);
    expect(find.text('Use Sample Product'), findsOneWidget);
  });
}
