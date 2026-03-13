## 证书验证错误解决方案

### 错误信息
```
HandshakeException: Handshake error in client (OS Error:
CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate)
```

### 原因
NexAI 使用了证书固定（Certificate Pinning）技术来防止中间人攻击。当访问 `api.951100.xyz` 时，如果：
1. 首次访问（TOFU 模式）
2. 证书已过期
3. 证书被更换
4. 网络环境有代理/防火墙

就会出现此错误。

### 解决方法

#### 方法 1：清除已存储的证书指纹（推荐）

在应用设置中添加"清除证书缓存"功能：

```dart
import 'package:nexai/services/pinned_http_client.dart';

// 在设置页面添加按钮
ElevatedButton(
  onPressed: () async {
    await clearCertPin();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('证书缓存已清除，请重启应用')),
    );
  },
  child: Text('清除证书缓存'),
)
```

#### 方法 2：临时禁用证书固定（开发环境）

修改 `lib/services/nexai_auth_service.dart`：

```dart
// 开发环境禁用证书固定
final client = await buildPinnedHttpClient(
  enablePinning: false, // 开发时设为 false
);
```

#### 方法 3：使用环境变量控制

在 `lib/services/pinned_http_client.dart` 中：

```dart
Future<http.Client> buildPinnedHttpClient() async {
  if (kIsWeb) return http.Client();

  // 开发环境自动禁用
  const bool isDevelopment = bool.fromEnvironment('DEVELOPMENT', defaultValue: false);
  if (isDevelopment) {
    debugPrint('NexAI Pinning: DISABLED (development mode)');
    return http.Client();
  }

  // ... 正常的证书固定逻辑
}
```

然后运行时添加参数：
```bash
flutter run --dart-define=DEVELOPMENT=true
```

#### 方法 4：检查网络环境

如果在公司网络或使用代理：

1. **检查代理设置**：
   ```dart
   // 检查是否有代理
   final httpProxy = Platform.environment['HTTP_PROXY'];
   final httpsProxy = Platform.environment['HTTPS_PROXY'];
   print('HTTP_PROXY: $httpProxy');
   print('HTTPS_PROXY: $httpsProxy');
   ```

2. **临时禁用代理**：
   ```bash
   # Windows
   set HTTP_PROXY=
   set HTTPS_PROXY=

   # Linux/Mac
   unset HTTP_PROXY
   unset HTTPS_PROXY
   ```

#### 方法 5：信任自签名证书（仅开发环境）

如果 `api.951100.xyz` 使用自签名证书：

```dart
class _ToFuClient extends http.BaseClient {
  final IOClient _inner = IOClient(
    HttpClient()
      ..badCertificateCallback = (cert, host, port) {
        // 仅开发环境：信任所有证书
        if (kDebugMode) {
          debugPrint('Trusting certificate for $host (development mode)');
          return true;
        }
        return false;
      },
  );
  // ...
}
```

### 生产环境建议

1. **保持证书固定启用**：防止中间人攻击
2. **提供清除缓存功能**：让用户在证书更新后能重新固定
3. **监控证书过期**：在证书过期前 30 天自动更新
4. **提供降级选项**：在设置中允许用户临时禁用（显示安全警告）

### 当前实现状态

NexAI 已实现：
- ✅ TOFU（首次信任）模式
- ✅ 证书过期自动重新固定
- ✅ 30 天内自动续期
- ✅ 手动清除证书缓存 API：`clearCertPin()`

### 快速修复（临时）

如果需要立即解决，在 `lib/services/nexai_auth_service.dart` 中找到：

```dart
final _client = await buildPinnedHttpClient();
```

改为：

```dart
final _client = http.Client(); // 临时禁用证书固定
```

**注意**：这会降低安全性，仅用于开发测试！
