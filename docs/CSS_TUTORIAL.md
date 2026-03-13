# gpt_markdown_chloemlla CSS 解析完整教程

## 目录

1. [简介](#简介)
2. [安装配置](#安装配置)
3. [基础用法](#基础用法)
4. [CSS 变量](#css-变量)
5. [样式表管理](#样式表管理)
6. [主题系统](#主题系统)
7. [实战示例](#实战示例)
8. [高级技巧](#高级技巧)
9. [最佳实践](#最佳实践)
10. [故障排除](#故障排除)

---

## 简介

`gpt_markdown_chloemlla` 提供了强大的 CSS 解析功能,支持:

- ✅ 完整的 CSS 文件解析
- ✅ CSS 变量 (Custom Properties)
- ✅ Media Queries
- ✅ 复杂选择器
- ✅ 样式缓存优化
- ✅ Flutter TextStyle 转换

### 支持的 CSS 特性

| 特性 | 支持程度 | 说明 |
|------|---------|------|
| CSS 变量 | ✅ 完全支持 | `--variable-name` 和 `var()` |
| 颜色 | ✅ 完全支持 | hex, rgb, rgba, named |
| 字体大小 | ✅ 完全支持 | px, pt, em, rem |
| 字体粗细 | ✅ 完全支持 | normal, bold, 100-900 |
| 字体样式 | ✅ 完全支持 | normal, italic |
| 文本装饰 | ✅ 完全支持 | underline, line-through |
| Media Queries | ⚠️ 部分支持 | 解析但不动态评估 |
| 伪类/伪元素 | ⚠️ 部分支持 | 基本支持 |

---

## 安装配置

### 1. 添加依赖

在 `pubspec.yaml` 中:

```yaml
dependencies:
  gpt_markdown_chloemlla: ^2.0.1
```

### 2. 导入包

```dart
import 'package:gpt_markdown_chloemlla/css/css.dart';
```

### 3. 配置 CSS 资源

如果要从 assets 加载 CSS:

```yaml
flutter:
  assets:
    - assets/styles/
    - assets/github-markdown.css
```

---

## 基础用法

### 1. 解析内联样式

最简单的用法是解析内联 CSS 样式:

```dart
import 'package:flutter/material.dart';
import 'package:gpt_markdown_chloemlla/css/css.dart';

void main() {
  // 解析内联样式
  final style = CssParser.parseInlineStyle(
    'color: #1f2328; font-size: 16px; font-weight: 600',
  );

  print(style?.color);      // Color(0xff1f2328)
  print(style?.fontSize);   // 16.0
  print(style?.fontWeight); // FontWeight.w600
}
```

### 2. 使用基础样式

可以提供基础样式,解析的样式会合并到基础样式上:

```dart
final baseStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 14.0,
);

final style = CssParser.parseInlineStyle(
  'color: #ff0000; font-weight: bold',
  baseStyle: baseStyle,
);

// 结果包含基础样式的 fontFamily 和 fontSize
// 以及新的 color 和 fontWeight
```

### 3. 从属性映射解析

```dart
final properties = {
  'color': '#1f2328',
  'font-size': '16px',
  'font-weight': '600',
  'font-style': 'italic',
};

final style = CssParser.parsePropertiesMap(properties);
```

---

## CSS 变量

### 1. 定义 CSS 变量

```css
:root {
  --primary-color: #4493f8;
  --secondary-color: #6c757d;
  --font-size-base: 16px;
  --font-size-large: 1.5rem;
  --spacing-unit: 8px;
}
```

### 2. 使用 CSS 变量

```css
.element {
  color: var(--primary-color);
  font-size: var(--font-size-base);
  padding: var(--spacing-unit);
}
```

### 3. 在 Dart 中访问变量

```dart
final stylesheet = CssStylesheet.parse(cssContent);

// 获取单个变量
final primaryColor = stylesheet.getCssVariable('--primary-color');
print(primaryColor); // "#4493f8"

// 获取所有变量
final allVariables = stylesheet.getAllVariables();
allVariables.forEach((name, value) {
  print('$name: $value');
});
```

### 4. 变量引用解析

```dart
final stylesheet = CssStylesheet.parse('''
  :root {
    --primary: #007bff;
    --link-color: var(--primary);
  }
''');

// 自动解析变量引用
final resolved = stylesheet.resolveCssVariables('var(--link-color)');
print(resolved); // "#007bff"
```

### 5. 带回退值的变量

```css
.element {
  /* 如果 --custom-color 不存在,使用 #000000 */
  color: var(--custom-color, #000000);
}
```

```dart
final resolved = stylesheet.resolveCssVariables(
  'var(--missing-color, #ff0000)'
);
print(resolved); // "#ff0000"
```

---

## 样式表管理

### 1. 解析完整样式表

```dart
const cssContent = '''
  .markdown-body {
    color: #1f2328;
    font-size: 16px;
    line-height: 1.5;
  }

  .markdown-body h1 {
    font-size: 2em;
    font-weight: 600;
    border-bottom: 1px solid #d1d9e0;
  }

  .markdown-body code {
    font-family: monospace;
    font-size: 85%;
    padding: 0.2em 0.4em;
    background-color: #f6f8fa;
  }
''';

final stylesheet = CssStylesheet.parse(cssContent);
```

### 2. 提取选择器样式

```dart
// 获取 .markdown-body 的样式
final bodyStyles = stylesheet.getStylesForSelector('.markdown-body');
print(bodyStyles['color']);      // "#1f2328"
print(bodyStyles['font-size']);  // "16px"
print(bodyStyles['line-height']); // "1.5"

// 获取 .markdown-body h1 的样式
final h1Styles = stylesheet.getStylesForSelector('.markdown-body h1');
print(h1Styles['font-size']);   // "2em"
print(h1Styles['font-weight']); // "600"
```

### 3. Media Queries

```dart
const cssContent = '''
  :root {
    --bg-color: #ffffff;
    --text-color: #1f2328;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --bg-color: #0d1117;
      --text-color: #f0f6fc;
    }
  }
''';

final stylesheet = CssStylesheet.parse(cssContent);

// 获取变量(包含 media query 中的定义)
final bgColor = stylesheet.getCssVariable('--bg-color');
final textColor = stylesheet.getCssVariable('--text-color');
```

---

## 主题系统

### 1. 从字符串创建主题

```dart
const customCss = '''
  :root {
    --primary: #007bff;
    --secondary: #6c757d;
    --success: #28a745;
    --danger: #dc3545;
  }

  .custom-markdown {
    color: #333;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto;
  }

  .custom-markdown h1 {
    color: var(--primary);
    font-size: 2.5em;
    font-weight: 700;
  }
''';

final theme = CssTheme.fromString(customCss);
```

### 2. 从 Asset 加载主题

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CssTheme? _theme;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await CssTheme.fromAsset('assets/github-markdown.css');
      setState(() {
        _theme = theme;
        _loading = false;
      });
    } catch (e) {
      print('Failed to load theme: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return CircularProgressIndicator();
    }

    if (_theme == null) {
      return Text('Failed to load theme');
    }

    return MyMarkdownWidget(theme: _theme!);
  }
}
```

### 3. 获取文本样式

```dart
final theme = CssTheme.fromString(cssContent);

// 获取特定选择器的样式
final h1Style = theme.getTextStyle('.markdown-body h1');
final h2Style = theme.getTextStyle('.markdown-body h2');
final codeStyle = theme.getTextStyle('.markdown-body code');

// 使用样式
Text(
  'Heading 1',
  style: h1Style,
);
```

### 4. 获取颜色

```dart
// 从 CSS 变量获取颜色
final bgColor = theme.getColor('--bgColor-default');
final fgColor = theme.getColor('--fgColor-default');
final accentColor = theme.getColor('--fgColor-accent');

// 使用颜色
Container(
  color: bgColor,
  child: Text(
    'Hello',
    style: TextStyle(color: fgColor),
  ),
);
```

### 5. 样式缓存

主题系统自动缓存解析的样式以提高性能:

```dart
// 第一次调用:解析并缓存
final style1 = theme.getTextStyle('.markdown-body h1');

// 第二次调用:直接返回缓存
final style2 = theme.getTextStyle('.markdown-body h1');

// 两次返回相同实例
assert(identical(style1, style2)); // true
```

---

## 实战示例

### 示例 1: GitHub Markdown 样式

```dart
import 'package:flutter/material.dart';
import 'package:gpt_markdown_chloemlla/gpt_markdown_chloemlla.dart';
import 'package:gpt_markdown_chloemlla/css/css.dart';

class GitHubMarkdownDemo extends StatefulWidget {
  @override
  State<GitHubMarkdownDemo> createState() => _GitHubMarkdownDemoState();
}

class _GitHubMarkdownDemoState extends State<GitHubMarkdownDemo> {
  CssTheme? _theme;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await CssTheme.fromAsset('assets/github-markdown.css');
    setState(() => _theme = theme);
  }

  @override
  Widget build(BuildContext context) {
    if (_theme == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: _theme!.getColor('--bgColor-default'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: GptMarkdown(
          '''
# GitHub Markdown Demo

This is a **bold** text and this is *italic*.

## Code Example

\`\`\`dart
void main() {
  print('Hello, World!');
}
\`\`\`

## List

- Item 1
- Item 2
- Item 3
          ''',
          style: _theme!.getTextStyle('.markdown-body'),
          config: GptMarkdownConfig(
            h1: _theme!.getTextStyle('.markdown-body h1'),
            h2: _theme!.getTextStyle('.markdown-body h2'),
            code: _theme!.getTextStyle('.markdown-body code'),
          ),
        ),
      ),
    );
  }
}
```

### 示例 2: 自定义主题切换

```dart
class ThemeSwitcherDemo extends StatefulWidget {
  @override
  State<ThemeSwitcherDemo> createState() => _ThemeSwitcherDemoState();
}

class _ThemeSwitcherDemoState extends State<ThemeSwitcherDemo> {
  bool _isDark = false;
  late CssTheme _lightTheme;
  late CssTheme _darkTheme;

  @override
  void initState() {
    super.initState();
    _initThemes();
  }

  void _initThemes() {
    // 亮色主题
    _lightTheme = CssTheme.fromString('''
      :root {
        --bg: #ffffff;
        --fg: #1f2328;
        --accent: #0969da;
      }
      .markdown-body {
        color: var(--fg);
        background-color: var(--bg);
      }
      .markdown-body h1 {
        color: var(--accent);
        font-size: 2em;
      }
    ''');

    // 暗色主题
    _darkTheme = CssTheme.fromString('''
      :root {
        --bg: #0d1117;
        --fg: #f0f6fc;
        --accent: #4493f8;
      }
      .markdown-body {
        color: var(--fg);
        background-color: var(--bg);
      }
      .markdown-body h1 {
        color: var(--accent);
        font-size: 2em;
      }
    ''');
  }

  CssTheme get _currentTheme => _isDark ? _darkTheme : _lightTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.getColor('--bg'),
      appBar: AppBar(
        title: Text('Theme Switcher'),
        actions: [
          IconButton(
            icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDark = !_isDark),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Hello, World!',
          style: _currentTheme.getTextStyle('.markdown-body h1'),
        ),
      ),
    );
  }
}
```

### 示例 3: 动态样式应用

```dart
class DynamicStyleDemo extends StatelessWidget {
  final CssTheme theme;
  final String markdownText;

  const DynamicStyleDemo({
    required this.theme,
    required this.markdownText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.getColor('--bgColor-default'),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            'Markdown Preview',
            style: theme.getTextStyle('.markdown-body h1'),
          ),

          SizedBox(height: 16),

          // 内容
          Expanded(
            child: GptMarkdown(
              markdownText,
              style: theme.getTextStyle('.markdown-body'),
              config: GptMarkdownConfig(
                h1: theme.getTextStyle('.markdown-body h1'),
                h2: theme.getTextStyle('.markdown-body h2'),
                h3: theme.getTextStyle('.markdown-body h3'),
                code: theme.getTextStyle('.markdown-body code'),
                link: theme.getTextStyle('.markdown-body a'),
                blockquote: theme.getTextStyle('.markdown-body blockquote'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 示例 4: CSS 变量实时预览

```dart
class CssVariableInspector extends StatelessWidget {
  final CssTheme theme;

  const CssVariableInspector({required this.theme});

  @override
  Widget build(BuildContext context) {
    final variables = theme.getAllVariables();

    return ListView.builder(
      itemCount: variables.length,
      itemBuilder: (context, index) {
        final entry = variables.entries.elementAt(index);
        final name = entry.key;
        final value = entry.value;

        // 尝试解析为颜色
        Color? color;
        if (value.startsWith('#') || value.startsWith('rgb')) {
          color = _parseColor(value);
        }

        return ListTile(
          leading: color != null
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Icon(Icons.text_fields),
          title: Text(
            name,
            style: TextStyle(fontFamily: 'monospace'),
          ),
          subtitle: Text(
            value,
            style: TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }

  Color? _parseColor(String value) {
    // 简化的颜色解析
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    return null;
  }
}
```

---

## 高级技巧

### 1. 性能优化

```dart
class OptimizedThemeLoader {
  static final Map<String, CssTheme> _cache = {};

  static Future<CssTheme> loadTheme(String assetPath) async {
    // 检查缓存
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath]!;
    }

    // 加载并缓存
    final theme = await CssTheme.fromAsset(assetPath);
    _cache[assetPath] = theme;
    return theme;
  }

  static void clearCache() {
    _cache.clear();
  }
}
```

### 2. 错误处理

```dart
Future<CssTheme?> loadThemeSafely(String assetPath) async {
  try {
    return await CssTheme.fromAsset(assetPath);
  } on FlutterError catch (e) {
    print('Asset not found: $e');
    return null;
  } catch (e) {
    print('Failed to parse CSS: $e');
    return null;
  }
}
```

### 3. 样式合并

```dart
TextStyle mergeStyles(CssTheme theme, List<String> selectors) {
  TextStyle? result;

  for (final selector in selectors) {
    final style = theme.getTextStyle(selector);
    if (style != null) {
      result = result?.merge(style) ?? style;
    }
  }

  return result ?? TextStyle();
}

// 使用
final combinedStyle = mergeStyles(theme, [
  '.markdown-body',
  '.markdown-body h1',
  '.custom-class',
]);
```

### 4. 条件样式

```dart
TextStyle getResponsiveStyle(
  CssTheme theme,
  BuildContext context,
) {
  final width = MediaQuery.of(context).size.width;

  if (width < 600) {
    // 移动端
    return theme.getTextStyle('.markdown-body-mobile') ??
           theme.getTextStyle('.markdown-body')!;
  } else {
    // 桌面端
    return theme.getTextStyle('.markdown-body-desktop') ??
           theme.getTextStyle('.markdown-body')!;
  }
}
```

---

## 最佳实践

### 1. 组织 CSS 文件

```
assets/
  styles/
    base.css          # 基础样式
    theme-light.css   # 亮色主题
    theme-dark.css    # 暗色主题
    components.css    # 组件样式
```

### 2. 使用 CSS 变量

```css
/* 推荐:使用语义化变量名 */
:root {
  --color-primary: #007bff;
  --color-secondary: #6c757d;
  --color-success: #28a745;
  --color-danger: #dc3545;

  --font-size-base: 16px;
  --font-size-large: 1.25rem;
  --font-size-small: 0.875rem;

  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;
}
```

### 3. 主题管理

```dart
class ThemeManager {
  static CssTheme? _currentTheme;

  static Future<void> initialize(String assetPath) async {
    _currentTheme = await CssTheme.fromAsset(assetPath);
  }

  static CssTheme get theme {
    if (_currentTheme == null) {
      throw StateError('Theme not initialized');
    }
    return _currentTheme!;
  }

  static Future<void> switchTheme(String assetPath) async {
    _currentTheme = await CssTheme.fromAsset(assetPath);
  }
}

// 使用
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.initialize('assets/theme-light.css');
  runApp(MyApp());
}
```

### 4. 类型安全的样式访问

```dart
class AppStyles {
  final CssTheme _theme;

  AppStyles(this._theme);

  TextStyle get h1 => _theme.getTextStyle('.markdown-body h1')!;
  TextStyle get h2 => _theme.getTextStyle('.markdown-body h2')!;
  TextStyle get body => _theme.getTextStyle('.markdown-body')!;
  TextStyle get code => _theme.getTextStyle('.markdown-body code')!;

  Color get background => _theme.getColor('--bgColor-default')!;
  Color get foreground => _theme.getColor('--fgColor-default')!;
  Color get accent => _theme.getColor('--fgColor-accent')!;
}

// 使用
final styles = AppStyles(theme);
Text('Hello', style: styles.h1);
```

---

## 故障排除

### 问题 1: CSS 文件加载失败

**症状**: `FlutterError: Unable to load asset`

**解决方案**:
1. 检查 `pubspec.yaml` 中的 assets 配置
2. 确保文件路径正确
3. 运行 `flutter clean` 和 `flutter pub get`

```yaml
flutter:
  assets:
    - assets/github-markdown.css  # 确保路径正确
```

### 问题 2: 样式未应用

**症状**: 获取的样式为 null

**解决方案**:
1. 检查选择器是否正确
2. 确保 CSS 文件已正确解析
3. 使用 `getAllVariables()` 检查变量是否提取

```dart
// 调试
final styles = stylesheet.getStylesForSelector('.markdown-body');
print('Found styles: $styles');

final variables = stylesheet.getAllVariables();
print('Found variables: $variables');
```

### 问题 3: 颜色解析错误

**症状**: 颜色显示不正确

**解决方案**:
1. 检查颜色格式是否支持
2. 确保 CSS 变量已正确解析
3. 使用 `resolveCssVariables()` 手动解析

```dart
// 调试颜色
final colorValue = stylesheet.getCssVariable('--primary-color');
print('Raw color value: $colorValue');

final resolved = stylesheet.resolveCssVariables(colorValue!);
print('Resolved color: $resolved');
```

### 问题 4: 性能问题

**症状**: 加载或渲染缓慢

**解决方案**:
1. 使用样式缓存
2. 避免重复解析相同的 CSS
3. 预加载主题

```dart
// 预加载
class App extends StatefulWidget {
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  CssTheme? _theme;

  @override
  void initState() {
    super.initState();
    _preloadTheme();
  }

  Future<void> _preloadTheme() async {
    _theme = await CssTheme.fromAsset('assets/theme.css');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_theme == null) {
      return SplashScreen();
    }
    return MainApp(theme: _theme!);
  }
}
```

### 问题 5: 选择器不匹配

**症状**: 无法获取特定选择器的样式

**解决方案**:
1. 简化选择器
2. 使用更通用的选择器
3. 检查 CSS 文件中的实际选择器

```dart
// 尝试不同的选择器
final styles1 = stylesheet.getStylesForSelector('.markdown-body h1');
final styles2 = stylesheet.getStylesForSelector('h1');
final styles3 = stylesheet.getStylesForSelector('.markdown-body');

print('Selector 1: ${styles1.isNotEmpty}');
print('Selector 2: ${styles2.isNotEmpty}');
print('Selector 3: ${styles3.isNotEmpty}');
```

---

## 总结

本教程涵盖了 `gpt_markdown_chloemlla` CSS 解析功能的所有方面:

1. ✅ 基础用法 - 内联样式解析
2. ✅ CSS 变量 - 定义和使用
3. ✅ 样式表管理 - 完整 CSS 文件解析
4. ✅ 主题系统 - 主题加载和切换
5. ✅ 实战示例 - 真实场景应用
6. ✅ 高级技巧 - 性能优化和错误处理
7. ✅ 最佳实践 - 代码组织和类型安全
8. ✅ 故障排除 - 常见问题解决

通过本教程,你应该能够:
- 解析和应用任何 CSS 样式
- 使用 CSS 变量创建主题系统
- 加载和管理复杂的 CSS 文件(如 GitHub Markdown CSS)
- 优化性能和处理错误
- 遵循最佳实践编写可维护的代码

## 参考资源

- [项目主页](https://github.com/Chloemlla/gpt_markdown)
- [API 文档](docs/CSS_SUPPORT.md)
- [示例代码](example/lib/css_stylesheet_demo.dart)
- [测试用例](test/css/css_stylesheet_test.dart)

---

**Happy Coding! 🎉**
