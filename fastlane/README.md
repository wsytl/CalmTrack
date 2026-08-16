# fastlane

CalmTrack 的自动打包配置。

## 安装（一次性，本机）

```bash
brew install fastlane
# 或使用 Gemfile：
# bundle install
```

## 本机真机打包（archive + ipa）

```bash
fastlane ios archive
```

- 产物：`build/ipa/CalmTrack.ipa` + `build/CalmTrack.xcarchive`
- 签名：Development（Automatic signing，使用钥匙串中的 `Apple Development: tianli yang (6BNWARU22R)`）
- 前提：Xcode 已登录 Apple 账号（偏好设置 → Accounts），本机有对应证书/描述文件

## CI（GitHub Actions）

每次 push/PR 自动执行：
- `fastlane ios build` —— 模拟器无签名构建
- `fastlane ios test_build` —— 测试 target 编译验证

## 升级路线：CI 全自动真机打包 / TestFlight

目前 CI 只做无签名验证（Development 证书在 CI 中不可用）。要 CI 产出真机 ipa 或上传 TestFlight，需要以下**人工步骤**（一次）：

1. **导出签名材料**（钥匙串访问 → 右键 `Apple Development: tianli yang` → 导出 .p12，设密码；`xcodebuild -showBuildSettings` 或 Xcode 查看描述文件，导出 `.mobileprovision`）
2. **放入 GitHub Secrets**（repo Settings → Secrets and variables → Actions）：
   - `IOS_CERTIFICATE`（p12 base64）
   - `IOS_CERTIFICATE_PASSWORD`
   - `IOS_PROVISIONING_PROFILE`（mobileprovision base64）
3. 在 workflow 中新增签名步骤（解 base64 → 安装到钥匙串/描述文件目录 → `xcodebuild archive`）
4. 或更推荐：**切换到 fastlane match + App Store Connect API key**（`fastlane match init`），然后启用 Fastfile 中注释的 `beta` lane（TestFlight 上传）。

## 环境事实（记录）

- Bundle ID：`com.ytl.CalmTrack`
- Team ID：`53353F8EY8`
- 本机证书：Apple Development: tianli yang (6BNWARU22R)
- App Store Connect API key：暂无（TestFlight 前创建）
