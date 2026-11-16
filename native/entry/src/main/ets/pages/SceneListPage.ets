/**
 * StashSift — 短片列表（对齐原版 UI：工具行 + 搜索行 + 双列封面网格）
 */
import { router } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Scene, SceneDto, SceneFile } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassDock } from '../components/GlassDock'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GLASS_THEME_DARK, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'
import { scenesVersion } from '../common/DataVersion'
import { SceneFilterState } from '../models/SceneFilter'
import { LayoutSpec, layoutFor, columnsTemplate, RADIUS_XS, RADIUS_S, RADIUS_CHIP, RADIUS_CARD, PAD_PAGE, GAP_S, GAP_M, DOCK_H, DOCK_MARGIN, RADIUS_DOCK } from '../common/Responsive'
import { BatchQueue, BatchJob } from '../common/BatchQueue'
import { SceneGroupRow } from '../models/Models'

class SortOption {
  label: string = ''
  field: string = ''
  dir: string = 'DESC'

  constructor(label: string, field: string, dir: string) {
    this.label = label
    this.field = field
    this.dir = dir
  }
}

class BatchOption {
  id: string = ''
  name: string = ''

  constructor(id: string, name: string) {
    this.id = id
    this.name = name
  }
}

@Entry
@Component
struct SceneListPage {
  @State scenes: Scene[] = []
  @State loading: boolean = false
  @State hasMore: boolean = true
  @State keyword: string = ''
  @State searchMode: boolean = false
  @State sortIndex: number = 0
  @State sortDir: string = 'DESC'
  @State sortMenuOpen: boolean = false
  @State onlyOrganized: boolean = false
  @State errorText: string = ''
  @State selectMode: boolean = false
  @State selected: string[] = []
  @State busy: boolean = false
  @StorageProp('batchActive') batchActive: number = 0
  @StorageProp('batchVersion') batchVersion: number = 0
  @State panel: string = ''
  @State optItems: BatchOption[] = []
  @State optPicked: string[] = []
  @State optLoading: boolean = false
  @State optQuery: string = ''
  @State toast: string = ''
  /** 下拉刷新中（Refresh 双向绑定） */
  @State pullRefreshing: boolean = false
  /** FAVORITE 标签 id（收藏 = 带这个标签） */
  private favTagId: string = ''
  @StorageProp('filterVersion') filterVersion: number = 0
  @StorageProp('winWidthVp') winW: number = 360
  private lastFilterVersion: number = 0
  private page: number = 1
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  private sorts: SortOption[] = [
    new SortOption('添加时间', 'created_at', 'DESC'),
    new SortOption('日期', 'date', 'DESC'),
    new SortOption('标题', 'title', 'ASC'),
    new SortOption('评分', 'rating', 'DESC'),
    new SortOption('时长', 'duration', 'DESC')
  ]

  aboutToAppear(): void {
    this.lastFilterVersion = this.filterVersion
    this.reload()
  }

  @StorageProp('sceneVersion') @Watch('onScenesChanged') sceneVersion: number = 0

  onScenesChanged(): void {
    this.reload()
  }

  onPageShow(): void {
    // 外观切换后返回本页要立即跟随
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
    if (this.filterVersion !== this.lastFilterVersion) {
      this.lastFilterVersion = this.filterVersion
      this.reload()
    }
  }

  private async reload(): Promise<void> {
    this.page = 1
    this.hasMore = true
    this.scenes = []
    this.errorText = ''
    await this.load()
  }

  /** 下拉刷新：回到第一页重新拉取（保留当前排序/筛选/搜索） */
  private async pullRefresh(): Promise<void> {
    console.info('[SceneListPage] pullRefresh fired, loading=' + this.loading.toString())
    if (this.loading) {
      this.pullRefreshing = false
      return
    }
    this.toast = '已刷新'
    await this.reload()
    this.pullRefreshing = false
  }

  private async load(): Promise<void> {
    if (this.loading || !this.hasMore) {
      return
    }
    this.loading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      if (this.favTagId.length === 0) {
        this.favTagId = await api.favoriteTagId()
      }
      const so: SortOption = this.sorts[this.sortIndex]
      const raw: SceneDto[] = await api.findScenesFiltered(
        this.page, 24, this.keyword.trim(), so.field, this.sortDir,
        SceneFilterState.instance.toJson()
      )
      const list: Scene[] = Scene.listFromDto(raw)
      const merged: Scene[] = this.scenes.slice()
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i])
      }
      this.scenes = merged
      this.hasMore = list.length === 24
      this.page = this.page + 1
    } catch (e) {
      this.errorText = (e as Error).message
      console.error('[SceneListPage] ' + this.errorText)
    }
    this.loading = false
  }

