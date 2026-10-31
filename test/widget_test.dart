// Widget tests for EmployeeScreen.
//
// These use an in-memory FakeFirebaseFirestore, so they check the UI,
// validation and Create/Read logic only. They do NOT talk to the real
// Google Cloud Firestore; that is verified by running the app on Android.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_experiment_7_google_cloud_firestore/employee_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeScreen(collection: firestore.collection('employees')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSave(
    WidgetTester tester,
    String name,
    String empid,
    String salary,
  ) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), empid);
    await tester.enterText(fields.at(2), salary);
    await tester.tap(find.text('Save Details'));
    await tester.pumpAndSettle();
  }

  setUp(() => firestore = FakeFirebaseFirestore());

  testWidgets('shows title, form and empty state', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Employee Application'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Save Details'), findsOneWidget);
    expect(find.text('No Employees Found'), findsOneWidget);
  });

  testWidgets('empty fields are rejected and nothing is saved', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Save Details'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Please enter your Employee ID'), findsOneWidget);
    expect(find.text('Please enter your salary'), findsOneWidget);
    expect(find.text('Data Saved Successfully'), findsNothing);
    expect((await firestore.collection('employees').get()).docs, isEmpty);
  });

  testWidgets('non-numeric EmpID and salary are rejected', (tester) async {
    await pumpScreen(tester);

    await fillAndSave(tester, 'Suresh', 'abc', '12.5x');

    expect(find.text('Employee ID must be a positive number'), findsOneWidget);
    expect(find.text('Salary must be a valid whole number'), findsOneWidget);
    expect((await firestore.collection('employees').get()).docs, isEmpty);
  });

  testWidgets('saves employee with correct types, clears form, lists it', (
    tester,
  ) async {
    await pumpScreen(tester);

    await fillAndSave(tester, 'Suresh', '2345', '67000');

    expect(find.text('Data Saved Successfully'), findsOneWidget);
    final docs = (await firestore.collection('employees').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.first.data(), {
      'name': 'Suresh',
      'empid': 2345,
      'salary': 67000,
    });

    // Inputs cleared
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.controller!.text, isEmpty);
    }

    // Shown in the list
    expect(find.text('Suresh'), findsOneWidget);
    expect(find.text('EMPID: 2345 SALARY:67000'), findsOneWidget);
  });

  testWidgets('multiple employees and external changes appear live', (
    tester,
  ) async {
    await pumpScreen(tester);

    await fillAndSave(tester, 'bright', '781', '60000');
    await fillAndSave(tester, 'Joel', '891', '78000');

    // A write made outside the form (e.g. Firebase Console) must show up
    // through the snapshots() stream without any manual refresh.
    await firestore.collection('employees').add({
      'name': 'Victor',
      'empid': 890,
      'salary': 40000,
    });
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('bright'), findsOneWidget);
    expect(find.text('Joel'), findsOneWidget);
    expect(find.text('Victor'), findsOneWidget);
  });
}
