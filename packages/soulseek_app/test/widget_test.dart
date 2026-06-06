import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soulseek_app/main.dart';

void main() {
  testWidgets('App shows login screen when not authenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SoulseekApp(),
      ),
    );

    // The app should render a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);

    // When not authenticated, the LoginScreen should be shown
    expect(find.text('Connect to Soulseek'), findsWidgets);

    // Verify username and password fields exist
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
