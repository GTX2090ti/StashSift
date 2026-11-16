# Stash GraphQL 接口参考（本项目实测版）

> 服务器：`http://192.168.2.180:9999`  ·  Stash **v0.31.1**
> 认证：HTTP 头 `ApiKey: <你的 key>`
> 端点：`POST /graphql`，`Content-Type: application/json`，body 为 `{ "query": "...", "variables": {...} }`
> 本文档由 live schema introspection 生成，**优先于任何记忆或猜测**。改代码前先查这里。

---

## 一、最常见的坑：字段会返回 `null`

ArkTS 里 `null.length`、`null.name` 会直接抛 `Cannot read property xxx of null`。
**这不是网络问题，是数据形状问题。**

### 1.1 `ScrapedScene`（刮削结果）— 大量字段可为 null

| 字段 | 类型 | 会是 null 吗 |
|---|---|---|
| `title` `code` `details` `director` `date` `image` `remote_site_id` | String | **会** |
| `duration` | Int | **会** |
| `file` | SceneFileType | **会** |
| `studio` | ScrapedStudio | **会**（整个对象为 null） |
| `urls` | [String!] | **会**（列表本身为 null） |
| `performers` `tags` `groups` | [Xxx!] | **会**（列表本身为 null） |
| `fingerprints` | StashBoxFingerprint | **会** |

> 实例：FANZA/Fantia 源对没有番号的片子返回 `"code": null`，直接导致 `code.length` 崩溃。

### 1.2 `Scene`（库内短片）— 标量可空，列表非空

| 字段 | 类型 | 会是 null 吗 |
|---|---|---|
| `id` | ID! | 不会 |
| `title` `code` `details` `director` `date` | String | **会** |
| `rating100` `o_counter` `play_count` | Int | **会** |
| `resume_time` `play_duration` | Float | **会** |
| `last_played_at` | Time | **会** |
| `organized` | Boolean! | 不会 |
| `created_at` `updated_at` | Time! | 不会 |
| **`urls` `files` `performers` `tags` `groups`** | **[X!]!** | **不会**（放心 `.length`） |
| `studio` | Studio | **会** |
| `stash_ids` `custom_fields` | — | 会 |

### 1.3 其他对象

- `ScrapedStudio.name`、`ScrapedTag.name`：**非空**（`String!`），但父对象 `studio` 可能为 null
- `ScrapedPerformer` 几乎所有字段可空，含 `name`

---

## 二、写操作输入类型（逐字段核对过）

### `SceneUpdateInput`（25 个字段，`sceneUpdate` 用）

```
clientMutationId, id(必填), title, code, details, director,
url(单个), urls(数组), date, rating100, o_counter, organized,
studio_id, gallery_ids, performer_ids, groups, movies, tag_ids,
cover_image, stash_ids, resume_time, play_duration, play_count,
primary_file_id, custom_fields
```

**注意**：
- `performer_ids` / `tag_ids` / `gallery_ids` 是 **ID 列表**
- 想清空工作室用 `studio_id: null`
- **不传 rating100/organized 就不会改**；传 0 / false 会覆盖原值 ← 本项目踩过这个坑

### `ScanMetadataInput`（`metadataScan` 用）

```
paths: [String!]        ← 选择性扫描：只扫这些目录
rescan: Boolean         ← true = 全量重扫
scanGenerateCovers / Previews / ImagePreviews / Sprites /
Phashes / ImagePhashes / Thumbnails / ClipPreviews: Boolean
filter: ScanMetaDataFilterInput
```

### `CleanMetadataInput`（`metadataClean` 用）

```
paths: [String!]            ← 限定清理范围
ignoreZipFileContents: Boolean
dryRun: Boolean!            ← 必填；true = 只预演
```

### `FindFilterType`（所有 `findXxx` 的通用分页/排序）

```
q: String          ← 关键词
page: Int
per_page: Int
sort: String       ← "created_at" / "name" / "rating" ...
direction: SortDirectionEnum   ← ASC / DESC
```

---

## 三、本项目用到的接口

### 查询

