/**
 * StashSift — 收藏页（短片 / 演员 / 工作室）
 *
 * 短片页签与「短片」列表页保持同一套网格卡片样式。
 * 三个页签各有独立的排序字段与方向，互不影响。
 */
import { router } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Scene, SceneDto, PerformerDto, StudioDto } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassDock } from '../components/GlassDock'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'
import { scenesVersion } from '../common/DataVersion'
import { SortBar } from '../components/SortBar'
import { SortOption, SCENE_FAV_SORTS, PERFORMER_SORTS, STUDIO_SORTS } from '../common/Sorts'
import {
  layoutFor, columnsTemplate, RADIUS_XS, RADIUS_S, RADIUS_CHIP, RADIUS_CARD,
  PAD_PAGE, GAP_S, GAP_M
} from '../common/Responsive'

@Entry
@Component
struct FavoritesPage {
  @State tab: number = 0
  /** 下拉刷新中（Refresh 双向绑定） */
  @State refreshing: boolean = false
  @State scenes: Scene[] = []
  @State loading: boolean = false
  @State hasMore: boolean = true
  @State errorText: string = ''
  @State performers: PerformerDto[] = []
  @State perfLoading: boolean = false
  @State perfHasMore: boolean = true
  private perfPage: number = 1
  @State studios: StudioDto[] = []
  @State studioLoading: boolean = false
  private studioLoaded: boolean = false
  @State sortLabel: string = '收藏时间'
  @State sortIndex: number = 0
  private sortField: string = 'favorite_at'
  @State sortDir: string = 'DESC'
  /** 演员页签独立的排序（空字符串方向 = 跟随选项自带默认方向） */
  @State perfSortIndex: number = 0
  @State perfSortDir: string = ''
  /** 工作室页签独立的排序：默认「短片数 DESC」，即页签本来的「按作品数排行」 */
  @State studioSortIndex: number = 2
  @State studioSortDir: string = ''
  private page: number = 1
  @StorageProp('winWidthVp') winW: number = 365
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  private tabs: string[] = ['短片', '演员', '工作室']

  aboutToAppear(): void {
    this.reload()
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
    // 对齐旧版：每次回到收藏页都重新拉（在网页端或别的页面改过收藏，回来才能看到最新的）
    this.refreshTab(this.tab)
  }

  /** 重新拉某个页签的数据（切页签 / 回到本页 / 下拉刷新都走这里） */
  private refreshTab(idx: number): void {
    if (idx === 0) {
      this.reload()
    } else if (idx === 1) {
      this.reloadPerformers()
    } else {
      this.loadStudios()
    }
  }

  /** 下拉刷新当前页签 */
  private async pullRefresh(): Promise<void> {
    if (this.tab === 0) {
      await this.reload()
    } else if (this.tab === 1) {
      await this.reloadPerformers()
    } else {
      await this.loadStudios()
    }
    this.refreshing = false
  }

  /** 详情页改了收藏/标题后回到本页要跟着变 */
  @StorageProp('sceneVersion') @Watch('onScenesChanged') sceneVersion: number = 0

