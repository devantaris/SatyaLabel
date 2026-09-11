import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:satyalabel_frontend/models/scan_models.dart';
import 'package:satyalabel_frontend/ui/widgets.dart';

ScanResult _result(Verdict verdict, {String? summary}) => ScanResult(
      scanId: '7c9e6679-0000-0000-0000-000000000000',
      status: 'COMPLETED',
      verdict: verdict,
      summary: summary,
      violations: const [
        Violation(
          field: 'best_before_date',
          severity: 'CRITICAL',
          message: 'MISSING: Best Before date not found.',
          rule: 'Rule 6(1)(g), LM(PC) Rules 2011',
        ),
      ],
    );

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('VerdictBanner shows the verdict label and summary',
      (tester) async {
    await tester.pumpWidget(wrap(
      VerdictBanner(result: _result(Verdict.nonCompliant, summary: 'Missing declarations')),
    ));

    expect(find.text('NON-COMPLIANT'), findsOneWidget);
    expect(find.text('Missing declarations'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('VerdictBanner reflects the compliant state', (tester) async {
    await tester.pumpWidget(wrap(VerdictBanner(result: _result(Verdict.compliant))));

    expect(find.text('COMPLIANT'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('VerdictBanner reflects the needs-verification state',
      (tester) async {
    await tester.pumpWidget(
        wrap(VerdictBanner(result: _result(Verdict.needsVerification))));

    expect(find.text('NEEDS VERIFICATION'), findsOneWidget);
    expect(find.byIcon(Icons.help), findsOneWidget);
  });

  testWidgets('StatusBanner renders message and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(StatusBanner(
      icon: Icons.cloud_off,
      message: 'Offline — scans will be queued',
      color: Colors.orange,
      action: TextButton(
        onPressed: () => tapped = true,
        child: const Text('Retry'),
      ),
    )));

    expect(find.text('Offline — scans will be queued'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(tapped, isTrue);
  });
}
