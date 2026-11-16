# StashSift

Stash 媒体库的鸿蒙客户端。**ArkTS 原生重写**，不是 WebView 套壳——所有页面都是声明式 UI，液态玻璃视觉，沉浸式全屏，单 HAP 交付。

面向自己的媒体库做日常维护：浏览、筛选、整理、刮削、批量改元数据、扫描与清理。**不用回 Stash 网页端。**

仓库里同时保留一套 Flutter 跨平台版（`lib/` + `ohos/`），两套实现功能对齐、互不依赖。

> 原名 `StashScrubber-Harmony`，2026-11 更名 StashSift 并纳入原生实现。

---

## 为什么又一个 Stash 客户端

现有客户端要么是 WebView 套壳（滚动发涩、手势断裂、没有系统材质），要么功能只到「看」——真正费时间的整理、刮削、批量改元数据还得开浏览器。

StashSift 的取舍：

- **原生到底**：ArkUI 声明式 UI + 系统符号图标 + 液态玻璃材质，手势和动画都是系统的
- **整理是一等公民**：多选批量、元数据编辑、合并、刮削写回全部在 App 内完成
- **不覆盖你已有的数据**：刮削写回是差异化的，文本只补空白、关系并集追加
- **顺手**：内网可达走内网，不可达自动落外网

---

## 两套实现

| | 原生版 | Flutter 版 |
|---|---|---|
| 位置 | [`native/`](native/) | 仓库根目录 |
| 技术栈 | ArkTS + ArkUI（Stage 模型） | Dart + Flutter |
| 版本 | **v1.0.32**（versionCode 832） | **v1.6.89**（build 599） |
| 目标 SDK | API 26，runtimeOS HarmonyOS | HarmonyOS NEXT（API 18+） |
| 规模 | 49 个 `.ets`，27 个路由页 | 43 个 `.dart`，33 个页面 |
| 交付物 | 单个 HAP | HAP |

原生版是主力，功能已追平并超出 Flutter 版；Flutter 版保留完整历史实现，可作为跨平台参考。

---

## 功能

### 浏览与检索

- **主页**：随机 8 条短片轮播（4 秒自动切换、循环、圆点指示）+ 最近添加
- **短片列表**：网格、分页、搜索、排序菜单、筛选入口、多选
- **筛选页**：工作室 / 演员 / 标签三段可折叠 + 评分、整理状态；支持服务端关键字搜索，突破本地候选上限
- **演员 / 工作室 / 标签 / 集合**：列表带排序条 + 搜索，竖版卡片，平板自适应列数
- **收藏**：短片（= 已整理）/ 演员 / 工作室三个页签，各自排序
- **去重**：按感知哈希距离 + 时长差查找重复短片，多选合并

### 短片详情

- 封面、标题、五星评分、基本情報、工作室、演员、标签、URL、文件信息
- **操作行**：刮削 / 编辑 / 合并 / 删除　**基本情報行**：清除刮削 / 收藏 / 整理 / 封面
- 演员显示**拍摄时年龄**（用短片日期与演员生日精确到月日计算）
- 多文件短片逐条显示文件名、路径、大小·时长，**文件名与文件夹各自可复制**
- 所属集合直接跳转；标签、工作室、演员可点击进详情

### 多选批量（全部走后台队列）

```
全选  取消选择  收藏  标签  演员  工作室  集合  合并
```

提交后立刻退出多选，写入在后台串行执行；顶栏出现 🕐 任务角标，点进任务队列看进度。重复项自动跳过，提示会说明「已提交 N 条（跳过 M 条重复）」。

### 刮削

- **三种输入**：短片标题 / 名称 / URL
- **刮削中心**：本地刮削器 + Stash-box 统一入口，刮削器列表可折叠
- **刮削器商店**：从索引源搜索并多选安装，自动补齐 `requires` 依赖，按 job id 轮询进度，装完自动重载
- **Fantia** 站点支持

**写回是差异化的，不会冲掉你已有的元数据：**

| 字段 | 已有内容时 |
|---|---|
| 标题 / 简介 / 日期 / 番号 / 导演 | 保留原值，只补空白 |
| 工作室 | 保留原值 |
| 演员 / 标签 / 链接 URL | **并集追加去重** |
| 封面 | 用刮削封面 |

写回完成后状态栏会说明「新增了什么、保留了哪些」。

### 元数据编辑闭环

四类实体都能在 App 内直接改，不用回网页端。所有写操作都是「预填当前值 → 改 → 整表写回」，失败留在编辑态并显示服务端原因。

