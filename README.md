# StashSift

Stash 媒体库的鸿蒙客户端。仓库里是**两套独立实现**，功能对齐、互不依赖：

| 实现 | 位置 | 技术栈 | 版本 | 交付物 |
|---|---|---|---|---|
| **原生版** | [`native/`](native/) | ArkTS + ArkUI（Stage 模型，API 26） | v1.0.21 | 单个 HAP |
| **Flutter 版** | 仓库根目录 | Dart + Flutter（`ohos/` 平台层） | v1.6.89 | 鸿蒙 HAP |

原生版不是 WebView 套壳，全部页面都是声明式 UI；Flutter 版用一套 Dart 源码构建鸿蒙应用。
两者都对接 **Stash 0.31.x 的 GraphQL 接口**，面向同一件事：给自己的媒体库做日常维护。

> 仓库原名 `StashScrubber-Harmony`，2026-11 更名为 `StashSift` 并纳入原生实现。

---

## 1. 它能做什么

浏览、筛选、整理、刮削、批量改元数据、扫描与清理——不用回 Stash 网页端。

- **多选批量**：标签 / 演员 / 工作室 / 集合 / 合并 / 收藏，全部走后台任务队列，顶栏有任务角标
- **刮削写回差异化**：文本类只补空白、关系类并集追加，不会把你已有的元数据冲掉
- **内外网自动切换**：内网可达就用内网，不可达自动落到外网并重试
- **元数据编辑闭环**：演员 / 标签 / 工作室 / 集合 / 短片都能在 App 内新建、编辑、合并

明确**不做**视频播放：详情页看的是封面与元数据。

---

## 2. 目录结构

```
StashSift/
├── native/                  # 原生版：ArkTS / ArkUI，独立可构建工程
│   ├── AppScope/            # 包名、版本、应用图标
│   ├── entry/src/main/ets/  # 48 个 .ets：api / models / common / components / pages
│   └── docs/                # 功能清单、Stash 接口参考、协作契约
├── lib/                     # Flutter 版：api / models / pages / settings / widgets
├── ohos/                    # Flutter 版的鸿蒙平台层（hvigor 工程）
├── test/
├── pubspec.yaml             # Flutter 版依赖与版本
└── README.md
```

两套实现各自带 `.gitignore` 与构建配置，可以单独打开、单独构建，互不干扰。

---

## 3. 原生版（`native/`）

| 项目 | 值 |
|---|---|
| 包名 | `com.gtx2090ti.stashgo.app` |
| 版本 | v1.0.21（versionCode 821） |
| 目标 SDK | API 26，runtimeOS HarmonyOS |
| 规模 | 48 个 `.ets`，25 个路由页 |
| 权限 | `ohos.permission.INTERNET`、`ACCESS_BIOMETRIC` |

**特点**

- 液态玻璃视觉：渐变背景 + 半透明填充 + `backdropBlur`，配套 `GlassCard` / `GlassNavBar` / `GlassDock`
- 沉浸式全屏：状态栏与导航条透明，安全区由页面自己补齐
- 登录 / 多档案 / 内外网自动切换 / 人脸指纹锁 / 安全模式
- 首页随机轮播、短片网格、演员·工作室·标签·集合列表、去重、统计、插件与任务队列
- 多选批量全部走后台队列，顶栏任务角标 + 进度条

### 3.1 构建

用 DevEco Studio 打开 `native/`，或在命令行跑 hvigor：

```bash
cd native
hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`

> 需要 DevEco Studio（含 API 26 SDK）与 JDK。若报 `spawn java ENOENT`，检查 `JAVA_HOME` 与 `PATH`；
> 若报 `Cannot find module '@ohos/hvigor-ohos-plugin'`，检查 `NODE_PATH` 是否指到 hvigor 的 project_caches。

### 3.2 签名与安装

```bash
hdc install -r <signed>.hap
hdc shell "aa start -a EntryAbility -b com.gtx2090ti.stashgo.app"
```

版本改 `native/AppScope/app.json5` 的 `versionName` / `versionCode`；每次交付 `versionCode` 要 +1，否则覆盖安装会被系统拦。

