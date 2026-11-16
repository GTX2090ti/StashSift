# StashGo · 鸿蒙原生版

用 **ArkTS / ArkUI** 重写的 Stash 客户端，液态玻璃视觉、沉浸式全屏、单 HAP 交付。
不是 WebView 套壳，所有页面都是原生声明式 UI。

| 项目 | 值 |
|---|---|
| 包名 | `com.gtx2090ti.stashgo.app` |
| 版本 | **v1.0.7**（versionCode **807**） |
| 目标 SDK | API 26（compatible / target 均 26.0.0，runtimeOS HarmonyOS） |
| 语言 / 框架 | ArkTS + ArkUI（Stage 模型） |
| 代码规模 | 46 个 `.ets`，约 **18650** 行 |
| 页面 | 25 个路由页 |
| 服务端 | Stash v0.31.1 GraphQL |

---

## 1. 它是什么

对着自己的 Stash 媒体库做日常维护：浏览、筛选、整理、刮削、批量改元数据、扫描与清理。

对标的是项目里的 Flutter 跨平台版（`flutter_src/`），鸿蒙版在功能上已经补齐并超出：

- **多选批量**：标签 / 演员 / 工作室 / 集合 / 合并 / 收藏，全部走后台任务队列，顶栏有任务角标
- **刮削写回差异化**：文本类只补空白、关系类并集追加，不会把你已有的元数据冲掉
- **内外网自动切换**：内网可达就用内网，不可达自动落到外网并重试

---

## 2. 构建与安装

### 2.1 环境

- DevEco Studio（含 SDK API 26）
- JDK：用 DevEco 自带 `jbr`
- 依赖已离线缓存在 hvigor project_caches，构建不需要联网

### 2.2 编译

```powershell
$env:NODE_PATH = "C:\Users\<你>\.hvigor\project_caches\<hash>\workspace\node_modules"
$env:HVIGOR_USER_HOME = "D:\DSHX\steash\LiquidGlassDemo\.hvigor_home"
$env:JAVA_HOME = "D:\DevEco Studio\jbr"
$env:PATH = "D:\DevEco Studio\jbr\bin;" + $env:PATH

node "D:\DevEco Studio\tools\hvigor\hvigor\bin\hvigor.js" assembleHap `
  -p product=default -p buildMode=debug --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`

> `HVIGOR_USER_HOME` 必须指到工程内目录，否则会写到用户目录。若报 `spawn java ENOENT`，就是 `JAVA_HOME` / `PATH` 没配好。
>
> **在受限沙箱里构建**：hvigor 与 ets-loader 会用管道拉 `restool.exe` / `es2abc.exe` 的输出，沙箱禁止建管道时会直接报 `spawn EPERM`（表现为 `CompileResource` 或 `Failed to execute es2abc with async handler` 失败）。绕法是预加载一个把子进程 stdio 改成 `inherit` 的 shim：
>
> ```powershell
> node -r D:\DSHX\steash\tmp\build-shim.js "D:\DevEco Studio\tools\hvigor\hvigor\bin\hvigor.js" `
>   assembleHap -p product=default -p buildMode=debug --no-daemon
> ```
>
> 另外 `NODE_PATH` 要指向 `~/.hvigor/project_caches/<hash>/workspace/node_modules`（含 `@ohos/hvigor-ohos-plugin`），否则报 `Cannot find module '@ohos/hvigor-ohos-plugin'`。

### 2.3 签名

```powershell
java -jar hap-sign-tool.jar sign-app `
  -keyAlias hokit -keyPwd hokit9527 -keystorePwd hokit9527 `
  -signCode 1 -signAlg SHA256withECDSA -mode localSign `
  -appCertFile <cert>.cer -profileFile <profile>.p7b `
  -keystoreFile <store>.p12 `
  -inFile  entry-default-unsigned.hap `
  -outFile StashGo-Native-v1.0.2-signed.hap
```

### 2.4 安装

