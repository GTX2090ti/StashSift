/**
 * StashSift — 标签列表（ArkTS 原生）
 *
 * v1.0.7：顶栏下方加「新建标签」入口（createTag），成功后刷新列表并提示。
 */
import { router, promptAction } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Tag, TagDto } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'
import { SortBar } from '../components/SortBar'
import { SortOption, TAG_SORTS, buildSortMenu } from '../common/Sorts'
import { RADIUS_CHIP, PAD_PAGE, GAP_S } from '../common/Responsive'
import { bumpScenes, scenesVersion } from '../common/DataVersion'
import { PickItem, PickCache } from '../common/OptionCache'

@Entry
@Component
struct TagsPage {
  @State items: Tag[] = []
  @State sortIndex: number = 0
  @State sortDir: string = ''
  @State searchMode: boolean = false
  @State keyword: string = ''
  @State loading: boolean = false
  @State hasMore: boolean = true
  @State toast: string = ''
  // ── 新建标签面板 ──
  @State newMode: boolean = false
  @State newName: string = ''
  @State newBusy: boolean = false
  private page: number = 1
  /** 上次看到的短片数据版本号，用于从详情页返回时判断是否需要刷新 */
  private lastVersion: number = 0
  /** 加载中被要求刷新时先记账，等本次加载结束再补一次 */
  private pendingReload: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.lastVersion = scenesVersion()
    this.load()
  }

  private reloadWithSort(): void {
    if (this.loading) {
      this.pendingReload = true
      return
    }
    this.items = []
    this.page = 1
    this.hasMore = true
    this.load()
  }

  private async load(): Promise<void> {
    if (this.loading || !this.hasMore) {
      return
    }
    this.loading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const so: SortOption = TAG_SORTS[this.sortIndex]
      const dir: string = this.sortDir.length > 0 ? this.sortDir : so.dir
      const raw: TagDto[] = await api.findTags(this.page, 120, so.sort, dir, this.keyword.trim())
      const list: Tag[] = []
      for (let i = 0; i < raw.length; i++) {
        list.push(Tag.fromDto(raw[i]))
      }
      const merged: Tag[] = this.items.slice()
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i])
      }
      this.items = merged
      this.hasMore = list.length === 120
      this.page = this.page + 1
    } catch (e) {
      console.error('[TagsPage] ' + (e as Error).message)
    }
    this.loading = false
    if (this.pendingReload) {
      this.pendingReload = false
      this.reloadWithSort()
    }
  }

  /** 统一提示：系统 Toast + 记录到状态 */
  private say(msg: string): void {
    this.toast = msg
    try {
      promptAction.showToast({ message: msg, duration: 2000 })
    } catch (e) {
      // Toast 不可用时仅记录状态
    }
  }

  /* ---------------- 新建标签 ---------------- */

  private canCreate(): boolean {
    return this.newName.trim().length > 0
  }

  private toggleNew(): void {
    this.newMode = !this.newMode
    this.newName = ''
  }

  private async createTagNow(): Promise<void> {
    if (this.newBusy) {
      return
    }
    const nm: string = this.newName.trim()
    if (nm.length === 0) {
      this.say('请输入标签名称')
      return
    }
    this.newBusy = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const id: string = await api.createTag(nm)
      if (id.length > 0) {
        // 让详情页的「父标签 / 标签」选择器缓存也能看到新标签。
        // 注意：缓存为空时不能追加，否则 loadOptions 会把这条当成「已缓存的全量」，
        // 之后所有选择器都只剩这一个候选；留空让它下次重新拉取即可。
        if (PickCache.tags.length > 0) {
          PickCache.tags = PickCache.tags.concat([new PickItem(id, nm)])
        }
        this.newMode = false
        this.newName = ''
        this.say('已新建标签：' + nm)
        bumpScenes()
        this.lastVersion = scenesVersion()
        this.reloadWithSort()
      } else {
        this.say('新建失败：服务端未返回 id')
      }
    } catch (e) {
      // 服务端原因（如同名标签已存在）原样透出
      this.say('新建失败：' + (e as Error).message)
    }
    this.newBusy = false
  }

  @Builder
  newPanel() {
    Column() {
      Row() {
        Text('新建标签').fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.brandColor).layoutWeight(1)
        Text('关闭')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .onClick(() => {
            this.newMode = false
            this.newName = ''
          })
      }
      .width('100%')

      Row() {
        TextInput({ text: this.newName, placeholder: '标签名称' })
          .fontSize(12).fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textSecondary)
          .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CHIP)
          .height(36).layoutWeight(1)
          .onChange((v: string) => {
            this.newName = v
          })
          .onSubmit(() => {
            this.createTagNow()
          })
        Text(this.newBusy ? '创建中…' : '创建')
          .fontSize(11)
          .fontColor(this.canCreate() ? Color.White : this.theme.textSecondary)
          .backgroundColor(this.canCreate() ? this.theme.brandColor : this.theme.cardBg)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.createTagNow()
          })
      }
      .width('100%').margin({ top: GAP_S })

      if (!this.canCreate()) {
        Text('名称为空，先输入再创建').fontSize(10)
          .fontColor(this.theme.textSecondary)
          .width('100%').margin({ top: 4 })
      }
    }
    .width('100%').padding(GAP_S + 2)
    .backgroundColor(this.theme.chipBg)
    .borderRadius(RADIUS_CHIP)
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  /** 系统深浅色变化时即时跟随 */
  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }
  /** 返回本页时刷新主题（设置页切换外观后立即生效），并补刷被编辑/合并过的标签 */
  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
    const v: number = scenesVersion()
    if (v !== this.lastVersion) {
      this.lastVersion = v
      // 标签被编辑/合并后返回：静默替换，不清空，列表才不会回顶
      this.softRefresh()
    }
  }

  /** 只重拉已加载的页并原地替换，保住滚动位置 */
  private async softRefresh(): Promise<void> {
    if (this.loading) {
      this.pendingReload = true
      return
    }
    this.loading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const so: SortOption = TAG_SORTS[this.sortIndex]
      const dir: string = this.sortDir.length > 0 ? this.sortDir : so.dir
      const pages: number = this.page > 1 ? this.page - 1 : 1
      const out: Tag[] = []
      let fetched: number = 1
      let full: boolean = true
      for (let p = 1; p <= pages; p++) {
        const raw: TagDto[] = await api.findTags(p, 120, so.sort, dir, this.keyword.trim())
        for (let i = 0; i < raw.length; i++) {
          out.push(Tag.fromDto(raw[i]))
        }
        fetched = p
        full = raw.length === 120
        if (!full) {
          break
        }
      }
      this.items = out
      this.hasMore = full
      this.page = fetched + 1
    } catch (e) {
      console.error('[TagsPage] softRefresh ' + (e as Error).message)
    }
    this.loading = false
    if (this.pendingReload) {
      this.pendingReload = false
      this.reloadWithSort()
    }
  }
  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('标签'),
        subtitle: '共 ' + this.items.length + ' 个',
        theme: this.theme,
        style: GlassStyle.REGULAR,
        showSearch: true,
        searchActive: this.searchMode,
        onSearchTap: () => {
          this.searchMode = !this.searchMode
          if (!this.searchMode) {
            this.keyword = ''
            this.reloadWithSort()
          }
        }
      })

      Row() {
        if (this.searchMode) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(15)
            .fontColor([this.theme.textSecondary])
            .margin({ right: 6 })
          TextInput({ text: this.keyword, placeholder: '搜索标签名' })
            .layoutWeight(1)
            .fontSize(13)
            .height(30)
            .backgroundColor(Color.Transparent)
            .placeholderColor(this.theme.textSecondary)
            .fontColor(this.theme.textPrimary)
            .onChange((v: string) => {
              this.keyword = v
            })
            .onSubmit(() => {
              this.reloadWithSort()
            })
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(14)
            .fontColor([this.theme.textSecondary])
            .padding(6)
            .onClick(() => {
              this.searchMode = false
              this.keyword = ''
              this.reloadWithSort()
            })
        } else {
          SortBar({
            options: TAG_SORTS,
            index: this.sortIndex,
            dirOverride: this.sortDir,
            theme: this.theme,
            onIndexChange: (idx: number) => {
              this.sortIndex = idx
              this.sortDir = ''
              this.reloadWithSort()
            },
            onDirChange: (d: string) => {
              this.sortDir = d
              this.reloadWithSort()
            }
          })
          Blank()
        }
        // 新建标签入口（文字按钮，避免用不确定的图标）
        Text(this.newMode ? '收起' : '新建')
          .fontSize(12)
          .fontColor(this.newMode ? this.theme.textSecondary : this.theme.brandColor)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.toggleNew()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 8, bottom: 2 })

      if (this.newMode) {
        Column() {
          this.newPanel()
        }
        .width('100%')
        .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6 })
      }

      List({ space: 8 }) {
        ForEach(this.items, (item: Tag) => {
          ListItem() {
            GlassCard({ style: GlassStyle.ULTRA_THIN, title: item.name, theme: this.theme }) {
              Row() {
                Text(item.scene_count.toString() + ' 部短片')
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
                  .layoutWeight(1)
                if (item.favorite) {
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(13)
                    .fontColor(['#FFFFB700'])
                    .margin({ right: 6 })
                }
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(10)
                  .fontColor([this.theme.textSecondary])
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
          }
          .onClick(() => {
            router.pushUrl({ url: 'pages/TagDetailPage', params: { 'id': item.id } })
          })
        }, (item: Tag) => item.id)

        if (this.loading) {
          ListItem() {
            Text(L10n.translate('加载中…'))
              .fontSize(14)
              .fontColor(this.theme.textSecondary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(16)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, top: 12 })
      .onReachEnd(() => {
        this.load()
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