更多细节（接口覆盖、界面约定、ArkTS 严格模式踩坑清单）见 [`native/README.md`](native/README.md)。

---

## 4. Flutter 版（仓库根目录）

| 项目 | 值 |
|---|---|
| 包名 | `stash_scrubber_flutter` |
| 版本 | v1.6.89（build 599） |
| 目标 SDK | HarmonyOS NEXT（API 18+） |
| 规模 | 43 个 `.dart`，33 个页面 |
| 依赖 | `local_auth_ohos`（自研 fork，面容 / 指纹解锁） |

**功能**

- **短片**：双排横版卡片、无限滚动、合并搜索（标题 / 路径 / 详情 / 演员 / 标签 / 工作室）、多选批量
- **详情**：封面、信息、演员·工作室·标签跳转、编辑、削刮、生成封面、收藏、清除全部削刮；演员标签附拍摄时年龄
- **演员 / 工作室 / 标签**：卡片列表 + 搜索 + 排序；演员合并；编辑表单覆盖 Stash 0.31.1 全字段
- **削刮**：片段 / 名称 / URL 三种模式，本地刮削器 + Stash-box；标签与已有工作室不覆盖
- **维护**：扫描（全部 / 指定文件夹）、任务队列、批量识别、按感知哈希去重、统计、插件与削刮器包管理
- **设置**：多服务器档案、诊断页、安全模式（缩略图打码）、面容解锁

### 4.1 构建

```bash
flutter pub get
flutter analyze
cd ohos && hvigorw assembleHap -p product=default -p buildMode=release
```

---

## 5. 下载与版本

- Releases：<https://github.com/GTX2090ti/StashSift/releases>
- 原生版命名：`StashGo-Native-v<versionName>-signed.hap`
- Flutter 版命名：`StashScrubber-Flutter-v<versionName>-unsigned.hap`

原生版的逐版变更见 [`native/README.md`](native/README.md)，Flutter 版见下方折叠的版本历史。

---

## 6. 仓库说明

- 更早的 ArkTS 版代码（tag `v1.6.1` 及之前）保留在 git 历史中
- [`README_EN.md`](README_EN.md) 是 Flutter 版时期的英文文档，原生版暂无英文版
- 两套实现共用同一套 Stash 服务端，但**配置不互通**（各自保存服务器档案）

---

## 7. Flutter 版版本历史

<details>
<summary>展开查看 v1.6.46 – v1.6.89</summary>

- **v1.6.89**：短片详情页新增「清除全部削刮」（二次确认后清空简介、日期、链接、工作室、演员与标签，标题回填文件名）；演员标签附拍摄时年龄
- **v1.6.88**：新增「削刮器包」页，从索引源多选安装并自动补齐 `requires` 依赖，按 job id 轮询进度
- **v1.6.87**：削刮写回不再覆盖已保存的标签（与本地标签取并集）
- **v1.6.86**：批量操作的工作室 / 演员 / 标签选择弹窗统一改为带搜索的通用选择器
- **v1.6.85**：演员档案补齐 Stash 0.31.1 全字段，编辑与添加共用表单、按分组折叠
- **v1.6.84**：批量识别、去重、统计、插件页；多选批量加「设置工作室」「添加演员」；生成选项补全
- **v1.6.70**：安全模式、收藏页、无限滚动；面容解锁（人脸优先，指纹回退）
- **v1.6.58**：平板自适应列数；详情页宽屏双栏；播放器式封面背景
- **v1.6.57**：演员合并；写回名字冲突保护
- **v1.6.55**：削刮错误中文提示；日期输入自动补全连字符
- **v1.6.52**：演员片段削刮改传 `performer_input`（0.31.1 的 `performer_id` 返回 not implemented）
- **v1.6.51**：全部搜索栏加清空按钮
- **v1.6.50**：术语简体中文化；生成封面查询字段修复
- **v1.6.48**：演员 / 工作室主列表排序；短片详情文件区改造（路径完整折行、多文件逐块、设为默认文件）
- **v1.6.46**：短片生成封面（详情页 + 多选批量）；Stash-box 片段削刮；演员详情别名显示

</details>

---

MIT License · 仅用于个人媒体库管理
