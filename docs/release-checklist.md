# CalmTrack 发布清单（Release Checklist）

> 配合 `docs/fastlane-guide.md` 使用。发布前逐项勾选；「首次」项只需做一次。

## A. 一次性环境配置（首次）

- [ ] 安装 fastlane：`brew install fastlane`
- [ ] Xcode 已登录 Apple 账号（Xcode → Settings → Accounts，team `53353F8EY8`）
- [ ] 创建 App Store Connect API key（ASC → 用户和访问 → 集成 → App Store Connect API → 生成；记下 **Key ID**、**Issuer ID**，下载 `.p8`）
- [ ] 建 match 证书私有仓库（GitHub：`wsytl/CalmTrack-match-certs`，Private）
- [ ] `cp fastlane/.env.example fastlane/.env` 并替换 **5 个占位符**（API key 3 项 + `MATCH_GIT_URL` + `MATCH_PASSWORD`）
- [ ] `fastlane match appstore` 首次生成 Distribution 证书 + 描述文件
- [ ] 验证通过：`fastlane match appstore --readonly` 无报错

## B. TestFlight 首次发布

- [ ] 打包并上传：`./scripts/package.sh --env appstore --distribute testflight --version x.y.z`
- [ ] ASC → **TestFlight** → 构建处理完成（状态变「可测试」）
- [ ] 添加内部测试员（或建外部测试组，并完成出口合规问卷）
- [ ] 测试员通过 **TestFlight App** 安装并验证核心流程（打卡/指标/日历）

## C. App Store 首次上架（仅首次，浏览器）

- [ ] ASC → 我的 App → **+ 创建 App 记录**（名称 CalmTrack / 慢养，bundle id `com.ytl.CalmTrack`，SKU 如 `calmtrack`）
- [ ] 完成 **协议 / 税务 / 银行**（付费账号必填，网站后台）
- [ ] App 信息：**隐私政策 URL** + **App 隐私**（隐私清单）
- [ ] 版本页：描述、关键词、分类、**截图**（6.7" 与 6.5" 至少各一张）
- [ ] 定价（免费或定价档）
- [ ] （App 图标已随工程打包，无需单独传）

## D. 每次发布（日常）

- [ ] `git pull`，工作树干净
- [ ] 决定版本号（`--version x.y.z`；build 号脚本自动递增）
- [ ] 打包/分发：`./scripts/package.sh --env appstore [--distribute testflight|appstore] --version x.y.z`
- [ ] 核对产物 `build/ipa/CalmTrack-*.ipa` 与 build 号
- [ ] **提交 build 号递增的工程改动**（`CalmTrack.xcodeproj/project.pbxproj`）并 `git push`（CI 自动验证）
- [ ] TestFlight：测试员验证通过后再提交审核
- [ ] App Store：ASC 版本页补全（若 `--distribute appstore` 仅上传了二进制）→ **添加以供审核**
- [ ] 审核通过：ASC 点 **发布**（或定时发布）

## E. 常见故障

| 症状 | 处理 |
| --- | --- |
| 报 `REPLACE_WITH_*` 占位符错误 | `fastlane/.env` 未配置或没复制 `.env.example` |
| match 认证失败 | 检查 API key 权限（App Manager 即可）与 `.p8` 路径 |
| 上传 401 / 403 | ASC 角色权限不足，或 API key 已失效（重新生成） |
| `App 记录不存在` | 未在 ASC 创建 App 记录（见 C 第 1 项） |
| 版本号冲突 | ASC 已存在同版本构建，`--version` 递增 |
| TestFlight 构建卡处理中 | 等 10–30 分钟；超时看构建日志（需 `skip_waiting` 已开，检查 ASC 是否有 error） |
