import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pato_track/widgets/loading_widgets.dart';

void main() {
  testWidgets('ModernLoadingIndicator renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ModernLoadingIndicator(message: 'Loading...'),
        ),
      ),
    );

    expect(find.byType(ModernLoadingIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
  });
}