```powershell
hdc tconn 192.168.2.137:12345          # 无线连接，IP 按实际改
hdc install -r StashGo-Native-v1.0.2-signed.hap
hdc shell "aa force-stop com.gtx2090ti.stashgo.app"
hdc shell "aa start -a EntryAbility -b com.gtx2090ti.stashgo.app"
```

### 2.5 版本与包名约定

- 版本改 `AppScope/app.json5` 的 `versionName` / `versionCode`
- **安装包命名只带 versionName**：`StashGo-Native-v<versionName>-signed.hap`
- 每次交付 `versionCode` +1，否则覆盖安装会被系统拦

---

## 3. 目录结构

```
LiquidGlassDemo/
├── AppScope/
│   ├── app.json5                     # 包名、版本、应用图标
│   └── resources/base/media/app_icon.png
├── entry/src/main/
│   ├── module.json5                  # 权限：INTERNET、ACCESS_BIOMETRIC
│   ├── resources/base/profile/main_pages.json
│   └── ets/
│       ├── entryability/EntryAbility.ets    # 启动路由、沉浸式、上锁、隐私遮罩
│       ├── api/StashApi.ets                 # GraphQL 客户端（57 个接口）
│       ├── models/
│       │   ├── Models.ets                   # DTO 与领域模型
│       │   └── SceneFilter.ets              # 筛选状态（单例）
│       ├── common/
│       │   ├── GlassUtils.ets               # 主题令牌、渐变、玻璃材质
│       │   ├── Responsive.ets               # 圆角/间距/Dock 尺寸
│       │   ├── BatchQueue.ets               # 后台批量任务队列
│       │   ├── NetSwitch.ets                # 内外网探测与切换
│       │   ├── Biometric.ets                # 生物识别
│       │   ├── OptionCache.ets              # picker 候选缓存
│       │   ├── DataVersion.ets              # 数据版本广播
│       │   ├── Sorts.ets                    # 各列表排序项
│       │   └── ErrorLog.ets                 # 未捕获异常落 hilog
│       ├── components/                      # GlassCard / GlassNavBar /
│       │                                    # GlassDock / SortBar / StarRating / AuthImage
│       ├── settings/
│       │   ├── AppSettings.ets              # preferences 持久化
│       │   └── L10n.ets
│       └── pages/                           # 24 个页面
└── docs/                                    # 功能清单、Stash 接口参考
```

---

## 4. 功能总览

### 4.1 连接与安全

| 功能 | 说明 |
|---|---|
| 登录 | 填 Stash 地址 + ApiKey，多档案（内网 / 外网双地址） |
| 内外网自动切换 | 启动探测内网，失败切外网；请求失败自动回退重试；设置页可关 |
| 应用锁 | 人脸 / 指纹（ATL3），切后台回来重新验证 |
| 多任务隐私模糊 | 后台时多任务卡片内容模糊 |
| 安全模式 | 封面 / 标题打码 |

### 4.2 浏览与检索

| 页面 | 能力 |
|---|---|
| 主页 | 顶部 **随机 8 条短片轮播**（4 秒自动切、循环、圆点指示）+ 最近添加 |
| 短片列表 | 网格、分页、搜索、排序菜单、筛选入口、多选 |
| 筛选页 | 工作室 / 演员 / 标签三段可折叠 + 评分、整理状态等 |
| 收藏 | 短片（= 已整理）/ 演员 / 工作室三个页签，各自排序 |
| 演员 / 工作室 / 标签 / 集合 | 列表均带 **排序条 + 搜索**（顶栏放大镜展开） |
| 去重 | 查找重复短片 |

### 4.3 短片详情

- 封面、标题、评分（五星）、基本情報、工作室、演员、标签、URL、文件信息
- **操作行**：刮削 / 编辑 / 合并 / 删除
- **基本情報行**：清除刮削 / 收藏 / 整理 / 封面
- 演员显示 **拍摄时年龄**（用短片日期与生日精确到月日计算）
- 标签可点击跳标签详情；工作室、演员同理
- 多文件短片逐条显示文件名、路径、大小·时长，**文件名与文件夹各自可复制**
- 合并后保留刮削数据，多文件按序号分行

