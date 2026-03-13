# GptMarkdown CSS 集成技术文档

## 目标

让 `gpt_markdown` 包支持加载和应用 `assets/github-markdown.css` 样式文件。

## 可行性分析

### 核心挑战

1. **架构不兼容**
   - GptMarkdown 使用 Flutter 原生渲染（TextSpan + Widget 树）
   - CSS 是 Web 技术，Flutter 不原生支持
   - 需要 CSS → Flutter 样式的转换层

2. **CSS 复杂度**
   - GitHub Markdown CSS 有 31KB，包含数百条规则
   - 包含 CSS 变量、媒体查询、伪类、复杂选择器
   - Flutter 的样式系统比 CSS 简单得多

3. **性能考虑**
   - 实时解析 CSS 会影响渲染性能
   - 需要缓存和预编译策略

## 方案对比

### 方案 1：Fork GptMarkdown + CSS 解析器（推荐）

**优点**：
- 完全控制渲染逻辑
- 可以优化性能
- 支持自定义扩展

**缺点**：
- 开发工作量大（2-3周）
- 需要维护 fork 版本
- CSS 解析器复杂

**实现步骤**：

1. **Fork gpt_markdown**
   ```bash
   git clone https://github.com/Chloemlla/gpt_markdown_css.git
   cd gpt_markdown_css
   ```

2. **添加 CSS 解析依赖**
   ```yaml
   # pubspec.yaml
   dependencies:
     csslib: ^1.0.0  # CSS 解析器
   ```

3. **创建 CSS 解析器**
   ```dart
   // lib/src/css_parser.dart
   import 'package:csslib/parser.dart' as css;
   import 'package:flutter/material.dart';

   class MarkdownCssParser {
     final Map<String, TextStyle> _textStyles = {};
     final Map<String, BoxDecoration> _decorations = {};

     Future<void> loadCss(String cssContent) async {
       final stylesheet = css.parse(cssContent);

       for (final rule in stylesheet.topLevels) {
         if (rule is css.RuleSet) {
           _parseRuleSet(rule);
         }
       }
     }

     void _parseRuleSet(css.RuleSet rule) {
       // 提取选择器
       final selector = rule.selectorGroup?.toString() ?? '';

       // 解析声明
       final declarations = <String, String>{};
       for (final decl in rule.declarationGroup.declarations) {
         if (decl is css.Declaration) {
           declarations[decl.property] = decl.expression.toString();
         }
       }

       // 转换为 Flutter 样式
       if (selector.contains('code')) {
         _textStyles['code'] = _buildTextStyle(declarations);
       } else if (selector.contains('h1')) {
         _textStyles['h1'] = _buildTextStyle(declarations);
       }
       // ... 更多选择器映射
     }

     TextStyle _buildTextStyle(Map<String, String> declarations) {
       Color? color;
       double? fontSize;
       FontWeight? fontWeight;

       if (declarations.containsKey('color')) {
         color = _parseColor(declarations['color']!);
       }
       if (declarations.containsKey('font-size')) {
         fontSize = _parseFontSize(declarations['font-size']!);
       }
       if (declarations.containsKey('font-weight')) {
         fontWeight = _parseFontWeight(declarations['font-weight']!);
       }

       return TextStyle(
         color: color,
         fontSize: fontSize,
         fontWeight: fontWeight,
       );
     }

     Color? _parseColor(String colorStr) {
       // 解析 #RRGGBB, rgb(), var(--color) 等
       if (colorStr.startsWith('#')) {
         return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
       }
       // ... 更多颜色格式
       return null;
     }

     double? _parseFontSize(String sizeStr) {
       // 解析 16px, 1rem, 1.5em 等
       if (sizeStr.endsWith('px')) {
         return double.tryParse(sizeStr.replaceAll('px', ''));
       }
       return null;
     }

     FontWeight? _parseFontWeight(String weightStr) {
       switch (weightStr) {
         case '400': return FontWeight.w400;
         case '500': return FontWeight.w500;
         case '600': return FontWeight.w600;
         case '700': return FontWeight.w700;
         case 'bold': return FontWeight.bold;
         default: return null;
       }
     }

     TextStyle? getTextStyle(String element) => _textStyles[element];
     BoxDecoration? getDecoration(String element) => _decorations[element];
   }
   ```

