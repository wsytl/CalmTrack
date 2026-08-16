# CalmTrack 打包与分发指南

## 一、本机真机打包（archive + ipa）

```bash
# 1. 安装 fastlane（一次性）
brew install fastlane

# 2. 确认 Xcode 已登录 Apple 账号（Xcode → Settings → Accounts，team 53353F8EY8）

# 3. 打包
cd ~/Desktop/CalmTrack
fastlane ios archive
```

产物：
- `build/ipa/CalmTrack.ipa` —— 可安装包
- `build/CalmTrack.xcarchive` —— 归档

签名：Development（Automatic signing，用本机 `Apple Development: tianli yang (6BNWARU22R)`）。

### 常见问题
| 现象 | 处理 |
|---|---|
| `No profiles for 'com.ytl.CalmTrack' were found` | Xcode 打开工程 → target → Signing & Capabilities → 勾选 Automatically manage signing、选 team，生成一次描述文件后重跑 |
| 描述文件不含当前设备 | 连上 iPhone，Xcode → Window → Devices and Simulators → 勾选 Use for development（自动登记设备），再重打包 |

## 二、装到 iPhone（本机 ad-hoc 安装）

前提：iPhone 已连接并信任此 Mac，且设备已登记为开发设备（见上表第二行）。

```bash
# 1. 打包（如已打过可跳过）
fastlane ios archive

# 2. 查看已连接设备，拿 UDID
xcrun devicectl list devices

# 3. 安装
xcrun devicectl device install app --device <UDID> build/ipa/CalmTrack.ipa
```

安装后：iPhone 主屏出现 CalmTrack。首次打开需在 设置 → 通用 → VPN 与设备管理 中信任开发者证书（Apple Development: tianli yang）。

> 说明：Development 签名的 ipa 只装在已登记设备；要装给外部测试员，走 TestFlight（见下）。

## 三、TestFlight 升级路线（当前为占位配置，按步骤激活）

### 第 1 步：建 match 证书仓库（一次）

GitHub 建一个私有仓库，例如 `wsytl/CalmTrack-match-certs`（Private）。fastlane 用它同步证书与描述文件。

### 第 2 步：创建 App Store Connect API Key（一次，需浏览器）

App Store Connect → 用户和访问 → 集成 → **App Store Connect API** → 生成 API 密钥：
- 记下 **Key ID**（形如 `XXXXXXXXXX`）
- 记下 **Issuer ID**（形如 `69a6de7d-...`，页面顶部「Issuer ID」）
- 下载 `.p8` 文件（只下载一次，妥善保存）

### 第 3 步：填入真实配置

```bash
cd ~/Desktop/CalmTrack
cp fastlane/.env.example fastlane/.env
# 编辑 fastlane/.env，替换 4 个 REPLACE_WITH_*：
#   APP_STORE_CONNECT_API_KEY_KEY_ID、_ISSUER_ID、_FILEPATH（.p8 路径）
#   MATCH_GIT_URL（证书仓库 git URL）、MATCH_PASSWORD（自设强密码）
```

> `fastlane/.env` 已被 .gitignore 忽略，不会误提交真实密钥。

### 第 4 步：首次生成 match 证书（本机，一次）

```bash
fastlane match appstore   # 生成 Distribution 证书 + App Store 描述文件并存入证书仓库
```

### 第 5 步：本机上传 TestFlight

```bash
fastlane ios beta
```

上传后：App Store Connect → TestFlight → 添加测试员（内部/外部）→ 测试员通过 TestFlight App 安装。

### 第 6 步（可选）：CI 全自动分发

仓库 Settings → Secrets and variables → Actions 添加：
- `APP_STORE_CONNECT_API_KEY_CONTENT`（.p8 文件 base64：`base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`）
- `APP_STORE_CONNECT_API_KEY_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- `MATCH_GIT_URL`、`MATCH_PASSWORD`

之后手动触发（Actions → Release TestFlight → Run workflow）或打 tag `v1.0.0` 即自动上传。

### 占位清单（激活前会失败的占位符）
- `fastlane/Fastfile` beta lane 内：`REPLACE_WITH_KEY_ID` / `REPLACE_WITH_ISSUER_ID` / `REPLACE_WITH_KEY_FILEPATH`（有 .env 后不会再读到）
- `fastlane/Matchfile`：`REPLACE_WITH_MATCH_CERTS_REPO_URL`（有 .env 后不会再读到）
- `fastlane/.env.example`：全部 REPLACE_WITH_*（复制为 .env 后替换）

## 四、脚本一键打包（推荐日常使用）

`scripts/package.sh` 包装了 `fastlane ios package`：指定环境、可选版本号、build 号自动递增。

```bash
# development 签名打包（默认），build 号自动 +1
./scripts/package.sh

# 指定版本号（覆盖 MARKETING_VERSION，仅本次生效）
./scripts/package.sh --version 1.2.0

# App Store 签名打包（需先完成 TestFlight 升级第 1-4 步）
./scripts/package.sh --env appstore --version 1.2.0
```

行为：
- **环境**：`--env development`（默认）→ Development 签名 ipa；`--env appstore` → App Store 签名（需 API key + match 已配置）
- **版本**：`--version x.y.z` → 本次打包覆盖版本号，不写回工程（工程 MARKETING_VERSION 不变）
- **build 号**：每次打包自动 +1（`increment_build_number`），**写回工程** `CURRENT_PROJECT_VERSION`——记得随改动一起提交，保证下次继续递增
- **产物**：`build/ipa/CalmTrack-<env>[-<version>]-<build>.ipa`（如 `CalmTrack-development-1.2.0-3.ipa`）
