import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_nova/screens/home_screen.dart';
import 'package:cyber_nova/screens/report_screen.dart';
import 'package:cyber_nova/utils/app_theme.dart';

void main() {
  Future<void> pumpPhone(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: home,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('home scan actions are vertically stacked with required labels',
      (tester) async {
    await pumpPhone(tester, const HomeScreen());

    expect(find.text('Scan Product from Camera'), findsOneWidget);
    expect(find.text('Select Photo from Gallery'), findsOneWidget);
    expect(find.text('Take Photo'), findsNothing);
    expect(find.text('Select Product Image'), findsNothing);
    expect(find.text('Add Another Photo'), findsNothing);
    expect(find.text('Analyze Product'), findsOneWidget);

    final camera = tester.getTopLeft(find.text('Scan Product from Camera'));
    final gallery = tester.getTopLeft(find.text('Select Photo from Gallery'));
    expect(gallery.dy, greaterThan(camera.dy));

    expect(tester.takeException(), isNull);
  });

  testWidgets('inspection report actions use two-row layout', (tester) async {
    await pumpPhone(tester, const ReportScreen());

    expect(find.text('Back'), findsWidgets);
    expect(find.text('Save Report'), findsOneWidget);
    expect(find.text('Generate PDF'), findsOneWidget);

    final back = tester.getCenter(find.text('Back').last);
    final save = tester.getCenter(find.text('Save Report'));
    final pdf = tester.getCenter(find.text('Generate PDF'));
    expect((back.dy - save.dy).abs(), lessThan(8));
    expect(pdf.dy, greaterThan(save.dy + 8));
  });
}