| 实体 | 入口 | 可改 |
|---|---|---|
| 演员 | 详情「编辑资料」 | 姓名、消歧义、别名、链接、性别、生日、忌日、国家、族裔、发色、瞳色、身高、体重、三围、假胸、纹身、穿孔、出道年、隐退年、简介 |
| 演员 | 详情「合并」 | 三步式：选保留目标 → 多选并入项 → 二次确认 |
| 标签 | 列表「新建」、详情「编辑」/「合并」 | 名称、排序名、简介、别名、收藏、父标签 |
| 工作室 | 详情「编辑」 | 名称、别名、链接、简介、收藏、评分、整理状态、父工作室 |
| 集合 | 列表「新建」、详情「编辑」/「删除」 | 名称、别名、日期、时长、评分、导演、简介、链接、工作室、标签 |
| 短片 | 详情「编辑」 | 原有字段 + **所属集合** |

### 媒体库维护

- 增量扫描 / 全量重扫 / **指定文件夹扫描**（多选弹层，只列库配置路径）
- 清理缺失文件，支持 **dryRun 预演**
- 任务队列：3 秒轮询、状态中文化、数据无变化不重绘
- 媒体库统计、插件管理（启停 / 任务 / 钩子）、网络日志

### 连接与安全

| 功能 | 说明 |
|---|---|
| 多档案 | 内网 / 外网双地址 + ApiKey |
| 内外网自动切换 | 启动探测内网，失败切外网；请求失败自动回退重试；可关 |
| 应用锁 | 人脸 / 指纹（ATL3），切后台回来重新验证 |
| 多任务隐私模糊 | 后台时多任务卡片内容模糊 |
| 安全模式 | 封面 / 标题打码，长按临时查看 |

---

## 界面

统一规则：**渐变背景 + 半透明填充 + `backdropBlur`**。

```ts
.linearGradient({ angle: 160, colors: [[top, 0], [mid, 0.5], [bottom, 1]] })
.backgroundColor(this.theme.cardBg)     // 带 alpha
.backdropBlur(24)
.borderRadius(16)
.border({ width: 1, color: this.theme.cardBorder })
```

- **沉浸式**：状态栏与导航条透明，页面根节点 `expandSafeArea`，安全区内边距由页面自己补
- **底部 Dock**：半透明悬浮胶囊，始终压在内容之上；多选时内容区收窄，批量操作栏浮在胶囊上方
- **图标**：一律用系统符号 `SymbolGlyph($r('sys.symbol.xxx'))`，不引第三方图标库

---

## 构建

### 原生版

用 DevEco Studio 打开 `native/`，或命令行：

```bash
cd native
hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`

安装：

```bash
hdc install -r <signed>.hap
hdc shell "aa start -a EntryAbility -b com.gtx2090ti.stashgo.app"
```

需要 DevEco Studio（含 API 26 SDK）与 JDK。版本改 `native/AppScope/app.json5` 的 `versionName` / `versionCode`，每次交付 `versionCode` 要 +1，否则覆盖安装会被系统拦。

常见报错：`spawn java ENOENT` → 检查 `JAVA_HOME` / `PATH`；`Cannot find module '@ohos/hvigor-ohos-plugin'` → 检查 `NODE_PATH` 是否指到 hvigor 的 project_caches。

### Flutter 版

```bash
flutter pub get
flutter analyze
cd ohos && hvigorw assembleHap -p product=default -p buildMode=release
```

---

## 目录结构

```
StashSift/
├── native/                       # 原生版，独立可构建
│   ├── AppScope/                 # 包名、版本、图标
│   ├── entry/src/main/ets/
│   │   ├── api/StashApi.ets      # GraphQL 客户端
│   │   ├── models/               # DTO 与领域模型、筛选状态
│   │   ├── common/               # 玻璃材质、响应式、批量队列、内外网切换、生物识别…
│   │   ├── components/           # GlassCard / GlassNavBar / GlassDock / FilterChip…
│   │   ├── settings/             # 持久化、本地化
│   │   └── pages/                # 27 个路由页
│   └── docs/                     # 功能清单、Stash 接口参考
├── lib/                          # Flutter 版：api / models / pages / widgets
├── ohos/                         # Flutter 版的鸿蒙平台层
└── test/
```

---

## 已知限制

- **不做视频播放**。详情页看的是封面与元数据，播放交给专门的播放器
- **短片没有 favorite 字段**，所以「收藏」落地为 `organized`（已整理）标记；演员、工作室是 Stash 原生 favorite
- **封面无法真正清空**：Stash 的 `cover_image` 只能设新值，不能恢复默认截图
- **后台队列是内存队列**：App 被杀掉则未完成任务丢失（每条是独立写操作，不会留半途脏数据）
- 服务端没有 `studioMerge`（Stash 0.31.1 实测），工作室只做编辑不做合并

---

## 文档

- [`native/README.md`](native/README.md) — 原生版完整文档：接口覆盖、界面约定、ArkTS 严格模式踩坑清单
- [`native/docs/功能清单-已实现.md`](native/docs/功能清单-已实现.md)
- [`native/docs/功能清单-待实现.md`](native/docs/功能清单-待实现.md)
- [`native/docs/Stash-接口参考.md`](native/docs/Stash-接口参考.md)
- [`README_EN.md`](README_EN.md) — Flutter 版英文文档

---

MIT License · 仅用于个人媒体库管理
