import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('horizontal SingleChildScrollView+Row in Column without explicit height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Container(
                color: Colors.red,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Icon(Icons.format_bold_rounded, size: 22),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Icon(Icons.format_italic_rounded, size: 22),
                      ),
                    ],
                  ),
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
    final size = tester.getSize(
      find.byType(SingleChildScrollView),
    );
    expect(size.height, 42.0); // content-based: 22 icon + 2*10 padding
  });
}
