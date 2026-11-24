/**
 * StashSift — 短片筛选面板
 */
import { router } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { PerformerDto, StudioDto, TagDto } from '../models/Models'
import { SceneFilterState, daysAgoDate } from '../models/SceneFilter'
import { GlassNavBar } from '../components/GlassNavBar'
import {
  GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop,
  currentGlassTheme, currentBackdrop
} from '../common/GlassUtils'
import { L10n } from '../settings/L10n'
import { PickItem, loadOptions } from '../common/OptionCache'
import { FilterChip } from '../components/FilterChip'
import { PAD_PAGE, RADIUS_CHIP, RADIUS_CARD, GAP_M, GAP_S, GAP_XS } from '../common/Responsive'

class NamedItem {
  id: string = ''
  name: string = ''

  constructor(id: string, name: string) {
    this.id = id
    this.name = name
  }
}

/** 单个分区最多渲染多少个 chip（标签库上千，全渲染会卡） */
const CHIP_LIMIT: number = 120

@Entry
@Component
struct SceneFilterPage {
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  // 工作副本
  @State rating: number = 0
  @State durMin: number = 0
  @State durMax: number = 0
  @State res: string = ''
  @State organized: number = -1
  @State dateAfter: string = ''
  @State dateBefore: string = ''

  @State studioIds: string[] = []
  @State performerIds: string[] = []
  @State tagIds: string[] = []

  @State studios: NamedItem[] = []
  @State performers: NamedItem[] = []
  @State tags: NamedItem[] = []
  @State keyword: string = ''
  /** 关键字走服务端搜索时的加载态（本地候选只有 500 条，标签库更大） */
  @State kwSearching: boolean = false
  @State loadingRefs: boolean = true
  @State openStudio: boolean = false
  @State openPerformer: boolean = false
  @State openTag: boolean = false
  @StorageProp('navInset') navInset: number = 0

  aboutToAppear(): void {
    const s: SceneFilterState = SceneFilterState.instance
    this.rating = s.rating100
    this.durMin = s.durationMin
    this.durMax = s.durationMax
    this.res = s.resolution
    this.organized = s.organized
    this.dateAfter = s.dateAfter
    this.dateBefore = s.dateBefore
    this.studioIds = s.studioIds.slice()
    this.performerIds = s.performerIds.slice()
    this.tagIds = s.tagIds.slice()
    this.loadRefs()
  }

