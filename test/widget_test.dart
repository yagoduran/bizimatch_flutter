import 'package:bizimatch_flutter/main.dart';
import 'package:bizimatch_flutter/providers/theme_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('BiziMatchApp builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const BiziMatchApp(),
      ),
    );

    expect(find.byType(BiziMatchApp), findsOneWidget);
  });
}
