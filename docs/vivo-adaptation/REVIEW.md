# Vivo Adaptation Doc Review Package

- Generated at: `2026-07-16 13:53:36Z`
- Repo root: `F:\Repositories\GitHub\NexAI`
- Output dir: `F:\Repositories\GitHub\NexAI\docs\vivo-adaptation`

## Documents

### 428 — Android 11应用适配指南

- Page: https://dev.vivo.com.cn/documentCenter/doc/428
- API: `https://dev.vivo.com.cn/webapi/doc/info?id=428`
- Breadcrumbs: vivo系统适配指南,Android适配,Android 11应用适配指南
- Version code: 11
- Update time (UTC): 2023-08-01T06:18:09+00:00
- Package: `docs/vivo-adaptation/428-android-11`

Headings:

- 1.1 vivo机器升级Android 11指导
- 1.2 vivo云真机调试
- 1.3 google原生机升级Android 11
- 2.1 兼容性
- 2.1.1 分区存储
- 2.1.2 单次授权
- 2.1.3 后台位置信息访问权限获取方式
- 2.1.4 软件包可见性
- 2.1.5 新的前台服务类型
- 2.1.6 自定义视图消息框使用受限
- 2.1.7 非SDK接口名单更新
- 2.2 新的交互体验和方式
- 2.2.1 聊天气泡
- 2.2.2 新的输入法键盘过渡动画
- 2.3 硬件层面的新支持
- 2.3.1 Android 11将更好地支持各类手机屏幕，以提升用户体验
- 2.3.2 Android 11支持并发使用多个摄像头
- 2.4 增强5G支持
- 2.5 其他功能
- 2.5.1 ADB增量APK安装
- 2.5.2 应用进程退出原因
- 2.5.3 动态资源加载器

## Suggested review flow

1. Read `content.txt` / `headings.txt` for each package.
2. Map high/medium priority sections to app surfaces:
   - Manifest / permissions / FGS
   - Activity orientation / large-screen behavior
   - Back navigation
   - Background timers / alarms
   - Share / FileProvider / intent grants
   - Network security / cleartext
3. Update adaptation notes under `docs/ANDROID_*_VIVO_ADAPTATION.md`.
4. Implement only the gaps that apply to this product.