  private async loadRefs(): Promise<void> {
    this.loadingRefs = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const stOpts: PickItem[] = await loadOptions(api, 'studio')
      const pfOpts: PickItem[] = await loadOptions(api, 'performer')
      const tgOpts: PickItem[] = await loadOptions(api, 'tag')
      const st: PickItem[] = stOpts
      const pf: PickItem[] = pfOpts
      const tg: PickItem[] = tgOpts

      const stl: NamedItem[] = []
      for (let i = 0; i < st.length; i++) {
        const id: string | undefined = st[i].id
        const nm: string | undefined = st[i].name
        if (id !== undefined && nm !== undefined) {
          stl.push(new NamedItem(id, nm))
        }
      }
      const pfl: NamedItem[] = []
      for (let i = 0; i < pf.length; i++) {
        const id: string | undefined = pf[i].id
        const nm: string | undefined = pf[i].name
        if (id !== undefined && nm !== undefined) {
          pfl.push(new NamedItem(id, nm))
        }
      }
      const tgl: NamedItem[] = []
      for (let i = 0; i < tg.length; i++) {
        const id: string | undefined = tg[i].id
        const nm: string | undefined = tg[i].name
        if (id !== undefined && nm !== undefined) {
          tgl.push(new NamedItem(id, nm))
        }
      }
      this.studios = stl
      this.performers = pfl
      this.tags = tgl
    } catch (e) {
      console.error('[SceneFilterPage] loadRefs failed: ' + (e as Error).message)
    }
    this.loadingRefs = false
  }

  /**
   * 分区标题：显示「有多少个可选」+「已选几个」。
   * 之前只显示已选数量，初始是 0，看起来像「没有工作室可选」。
   */
  private sectionLabel(title: string, total: number, selected: number): string {
    // 本地候选是 500 条上限，命中上限时标成 500+，提示还有更多（用关键字搜索可达）
    const totalText: string = total >= 500 ? '500+' : total.toString()
    if (selected > 0) {
      return title + ' (' + totalText + ' · 已选 ' + selected.toString() + ')'
    }
    return title + ' (' + totalText + ')'
  }

  /** 当前工作副本里生效的条件数（含评分/时长/分辨率/日期/整理状态与三类关联） */
  private workingCount(): number {
    let n: number = 0
    if (this.organized !== -1) {
      n = n + 1
    }
    if (this.rating > 0) {
      n = n + 1
    }
    if (this.durMin > 0 || this.durMax > 0) {
      n = n + 1
    }
    if (this.res.length > 0) {
      n = n + 1
    }
    if (this.dateAfter.length > 0 || this.dateBefore.length > 0) {
      n = n + 1
    }
    if (this.studioIds.length > 0) {
      n = n + 1
    }
    if (this.performerIds.length > 0) {
      n = n + 1
    }
    if (this.tagIds.length > 0) {
      n = n + 1
    }
    return n
  }

  private listFor(mode: string): NamedItem[] {
    if (mode === 'studio') {
      return this.studios
    }
    if (mode === 'performer') {
      return this.performers
    }
    return this.tags
  }

  private selectedFor(mode: string): string[] {
    if (mode === 'studio') {
      return this.studioIds
    }
    if (mode === 'performer') {
      return this.performerIds
    }
    return this.tagIds
  }

  private toggleFor(mode: string, id: string): void {
    if (mode === 'studio') {
      this.studioIds = this.toggle(this.studioIds, id)
    } else if (mode === 'performer') {
      this.performerIds = this.toggle(this.performerIds, id)
    } else {
      this.tagIds = this.toggle(this.tagIds, id)
    }
  }

  private inList(arr: string[], id: string): boolean {    for (let i = 0; i < arr.length; i++) {
      if (arr[i] === id) {
        return true
      }
    }
    return false
  }

  private toggle(arr: string[], id: string): string[] {
    const out: string[] = []
    let found: boolean = false
    for (let i = 0; i < arr.length; i++) {
      if (arr[i] === id) {
        found = true
      } else {
        out.push(arr[i])
      }
    }
    if (!found) {
      out.push(id)
    }
    return out
  }

  /** 实际渲染的 chip：先按关键字过滤，未输入关键字时最多取 CHIP_LIMIT 个 */
  private chipsOf(list: NamedItem[]): NamedItem[] {
    const shown: NamedItem[] = this.visible(list)
    if (this.keyword.trim().length > 0) {
      return shown
    }
    if (shown.length <= CHIP_LIMIT) {
      return shown
    }
    return shown.slice(0, CHIP_LIMIT)
  }

  /**
   * 关键字搜索：本地候选（OptionCache 只取 500 条）不够覆盖上千个标签，
   * 输入关键字时改走服务端 q 搜索，命中名称之外的也能找到。
   */
  private async searchRemote(): Promise<void> {
    const kw: string = this.keyword.trim()
    if (kw.length === 0) {
      // 清空关键字：回到本地候选
      await this.loadRefs()
      return
    }
    this.kwSearching = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const st: StudioDto[] = await api.findStudios(1, 200, 'name', 'ASC', kw)
      const pf: PerformerDto[] = await api.findPerformersEx(1, 200, kw, 'name', 'ASC')
      const tg: TagDto[] = await api.findTags(1, 200, 'name', 'ASC', kw)
      this.studios = this.toNamedStudios(st)
      this.performers = this.toNamedPerformers(pf)
      this.tags = this.toNamedTags(tg)
    } catch (e) {
      console.error('[SceneFilterPage] searchRemote failed: ' + (e as Error).message)
    }
    this.kwSearching = false
  }

  private toNamedStudios(arr: StudioDto[]): NamedItem[] {
    const out: NamedItem[] = []
    for (let i = 0; i < arr.length; i++) {
      const d: StudioDto = arr[i]
      const id: string = d.id === undefined || d.id === null ? '' : d.id
      const nm: string = d.name === undefined || d.name === null ? '' : d.name
      if (id.length > 0) {
        out.push(new NamedItem(id, nm))
      }
    }
    return out
  }

  private toNamedPerformers(arr: PerformerDto[]): NamedItem[] {
    const out: NamedItem[] = []
    for (let i = 0; i < arr.length; i++) {
      const d: PerformerDto = arr[i]
      const id: string = d.id === undefined || d.id === null ? '' : d.id
      const nm: string = d.name === undefined || d.name === null ? '' : d.name
      if (id.length > 0) {
        out.push(new NamedItem(id, nm))
      }
    }
    return out
  }

  private toNamedTags(arr: TagDto[]): NamedItem[] {
    const out: NamedItem[] = []
    for (let i = 0; i < arr.length; i++) {
      const d: TagDto = arr[i]
      const id: string = d.id === undefined || d.id === null ? '' : d.id
      const nm: string = d.name === undefined || d.name === null ? '' : d.name
      if (id.length > 0) {
        out.push(new NamedItem(id, nm))
      }
    }
    return out
  }

  private visible(list: NamedItem[]): NamedItem[] {    const kw: string = this.keyword.trim().toLowerCase()
    if (kw.length === 0) {
      return list
    }
    const out: NamedItem[] = []
    for (let i = 0; i < list.length; i++) {
      if (list[i].name.toLowerCase().indexOf(kw) >= 0) {
        out.push(list[i])
      }
    }
    return out
  }

  private apply(): void {
    const s: SceneFilterState = SceneFilterState.instance
    s.rating100 = this.rating
    s.durationMin = this.durMin
    s.durationMax = this.durMax
    s.resolution = this.res
    s.organized = this.organized
    s.dateAfter = this.dateAfter
    s.dateBefore = this.dateBefore
    s.studioIds = this.studioIds.slice()
    s.performerIds = this.performerIds.slice()
    s.tagIds = this.tagIds.slice()
    // 通知列表页刷新
    const v: number = AppStorage.get<number>('filterVersion') ?? 0
    AppStorage.setOrCreate('filterVersion', v + 1)
    router.back()
  }

  private reset(): void {
    this.rating = 0
    this.durMin = 0
    this.durMax = 0
    this.res = ''
    this.organized = -1
    this.dateAfter = ''
    this.dateBefore = ''
    this.studioIds = []
    this.performerIds = []
    this.tagIds = []
  }


  @Builder
  sectionTitle(t: string) {
    Text(t)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme.textPrimary)
      .width('100%')
      .margin({ top: 16, bottom: 8 })
  }

  @Builder
  nameChipsFor(mode: string) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.chipsOf(this.listFor(mode)), (it: NamedItem) => {
        FilterChip({
          label: it.name,
          active: this.inList(this.selectedFor(mode), it.id),
          theme: this.theme,
          onTap: () => {
            this.toggleFor(mode, it.id)
          }
        })
      }, (it: NamedItem) => it.id)
    }
    .width('100%')

    if (this.keyword.trim().length === 0 && this.listFor(mode).length > CHIP_LIMIT) {
      Text('已显示前 ' + CHIP_LIMIT.toString() + ' 个，共 ' + this.listFor(mode).length.toString() +
        ' 个；上面输入关键字可缩小范围')
        .fontSize(11)
        .fontColor(this.theme.textSecondary)
        .width('100%')
        .margin({ top: GAP_S })
    }
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  /** 系统深浅色变化时即时跟随 */
  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }
  /** 返回本页时刷新主题（设置页切换外观后立即生效） */
  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        GlassNavBar({
        title: L10n.translate('筛选'),
        subtitle: '已选 ' + this.workingCount().toString() + ' 项条件',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          // 已整理
          this.sectionTitle('整理状态')
          Flex({ wrap: FlexWrap.Wrap }) {
            FilterChip({ label: '不限', active: this.organized === -1, theme: this.theme, onTap: () => {
              this.organized = -1
            } })
            FilterChip({ label: '已整理', active: this.organized === 1, theme: this.theme, onTap: () => {
              this.organized = 1
            } })
            FilterChip({ label: '未整理', active: this.organized === 0, theme: this.theme, onTap: () => {
              this.organized = 0
            } })
          }
          .width('100%')

          // 评分
          this.sectionTitle('评分')
          Flex({ wrap: FlexWrap.Wrap }) {
            FilterChip({ label: '不限', active: this.rating === 0, theme: this.theme, onTap: () => {
              this.rating = 0
            } })
            FilterChip({ label: '≥ 2.0', active: this.rating === 40, theme: this.theme, onTap: () => {
              this.rating = 40
            } })
            FilterChip({ label: '≥ 3.0', active: this.rating === 60, theme: this.theme, onTap: () => {
              this.rating = 60
            } })
            FilterChip({ label: '≥ 4.0', active: this.rating === 80, theme: this.theme, onTap: () => {
              this.rating = 80
            } })
            FilterChip({ label: '≥ 4.5', active: this.rating === 90, theme: this.theme, onTap: () => {
              this.rating = 90
            } })
            FilterChip({ label: '5.0', active: this.rating === 100, theme: this.theme, onTap: () => {
              this.rating = 100
            } })
          }
          .width('100%')

          // 时长
          this.sectionTitle('时长')
          Flex({ wrap: FlexWrap.Wrap }) {
            FilterChip({ label: '不限', active: this.durMin === 0 && this.durMax === 0, theme: this.theme, onTap: () => {
              this.durMin = 0
              this.durMax = 0
            } })
            FilterChip({ label: '< 10 分钟', active: this.durMin === 0 && this.durMax === 600, theme: this.theme, onTap: () => {
              this.durMin = 0
              this.durMax = 600
            } })
            FilterChip({ label: '10 - 30 分钟', active: this.durMin === 600 && this.durMax === 1800, theme: this.theme, onTap: () => {
              this.durMin = 600
              this.durMax = 1800
            } })
            FilterChip({ label: '30 - 60 分钟', active: this.durMin === 1800 && this.durMax === 3600, theme: this.theme, onTap: () => {
              this.durMin = 1800
              this.durMax = 3600
            } })
            FilterChip({ label: '> 60 分钟', active: this.durMin === 3600 && this.durMax === 0, theme: this.theme, onTap: () => {
              this.durMin = 3600
              this.durMax = 0
            } })
          }
          .width('100%')

          // 分辨率
          this.sectionTitle('分辨率')
          Flex({ wrap: FlexWrap.Wrap }) {
            FilterChip({ label: '不限', active: this.res === '', theme: this.theme, onTap: () => {
              this.res = ''
            } })
            FilterChip({ label: '720P', active: this.res === 'STANDARD_HD', theme: this.theme, onTap: () => {
              this.res = 'STANDARD_HD'
            } })
            FilterChip({ label: '1080P', active: this.res === 'FULL_HD', theme: this.theme, onTap: () => {
              this.res = 'FULL_HD'
            } })
            FilterChip({ label: '4K', active: this.res === 'FOUR_K', theme: this.theme, onTap: () => {
              this.res = 'FOUR_K'
            } })
          }
          .width('100%')

          // 日期
          this.sectionTitle('加入日期')
          Flex({ wrap: FlexWrap.Wrap }) {
            FilterChip({ label: '不限', active: this.dateAfter === '' && this.dateBefore === '', theme: this.theme, onTap: () => {
              this.dateAfter = ''
              this.dateBefore = ''
            } })
            FilterChip({ label: '近 7 天', active: this.dateAfter === daysAgoDate(7) && this.dateBefore === '', theme: this.theme, onTap: () => {
              this.dateAfter = daysAgoDate(7)
              this.dateBefore = ''
            } })
            FilterChip({ label: '近 30 天', active: this.dateAfter === daysAgoDate(30) && this.dateBefore === '', theme: this.theme, onTap: () => {
              this.dateAfter = daysAgoDate(30)
              this.dateBefore = ''
            } })
            FilterChip({ label: '近 1 年', active: this.dateAfter === daysAgoDate(365) && this.dateBefore === '', theme: this.theme, onTap: () => {
              this.dateAfter = daysAgoDate(365)
              this.dateBefore = ''
            } })
          }
          .width('100%')

          // 关键字（本地候选只有 500 条，点「搜索」走服务端，能覆盖上千个标签）
          this.sectionTitle('按名称查找')
          Row() {
            TextInput({ text: this.keyword, placeholder: '输入工作室 / 演员 / 标签名称' })
              .fontSize(13)
              .fontColor(this.theme.textPrimary)
              .placeholderColor(this.theme.textSecondary)
              .backgroundColor(this.theme.chipBg)
              .borderRadius(RADIUS_CHIP)
              .height(40)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.keyword = v
              })
              .onSubmit(() => {
                this.searchRemote()
              })
            Text('搜索')
              .fontSize(13)
              .fontColor(this.theme.brandColor)
              .backgroundColor(this.theme.chipBg)
              .borderRadius(RADIUS_CHIP)
              .height(40)
              .padding({ left: 14, right: 14 })
              .textAlign(TextAlign.Center)
              .margin({ left: GAP_S })
              .onClick(() => {
                this.searchRemote()
              })
            Text('清空')
              .fontSize(13)
              .fontColor(this.theme.textSecondary)
              .backgroundColor(this.theme.chipBg)
              .borderRadius(RADIUS_CHIP)
              .height(40)
              .padding({ left: 14, right: 14 })
              .textAlign(TextAlign.Center)
              .margin({ left: GAP_S })
              .onClick(() => {
                this.keyword = ''
                this.loadRefs()
              })
          }
          .width('100%')

          if (this.kwSearching) {
            Row() {
              LoadingProgress().width(16).height(16)
              Text('搜索中…').fontSize(11).fontColor(this.theme.textSecondary).margin({ left: 6 })
            }
            .width('100%')
            .margin({ top: 6 })
          }

          if (this.loadingRefs) {
            Row() {
              LoadingProgress().width(18).height(18)
              Text('加载选项…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 8 })
            }
            .width('100%')
            .margin({ top: 16 })
          } else {
            // 注意：这里必须「内联」写标题，不能用 @Builder 传字符串参数——
            // ArkUI 的 @Builder 按值传参不会订阅状态变化，标题里的计数会永远停在首屏渲染的值。
            Row() {
              Text(this.sectionLabel('工作室', this.studios.length, this.studioIds.length))
                .fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary).layoutWeight(1)
              Text(this.openStudio ? '收起' : '展开')
                .fontSize(12).fontColor(this.theme.textSecondary)
            }
            .width('100%').padding({ top: 12, bottom: 6 })
            .onClick(() => {
              this.openStudio = !this.openStudio
            })
            if (this.openStudio) {
              this.nameChipsFor('studio')
            }

            Row() {
              Text(this.sectionLabel('演员', this.performers.length, this.performerIds.length))
                .fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary).layoutWeight(1)
              Text(this.openPerformer ? '收起' : '展开')
                .fontSize(12).fontColor(this.theme.textSecondary)
            }
            .width('100%').padding({ top: 12, bottom: 6 })
            .onClick(() => {
              this.openPerformer = !this.openPerformer
            })
            if (this.openPerformer) {
              this.nameChipsFor('performer')
            }

            Row() {
              Text(this.sectionLabel('标签', this.tags.length, this.tagIds.length))
                .fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary).layoutWeight(1)
              Text(this.openTag ? '收起' : '展开')
                .fontSize(12).fontColor(this.theme.textSecondary)
            }
            .width('100%').padding({ top: 12, bottom: 6 })
            .onClick(() => {
              this.openTag = !this.openTag
            })
            if (this.openTag) {
              this.nameChipsFor('tag')
            }
          }
        }
        .width('100%')
        .padding({ left: PAD_PAGE, right: PAD_PAGE, bottom: 130 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 160,
        colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      this.bottomBar()
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }


  @Builder
  bottomBar() {
    Row() {
      // 内层胶囊：layoutWeight 撑满剩余宽度，避免 100% + margin 溢出
      Row() {
        Button('重置')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(this.theme.textPrimary)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(22)
          .onClick(() => {
            this.reset()
          })
        Blank().width(GAP_M)
        Button('应用筛选')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(this.theme.brandColor)
          .borderRadius(22)
          .onClick(() => {
            this.apply()
          })
      }
      .layoutWeight(1)
      .padding({ left: GAP_M, right: GAP_M, top: GAP_M, bottom: GAP_M })
      .backgroundColor(this.theme.dockBg)
      .borderRadius(RADIUS_CARD + 8)
      .backgroundEffect({ radius: 24, saturation: 1.35 })
      .shadow({ radius: 20, color: this.theme.cardShadow })
    }
    .width('100%')
    .padding({ left: PAD_PAGE, right: PAD_PAGE })
    .margin({ bottom: 16 + this.navInset })
  }
}