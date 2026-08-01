import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('horizontal ListView in Column without explicit height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Container(
                // no height
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Icon(Icons.format_bold_rounded, size: 22),
                    Icon(Icons.format_italic_rounded, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('below'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
