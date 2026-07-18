import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/models/chat_assistant.dart';
import 'package:nexai/models/message.dart';

void main() {
  test('conversation keeps assistant and overrides', () {
    final conversation = Conversation(
      id: 'c1',
      title: 't',
      messages: const [],
      createdAt: DateTime.parse('2026-07-18T12:00:00.000Z'),
      assistantId: 'coder',
      modelOverride: 'gpt-4o-mini',
      systemPromptOverride: 'Be brief',
    );
    final restored = Conversation.fromJson(
      jsonDecode(jsonEncode(conversation.toJson())) as Map<String, dynamic>,
    );
    expect(restored.assistantId, 'coder');
    expect(restored.modelOverride, 'gpt-4o-mini');
    expect(restored.systemPromptOverride, 'Be brief');
  });

  test('message keeps reasoning and attachments', () {
    final message = Message(
      role: 'user',
      content: 'describe this',
      timestamp: DateTime.parse('2026-07-18T12:00:00.000Z'),
      reasoning: 'thinking',
      attachments: const [
        ChatAttachment(
          id: 'a1',
          type: 'image',
          name: 'x.png',
          path: '/tmp/x.png',
          mimeType: 'image/png',
          sizeBytes: 12,
        ),
      ],
    );
    final restored = Message.fromJson(
      jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
    );
    expect(restored.reasoning, 'thinking');
    expect(restored.attachments, hasLength(1));
    expect(restored.attachments.first.name, 'x.png');
  });

  test('prompt templates expand input', () {
    final template = PromptTemplateCatalog.all.first;
    final expanded = PromptTemplateCatalog.expand(template, 'hello');
    expect(expanded.contains('hello'), isTrue);
    expect(expanded.contains('{{input}}'), isFalse);
  });

  test('assistant catalog fallback', () {
    final assistant = ChatAssistantCatalog.byId('missing');
    expect(assistant.id, ChatAssistantCatalog.generalId);
  });
}
