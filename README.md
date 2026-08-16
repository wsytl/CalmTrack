# CalmTrack · 慢养

> 一款以「食疗养生」为主题的 iOS 习惯打卡与身体状态记录应用。
> 中式慢养节奏：规律作息、忌口守护、饮食调养、身体观察，每天轻轻记一笔。

## 功能特性

- **习惯打卡**：按分类（饮食调养 / 忌口守护 / 作息活动 / 身体观察）管理日常养生习惯，支持三种打卡类型：
  - `check` 勾选式打卡（默认）
  - `count` 计数型打卡（如「晨起温水一杯」）
  - `rating` 评分型打卡（星级打分）
- **每日状态记录**：用滑杆记录胃口、腹胀舒适、睡眠、精神、排便顺畅等身体指标（0–5 分）。
- **日历视图**：月度日历按完成比例着色，一眼看出坚持情况；支持年/月快速跳转。
- **历史回看**：按月份分组的指标历史、近 7 天完成率趋势与建议洞察。
- **连续天数统计**：全部习惯完成即算一天，展示连续「全勤」天数。
- **食疗小贴士**：首页根据当日指标与所选调养目标（健脾养胃、祛湿轻身、控糖饮食、改善睡眠、清淡减脂）给出「宜 / 忌」提示。
- **营养日记**：快速记录每日三餐与身体反应，身体反应支持 Markdown 语法编辑与实时预览。
- **内置模板**：首次启动引导中选择调养目标与模板（养胃 7 天、祛湿轻身、控糖饮食、早睡温养），一键生成习惯清单。
- **首次启动引导（Onboarding）**：新用户选择目标与模板后即可开始。

## 技术栈

| 项目 | 说明 |
| --- | --- |
| 语言 | Swift 5.0 |
| UI | SwiftUI（iOS 15.6+） |
| 数据持久化 | Core Data（NSPersistentContainer，自动迁移） |
| 本地化 | String Catalogs（`Localizable.xcstrings`，简体中文 + 英文） |
| 第三方依赖 | 无 |

- 最低部署目标：**iOS 15.6**（工程级配置 26.4，Target 级为 15.6）
- Bundle ID：`com.ytl.CalmTrack`
- 仅支持竖屏（LaunchScreen 通过 Storyboard 配置）

## 项目结构

```
CalmTrack/
├── CalmTrackApp.swift              # App 入口：注入持久化容器，启动 Splash 门控
├── PersistenceController.swift     # Core Data 容器 + 首次启动默认数据种子
├── L10n.swift                      # 本地化读取封装（tr / trf）
├── LocalizedDateFormat.swift       # 本地化日期格式化
├── LaunchScreen.storyboard         # 启动屏
├── Localizable.xcstrings           # String Catalog（zh-Hans / en）
├── CalmTrack.xcdatamodeld/         # Core Data 模型（6 个实体）
├── Extensions/
│   └── Date+CalendarDay.swift      # 自然日 0 点归一化（打卡按日存储的关键）
├── Services/
│   ├── DayRecordStore.swift        # 按自然日取/建记录的统一存储入口（含去重）
│   ├── TemplateCatalog.swift       # 食疗模板唯一数据源（Onboarding / 设置共用）
│   ├── HabitService.swift          # 打卡读写、进度调整、完成度合并、连续天数
│   └── MetricService.swift         # 指标记录读写（读路径只读，不创建记录）
├── Theme/
│   └── CalmStyle.swift             # 「慢养」配色与按钮反馈（CalmChrome）
└── Views/
    ├── ContentView.swift           # 主界面 + 首次启动引导（Onboarding）
    ├── HomeTabBar.swift            # 底部操作栏（设置 / 历史 / 指标）
    ├── HabitListView.swift         # 当日打卡列表 + 营养日记入口
    ├── MarkdownText.swift          # 轻量 Markdown 渲染（AttributedString）
    ├── HabitSummaryStrip.swift     # 完成率环 + 连续天数
    ├── EmptyPlaceholder.swift      # 列表空态占位（分类/习惯/指标管理共用）
    ├── CalendarView.swift          # 月度日历（含年月选择器）
    ├── MetricSheetView.swift       # 每日状态滑杆录入
    ├── MetricHistoryView.swift     # 指标历史 + 近 7 天趋势
    ├── CategoryManagementView.swift    # 分类管理
    ├── HabitItemManagementView.swift   # 习惯项目管理
    ├── MetricItemManagementView.swift  # 指标项管理
    ├── SettingsView.swift          # 设置（调养目标 / 模板 / 分类 / 习惯 / 指标）
    └── LaunchSplashGate.swift      # 启动过渡层（保证「慢养」可见）
```

## 数据模型

Core Data 中共 6 个实体：

| 实体 | 用途 |
| --- | --- |
| `HabitCategory` | 习惯分类（名称 + 排序） |
| `HabitItem` | 习惯项目（标题、类型、目标值、单位，隶属分类） |
| `HabitRecord` | 每日打卡记录（完成 ID 集合 + 计数/评分进度，按自然日唯一） |
| `DietNote` | 营养日记（三餐 + 反应，按自然日） |
| `MetricItem` | 身体指标项（名称、满分值） |
| `MetricRecord` | 每日指标值（按自然日） |

关键约定：

- 所有记录以 **自然日 0 点**（`calendarDayStart`）为键存储与查询，避免时区 / 时分秒不一致导致的读取问题。
- 打卡规则：**只能打卡今天**——未来日期不可打卡，历史日期只读。
- `HabitRecord.completedIDs` 与 `progressValues`、`MetricRecord.values` 使用 Transformable（NSSecureUnarchiveFromData）存储 UUID 集合 / 字典。
- 首次启动自动种子默认分类、默认习惯与默认指标（胃口 / 腹胀舒适 / 睡眠 / 精神 / 排便顺畅），并兼容旧版「晨起 / 日间 / 晚间」分类的自动升级。

## 构建运行

1. 使用 **Xcode 26**（或兼容版本）打开 `CalmTrack.xcodeproj`。
2. 选择 `CalmTrack` scheme 与一个 iOS 模拟器 / 真机。
3. ⌘R 运行。首次启动会展示引导页，选择调养目标与模板后进入主页。

> 无第三方依赖、无需额外配置，Clone 后即可构建。

## 本地化

- 使用 String Catalogs（`Localizable.xcstrings`），通过 `L10n.tr("key")` / `L10n.trf("key", args)` 读取。
- 当前支持 **简体中文（zh-Hans）** 与 **英文（en）**，随系统语言自动切换；中文名「慢养」，英文名「CalmTrack」。

## 目录规划（Roadmap）

- [ ] 数据导出 / 导入（JSON）
- [ ] 提醒通知（每日打卡提醒）
- [ ] 更多统计图表与周报
- [ ] 多平台支持（iPad / macOS）

## License

私有项目，仅供学习参考。