private sortMenu(): MenuElement[] {
    const items: MenuElement[] = []
    for (let i = 0; i < this.sorts.length; i++) {
      const idx: number = i
      const label: string = this.sorts[i].label
      items.push({
        value: label,
        action: () => {
          this.sortIndex = idx
          this.reload()
        }
      })
    }
    return items
  }
  private durText(d: number): string {
    const t: number = Math.floor(d)
    if (t <= 0) {
      return ''
    }
    const h: number = Math.floor(t / 3600)
    const m: number = Math.floor((t % 3600) / 60)
    const s: number = t % 60
    const ss: string = s < 10 ? '0' + s.toString() : s.toString()
    if (h > 0) {
      const mm: string = m < 10 ? '0' + m.toString() : m.toString()
      return h.toString() + ':' + mm + ':' + ss
    }
    return m.toString() + ':' + ss
  }

  private resText(h: number): string {
    if (h >= 2000) {
      return '4K'
    }
    if (h >= 1000) {
      return '1080P'
    }
    if (h >= 700) {
      return '720P'
    }
    return ''
  }

  private heightOf(s: Scene): number {
    if (s.files.length > 0) {
      return s.files[0].height
    }
    return 0
  }

  /** 工作室 · 演员；没有工作室时用占位符，保证每张卡片行高与结构一致 */
  private artistText(s: Scene): string {
    const parts: string[] = []
    if (s.studioNames.length === 0) {
      parts.push('未知工作室')
    }
    for (let i = 0; i < s.studioNames.length; i++) {
      parts.push(s.studioNames[i])
    }
    for (let i = 0; i < s.performerNames.length; i++) {
      parts.push(s.performerNames[i])
    }
    return parts.join(' · ')
  }

  @Builder
  badge(text: string, bg: string) {
    Text(text)
      .fontSize(10)
      .fontColor(Color.White)
      .backgroundColor(bg)
      .borderRadius(RADIUS_XS)
      .padding({ left: 5, right: 5, top: 2, bottom: 2 })
  }

  @Builder
  sceneCard(s: Scene) {
    Column() {
      // 封面区（16:9）
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          AuthImage({ rawPath: s.poster })
        }
        .width('100%')
        .aspectRatio(16 / 9)
        .clip(true)

        // 左上：分辨率
        Column() {
          if (this.resText(this.heightOf(s)).length > 0) {
            this.badge(this.resText(this.heightOf(s)), '#FF0A59F7')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 6, top: 6 })
        // 右上：已收藏星标（收藏 = FAVORITE 标签，与 SJP 一致）
        if (this.isFavScene(s)) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(14)
            .fontColor(['#FFFFB700'])
            .backgroundColor('#80000000')
            .borderRadius(RADIUS_S)
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .position({ right: 6, top: 6 })
        }
        // 右下：时长
        if (this.durText(s.duration).length > 0) {
          Text(this.durText(s.duration))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(RADIUS_XS)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .position({ right: 6, bottom: 6 })
        }
        // 左下：字幕（与右下角时长同底对齐）
        if (s.hasCaption) {
          Text('字幕')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(RADIUS_XS)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .position({ left: 6, bottom: 6 })
        }
        // 多选指示
        if (this.selectMode) {
          Text(this.isSelected(s.id) ? '✓' : '○')
            .fontSize(14)
            .fontColor(Color.White)
            .width(24)
            .height(24)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.isSelected(s.id) ? this.theme.brandColor : '#8C000000')
            .borderRadius(RADIUS_CARD)
            .position({ left: 6, top: 6 })
        }
      }
      .width('100%')

      // 文字区
      Column() {
        Text(s.title.length === 0 ? '（无标题）' : s.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(17)
          .width('100%')
          .height(34)

        Row() {
          Text(this.artistText(s))
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (s.rating100 > 0) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(11)
              .fontColor(['#FFFFB700'])
            Text((s.rating100 / 20).toFixed(1))
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .margin({ left: 1 })
          }
          if (s.tagNames.length > 0) {
            SymbolGlyph($r('sys.symbol.label'))
              .fontSize(11)
              .fontColor([this.theme.textSecondary])
              .margin({ left: 6 })
            Text(s.tagNames.length.toString())
              .fontSize(10)
              .fontColor(this.theme.textSecondary)
              .margin({ left: 1 })
          }
        }
        .width('100%')
        .height(18)
        .margin({ top: 4 })
      }
      .width('100%')
      .padding({ left: GAP_M, right: GAP_M, top: 8, bottom: 10 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .shadow({ radius: 14, color: this.theme.cardShadow })
    .backdropBlur(24)
    .clip(true)
    .onClick(() => {
      if (this.selectMode) {
        this.toggleSelect(s.id)
      } else {
        router.pushUrl({ url: 'pages/SceneDetailPage', params: { 'id': s.id } })
      }
    })
    .gesture(
      // 长按卡片：进入多选并选中这一张（搜索结果里同样可用）
      LongPressGesture({ repeat: false, duration: 400 })
        .onAction(() => {
          if (!this.selectMode) {
            this.selectMode = true
          }
          if (!this.isSelected(s.id)) {
            this.toggleSelect(s.id)
          }
        })
    )
  }

  /* ---------------- 批量面板 ---------------- */

  /** 顶栏任务按钮的角标：队列里还有任务（含刚结束未清理的）就显示 */
  private taskBadgeCount(): number {
    const stamp: number = this.batchVersion
    const list: BatchJob[] = BatchQueue.instance.list()
    if (list.length === 0) {
      return 0
    }
    return list.length
  }

  private panelTitle(): string {
    if (this.panel === 'tag') {
      return '批量加标签'
    }
    if (this.panel === 'performer') {
      return '批量加演员'
    }
    if (this.panel === 'studio') {
      return '批量设工作室'
    }
    if (this.panel === 'group') {
      return '批量加集合'
    }
    if (this.panel === 'merge') {
      return '合并到'
    }
    return ''
  }

  private closePanel(): void {
    this.panel = ''
    this.optItems = []
    this.optPicked = []
    this.optQuery = ''
  }

  /** 打开面板并加载候选 */
  private async openPanel(kind: string): Promise<void> {
    this.panel = kind
    this.optQuery = ''
    this.optPicked = []
    this.optItems = []
    if (kind === 'merge') {
      // 合并候选 = 已选的短片
      for (let i = 0; i < this.scenes.length; i++) {
        const sc = this.scenes[i]
        if (this.isSelected(sc.id)) {
          this.optItems.push(new BatchOption(sc.id, sc.title.length > 0 ? sc.title : sc.id))
        }
      }
      return
    }
    this.optLoading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      if (kind === 'tag') {
        const raw = await api.findTags(1, 300, 'name', 'ASC')
        for (let i = 0; i < raw.length; i++) {
          const d = raw[i]
          this.optItems.push(new BatchOption(d.id === undefined ? '' : d.id,
            d.name === undefined ? '' : d.name))
        }
      } else if (kind === 'performer') {
        const raw = await api.findPerformersEx(1, 300, '', 'name', 'ASC')
        for (let i = 0; i < raw.length; i++) {
          const d = raw[i]
          this.optItems.push(new BatchOption(d.id === undefined ? '' : d.id,
            d.name === undefined ? '' : d.name))
        }
      } else if (kind === 'studio') {
        const raw = await api.findStudiosLite(1, 300, 'name', 'ASC')
        for (let i = 0; i < raw.length; i++) {
          const d = raw[i]
          this.optItems.push(new BatchOption(d.id === undefined ? '' : d.id,
            d.name === undefined ? '' : d.name))
        }
      } else if (kind === 'group') {
        const raw = await api.findGroups(1, 300, 'name', 'ASC')
        for (let i = 0; i < raw.length; i++) {
          const d = raw[i]
          this.optItems.push(new BatchOption(d.id === undefined ? '' : d.id,
            d.name === undefined ? '' : d.name))
        }
      }
    } catch (e) {
      this.toast = '加载候选失败：' + (e as Error).message
    }
    this.optLoading = false
  }

  private toggleOpt(id: string): void {
    if (this.panel === 'merge' || this.panel === 'studio') {
      // 单选
      this.optPicked = [id]
      return
    }
    const out: string[] = []
    let had: boolean = false
    for (let i = 0; i < this.optPicked.length; i++) {
      if (this.optPicked[i] === id) {
        had = true
      } else {
        out.push(this.optPicked[i])
      }
    }
    if (!had) {
      out.push(id)
    }
    this.optPicked = out
  }

  private isOptPicked(id: string): boolean {
    for (let i = 0; i < this.optPicked.length; i++) {
      if (this.optPicked[i] === id) {
        return true
      }
    }
    return false
  }

  private filteredOpts(): BatchOption[] {
    const q: string = this.optQuery.trim().toLowerCase()
    if (q.length === 0) {
      return this.optItems
    }
    const out: BatchOption[] = []
    for (let i = 0; i < this.optItems.length; i++) {
      if (this.optItems[i].name.toLowerCase().indexOf(q) >= 0) {
        out.push(this.optItems[i])
      }
    }
    return out
  }

  /** 执行批量写入（走后台队列） */
  private async applyBatch(): Promise<void> {
    if (this.optPicked.length === 0 || this.selected.length === 0) {
      return
    }
    const ids: string[] = this.selected.slice()
    const picked: string[] = this.optPicked.slice()
    const kind: string = this.panel
    const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)

    if (kind === 'merge') {
      // 合并后谁当主文件：优先「已经刮削过」的那条（有标题/封面/演员/标签）
      let dest: string = picked[0]
      let bestScore: number = this.scrapedScoreOf(dest)
      for (let i = 0; i < ids.length; i++) {
        const sc: number = this.scrapedScoreOf(ids[i])
        if (sc > bestScore) {
          bestScore = sc
          dest = ids[i]
        }
      }
      const rest: string[] = []
      for (let i = 0; i < ids.length; i++) {
        if (ids[i] !== dest) {
          rest.push(ids[i])
        }
      }
      BatchQueue.instance.start('合并 ' + rest.length.toString() + ' 条', rest,
        async (id: string): Promise<boolean> => {
          return await api.mergeScenes([id], dest, true, true, '')
        })
      this.toast = '已提交合并任务：' + rest.length.toString() + ' 条' +
        (dest !== picked[0] ? '（主文件已改为刮削过的那条）' : '')
    } else if (kind === 'tag') {
      // 已经有这些标签的直接跳过
      const todo: string[] = []
      for (let i = 0; i < ids.length; i++) {
        if (!this.hasAllTags(ids[i], picked)) {
          todo.push(ids[i])
        }
      }
      const skipped: number = ids.length - todo.length
      if (todo.length > 0) {
        BatchQueue.instance.start('批量加标签', todo, async (id: string): Promise<boolean> => {
          const next: string[] = this.tagIdsOf(id).slice()
          for (let i = 0; i < picked.length; i++) {
            if (next.indexOf(picked[i]) < 0) {
              next.push(picked[i])
            }
          }
          return await api.setSceneTags(id, next)
        })
      }
      this.toast = this.batchToast('加标签', todo.length, skipped)
    } else if (kind === 'performer') {
      const todo: string[] = []
      for (let i = 0; i < ids.length; i++) {
        if (!this.hasAllPerformers(ids[i], picked)) {
          todo.push(ids[i])
        }
      }
      const skipped: number = ids.length - todo.length
      if (todo.length > 0) {
        BatchQueue.instance.start('批量加演员', todo, async (id: string): Promise<boolean> => {
          const next: string[] = this.performerIdsOf(id).slice()
          for (let i = 0; i < picked.length; i++) {
            if (next.indexOf(picked[i]) < 0) {
              next.push(picked[i])
            }
          }
          return await api.setScenePerformers(id, next)
        })
      }
      this.toast = this.batchToast('加演员', todo.length, skipped)
    } else if (kind === 'studio') {
      const studio: string = picked[0]
      const todo: string[] = []
      for (let i = 0; i < ids.length; i++) {
        if (this.studioIdOf(ids[i]) !== studio) {
          todo.push(ids[i])
        }
      }
      const skipped: number = ids.length - todo.length
      if (todo.length > 0) {
        BatchQueue.instance.start('批量设工作室', todo, async (id: string): Promise<boolean> => {
          return await api.setSceneStudio(id, studio)
        })
      }
      this.toast = this.batchToast('设工作室', todo.length, skipped)
    } else if (kind === 'group') {
      // 先取各短片已有集合，已在其中的跳过
      let rows: SceneGroupRow[] = []
      try {
        rows = await api.sceneGroupIds(ids)
      } catch (e) {
        this.toast = '读取集合失败：' + (e as Error).message
        return
      }
      const map: Map<string, string[]> = new Map<string, string[]>()
      for (let i = 0; i < rows.length; i++) {
        map.set(rows[i].sceneId, rows[i].groupIds)
      }
      const todo: string[] = []
      for (let i = 0; i < ids.length; i++) {
        const cur: string[] = map.get(ids[i]) === undefined ? [] : (map.get(ids[i]) as string[])
        let all: boolean = true
        for (let k = 0; k < picked.length; k++) {
          if (cur.indexOf(picked[k]) < 0) {
            all = false
          }
        }
        if (!all) {
          todo.push(ids[i])
        }
      }
      const skipped: number = ids.length - todo.length
      if (todo.length > 0) {
        BatchQueue.instance.start('批量加集合', todo, async (id: string): Promise<boolean> => {
          const base: string[] = map.get(id) === undefined ? [] : (map.get(id) as string[])
          const next: string[] = base.slice()
          for (let i = 0; i < picked.length; i++) {
            if (next.indexOf(picked[i]) < 0) {
              next.push(picked[i])
            }
          }
          return await api.setSceneGroups(id, next)
        })
      }
      this.toast = this.batchToast('加集合', todo.length, skipped)
    }

    this.closePanel()
    this.selectMode = false
    this.selected = []
  }

  private batchToast(action: string, todo: number, skipped: number): string {
    if (todo === 0) {
      return '所选条目都已' + action + '，无需处理'
    }
    const base: string = '已提交后台任务：' + action + ' ' + todo.toString() + ' 条'
    return skipped > 0 ? (base + '（跳过 ' + skipped.toString() + ' 条重复）') : base
  }

  private hasAllTags(sceneId: string, tagIds: string[]): boolean {
    const cur: string[] = this.tagIdsOf(sceneId)
    for (let i = 0; i < tagIds.length; i++) {
      if (cur.indexOf(tagIds[i]) < 0) {
        return false
      }
    }
    return true
  }

  private hasAllPerformers(sceneId: string, performerIds: string[]): boolean {
    const cur: string[] = this.performerIdsOf(sceneId)
    for (let i = 0; i < performerIds.length; i++) {
      if (cur.indexOf(performerIds[i]) < 0) {
        return false
      }
    }
    return true
  }

  private studioIdOf(sceneId: string): string {
    for (let i = 0; i < this.scenes.length; i++) {
      if (this.scenes[i].id === sceneId) {
        return this.scenes[i].studioId
      }
    }
    return ''
  }

  /** 刮削完整度打分：合并时用来决定让哪条当主文件 */
  private scrapedScoreOf(sceneId: string): number {
    for (let i = 0; i < this.scenes.length; i++) {
      const s: Scene = this.scenes[i]
      if (s.id !== sceneId) {
        continue
      }
      let n: number = 0
      if (s.title.length > 0) {
        n = n + 5
      }
      if (s.poster.length > 0) {
        n = n + 4
      }
      if (s.details.length > 0) {
        n = n + 2
      }
      if (s.date.length > 0) {
        n = n + 1
      }
      if (s.studioId.length > 0) {
        n = n + 3
      }
      n = n + Math.min(s.performerRefs.length, 5)
      n = n + Math.min(s.tagIds.length, 5)
      if (s.rating100 > 0) {
        n = n + 2
      }
      return n
    }
    return 0
  }

  private tagIdsOf(sceneId: string): string[] {
    for (let i = 0; i < this.scenes.length; i++) {
      if (this.scenes[i].id === sceneId) {
        return this.scenes[i].tagIds
      }
    }
    return []
  }

  private performerIdsOf(sceneId: string): string[] {
    for (let i = 0; i < this.scenes.length; i++) {
      const sc = this.scenes[i]
      if (sc.id === sceneId) {
        const out: string[] = []
        for (let k = 0; k < sc.performerRefs.length; k++) {
          out.push(sc.performerRefs[k].id)
        }
        return out
      }
    }
    return []
  }

  /* ---------------- 多选 ---------------- */


  /** 全选当前已加载的短片 */
  private selectAll(): void {
    const all: string[] = []
    for (let i = 0; i < this.scenes.length; i++) {
      all.push(this.scenes[i].id)
    }
    this.selected = all
  }


  private toggleSelect(id: string): void {
    const out: string[] = []
    let found: boolean = false
    for (let i = 0; i < this.selected.length; i++) {
      if (this.selected[i] === id) {
        found = true
      } else {
        out.push(this.selected[i])
      }
    }
    if (!found) {
      out.push(id)
    }
    this.selected = out
    // 与跨平台版一致：取消到空自动退出多选
    if (out.length === 0) {
      this.selectMode = false
    }
  }

  private isSelected(id: string): boolean {
    for (let i = 0; i < this.selected.length; i++) {
      if (this.selected[i] === id) {
        return true
      }
    }
    return false
  }

  /** 选中条目里是否还有未收藏的（收藏 = 带 FAVORITE 标签，与 SJP 一致） */
  private allSelectedFav(): boolean {
    if (this.selected.length === 0) {
      return false
    }
    for (let i = 0; i < this.scenes.length; i++) {
      const sc = this.scenes[i]
      if (this.isSelected(sc.id) && !this.isFavScene(sc)) {
        return false
      }
    }
    return true
  }

  /** 这条是否已收藏（带收藏标签） */
  private isFavScene(sc: Scene): boolean {
    if (this.favTagId.length === 0) {
      return false
    }
    return sc.tagIds.indexOf(this.favTagId) >= 0
  }

  /** 收藏按钮文案：全部已收藏时显示「已收藏」，否则「收藏」 */
  private favBtnLabel(): string {
    return this.allSelectedFav() ? '已收藏' : '收藏'
  }

  /** 一键切换：全已收藏 → 取消收藏；否则全部收藏 */
  private batchToggleFav(): void {
    this.batchSetFav(!this.allSelectedFav())
  }

  /** 批量收藏 / 取消收藏：加 / 删 FAVORITE 标签 */
  private async batchSetFav(target: boolean): Promise<void> {
    if (this.busy || this.selected.length === 0) {
      return
    }
    this.busy = true
    const ids: string[] = this.selected.slice()
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      if (this.favTagId.length === 0) {
        this.favTagId = await api.favoriteTagId()
      }
      const ok: boolean = await api.setScenesFavorite(ids, target)
      this.toast = ok
        ? ('已' + (target ? '收藏 ' : '取消收藏 ') + ids.length.toString() + ' 条')
        : '操作失败：服务端没有返回结果'
    } catch (e) {
      this.toast = '操作失败：' + (e as Error).message
    }
    this.busy = false
    this.selectMode = false
    this.selected = []
    this.reload()
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        GlassNavBar({
          title: L10n.translate('短片'),
          subtitle: '共 ' + this.scenes.length + ' 部',
          theme: this.theme,
          style: GlassStyle.REGULAR,
          showSearch: true,
          taskCount: this.taskBadgeCount(),
          onTaskTap: () => {
            router.pushUrl({ url: 'pages/StashTasksPage' })
          },
          searchActive: this.searchMode,
          onSearchTap: () => {
            // 一下展开、再一下收起（收起时清空关键字）
            this.searchMode = !this.searchMode
            if (!this.searchMode) {
              this.keyword = ''
              this.reload()
            }
          }
        })

        // 工具行：排序字段 + 切换顺序 + 筛选 + 多选
        if (this.searchMode) {
          Row() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(15)
              .fontColor([this.theme.textSecondary])
              .margin({ right: 6 })
            TextInput({ text: this.keyword, placeholder: '搜索标题 / 演员 / 标签 / 工作室' })
              .fontSize(14)
              .fontColor(this.theme.textPrimary)
              .placeholderColor(this.theme.textSecondary)
              .layoutWeight(1)
              .backgroundColor(Color.Transparent)
              .padding(0)
              .onChange((v: string) => {
                this.keyword = v
              })
              .onSubmit(() => {
                this.reload()
              })
            if (this.keyword.length > 0) {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(14)
                .fontColor([this.theme.textSecondary])
                .margin({ left: 6 })
                .onClick(() => {
                  this.keyword = ''
                  this.reload()
                })
            }
          }
          .width('100%')
          .height(40)
          .padding({ left: GAP_M, right: GAP_M, top: 8, bottom: 8 })
          .backgroundColor(this.theme.cardBg)
          .borderRadius(RADIUS_CHIP)
          .border({ width: 1, color: this.theme.cardBorder })
          .margin({ top: 8, bottom: 6 })
        } else {
          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            // 按钮一：排序字段（点击弹菜单）
            Row() {
              Text(this.sorts[this.sortIndex].label)
                .fontSize(12)
                .fontColor(this.theme.textPrimary)
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontSize(10)
                .fontColor([this.theme.textSecondary])
            }
            .flexShrink(0)
            .margin({ right: 6 })
            .padding({ left: GAP_M, right: GAP_S, top: 7, bottom: 7 })
            .backgroundColor(this.theme.chipBg)
            .borderRadius(RADIUS_CHIP)
            .bindMenu(this.sortMenu())

            // 按钮二：切换顺序（↓ 降序 / ↑ 升序）
            Row() {
              Text(this.sortDir === 'DESC' ? '↓ 降序' : '↑ 升序')
                .fontSize(12)
                .fontColor(this.theme.brandColor)
            }
            .flexShrink(0)
            .margin({ right: 6 })
            .padding({ left: GAP_M, right: GAP_M, top: 7, bottom: 7 })
            .backgroundColor(this.theme.chipBg)
            .borderRadius(RADIUS_CHIP)
            .onClick(() => {
              this.sortDir = this.sortDir === 'DESC' ? 'ASC' : 'DESC'
              this.reload()
            })

            // 按钮三：筛选
            Text(SceneFilterState.instance.isEmpty()
              ? '筛选'
              : ('筛选 · ' + SceneFilterState.instance.activeCount().toString()))
              .fontSize(12)
              .fontColor(SceneFilterState.instance.isEmpty() ? this.theme.textSecondary : Color.White)
              .backgroundColor(SceneFilterState.instance.isEmpty()
                ? this.theme.chipBg : this.theme.brandColor)
              .borderRadius(RADIUS_CHIP)
              .padding({ left: GAP_M, right: GAP_M, top: 7, bottom: 7 })
              .margin({ right: 6 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/SceneFilterPage' })
              })

            // 按钮四：多选
            Text(this.selectMode ? ('已选 ' + this.selected.length.toString()) : '多选')
              .fontSize(12)
              .fontColor(this.selectMode ? Color.White : this.theme.textSecondary)
              .backgroundColor(this.selectMode ? this.theme.brandColor : this.theme.chipBg)
              .borderRadius(RADIUS_CHIP)
              .padding({ left: GAP_M, right: GAP_M, top: 7, bottom: 7 })
              .onClick(() => {
                this.selectMode = !this.selectMode
                this.selected = []
              })
          }
          .width('100%')
          .padding({ left: PAD_PAGE, right: PAD_PAGE })
          .margin({ top: 8, bottom: 6 })
        }

        // 网格（Refresh 的直接子节点必须是可滚动组件，所以只包 Grid，不包空态）
        if (!this.loading && this.scenes.length === 0) {
          Column() {
            Text(this.errorText.length > 0 ? this.errorText : '没有短片')
              .fontSize(14)
              .fontColor(this.errorText.length > 0 ? '#FFE84026' : this.theme.textSecondary)
            Button('重试')
              .height(34)
              .fontSize(14)
              .backgroundColor(this.theme.brandColor)
              .fontColor(Color.White)
              .borderRadius(RADIUS_CHIP)
              .margin({ top: 12 })
              .onClick(() => {
                this.reload()
              })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Refresh({ refreshing: $$this.pullRefreshing, promptText: '下拉刷新列表' }) {
          Grid() {
            ForEach(this.scenes, (s: Scene) => {
              GridItem() {
                this.sceneCard(s)
              }
            }, (s: Scene) => s.id)

            if (this.loading || this.hasMore) {
              GridItem() {
                Row() {
                  LoadingProgress().width(22).height(22)
                  Text('加载中…')
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                    .margin({ left: 6 })
                }
                .justifyContent(FlexAlign.Center)
                .width('100%')
                .height(44)
              }
              .columnStart(0)
              .columnEnd(1)
            }
          }
          .columnsTemplate(columnsTemplate(layoutFor(this.winW).columns))
          .columnsGap(layoutFor(this.winW).gap)
          .rowsGap(layoutFor(this.winW).gap + 2)
          .width('100%')
          .height('100%')
          .padding({
            left: layoutFor(this.winW).pagePadding,
            right: layoutFor(this.winW).pagePadding,
            top: 6,
            bottom: this.selectMode ? 8 : 96
          })
          .onReachEnd(() => {
            this.load()
          })
          }
          .layoutWeight(1)
          .width('100%')
          .onRefreshing(() => {
            this.pullRefresh()
          })
        }

        if (this.toast.length > 0) {
          Text(this.toast)
            .fontSize(12)
            .fontColor('#FF64BB5C')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 4, bottom: 4 })
        }

        // 批量操作栏（多动作，横向可滚动）
        if (this.selectMode) {
          Row() {
            Column() {
              Scroll() {
                Row() {
                  this.batchBtn('全选', () => {
                    this.selectAll()
                  })
                  this.batchBtn('取消选择', () => {
                    this.selected = []
                    this.selectMode = false
                  })
                  this.batchBtn(this.favBtnLabel(), () => {
                    this.batchToggleFav()
                  })
                  this.batchBtn('标签', () => {
                    this.openPanel('tag')
                  })
                  this.batchBtn('演员', () => {
                    this.openPanel('performer')
                  })
                  this.batchBtn('工作室', () => {
                    this.openPanel('studio')
                  })
                  this.batchBtn('集合', () => {
                    this.openPanel('group')
                  })
                  this.batchBtn('合并', () => {
                    this.openPanel('merge')
                  })
                }
                .height(44)
                .alignItems(VerticalAlign.Center)
                .padding({ left: 8, right: 8 })
              }
              .height(44)
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.theme.cardBg)
            .backdropBlur(30)
            .borderRadius(22)
            .border({ width: 1, color: this.theme.cardBorder })
            .shadow({ radius: 24, color: this.theme.cardShadow })
          }
          .width('100%')
          .padding({ left: PAD_PAGE, right: PAD_PAGE })
          .margin({ bottom: DOCK_H + DOCK_MARGIN })
        }
      }
      .width('100%')
      .height('100%')

      // 悬浮胶囊底栏：始终显示，批量操作栏浮在它上面
      GlassDock({ current: 1, isRoot: false, theme: this.theme })
      if (this.panel.length > 0) {
        this.panelSheet()
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  batchBtn(label: string, onTap: () => void) {
    Text(label)
      .fontSize(11)
      .fontColor(this.theme.textPrimary)
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .margin({ right: 6 })
      .height(28)
      .textAlign(TextAlign.Center)
      .onClick(onTap)
  }
  @Builder
  panelSheet() {
    Column() {
      // 标题栏
      Row() {
        Text(this.panelTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
        Blank()
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(18)
          .fontColor([this.theme.textPrimary])
          .padding(6)
          .onClick(() => {
            this.closePanel()
          })
      }
      .width('100%')
      .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 14, bottom: 8 })

      // 搜索
      Row() {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(14)
          .fontColor([this.theme.textSecondary])
          .margin({ right: 6 })
        TextInput({ text: this.optQuery, placeholder: '搜索' })
          .layoutWeight(1)
          .fontSize(13)
          .height(30)
          .backgroundColor(Color.Transparent)
          .placeholderColor(this.theme.textSecondary)
          .fontColor(this.theme.textPrimary)
          .onChange((v: string) => {
            this.optQuery = v
          })
      }
      .width('100%')
      .height(38)
      .padding({ left: GAP_M, right: GAP_M })
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .margin({ left: PAD_PAGE, right: PAD_PAGE, bottom: 8 })

      if (this.optLoading) {
        Row() {
          LoadingProgress().width(20).height(20)
          Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.filteredOpts(), (o: BatchOption) => {
            ListItem() {
              Row() {
                Text(o.name)
                  .fontSize(13)
                  .fontColor(this.theme.textPrimary)
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                SymbolGlyph(this.isOptPicked(o.id)
                  ? $r('sys.symbol.checkmark_circle_fill')
                  : $r('sys.symbol.circle'))
                  .fontSize(18)
                  .fontColor([this.isOptPicked(o.id) ? this.theme.brandColor : this.theme.textSecondary])
              }
              .width('100%')
              .padding({ left: GAP_M, right: GAP_M, top: 10, bottom: 10 })
            }
            .onClick(() => {
              this.toggleOpt(o.id)
            })
          }, (o: BatchOption) => o.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: PAD_PAGE, right: PAD_PAGE })
        .scrollBar(BarState.Off)
      }

      // 底部操作
      Row() {
        Text('已选 ' + this.optPicked.length.toString())
          .fontSize(12)
          .fontColor(this.theme.textSecondary)
          .layoutWeight(1)
        Button('取消')
          .height(34)
          .fontSize(13)
          .backgroundColor(this.theme.chipBg)
          .fontColor(this.theme.textPrimary)
          .borderRadius(RADIUS_CHIP)
          .onClick(() => {
            this.closePanel()
          })
        Button(this.panel === 'merge' ? '合并' : '应用')
          .height(34)
          .fontSize(13)
          .backgroundColor(this.theme.brandColor)
          .fontColor(Color.White)
          .borderRadius(RADIUS_CHIP)
          .margin({ left: 8 })
          .enabled(this.optPicked.length > 0)
          .onClick(() => {
            this.applyBatch()
          })
      }
      .width('100%')
      .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bd.mid)
    .onClick(() => {
    })
  }

}
