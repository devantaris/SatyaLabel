import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:satyalabel_frontend/models/scan_models.dart';
import 'package:satyalabel_frontend/ui/checklist/checklist_sheet.dart';
import 'package:satyalabel_frontend/ui/rules/rules_sheet.dart';
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

  testWidgets('DashboardStatCard renders title, value, subtitle and handles tap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      DashboardStatCard(
        title: 'Total Scans',
        value: '42',
        subtitle: 'On this device',
        icon: Icons.history,
        color: Colors.teal,
        onTap: () => tapped = true,
      ),
    ));

    expect(find.text('Total Scans'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);

    await tester.tap(find.text('Total Scans'));
    expect(tapped, isTrue);
  });

  testWidgets('QuickActionTile renders title, subtitle, badge and handles tap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      QuickActionTile(
        title: 'Batch Raid Sessions',
        subtitle: 'Scan multiple products under one session',
        badgeText: 'OFFICER',
        badgeColor: Colors.indigo,
        icon: Icons.inventory_2,
        color: Colors.indigo,
        onTap: () => tapped = true,
      ),
    ));

    expect(find.text('Batch Raid Sessions'), findsOneWidget);
    expect(find.text('Scan multiple products under one session'), findsOneWidget);
    expect(find.text('OFFICER'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2), findsOneWidget);

    await tester.tap(find.text('Batch Raid Sessions'));
    expect(tapped, isTrue);
  });

  testWidgets('SectionHeader renders title and action label', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      SectionHeader(
        title: 'TEST SECTION',
        actionLabel: 'View More',
        onAction: () => tapped = true,
      ),
    ));

    expect(find.text('TEST SECTION'), findsOneWidget);
    expect(find.text('View More'), findsOneWidget);

    await tester.tap(find.text('View More'));
    expect(tapped, isTrue);
  });

  testWidgets('ChecklistSheet displays verification items and updates progress',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChecklistSheet()));
    expect(find.text('Field Inspection Checklist'), findsOneWidget);
    expect(find.text('0 of 8 items verified'), findsOneWidget);

    // Tap first checkbox
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('1 of 8 items verified'), findsOneWidget);
  });

  testWidgets('RulesSheet renders standards and supports searching',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RulesSheet()));
    expect(find.text('LM(PC) Rules 2011 Standards'), findsOneWidget);
    expect(find.text('Rule 6(1)(a)'), findsOneWidget);

    // Filter by search query
    await tester.enterText(find.byType(TextField), 'MRP');
    await tester.pump();

    expect(find.text('Rule 6(1)(e)'), findsOneWidget);
  });
}


