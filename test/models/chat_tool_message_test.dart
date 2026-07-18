import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/models/chat_tool.dart';
import 'package:nexai/models/message.dart';
import 'package:nexai/services/chat_tool_catalog.dart';

void main() {
  test('message roundtrip keeps tool calls and citations', () {
    final original = Message(
      role: 'assistant',
      content: '工具结果如下',
      timestamp: DateTime.parse('2026-07-18T10:00:00.000Z'),
      toolCalls: [
        const ToolCallRecord(
          id: 'call_1',
          name: 'web_search',
          argumentsJson: '{"query":"nexai"}',
        ),
      ],
      toolRuns: [
        ToolRunRecord(
          callId: 'call_1',
          name: 'web_search',
          argumentsJson: '{"query":"nexai"}',
          status: ChatToolRunStatus.success,
          resultPreview: 'ok',
          citations: const [
            Citation(
              title: 'NexAI',
              url: 'https://example.com',
              snippet: 'demo',
              source: 'web_search',
            ),
          ],
          updatedAt: DateTime.parse('2026-07-18T10:00:01.000Z'),
        ),
      ],
      citations: const [
        Citation(
          title: 'NexAI',
          url: 'https://example.com',
          snippet: 'demo',
          source: 'web_search',
        ),
      ],
    );

    final encoded = jsonEncode(original.toJson());
    final restored = Message.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );

    expect(restored.role, 'assistant');
    expect(restored.toolCalls, hasLength(1));
    expect(restored.toolCalls.first.name, 'web_search');
    expect(restored.toolRuns, hasLength(1));
    expect(restored.toolRuns.first.status, ChatToolRunStatus.success);
    expect(restored.citations, hasLength(1));
    expect(restored.citations.first.url, 'https://example.com');
  });

  test('legacy plain messages still decode', () {
    final message = Message.fromJson({
      'role': 'user',
      'content': 'hello',
      'timestamp': '2026-07-18T10:00:00.000Z',
    });
    expect(message.role, 'user');
    expect(message.content, 'hello');
    expect(message.toolCalls, isEmpty);
    expect(message.citations, isEmpty);
  });

  test('catalog enables selected tools only', () {
    final tools = ChatToolCatalog.enabledFromFlags(
      webSearchEnabled: true,
      notesEnabled: true,
      imageEnabled: false,
      artifactsEnabled: true,
      fetchUrlEnabled: false,
      createNoteEnabled: true,
      knowledgeEnabled: false,
    );
    final names = tools.map((t) => t.name).toSet();
    expect(names, contains(ChatToolCatalog.webSearch));
    expect(names, contains(ChatToolCatalog.notesSearch));
    expect(names, contains(ChatToolCatalog.notesRead));
    expect(names, contains(ChatToolCatalog.reportArtifacts));
    expect(names, contains(ChatToolCatalog.createNote));
    expect(names, isNot(contains(ChatToolCatalog.generateImage)));
    expect(names, isNot(contains(ChatToolCatalog.fetchUrl)));
  });

  test('openai tool schema includes function type', () {
    final tool = ChatToolCatalog.byName(ChatToolCatalog.webSearch)!;
    final schema = tool.toOpenAiTool();
    expect(schema['type'], 'function');
    expect(schema['function']?['name'], 'web_search');
    expect(schema['function']?['parameters'], isA<Map>());
  });
}