4. **修改 GptMarkdown 主类**
   ```dart
   // lib/gpt_markdown.dart
   class GptMarkdown extends StatelessWidget {
     final String data;
     final MarkdownCssParser? cssParser;  // 新增

     const GptMarkdown(
       this.data, {
       this.cssParser,
       // ... 其他参数
     });

     @override
     Widget build(BuildContext context) {
       // 使用 cssParser 提供的样式
       final codeStyle = cssParser?.getTextStyle('code') ?? defaultCodeStyle;
       final h1Style = cssParser?.getTextStyle('h1') ?? defaultH1Style;

       // ... 渲染逻辑
     }
   }
   ```

5. **在 NexAI 中使用**
   ```dart
   // lib/widgets/rich_content_view.dart
   class _MarkdownWidgetState extends State<_MarkdownWidget> {
     late MarkdownCssParser _cssParser;

     @override
     void initState() {
       super.initState();
       _loadCss();
     }

     Future<void> _loadCss() async {
       _cssParser = MarkdownCssParser();
       final cssContent = await rootBundle.loadString(
         'assets/github-markdown.css',
       );
       await _cssParser.loadCss(cssContent);
       setState(() {});
     }

     @override
     Widget build(BuildContext context) {
       return GptMarkdown(
         widget.data,
         cssParser: _cssParser,
       );
     }
   }
   ```

**工作量估算**：
- CSS 解析器：5-7天
- GptMarkdown 集成：3-5天
- 测试和优化：3-5天
- **总计：2-3周**

---

### 方案 2：CSS 预编译器（快速方案）

**优点**：
- 无需 fork GptMarkdown
- 开发速度快（2-3天）
- 易于维护

**缺点**：
- 不支持动态 CSS
- 需要手动映射样式
- 功能有限

**实现步骤**：

1. **创建 CSS 提取工具**
   ```dart
   // tools/extract_css_colors.dart
   import 'dart:io';

   void main() async {
     final cssFile = File('assets/github-markdown.css');
     final cssContent = await cssFile.readAsString();

     // 提取 CSS 变量
     final varPattern = RegExp(r'--([a-zA-Z0-9-]+):\s*([^;]+);');
     final matches = varPattern.allMatches(cssContent);

     final output = StringBuffer();
     output.writeln('// Auto-generated from github-markdown.css');
     output.writeln('class GitHubMarkdownColors {');

     for (final match in matches) {
       final varName = match.group(1)!;
       final varValue = match.group(2)!.trim();

       if (varValue.startsWith('#')) {
         final dartName = _toCamelCase(varName);
         output.writeln('  static const $dartName = Color(0xFF${varValue.substring(1)});');
       }
     }

     output.writeln('}');

     await File('lib/utils/github_markdown_colors_generated.dart')
         .writeAsString(output.toString());

     print('✅ Generated github_markdown_colors_generated.dart');
   }

   String _toCamelCase(String kebab) {
     return kebab.split('-').map((part) {
       if (part.isEmpty) return '';
       return part[0].toUpperCase() + part.substring(1);
     }).join('');
   }
   ```

2. **运行提取工具**
   ```bash
   dart tools/extract_css_colors.dart
   ```

3. **使用生成的颜色**
   ```dart
   // lib/widgets/rich_content_view.dart
   import '../utils/github_markdown_colors_generated.dart';

   final codeStyle = TextStyle(
     color: GitHubMarkdownColors.fgDefault,
     backgroundColor: GitHubMarkdownColors.bgMuted,
   );
   ```

**工作量估算**：2-3天

---

### 方案 3：使用 flutter_html（替代方案）

**优点**：
- 原生支持 CSS
- 无需魔改
- 功能完整

**缺点**：
- 不支持 LaTeX（需要额外处理）
- 性能略低于 GptMarkdown
- 包体积较大

**实现步骤**：