  onScenesChanged(): void {
    if (this.tab === 0) {
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

  private async load(): Promise<void> {
    if (this.loading || !this.hasMore) {
      return
    }
    this.loading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      // 对齐 SJP：收藏 = 打了 FAVORITE 标签的短片（不再是 organized）
      if (this.sortField === 'favorite_at') {
        // 服务端不能按 custom_fields 排序：一次拿全量，本地按收藏时间排
        const raw: SceneDto[] = await api.findAllFavoriteScenes()
        this.scenes = this.sortByFavoriteTime(Scene.listFromDto(raw), this.sortDir)
        this.hasMore = false
        this.page = 2
      } else {
        const raw: SceneDto[] = await api.findFavoriteScenes(
          this.page, 24, this.sortField, this.sortDir)
        const list: Scene[] = Scene.listFromDto(raw)
        const merged: Scene[] = this.scenes.slice()
        for (let i = 0; i < list.length; i++) {
          merged.push(list[i])
        }
        this.scenes = merged
        this.hasMore = list.length === 24
        this.page = this.page + 1
      }
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
    }
    this.loading = false
  }

  /** 收藏时间（毫秒）：优先 custom_fields.favorite_at，老收藏退回 updated_at */
  private favTime(s: Scene): number {
    const src: string = s.favoriteAt.length > 0 ? s.favoriteAt : s.updatedAt
    // 形如 2026-11-16T14:30:00+08:00，手写解析，避免依赖引擎的字符串日期解析
    if (src.length < 19) {
      return 0
    }
    const y: number = Number.parseInt(src.substring(0, 4))
    const mo: number = Number.parseInt(src.substring(5, 7))
    const d: number = Number.parseInt(src.substring(8, 10))
    const h: number = Number.parseInt(src.substring(11, 13))
    const mi: number = Number.parseInt(src.substring(14, 16))
    const se: number = Number.parseInt(src.substring(17, 19))
    let offMin: number = 0
    const tail: string = src.substring(19)
    if (tail.indexOf('Z') < 0 && tail.length >= 5) {
      const oh: number = Number.parseInt(tail.substring(1, 3))
      const om: number = Number.parseInt(tail.substring(4, 6))
      const sign: number = tail.substring(0, 1) === '-' ? -1 : 1
      offMin = sign * (oh * 60 + om)
    }
    return Date.UTC(y, mo - 1, d, h, mi, se) - offMin * 60000
  }

  private sortByFavoriteTime(list: Scene[], dir: string): Scene[] {
    const out: Scene[] = list.slice()
    out.sort((a: Scene, b: Scene): number => {
      const ta: number = this.favTime(a)
      const tb: number = this.favTime(b)
      if (ta === tb) {
        const ia: number = Number.parseInt(a.id)
        const ib: number = Number.parseInt(b.id)
        return dir === 'ASC' ? ia - ib : ib - ia
      }
      return dir === 'ASC' ? ta - tb : tb - ta
    })
    return out
  }

  /** 收藏的演员 */
  private async reloadPerformers(): Promise<void> {
    this.perfPage = 1
    this.perfHasMore = true
    this.performers = []
    await this.loadPerformers()
  }

  /** 演员页签当前排序项 */
  private perfSortOption(): SortOption {
    return PERFORMER_SORTS[this.perfSortIndex]
  }

  /** 演员页签当前生效方向（未手动切换过就跟随选项默认值） */
  private perfDir(): string {
    if (this.perfSortDir.length > 0) {
      return this.perfSortDir
    }
    return this.perfSortOption().dir
  }

  private async loadPerformers(): Promise<void> {
    if (this.perfLoading || !this.perfHasMore) {
      return
    }
    this.perfLoading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      // 服务端默认 name ASC：必须把当前排序项与方向显式传下去，否则看起来「没有排序」
      const list: PerformerDto[] = await api.findFavoritePerformers(
        this.perfPage, 30, this.perfSortOption().sort, this.perfDir())
      const merged: PerformerDto[] = this.performers.slice()
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i])
      }
      this.performers = merged
      this.perfHasMore = list.length === 30
      this.perfPage = this.perfPage + 1
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
    }
    this.perfLoading = false
  }
  /**
   * 收藏的工作室（studio_filter.favorite）。
   * 工作室数量有限，一次取 200 条；排序交给服务端，按当前选项传 sort/dir
   * （默认「短片数 DESC」，即按作品数排行）。
   */
  private studioSortOption(): SortOption {
    return STUDIO_SORTS[this.studioSortIndex]
  }

  private studioDir(): string {
    if (this.studioSortDir.length > 0) {
      return this.studioSortDir
    }
    return this.studioSortOption().dir
  }

  private async loadStudios(): Promise<void> {
    if (this.studioLoading) {
      return
    }
    this.studioLoading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      this.studios = await api.findFavoriteStudios(
        1, 200, this.studioSortOption().sort, this.studioDir())
      this.studioLoaded = true
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
    }
    this.studioLoading = false
  }
  /** 按当前排序项与方向重载 */
  private applySort(): void {
    const so: SortOption = SCENE_FAV_SORTS[this.sortIndex]
    this.sortField = so.sort
    if (this.sortDir.length === 0) {
      this.sortDir = so.dir
    }
    this.sortLabel = so.label
    this.reload()
  }

  private setSort(field: string, dir: string, label: string): void {
    this.sortField = field
    this.sortDir = dir
    this.sortLabel = label
    this.reload()
  }

  /** 演员页签换排序字段：清掉方向覆盖回到选项默认，再从第一页重拉 */
  private applyPerfSort(idx: number): void {
    this.perfSortIndex = idx
    this.perfSortDir = ''
    this.reloadPerformers()
  }

  /** 演员页签切方向 */
  private setPerfDir(d: string): void {
    this.perfSortDir = d
    this.reloadPerformers()
  }

  /** 工作室页签换排序字段 */
  private applyStudioSort(idx: number): void {
    this.studioSortIndex = idx
    this.studioSortDir = ''
    this.loadStudios()
  }

  /** 工作室页签切方向 */
  private setStudioDir(d: string): void {
    this.studioSortDir = d
    this.loadStudios()
  }

  /* ---------------- 卡片辅助 ---------------- */

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
  badge(txt: string, color: string) {
    Text(txt)
      .fontSize(10)
      .fontColor(Color.White)
      .backgroundColor(color)
      .borderRadius(RADIUS_XS)
      .padding({ left: 5, right: 5, top: 2, bottom: 2 })
  }

  @Builder
  sceneCard(s: Scene) {
    Column() {
      // 封面（16:9）
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          AuthImage({ rawPath: s.poster })
        }
        .width('100%')
        .aspectRatio(16 / 9)
        .clip(true)

        Column() {
          if (this.resText(this.heightOf(s)).length > 0) {
            this.badge(this.resText(this.heightOf(s)), '#FF0A59F7')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 6, top: 6 })

        if (true) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(14)
            .fontColor(['#FFFFB700'])
            .backgroundColor('#80000000')
            .borderRadius(RADIUS_S)
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .position({ right: 6, top: 6 })
        }

        if (this.durText(s.duration).length > 0) {
          Text(this.durText(s.duration))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(RADIUS_XS)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .position({ right: 6, bottom: 6 })
        }

        if (s.hasCaption) {
          Text('字幕')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(RADIUS_XS)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .position({ left: 6, bottom: 6 })
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
      router.pushUrl({ url: 'pages/SceneDetailPage', params: { 'id': s.id } })
    })
  }

  @Builder
  performerCard(p: PerformerDto) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          AuthImage({ rawPath: p.image_path === undefined ? '' : p.image_path })
        }
        .width('100%')
        .aspectRatio(1)
        .clip(true)

        if (p.favorite === true) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(14)
            .fontColor(['#FFFFB700'])
            .backgroundColor('#80000000')
            .borderRadius(RADIUS_S)
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .margin({ right: 6, top: 6 })
        }
      }
      .width('100%')

      Column() {
        Text(p.name === undefined ? '（未命名）' : p.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row() {
          Text('作品 ' + (p.scene_count === undefined ? 0 : p.scene_count).toString())
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
            .layoutWeight(1)
          if (p.rating100 !== undefined && p.rating100 > 0) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(10)
              .fontColor(['#FFFFB700'])
            Text((p.rating100 / 20).toFixed(1))
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .margin({ left: 1 })
          }
        }
        .width('100%')
        .height(16)
        .margin({ top: 2 })
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
      if (p.id !== undefined) {
        router.pushUrl({ url: 'pages/PerformerDetailPage', params: { 'id': p.id } })
      }
    })
  }

  @Builder
  studioCard(s: StudioDto) {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          AuthImage({ rawPath: s.image_path === undefined ? '' : s.image_path })
        }
        .width('100%')
        .aspectRatio(16 / 9)
        .clip(true)

        Text((s.scene_count === undefined ? 0 : s.scene_count).toString() + ' 部')
          .fontSize(10)
          .fontColor(Color.White)
          .backgroundColor('#9E000000')
          .borderRadius(RADIUS_XS)
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .position({ right: 6, bottom: 6 })
      }
      .width('100%')

      Column() {
        Text(s.name === undefined || s.name.length === 0 ? '（未命名）' : s.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(17)
          .height(34)
          .width('100%')
        Row() {
          Text((s.scene_count === undefined ? 0 : s.scene_count).toString() + ' 部作品')
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
            .layoutWeight(1)
          if (s.rating100 !== undefined && s.rating100 > 0) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(10)
              .fontColor(['#FFFFB700'])
            Text((s.rating100 / 20).toFixed(1))
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .margin({ left: 1 })
          }
        }
        .width('100%')
        .height(16)
        .margin({ top: 2 })
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
      if (s.id !== undefined) {
        router.pushUrl({ url: 'pages/StudioDetailPage', params: { 'id': s.id } })
      }
    })
  }
  @Builder
  tabChip(idx: number, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.tab === idx ? Color.White : this.theme.textSecondary)
      .backgroundColor(this.tab === idx ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: GAP_M, right: GAP_M, top: 7, bottom: 7 })
      .onClick(() => {
        this.tab = idx
        // 对齐旧版：每次切页签都重新拉，别用第一次的缓存
        this.refreshTab(idx)
      })
  }

  @Builder
  sortMenu() {
    Menu() {
      MenuItem({ content: '最新添加' }).onClick(() => {
        this.setSort('date', 'DESC', '最新')
      })
      MenuItem({ content: '最早添加' }).onClick(() => {
        this.setSort('date', 'ASC', '最早')
      })
      MenuItem({ content: '评分最高' }).onClick(() => {
        this.setSort('rating', 'DESC', '评分')
      })
      MenuItem({ content: '标题' }).onClick(() => {
        this.setSort('title', 'ASC', '标题')
      })
      MenuItem({ content: '时长' }).onClick(() => {
        this.setSort('duration', 'DESC', '时长')
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
    Column() {
      GlassNavBar({
        title: L10n.translate('收藏'),
        subtitle: this.tab === 0 ? ('共 ' + this.scenes.length.toString() + ' 部') : '',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      // 页签 + 排序
      Row() {
        this.tabChip(0, L10n.translate('短片'))
        Blank().width(8)
        this.tabChip(1, L10n.translate('演员'))
        Blank().width(8)
        this.tabChip(2, L10n.translate('工作室'))
        Blank()
        if (this.tab === 0) {
          SortBar({
            options: SCENE_FAV_SORTS,
            index: this.sortIndex,
            dirOverride: this.sortDir,
            theme: this.theme,
            onIndexChange: (idx: number) => {
              this.sortIndex = idx
              this.sortDir = ''
              this.applySort()
            },
            onDirChange: (d: string) => {
              this.sortDir = d
              this.applySort()
            }
          })
        } else if (this.tab === 1) {
          SortBar({
            options: PERFORMER_SORTS,
            index: this.perfSortIndex,
            dirOverride: this.perfSortDir,
            theme: this.theme,
            onIndexChange: (idx: number) => {
              this.applyPerfSort(idx)
            },
            onDirChange: (d: string) => {
              this.setPerfDir(d)
            }
          })
        } else {
          SortBar({
            options: STUDIO_SORTS,
            index: this.studioSortIndex,
            dirOverride: this.studioSortDir,
            theme: this.theme,
            onIndexChange: (idx: number) => {
              this.applyStudioSort(idx)
            },
            onDirChange: (d: string) => {
              this.setStudioDir(d)
            }
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 10, bottom: 6 })

      if (this.tab === 0) {
        if (!this.loading && this.scenes.length === 0) {
          Column() {
            SymbolGlyph($r('sys.symbol.star'))
              .fontSize(34)
              .fontColor([this.theme.textSecondary])
            Text(this.errorText.length > 0 ? this.errorText : '还没有收藏的短片')
              .fontSize(13)
              .fontColor(this.errorText.length > 0 ? '#FFE84026' : this.theme.textSecondary)
              .margin({ top: GAP_M })
            Button('刷新')
              .height(34)
              .fontSize(13)
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
          Refresh({ refreshing: $$this.refreshing, promptText: '下拉刷新收藏' }) {
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
                  Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
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
            bottom: 96
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
      } else if (this.tab === 1) {
        // 收藏的演员
        if (!this.perfLoading && this.performers.length === 0) {
          Column() {
            SymbolGlyph($r('sys.symbol.person'))
              .fontSize(34)
              .fontColor([this.theme.textSecondary])
            Text('还没有收藏的演员')
              .fontSize(13)
              .fontColor(this.theme.textSecondary)
              .margin({ top: GAP_M })
            Text('在演员详情页点右上角星标即可收藏')
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .margin({ top: GAP_S })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Grid() {
            ForEach(this.performers, (p: PerformerDto) => {
              GridItem() {
                this.performerCard(p)
              }
            }, (p: PerformerDto) => p.id === undefined ? '' : p.id)

            if (this.perfLoading || this.perfHasMore) {
              GridItem() {
                Row() {
                  LoadingProgress().width(22).height(22)
                  Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
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
          .layoutWeight(1)
          .padding({
            left: layoutFor(this.winW).pagePadding,
            right: layoutFor(this.winW).pagePadding,
            top: 6,
            bottom: 96
          })
          .onReachEnd(() => {
            this.loadPerformers()
          })
        }
      } else {
        // 工作室（按作品数排行）
        if (!this.studioLoading && this.studios.length === 0) {
          Column() {
            SymbolGlyph($r('sys.symbol.house'))
              .fontSize(34)
              .fontColor([this.theme.textSecondary])
            Text('还没有工作室数据')
              .fontSize(13)
              .fontColor(this.theme.textSecondary)
              .margin({ top: GAP_M })
            Button('刷新')
              .height(34)
              .fontSize(13)
              .backgroundColor(this.theme.brandColor)
              .fontColor(Color.White)
              .borderRadius(RADIUS_CHIP)
              .margin({ top: 12 })
              .onClick(() => {
                this.loadStudios()
              })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Grid() {
            ForEach(this.studios, (s: StudioDto) => {
              GridItem() {
                this.studioCard(s)
              }
            }, (s: StudioDto) => s.id === undefined ? '' : s.id)

            if (this.studioLoading) {
              GridItem() {
                Row() {
                  LoadingProgress().width(22).height(22)
                  Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
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
          .layoutWeight(1)
          .padding({
            left: layoutFor(this.winW).pagePadding,
            right: layoutFor(this.winW).pagePadding,
            top: 6,
            bottom: 96
          })
        }
      }

    }
    .width('100%').height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      GlassDock({ current: 2, isRoot: false, theme: this.theme })
    }
  }
}