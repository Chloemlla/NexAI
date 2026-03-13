# NexAI 商业化安全防御全景清单

> 当前时间：2026-03-13 | 基线：已完成本次会话全部加固项

---

## 已完成（本次会话）

| # | 项目 | 说明 |
|---|---|---|
| ✅ | Dart 代码混淆 | `--obfuscate --split-debug-info`，CI 全平台启用 |
| ✅ | 敏感凭据加密存储 | API Key/密码迁移至 FlutterSecureStorage（Keystore/Keychain）|
| ✅ | TOFU 证书固定 | 零静态指纹，存储加密，自动到期续签 |
| ✅ | R8/ProGuard 混淆 | Android Java/Kotlin 层压缩混淆 |
| ✅ | `_chargePattern` lookbehind | 修复化学方程式渲染 + 运算符误判 |
| ✅ | [didUpdateWidget](file:///f:/Repositories/GitHub/NexAI/lib/widgets/rich_content_view.dart#48-56) setState | 修复流式输出不刷新 |
| ✅ | debug_symbols gitignore | 符号表不进仓库 |

---

## 一、客户端层（Flutter App）

### 🔴 高优先级

#### 1. 完整性检测（防篡改/重打包）
APK 被解包重签后，可绕过所有客户端检查。

```dart
// lib/utils/integrity_check.dart
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 验证签名证书与已知值一致（防重打包）
/// Android: 从 PackageManager 读取签名 SHA-256
/// 不一致 → 拒绝启动或静默降级（蜜罐模式）
Future<bool> verifyAppSignature() async {
  if (!Platform.isAndroid) return true;
  // 实现见下方 MethodChannel 调用 Android 原生 API
  // PackageManager.GET_SIGNATURES / GET_SIGNING_CERTIFICATES
}
```

Android 原生侧（`MainActivity.kt`）：
```kotlin
// 读取 APK 签名证书 SHA-256 并暴露给 Flutter
val sig = packageManager.getPackageInfo(packageName, 
    PackageManager.GET_SIGNING_CERTIFICATES)
    .signingInfo.apkContentsSigners[0]
val fp = MessageDigest.getInstance("SHA-256")
    .digest(sig.toByteArray())
    .joinToString("") { "%02x".format(it) }
```

存储预期签名的方式：**不要明文硬编码**，用与证书固定相同的 TOFU 思路——首次启动由用户确认后存入 SecureStorage。

#### 2. Root/越狱检测
Root 设备可绕过 Keystore，直接读取内存中的明文 API Key。

```dart
// 推荐包：flutter_jailbreak_detection（现已停更，可自实现）
// 检查项：
// Android: /system/app/Superuser.apk, su binary, Magisk 路径
// iOS: /Applications/Cydia.app, /etc/apt, cydia:// scheme
bool isDeviceCompromised() {
  if (Platform.isAndroid) {
    return _checkAndroid();
  }
  return false;
}
// 策略：不要直接拒绝（攻击者会针对性 patch），改为「蜜罐模式」
// 蜜罐模式：允许使用但请求携带标记，服务端识别后限流
```

#### 3. 请求签名（HMAC-SHA256）
防止 API 被直接调用（绕过客户端）。每个请求加入由客户端密钥派生的签名头：

```dart
// 在 _NexaiHttp 里加入签名拦截
String _signRequest(String method, String path, String body, int timestamp) {
  // key = derive(app_build_id + device_id + timestamp / 30)
  // 每 30s 一个窗口，防重放
  final key = _deriveKey();
  final message = '$method\n$path\n$timestamp\n${sha256Hex(body)}';
  final hmac = Hmac(sha256, key);
  return base64.encode(hmac.convert(utf8.encode(message)).bytes);
}
// Header: X-NexAI-Sig: <hmac> X-NexAI-Ts: <timestamp>
// 服务端验证：timestamp 在 ±30s 内且签名正确
```

> **关键**：`_deriveKey` 的输入来自 `device_id`（不可预测），即使攻击者拿到算法，没有设备 ID 也无法伪造。

#### 4. 截图/录屏保护（敏感页面）
```dart
// Android: Window.FLAG_SECURE
// 在 API Key 设置页、登录页调用
SystemChrome.setSecureScreen(true); // 或原生 MethodChannel
```

#### 5. 内存敏感数据清理
API Key 使用完毕后，不应在 Dart 堆上长期存留：
```dart
// 使用后立即用随机字符覆盖（Dart GC 不保证立即释放）
// 改用 Uint8List 存储 key，用完后 fillRange(0, len, 0)
```

---

### 🟡 中优先级

| 项目 | 说明 |
|---|---|
| 反调试检测 | 检测 `ptrace`/调试器附加（Android `isBeingDebugged`）|
| 模拟器检测 | Build.FINGERPRINT 包含 `generic`/`sdk` → 标记风险设备 |
| Frida 检测 | 扫描 `/proc/maps` 中 `frida-agent` 字样（native 层）|
| 网络代理检测 | [HttpClient().findProxy](file:///f:/Repositories/GitHub/NexAI/lib/services/pinned_http_client.dart#40-94) 返回非 DIRECT → 提示用户 |
| 本地数据加密 | 聊天记录 JSON 落盘前 AES-256 加密（`encrypt` 包已引入）|

---

## 二、服务端层（api.951100.xyz）

### 🔴 高优先级

#### 1. 速率限制（Rate Limiting）
```
每 IP：
  未登录接口：10 req/min（登录、注册、找密码）
  已登录接口：100 req/min
  
每用户账号：
  AI 调用：按会员等级限制（防止 API Key 滥用）
  
全局：
  异常流量（>10x 正常）→ Cloudflare 触发挑战
```

#### 2. JWT 安全配置
```
Access Token：15 分钟过期（目前状态未知）
Refresh Token：7 天过期 + 每次刷新轮换（防重放）
存储：HttpOnly Cookie（Web）/ SecureStorage（App）
RS256 签名（非 HS256，避免密钥泄露即签名被伪造）
```

#### 3. 强制 HTTPS + HSTS
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
HSTS Preload List 申请
禁止降级到 HTTP
```

#### 4. 请求签名验证（配合客户端 §3）
```javascript
// Express 中间件
function verifyNexaiSig(req, res, next) {
  const ts = parseInt(req.headers['x-nexai-ts']);
  if (Math.abs(Date.now()/1000 - ts) > 30) return res.status(401).end();
  const expected = computeHmac(req.method, req.path, ts, req.body);
  if (!timingSafeEqual(expected, req.headers['x-nexai-sig'])) 
    return res.status(401).end();
  next();
}
```

### 🟡 中优先级

#### 安全响应头
```
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer
Permissions-Policy: camera=(), microphone=()
```

#### 输入验证
- 所有接口参数用 Zod/Joi 验证 Schema，禁止透传到 DB
- SQL/NoSQL 注入防护（使用 ORM Prepared Statement）
- 文件上传类型白名单 + 大小限制

#### 暴力破解防护
```
连续 5 次登录失败 → 账号锁定 15 分钟
IP 连续失败 20 次 → 临时封禁
Google reCAPTCHA v3 接入（登录/注册）
```

#### 敏感操作二次验证
- 修改邮箱/密码 → 邮件确认
- 大额操作 → TOTP/Passkey 二次认证
- 管理员操作 → IP 白名单 + MFA

---

## 三、基础设施层

### 🔴 必须实施

| 项目 | 方案 | 说明 |
|---|---|---|
| **DDoS 防护** | Cloudflare Free/Pro | 接入后隐藏源站 IP，L3/L4/L7 防护 |
| **WAF** | Cloudflare WAF 规则 | OWASP Top 10 规则集，SQL/XSS 注入拦截 |
| **源站 IP 保护** | Cloudflare Tunnel / Argo | 源站不暴露公网 IP |
| **HTTPS 证书** | Let's Encrypt via Cloudflare | 自动续签，零运维 |
| **数据库加密** | 静态加密（透明数据加密）| 防止物理拿走磁盘读取 |
| **备份策略** | 异地每日备份 + 测试恢复 | 勒索攻击最后一道防线 |

### 🟡 推荐实施

```
秘密管理:
  环境变量不要存在代码里 ✅（已有）
  使用 Vault / GitHub Secrets / 云 KMS 管理密钥
  轮换周期：DB密码90天，API Key 180天

容器安全（若使用 Docker）:
  非 root 用户运行
  只读文件系统
  最小化基础镜像（distroless）
  定期 trivy/snyk 扫描镜像漏洞

网络隔离:
  数据库不对公网暴露（VPC 内网访问）
  Redis/MQ 同理
  管理后台端口非标准端口 + IP 白名单
```

---

## 四、监控与响应层

### 实时监控
```
错误率监控:  Sentry（Flutter + Node.js 双端接入）
性能监控:    Datadog / Better Uptime
日志中心:    ELK Stack / Loki + Grafana

关键告警阈值:
  5xx 错误率 > 1%         → PagerDuty 告警
  登录失败率突增          → 可能暴力破解
  单 IP 请求量 > 1000/min → 自动封禁
  新注册账号异常          → 机器人注册检测
```

### 审计日志
```
记录内容（不可篡改，追加写入）:
  所有认证事件（登录/注销/失败）
  管理员操作
  数据导出/删除
  配置变更

保留周期: 90 天在线，1年冷存储
```

### 应急响应预案
```
1. 发现入侵迹象 → 立即轮换所有 Secret + JWT 密钥
2. 数据泄露 → 72小时内通知受影响用户（GDPR 要求）
3. DDoS → 启用 Cloudflare Under Attack Mode
4. 证书异常 → 调用 clearCertPin() 强制客户端重建信任
```

---

## 五、合规与法律（商业化必须）

| 项目 | 要求 |
|---|---|
| **隐私政策** | 明确说明收集的数据、用途、保留期限 |
| **服务条款** | 禁止滥用条款、免责声明 |
| **数据本地化** | 中国用户数据存中国（ICP 备案要求） |
| **用户数据删除** | 提供账号注销 + 数据清除功能（PIPL/GDPR）|
| **最小化采集** | 只收集业务必需的数据 |

---

## 优先实施顺序

```
本周（阻塞商业化）:
  □ Cloudflare 接入 + 源站 IP 隐藏
  □ 登录接口速率限制
  □ JWT 过期时间缩短至 15 分钟
  □ 隐私政策页面上线

本月（提升防御深度）:
  □ 客户端请求 HMAC 签名
  □ Root 检测（蜜罐模式）
  □ 暴力破解锁定
  □ Sentry 接入

季度目标（完整商业级防护）:
  □ WAF 规则调优
  □ APK 签名完整性检测
  □ 安全审计（渗透测试）
  □ 数据合规审查
```
