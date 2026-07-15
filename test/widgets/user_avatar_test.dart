import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/widgets/user_avatar.dart';

void main() {
  testWidgets('UserAvatar falls back to initial when imageUrl is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            imageUrl: null,
            displayName: 'Chloe',
            username: 'chloe',
            radius: 20,
          ),
        ),
      ),
    );

    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('UserAvatar uses username initial when displayName is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            imageUrl: '',
            displayName: '  ',
            username: 'nexai',
            radius: 20,
          ),
        ),
      ),
    );

    expect(find.text('N'), findsOneWidget);
  });
}
