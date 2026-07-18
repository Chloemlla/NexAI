/// Builtin chat tool catalog for NexAI Android conversations.
library;

import '../models/chat_tool.dart';

class ChatToolCatalog {
  ChatToolCatalog._();

  static const webSearch = 'web_search';
  static const notesSearch = 'notes_search';
  static const notesRead = 'notes_read';
  static const generateImage = 'generate_image';
  static const reportArtifacts = 'report_artifacts';
  static const fetchUrl = 'fetch_url';
  static const createNote = 'create_note';
  static const knowledgeSearch = 'knowledge_search';
  static const knowledgeRead = 'knowledge_read';

  static const List<ChatToolDefinition> all = [
    ChatToolDefinition(
      name: webSearch,
      description:
          'Search the public web for up-to-date information. Prefer short, concrete queries.',
      approval: ChatToolApprovalPolicy.auto,
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Search keywords. Avoid pronouns; expand context.',
          },
          'max_results': {
            'type': 'integer',
            'description': 'Maximum results to return (1-8). Default 5.',
          },
        },
        'required': ['query'],
      },
    ),
    ChatToolDefinition(
      name: notesSearch,
      description:
          'Search the user local notes by keywords, tags (tag:name), or is:starred.',
      approval: ChatToolApprovalPolicy.auto,
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Notes search query. Supports tag: and is:starred.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum notes to return (1-20). Default 8.',
          },
        },
        'required': ['query'],
      },
    ),
    ChatToolDefinition(
      name: notesRead,
      description:
          'Read one local note by id or exact title. Use after notes_search.',
      approval: ChatToolApprovalPolicy.auto,
      parameters: {
        'type': 'object',
        'properties': {
          'note_id': {
            'type': 'string',
            'description': 'Note id from notes_search.',
          },
          'title': {
            'type': 'string',
            'description': 'Exact note title when id is unknown.',
          },
          'max_chars': {
            'type': 'integer',
            'description': 'Maximum characters of body to return. Default 4000.',
          },
        },
      },
    ),
    ChatToolDefinition(
      name: generateImage,
      description:
          'Generate an image from a text prompt using the configured NexAI image model.',
      approval: ChatToolApprovalPolicy.prompt,
      readOnly: false,
      parameters: {
        'type': 'object',
        'properties': {
          'prompt': {
            'type': 'string',
            'description': 'Image generation prompt.',
          },
          'size': {
            'type': 'string',
            'description': 'Optional size like 1024x1024.',
          },
        },
        'required': ['prompt'],
      },
    ),
    ChatToolDefinition(
      name: reportArtifacts,
      description:
          'Publish content as a NexAI artifact and return a share URL. Requires login.',
      approval: ChatToolApprovalPolicy.prompt,
      readOnly: false,
      parameters: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Artifact title.'},
          'content': {
            'type': 'string',
            'description': 'Artifact body content.',
          },
          'content_type': {
            'type': 'string',
            'description': 'markdown | code | html | mermaid. Default markdown.',
          },
          'language': {
            'type': 'string',
            'description': 'Optional programming language for code artifacts.',
          },
          'description': {
            'type': 'string',
            'description': 'Optional short description.',
          },
          'visibility': {
            'type': 'string',
            'description': 'public | private | password. Default public.',
          },
        },
        'required': ['title', 'content'],
      },
    ),
    ChatToolDefinition(
      name: fetchUrl,
      description:
          'Fetch a public URL and return a readable text extract for the model.',
      approval: ChatToolApprovalPolicy.prompt,
      parameters: {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'Absolute http(s) URL to fetch.',
          },
          'max_chars': {
            'type': 'integer',
            'description': 'Maximum characters to return. Default 6000.',
          },
        },
        'required': ['url'],
      },
    ),
    ChatToolDefinition(
      name: createNote,
      description:
          'Create a local note with title and markdown content for the user.',
      approval: ChatToolApprovalPolicy.prompt,
      readOnly: false,
      parameters: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Note title.'},
          'content': {
            'type': 'string',
            'description': 'Note markdown content.',
          },
        },
        'required': ['content'],
      },
    ),

    ChatToolDefinition(
      name: knowledgeSearch,
      description:
          'Search imported local knowledge documents (txt/md/json/csv/log).',
      approval: ChatToolApprovalPolicy.auto,
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Keywords to search imported knowledge docs.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Max hits (1-20). Default 8.',
          },
        },
        'required': ['query'],
      },
    ),
    ChatToolDefinition(
      name: knowledgeRead,
      description: 'Read one imported knowledge document by id.',
      approval: ChatToolApprovalPolicy.auto,
      parameters: {
        'type': 'object',
        'properties': {
          'doc_id': {
            'type': 'string',
            'description': 'Document id from knowledge_search.',
          },
          'max_chars': {
            'type': 'integer',
            'description': 'Max characters to return. Default 5000.',
          },
        },
        'required': ['doc_id'],
      },
    ),
  ];

  static ChatToolDefinition? byName(String name) {
    for (final tool in all) {
      if (tool.name == name) return tool;
    }
    return null;
  }

  static List<ChatToolDefinition> enabledFromFlags({
    required bool webSearchEnabled,
    required bool notesEnabled,
    required bool imageEnabled,
    required bool artifactsEnabled,
    required bool fetchUrlEnabled,
    required bool createNoteEnabled,
    required bool knowledgeEnabled,
  }) {
    return all.where((tool) {
      switch (tool.name) {
        case webSearch:
          return webSearchEnabled;
        case notesSearch:
        case notesRead:
          return notesEnabled;
        case generateImage:
          return imageEnabled;
        case reportArtifacts:
          return artifactsEnabled;
        case fetchUrl:
          return fetchUrlEnabled;
        case createNote:
          return createNoteEnabled;
        case knowledgeSearch:
        case knowledgeRead:
          return knowledgeEnabled;
        default:
          return false;
      }
    }).toList(growable: false);
  }

  static bool isMcpTool(String name) => name.startsWith('mcp__');

  static String? mcpServerId(String name) {
    if (!isMcpTool(name)) return null;
    final parts = name.split('__');
    if (parts.length < 3) return null;
    return parts[1];
  }

  static String? mcpToolName(String name) {
    if (!isMcpTool(name)) return null;
    final parts = name.split('__');
    if (parts.length < 3) return null;
    return parts.sublist(2).join('__');
  }
}