### 4.4 多选批量（全部走后台队列）

```
全选  取消选择  收藏  标签  演员  工作室  集合  合并
```

| 动作 | 行为 |
|---|---|
| 收藏 | 全未收藏 → 全部收藏；全已收藏 → 全部取消 |
| 标签 / 演员 / 集合 | 弹候选多选层 → **已有相同项的条目自动跳过** |
| 工作室 | 候选单选 |
| 合并 | 选中条目选一个目标，其余并入 |

- 提交后立刻退出多选，实际写入在后台串行执行
- 顶栏出现 **🕐 任务角标**，点进任务队列看进度条
- 提示会说明「已提交 N 条（跳过 M 条重复）」

### 4.5 刮削

- 三种输入：短片标题 / 名称 / URL
- 刮削器列表可折叠，成功后自动收起
- 结果预览：封面、标题、日期、工作室、演员、标签、简介

**写回规则（差异化）**：

| 字段 | 已有内容时 |
|---|---|
| 标题 / 简介 / 日期 / 番号 / 导演 | 保留原值，只补空白 |
| 工作室 | 保留原值 |
| 演员 | **并集追加去重** |
| 标签 | **并集追加去重** |
| 链接 URL | **并集追加去重** |
| 封面 | 用刮削封面 |

写回完成后状态栏会说明「新增了什么、保留了哪些」。

### 4.6 媒体库维护

- 增量扫描 / 全量重扫 / **指定文件夹扫描**（只列库配置路径，多选弹层）
- 清理缺失文件（支持**预演** dryRun）
- 任务队列：3 秒轮询、状态中文化、按任务号升序、数据无变化不重绘
- 媒体库统计、插件管理、网络日志

### 4.7 元数据编辑（v1.0.7）

四类实体都能在 App 内直接改，不用回 Stash 网页端。所有写操作都是「预填当前值 → 改 → 整表写回」，失败留在编辑态并显示服务端返回的原因。

| 实体 | 入口 | 可改 |
|---|---|---|
| 演员 | 演员详情「编辑资料」 | 姓名、消歧义、别名、链接、性别、生日、忌日、国家、族裔、发色、瞳色、身高、体重、三围、假胸、纹身、穿孔、出道年、隐退年、简介 |
| 演员 | 演员详情「合并」 | 三步式：选保留目标 → 多选并入项 → 二次确认，并入项会被删除 |
| 标签 | 标签列表「新建」、标签详情「编辑」 | 名称、排序名、简介、别名、收藏、父标签（多选） |
| 标签 | 标签详情「合并」 | 同上三步式 |
| 工作室 | 工作室详情「编辑」 | 名称、别名、链接、简介、收藏、评分、整理状态、父工作室（可清除） |
| 集合 | 集合列表「新建」、集合详情「编辑」/「删除」 | 名称、别名、日期、时长、评分、导演、简介、链接、工作室、标签 |
| 短片 | 短片详情「编辑」 | 在原有字段之外新增**所属集合**（chip + 选择器，保存时覆盖写回） |

集合同样支持在短片详情里反向维护：详情页只读区会显示「所属集合」，点 chip 直接跳到集合详情。

### 4.8 设置

外观（跟随系统 / 浅色 / 深色）、生物识别锁、安全模式、内外网自动切换、功能入口（任务队列 / 扫描 / 统计 / 刮削 / 插件 / 网络日志）。

---

## 5. 界面约定

### 5.1 液态玻璃

统一规则：**渐变背景 + 半透明填充 + `backdropBlur`**。

```ts
.linearGradient({ angle: 160, colors: [[top, 0], [mid, 0.5], [bottom, 1]] })
.backgroundColor(this.theme.cardBg)     // 带 alpha
.backdropBlur(24)
.borderRadius(16)
.border({ width: 1, color: this.theme.cardBorder })
```