| 用途 | 接口 | 关键参数 |
|---|---|---|
| 短片列表 | `findScenes` | `filter`, `scene_filter` |
| 短片详情 | `findScene` | `id` |
| 演员 | `findPerformers` / `findPerformer` | `filter` / `id` |
| 工作室 | `findStudios` / `findStudio` | `filter` / `id` |
| 标签 | `findTags` / `findTag` | `filter` / `id` |
| 合集 | `findGroups` / `findGroup` | `filter` / `id` |
| 重复短片 | `findDuplicateScenes` | `distance` |
| 媒体库路径 | `configuration { general { stashes { path excludeVideo } } }` | — |
| 统计 | `stats { scene_count scenes_size ... }` | — |
| 任务队列 | `jobQueue { id status description progress subTasks }` | — |
| 插件 | `plugins` / `listPlugins` / `listPluginTasks` | — |
| 刮削器 | `scrapers { id name }` | — |
| 刮削 | `scrapeSingleScene(source, input)` | `source: {scraper_id}` `input: {query}` |

### 变更

| 用途 | 接口 |
|---|---|
| 更新短片 | `sceneUpdate(SceneUpdateInput)` |
| 新建 | `studioCreate` / `performerCreate` / `tagCreate` |
| 标记已看 | `sceneAddPlay(id)` |
| 清零播放 | `sceneResetPlayCount(id)` |
| 删除 | `sceneDestroy(id)` / `sceneDestroy` 批量 |
| 合并 | `sceneMerge` |
| 识别 | `identify(input)` |
| 扫描 | `metadataScan(ScanMetadataInput)` |
| 清理 | `metadataClean(CleanMetadataInput)` |
| 生成封面 | `metadataGenerate` |
| 插件 | `runPluginTask` / `configurePlugin` |

> ⚠️ **没有单独的「选择性扫描」接口**。Stash 网页版的选择性扫描 = `metadataScan` 带 `paths`。

---

## 四、已踩过的坑（改代码前必看）

| # | 坑 | 现象 | 正确做法 |
|---|---|---|---|
| 1 | 可空字段直接 `.length` / `.name` | `Cannot read property length of null` | 全部过 `toStr()` / 判 `=== null` |
| 2 | `updateScene` 传 `rating100:0, organized:false` | 评分和整理标记被清空 | 写前先读旧值再原样传回 |
| 3 | `direction: "ASC"` 直接拼在 query 字符串里 | `Expected value of type SortDirectionEnum` | 必须走 `variables` |
| 4 | `findFolders(folder_filter:{path:"/x"})` | `Expected StringCriterionInput` | `path` 要传 `{value, modifier}` 对象；本项目改用库配置路径 |
| 5 | `metadataScan` 以为是同步 | 界面卡住等不到结果 | 它是**异步任务**，立刻返回，进度看 `jobQueue` |
| 6 | `jobQueue` 会整表重绘 | 界面一直闪 | 比对数据，变了才 `this.jobs = next` |
| 7 | 刮削结果直接丢弃关联名字 | 演员/标签/工作室写不进去 | 先用名字查 ID，查不到再 `create` |
| 8 | 列表页不刷新 | 改了标题返回列表还是旧标题 | 改动后 `bumpScenes()`，列表 `@Watch` 重载 |

---

## 五、本项目编码约定（强制）

1. **所有从 JSON 拿到的字段都视为可空**，一律走安全转换：
   ```ts
   private toStr(v: Object | undefined): string {
     if (v === undefined || v === null) return ''
     return v.toString()
   }
   ```
2. **列表字段先判空再 `.length`**：
   ```ts
   if (r.urls !== undefined && r.urls !== null) { ... }
   ```
3. **写操作前必读旧值**：`rating100`、`organized` 这类不能凭空给默认值。
4. **输入类型先核对本文第二节**，不要凭印象加字段。
5. **新接口先验证再写界面**：用 `Invoke-RestMethod` 或 curl 打一次真实请求，确认形状合法再写 ArkTS。
6. 枚举值（`direction` 等）一律走 `variables`，不拼字符串。

---

## 六、验证接口形状的快捷方法

```powershell
$headers = @{ "ApiKey" = "<key>" }
$b = @{ query = 'query { jobQueue { id status } }' } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "http://192.168.2.180:9999/graphql" -Method Post `
  -Headers $headers -ContentType "application/json" -Body $b
```

用**不存在的 id** 验证调整 mutation 形状最安全：

```graphql
mutation { sceneUpdate(input: { id: "99999999", title: "x" }) { id } }
# 返回 "scene with id 99999999 not found" = 形状合法
# 返回 "Field xxx is not defined by type SceneUpdateInput" = 形状有问题
```