1. **添加依赖**
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter_html: ^3.0.0-beta.2
     flutter_html_table: ^3.0.0-beta.2
     flutter_math_fork: ^0.7.2  # 保留 LaTeX 支持
   ```

2. **创建混合渲染器**
   ```dart
   // lib/widgets/html_markdown_view.dart
   import 'package:flutter_html/flutter_html.dart';
   import 'package:markdown/markdown.dart' as md;

   class HtmlMarkdownView extends StatelessWidget {
     final String markdown;

     const HtmlMarkdownView({required this.markdown});

     @override
     Widget build(BuildContext context) {
       // 1. 提取 LaTeX 块
       final latexBlocks = <String, String>{};
       var processed = markdown.replaceAllMapped(
         RegExp(r'\$\$(.+?)\$\$', dotAll: true),
         (m) {
           final id = 'LATEX_${latexBlocks.length}';
           latexBlocks[id] = m.group(1)!;
           return '<span class="latex-block">$id</span>';
         },
       );

       // 2. 转换 Markdown → HTML
       final html = md.markdownToHtml(processed);

       // 3. 加载 CSS
       final cssContent = await rootBundle.loadString(
         'assets/github-markdown.css',
       );

       // 4. 渲染 HTML + CSS
       return Html(
         data: '<div class="markdown-body">$html</div>',
         style: {
           '.markdown-body': Style.fromCss(cssContent),
         },
         customRenders: {
           // 自定义 LaTeX 渲染
           tagMatcher('span', className: 'latex-block'): CustomRender.widget(
             widget: (context, child) {
               final id = context.tree.element?.text ?? '';
               final latex = latexBlocks[id];
               if (latex != null) {
                 return Math.tex(latex);
               }
               return const SizedBox.shrink();
             },
           ),
         },
       );
     }
   }
   ```

**工作量估算**：3-5天

---

### 方案 4：WebView 渲染（最简单）

**优点**：
- 完美支持 CSS
- 开发速度最快（1天）
- 无需转换

**缺点**：
- 性能最差
- 内存占用高
- 不适合大量消息

**实现步骤**：

1. **添加依赖**
   ```yaml
   dependencies:
     webview_flutter: ^4.0.0
   ```

2. **创建 WebView 渲染器**
   ```dart
   // lib/widgets/webview_markdown.dart
   import 'package:webview_flutter/webview_flutter.dart';
   import 'package:markdown/markdown.dart' as md;

   class WebViewMarkdown extends StatefulWidget {
     final String markdown;

     const WebViewMarkdown({required this.markdown});

     @override
     State<WebViewMarkdown> createState() => _WebViewMarkdownState();
   }

   class _WebViewMarkdownState extends State<WebViewMarkdown> {
     late final WebViewController _controller;

     @override
     void initState() {
       super.initState();
       _controller = WebViewController()
         ..setJavaScriptMode(JavaScriptMode.unrestricted)
         ..loadHtmlString(_buildHtml());
     }

     String _buildHtml() {
       final html = md.markdownToHtml(widget.markdown);
       final css = await rootBundle.loadString('assets/github-markdown.css');

       return '''
       <!DOCTYPE html>
       <html>
       <head>
         <meta name="viewport" content="width=device-width, initial-scale=1.0">
         <style>$css</style>
         <script src="https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/katex.min.js"></script>
         <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/katex.min.css">
       </head>
       <body>
         <div class="markdown-body">$html</div>
         <script>
           // 渲染 LaTeX
           document.querySelectorAll('.math').forEach(el => {
             katex.render(el.textContent, el, { throwOnError: false });
           });
         </script>
       </body>
       </html>
       ''';
     }

     @override
     Widget build(BuildContext context) {
       return WebViewWidget(controller: _controller);
     }
   }
   ```

**工作量估算**：1天

---

## 推荐方案

### 短期（1周内）：方案 2（CSS 预编译器）
- 快速实现
- 低风险
- 已经部分完成（GitHubMarkdownTheme）

### 中期（1个月内）：方案 1（Fork GptMarkdown）
- 最佳性能
- 完全控制
- 可扩展性强

### 长期（3个月+）：方案 3（flutter_html）
- 如果 GptMarkdown 无法满足需求
- 需要更复杂的 HTML/CSS 支持

## 实现优先级

1. **Phase 1（已完成）**：
   - ✅ 下载 github-markdown.css
   - ✅ 创建 GitHubMarkdownTheme
   - ✅ 应用基础颜色

2. **Phase 2（推荐）**：
   - 创建 CSS 提取工具
   - 自动生成颜色常量
   - 扩展 GitHubMarkdownTheme 支持更多样式

3. **Phase 3（可选）**：
   - Fork gpt_markdown
   - 实现完整 CSS 解析器
   - 发布自定义包

## 性能对比

| 方案 | 渲染速度 | 内存占用 | 包体积 | 开发时间 |
|------|---------|---------|--------|---------|
| 方案1 Fork | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | +200KB | 2-3周 |
| 方案2 预编译 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | +50KB | 2-3天 |
| 方案3 flutter_html | ⭐⭐⭐ | ⭐⭐⭐ | +2MB | 3-5天 |
| 方案4 WebView | ⭐⭐ | ⭐⭐ | +5MB | 1天 |

## 结论

**当前最佳方案**：继续使用方案2（CSS预编译），因为：
1. 已经实现了基础功能
2. 性能最优
3. 维护成本低
4. 满足 90% 的样式需求

如果未来需要支持用户自定义 CSS 主题，再考虑方案1（Fork GptMarkdown）。