**不要**用 `systemMaterial` / `backgroundStyle(BlurStyle.COMPONENT_*)`——在真机上会变成不透明实色，玻璃感全丢。

### 5.2 沉浸式

- `setWindowLayoutFullScreen(true)`
- 状态栏 / 导航栏 `#00000000` 透明，图标颜色跟随主题
- 页面根节点 `expandSafeArea([SYSTEM], [TOP, BOTTOM])`
- 页面自己补内边距：`statusInset`（状态栏）、`navInset`（导航条）

### 5.3 底部 Dock

半透明悬浮胶囊，**始终显示**，压在内容之上：

```
Stack({ alignContent: Alignment.Bottom }) {
  Column() { 导航栏 + 内容 }
  GlassDock({ current: n, isRoot })
}
```

已覆盖：主页 / 短片 / 收藏 / 资料库（设置页从 Dock 进入，页内不显示）。
内容区底部留 96vp，多选时收到 8vp；批量操作栏浮在胶囊上方 24vp。

### 5.4 图标

一律用官方符号：`SymbolGlyph($r('sys.symbol.xxx'))`。
已验证可用：`magnifyingglass` `xmark` `arrow_up` `arrow_down` `arrow_clockwise` `arrow_counterclockwise` `star` `star_fill` `checkmark_circle` `checkmark_circle_fill` `circle` `line_3_horizontal` `chevron_down` `chevron_right` `label` `house` `film` `book` `gearshape` `person` `lock_fill` `histogram` `clock` `doc_text`

### 5.5 全局状态（AppStorage）

| Key | 用途 |
|---|---|
| `navInset` / `statusInset` | 安全区内边距 |
| `winWidthVp` / `winHeightVp` | 响应式布局 |
| `systemDark` / `themeVersion` | 深浅色跟随与广播 |
| `filterVersion` | 筛选条件变更 → 列表刷新 |
| `sceneVersion` | 短片数据变更 → 列表刷新 |
| `safeMode` | 安全模式 |
| `batchActive` / `batchVersion` | 后台任务数与进度广播 |

---

## 6. ArkTS 严格模式踩坑清单

写这个项目时反复踩到的，记下来省事：

| 问题 | 正确写法 |
|---|---|
| 不许 `any` | 用具体类型；`JSON.parse` 结果走 `Record<string, Object>` |
| 不能用 `arr[i].field` 做类型收窄 | 先 `const d = list[i]` 再访问 |
| 不支持声明合并 | 拆成独立 interface |
| 对象字面量必须有明确类型 | 定义 class，或 `Record<string, string>` |
| 具名导入 CommonJS | `import { errorManager } from '@kit.PerformanceAnalysisKit'` 之外用 default import |
| `connection.on(...)` 不存在 | 该 SDK 版本不暴露，改用主动探测 |
| GraphQL 枚举不能内联 | 放进 `variables` 传 |
| **`@Builder` 按值传参不刷新** | `@Builder chip(label, active, onTap)` 这类写法，参数变化**不会**触发 builder 内 UI 更新（表现为「点了没反应、选中不变色」）。要跟随状态刷新：① 改成 `@Component` + `@Prop`（本项目的 `components/FilterChip.ets`）；② 或让 builder 只接一个常量参数，动态值在 builder 体内直接读 `this.xxx` |
| DTO 字符串字段可能是 `null` | GraphQL 的空标量返回 `null` 而不是 `undefined`，`x !== undefined && x.length` 会崩；统一走 `strOf(v)`（`undefined \|\| null → ''`） |

---

## 7. 已知限制

- **不做什么**：视频播放（明确排除）。点详情看的是封面与元数据，不放视频。
- **Stash 的短片没有 favorite 字段**，所以「收藏」落地为 `organized`（已整理）标记；演员、工作室是 Stash 原生 favorite。
- **封面无法真正清空**：Stash 的 `cover_image` 只能设新值，不能恢复默认截图。
- **后台队列是内存队列**：App 被杀掉则未完成任务丢失（每条是独立 `sceneUpdate`，不会留半途脏数据）。
- **未逐项真机点检**：去重处理、插件任务运行、筛选器高级组合、演员详情编辑。

