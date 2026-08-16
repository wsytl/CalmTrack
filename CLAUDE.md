# CLAUDE.md

## Agent skills

### Issue tracker

Issues are tracked as local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical roles, label strings equal to their names: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.

## 工程命令与约定

- **构建**：Xcode 26 打开 `CalmTrack.xcodeproj`（无第三方依赖）。
- **测试**：Xcode ⌘U 运行 `CalmTrackTests`（7 个 seam）；CI 每次 push 跑 `fastlane ios build` + `test_build`。
- **打包**：`./scripts/package.sh [--env development|appstore] [--version x.y.z]`；build 号自动 +1 并写回工程 `CURRENT_PROJECT_VERSION`——打包后记得提交该工程改动。产物在 `build/ipa/`。
- **分发**：装 iPhone 用 `xcrun devicectl device install app`；TestFlight 见 `docs/fastlane-guide.md`（API key 占位，激活前 `beta`/`package --env appstore` 会失败）。
- **git**：main + GitHub 私有仓库 wsytl/CalmTrack；一个逻辑改动一个提交；push 前 CI 自动验证。
- **领域约定**：打卡只能今天；「一日一记录」由写入路径强制；视图层不直接触碰 Transformable blob（走 `HabitService`/`MetricService` 类型化接口）。
