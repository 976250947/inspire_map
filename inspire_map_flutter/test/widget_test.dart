// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inspire_map_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: InspireMapApp()));
    await tester.pumpAndSettle();
    
    // We just verify it builds without crashing for now
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
