/// Chat assistant presets and local catalog for NexAI conversations.
library;

class ChatAssistant {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String systemPrompt;
  final String? preferredModel;

  const ChatAssistant({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.systemPrompt,
    this.preferredModel,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'description': description,
    'systemPrompt': systemPrompt,
    if (preferredModel != null) 'preferredModel': preferredModel,
  };

  factory ChatAssistant.fromJson(Map<String, dynamic> json) => ChatAssistant(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? 'Assistant').toString(),
    emoji: (json['emoji'] ?? '🤖').toString(),
    description: (json['description'] ?? '').toString(),
    systemPrompt: (json['systemPrompt'] ?? '').toString(),
    preferredModel: json['preferredModel']?.toString(),
  );
}

class ChatAssistantCatalog {
  ChatAssistantCatalog._();

  static const generalId = 'general';

  static const List<ChatAssistant> presets = [
    ChatAssistant(
      id: generalId,
      name: '通用助手',
      emoji: '🤖',
      description: '均衡回答，适合日常问答与写作。',
      systemPrompt:
          'You are a helpful assistant. When responding with mathematical or chemical formulas, use LaTeX notation.',
    ),
    ChatAssistant(
      id: 'coder',
      name: '编程搭档',
      emoji: '💻',
      description: '偏代码实现、排错与重构建议。',
      systemPrompt:
          'You are a senior software engineer. Prefer concise, correct code, explain trade-offs briefly, and call out risks.',
    ),
    ChatAssistant(
      id: 'researcher',
      name: '研究助手',
      emoji: '🔎',
      description: '适合检索整理与带来源的分析。',
      systemPrompt:
          'You are a careful research assistant. Prefer verified facts, cite sources when tools provide them, and separate facts from speculation.',
    ),
    ChatAssistant(
      id: 'translator',
      name: '翻译润色',
      emoji: '🌐',
      description: '中英互译与表达润色。',
      systemPrompt:
          'You are a professional translator and editor. Preserve meaning, improve clarity, and keep terminology consistent.',
    ),
    ChatAssistant(
      id: 'concise',
      name: '简洁模式',
      emoji: '⚡️',
      description: '短答优先，少客套。',
      systemPrompt:
          'You are a concise assistant. Answer in the fewest useful words. Use bullets when listing. Avoid filler.',
    ),
  ];

  static ChatAssistant byId(String? id) {
    final target = (id == null || id.isEmpty) ? generalId : id;
    for (final item in presets) {
      if (item.id == target) return item;
    }
    return presets.first;
  }
}

class PromptTemplate {
  final String id;
  final String title;
  final String body;
  final String? description;

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.body,
    this.description,
  });
}

class PromptTemplateCatalog {
  PromptTemplateCatalog._();

  static const List<PromptTemplate> all = [
    PromptTemplate(
      id: 'summarize',
      title: '总结要点',
      description: '提炼关键结论',
      body: '请用简洁中文总结以下内容，列出 3-5 个要点：\n\n{{input}}',
    ),
    PromptTemplate(
      id: 'explain',
      title: '通俗解释',
      description: '把复杂内容讲清楚',
      body: '请用通俗易懂的中文解释下面内容，并给一个生活化例子：\n\n{{input}}',
    ),
    PromptTemplate(
      id: 'rewrite',
      title: '润色改写',
      description: '更清晰专业',
      body: '请润色以下文本，保持原意，让表达更清晰专业：\n\n{{input}}',
    ),
    PromptTemplate(
      id: 'translate_zh',
      title: '译成中文',
      description: '保留术语',
      body: '请把以下内容翻译成自然中文，保留专有名词：\n\n{{input}}',
    ),
    PromptTemplate(
      id: 'translate_en',
      title: '译成英文',
      description: '自然流畅',
      body: 'Translate the following into natural English. Keep technical terms accurate:\n\n{{input}}',
    ),
    PromptTemplate(
      id: 'plan',
      title: '行动计划',
      description: '拆成可执行步骤',
      body: '请把下面目标拆成可执行计划，包含步骤、风险和验收标准：\n\n{{input}}',
    ),
  ];

  static String expand(PromptTemplate template, String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return template.body.replaceAll('{{input}}', '');
    }
    return template.body.replaceAll('{{input}}', value);
  }
}