---

## 8. 接口覆盖

`api/StashApi.ets` 共 **66** 个方法，含全部用到的查询与变更：

- 查询：`findScenes` `findScene` `findScenesAdvanced` `findScenesFiltered` `findScenesByTag` `findScenesByPerformer` `findPerformers(Ex)` `findPerformer` `findStudios` `findStudiosLite` `studiosForBrowse` `findFavoriteStudios` `findFavoritePerformers` `findTags` `findGroups` `findGroupsRich` `findDuplicateScenes` `performersLite` `tagsLite` `studiosLite` `libraryPaths` `folderOptions` `sceneGroupIds` `stats` `plugins` `listPlugins` `listPluginTasks` `scrapers` `jobQueue` `version`
- 变更：`updateScene` `updateSceneMeta` `setSceneTags` `setScenePerformers` `setSceneStudio` `setSceneGroups` `clearSceneMeta` `updatePerformerFavorite` `updatePerformerRating` `updatePerformer` `mergePerformers` `updateTag` `mergeTags` `updateStudio` `createGroup` `updateGroup` `destroyGroup` `createStudio` `createPerformer` `createTag` `resolveId` `markScenePlayed` `resetScenePlayCount` `bulkUpdateScenes` `bulkUpdateSceneTags` `identifyScenes` `mergeScenes` `destroyScene(s)` `scanLibrary` `cleanLibrary` `metadataScan` `generateCovers` `scrapeSceneByName` `scrapeSceneURL` `runPluginTask` `setPluginEnabled`
- 服务端没有 `studioMerge`（Stash 0.31.1 实测），所以工作室只做编辑不做合并。

---

## 9. 相关文档

- [`docs/功能清单-已实现.md`](docs/功能清单-已实现.md)
- [`docs/功能清单-待实现.md`](docs/功能清单-待实现.md)
- [`docs/Stash-接口参考.md`](docs/Stash-接口参考.md)

---

## 10. 变更记录

| 版本 | 主要变化 |
|---|---|
| **1.0.7** | **元数据编辑闭环**：演员资料编辑（20 字段）+ 演员合并；标签新建/编辑（含父标签）/合并；工作室编辑（含父工作室）+ 修复「新建工作室」入口不可达的死代码；集合新建/编辑/删除 + 列表封面与计数；短片详情展示所属集合、编辑表单可直接增删集合。新增 9 个 GraphQL 写接口并逐个对真实 Stash 0.31.1 校验过 payload 形状。**真机点检修复 5 个 bug**：集合详情/列表在 `date: null` 上抛 `Cannot read property length of null` 导致白屏与元信息缺失；演员合并后列表不刷新；**筛选页 chip 用 `@Builder` 按值传参导致点了不变色、分组计数永远停在 0**（改为 `@Component` + `@Prop`）；筛选页计数改为「已选 N 项条件」并支持服务端关键字搜索（突破本地 500 条候选上限） |
| 1.0.6 | 演员详情分卡片（基本情報 / 别名 / 简介 / 履历 / 链接 / 统计），补拍片年龄 |
| 1.0.5 | 刮削写回改成「文本只补空白、关系并集追加」，不再冲掉已有元数据 |
| 1.0.4 | 批量任务队列（顶栏角标 + 进度），多选批量加标签/演员/工作室/集合/合并 |
| 1.0.2 | 修复详情页操作行被嵌套的收藏按钮（收藏已归位到基本情報行）；应用图标更新为液态玻璃播放键 |
| 1.0.1 | 启用版本号体系 |
| 1.0.0 | 功能补齐：首页随机 8 条轮播、多选批量 + 后台任务队列 + 顶栏角标、批量加标签/演员/工作室/集合/合并（重复跳过）、刮削差异化写回、演员拍摄时年龄、各列表搜索、底栏全页半透明悬浮、收藏语义回归 organized、内外网自动切换 |

---

MIT License · 仅用于个人媒体库管理
