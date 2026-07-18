/// Minimal remote MCP client (HTTP JSON-RPC) for tool discovery/execution.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_knowledge.dart';
import '../models/chat_tool.dart';

class RemoteMcpTool {
  final String serverId;
  final String serverName;
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const RemoteMcpTool({
    required this.serverId,
    required this.serverName,
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  String get qualifiedName => 'mcp__${serverId}__$name';

  ChatToolDefinition toDefinition() => ChatToolDefinition(
    name: qualifiedName,
    description: 'MCP/$serverName: $description',
    parameters: inputSchema.isEmpty
        ? {
            'type': 'object',
            'properties': <String, dynamic>{},
          }
        : inputSchema,
    approval: ChatToolApprovalPolicy.prompt,
    readOnly: false,
  );
}

class RemoteMcpClient {
  RemoteMcpClient({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 20),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json, text/event-stream',
              },
            ),
          );

  final Dio _dio;
  int _rpcId = 1;

  Future<List<RemoteMcpTool>> listTools(McpServerConfig server) async {
    final response = await _rpc(
      server,
      method: 'tools/list',
      params: const <String, dynamic>{},
    );
    final toolsRaw = response['tools'];
    if (toolsRaw is! List) return const [];
    final tools = <RemoteMcpTool>[];
    for (final item in toolsRaw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final schema = map['inputSchema'];
      tools.add(
        RemoteMcpTool(
          serverId: server.id,
          serverName: server.name,
          name: (map['name'] ?? '').toString(),
          description: (map['description'] ?? '').toString(),
          inputSchema: schema is Map
              ? schema.map((k, v) => MapEntry(k.toString(), v))
              : <String, dynamic>{'type': 'object', 'properties': <String, dynamic>{}},
        ),
      );
    }
    return tools;
  }

  Future<ToolExecutionResult> callTool({
    required McpServerConfig server,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    final response = await _rpc(
      server,
      method: 'tools/call',
      params: {
        'name': toolName,
        'arguments': arguments,
      },
    );
    final isError = response['isError'] == true;
    final content = response['content'];
    final parts = <String>[];
    if (content is List) {
      for (final item in content) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          final text = (map['text'] ?? map['data'] ?? '').toString();
          if (text.isNotEmpty) parts.add(text);
        } else if (item != null) {
          parts.add(item.toString());
        }
      }
    }
    final body = parts.isEmpty ? jsonEncode(response) : parts.join('\n\n');
    return ToolExecutionResult(
      content: body,
      isError: isError,
    );
  }

  Future<Map<String, dynamic>> _rpc(
    McpServerConfig server, {
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final id = _rpcId++;
    final payload = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };
    try {
      final response = await _dio.post<dynamic>(
        server.url,
        data: payload,
        options: Options(
          headers: {
            if (server.bearerToken != null && server.bearerToken!.isNotEmpty)
              'Authorization': 'Bearer ${server.bearerToken}',
          },
          responseType: ResponseType.plain,
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      final raw = (response.data ?? '').toString();
      final decoded = _decodePossiblySse(raw);
      if (decoded['error'] != null) {
        throw StateError(decoded['error'].toString());
      }
      final result = decoded['result'];
      if (result is Map<String, dynamic>) return result;
      if (result is Map) {
        return result.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{'result': result};
    } catch (e) {
      debugPrint('MCP rpc failed ($method @ ${server.url}): $e');
      rethrow;
    }
  }

  Map<String, dynamic> _decodePossiblySse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      final json = jsonDecode(trimmed);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return json.map((k, v) => MapEntry(k.toString(), v));
    }
    // SSE: take last data: line
    String? lastData;
    for (final line in trimmed.split('\n')) {
      final t = line.trim();
      if (t.startsWith('data:')) {
        lastData = t.substring(5).trim();
      }
    }
    if (lastData != null && lastData.isNotEmpty) {
      final json = jsonDecode(lastData);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return json.map((k, v) => MapEntry(k.toString(), v));
    }
    throw StateError('Unrecognized MCP response');
  }
}
