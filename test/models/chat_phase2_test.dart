import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/models/chat_knowledge.dart';
import 'package:nexai/models/message.dart';
import 'package:nexai/services/chat_tool_catalog.dart';

void main() {
  test('message stats and branch metadata roundtrip', () {
    final message = Message(
      role: 'assistant',
      content: 'hi',
      timestamp: DateTime.parse('2026-07-18T12:00:00.000Z'),
      modelId: 'gpt-4o',
      siblingGroupId: 3,
      isActiveBranch: true,
      stats: const MessageStats(
        promptTokens: 10,
        completionTokens: 20,
        totalTokens: 30,
        timeToFirstTokenMs: 120,
        completionMs: 900,
      ),
    );
    final restored = Message.fromJson(
      jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
    );
    expect(restored.modelId, 'gpt-4o');
    expect(restored.siblingGroupId, 3);
    expect(restored.stats?.totalTokens, 30);
    expect(restored.stats?.timeToFirstTokenMs, 120);
  });

  test('knowledge doc encode/decode', () {
    final doc = KnowledgeDoc(
      id: 'd1',
      title: 'spec',
      sourceType: 'file',
      sourcePath: '/tmp/a.md',
      content: 'hello knowledge',
      createdAt: DateTime.parse('2026-07-18T12:00:00.000Z'),
      updatedAt: DateTime.parse('2026-07-18T12:00:00.000Z'),
    );
    final list = KnowledgeDoc.decodeList(KnowledgeDoc.encodeList([doc]));
    expect(list, hasLength(1));
    expect(list.first.title, 'spec');
  });

  test('mcp tool name helpers', () {
    expect(ChatToolCatalog.isMcpTool('mcp__s1__search'), isTrue);
    expect(ChatToolCatalog.mcpServerId('mcp__s1__search'), 's1');
    expect(ChatToolCatalog.mcpToolName('mcp__s1__search'), 'search');
  });

  test('catalog includes knowledge tools when enabled', () {
    final tools = ChatToolCatalog.enabledFromFlags(
      webSearchEnabled: false,
      notesEnabled: false,
      imageEnabled: false,
      artifactsEnabled: false,
      fetchUrlEnabled: false,
      createNoteEnabled: false,
      knowledgeEnabled: true,
    );
    final names = tools.map((t) => t.name).toSet();
    expect(names, contains(ChatToolCatalog.knowledgeSearch));
    expect(names, contains(ChatToolCatalog.knowledgeRead));
  });
}
