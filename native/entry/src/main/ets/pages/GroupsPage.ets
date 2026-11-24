/**
 * StashSift — 集合列表（ArkTS 原生）
 *
 * v1.0.7：改用 findGroupsRich 展示封面 / 短片数 / 日期 / 工作室，并支持新建集合。
 */
import { router, promptAction } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { GroupDto, StudioRefDto } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { bumpScenes } from '../common/DataVersion'
import { L10n } from '../settings/L10n'
import { SortBar } from '../components/SortBar'
import { SortOption, GROUP_SORTS } from '../common/Sorts'
import { RADIUS_CHIP, RADIUS_CARD, PAD_PAGE, GAP_M, GAP_S, GAP_XS } from '../common/Responsive'

@Entry
@Component
struct GroupsPage {
  @State items: GroupDto[] = []
  @State sortIndex: number = 0
  @State sortDir: string = ''
  @State searchMode: boolean = false
  @State keyword: string = ''
  @State loading: boolean = false
  @State hasMore: boolean = true
  /** 新建面板 */
  @State newMode: boolean = false
  @State newName: string = ''
  @State newBusy: boolean = false
  @State toast: string = ''
  private page: number = 1
  /** 加载中又要求重载时，等这次加载结束后再拉一次，避免列表卡在空态 */
  private reloadQueued: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.load()
  }

  private api(): StashApi {
    return new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
  }

  private reloadWithSort(): void {
    if (this.loading) {
      this.reloadQueued = true
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
      const so: SortOption = GROUP_SORTS[this.sortIndex]
      const dir: string = this.sortDir.length > 0 ? this.sortDir : so.dir
      const raw: GroupDto[] = await this.api().findGroupsRich(
        this.page, 120, so.sort, dir, this.keyword.trim())
      const merged: GroupDto[] = this.items.slice()
      for (let i = 0; i < raw.length; i++) {
        merged.push(raw[i])
      }
      this.items = merged
      this.hasMore = raw.length === 120
      this.page = this.page + 1
    } catch (e) {
      this.say('加载失败：' + (e as Error).message)
    }
    this.loading = false
    if (this.reloadQueued) {
      this.reloadQueued = false
      this.reloadWithSort()
    }
  }

  /* ---------------- 新建集合 ---------------- */

  private openNew(): void {
    this.newMode = true
    this.newName = ''
  }

  private async createNew(): Promise<void> {
    const nm: string = this.newName.trim()
    if (nm.length === 0) {
      this.say('请输入集合名称')
      return
    }
    if (this.newBusy) {
      return
    }
    this.newBusy = true
    try {
      await this.api().createGroup(nm)
      this.newMode = false
      this.newName = ''
      this.say('已新建集合：' + nm)
      bumpScenes()
      this.reloadWithSort()
    } catch (e) {
      this.say('新建失败：' + (e as Error).message)
    }
    this.newBusy = false
  }

  /* ---------------- 展示辅助 ---------------- */

  /** DTO 字符串字段可能是 null（GraphQL 可空），统一走这里 */
  private strOf(v: string | undefined): string {
    if (v === undefined || v === null) {
      return ''
    }
    return v
  }

  private nameOf(g: GroupDto): string {
    const n: string = this.strOf(g.name)
    return n.length === 0 ? '（未命名）' : n
  }

  private coverOf(g: GroupDto): string {
    const f: string = this.strOf(g.front_image_path)
    if (f.length > 0) {
      return f
    }
    return this.strOf(g.back_image_path)
  }

  /** 元信息行：短片数 · 日期 · 工作室 */
  private metaOf(g: GroupDto): string {
    const parts: string[] = []
    const c: number = g.scene_count === undefined || g.scene_count === null ? 0 : g.scene_count
    parts.push(c.toString() + ' 部短片')
    const d: string = this.strOf(g.date)
    if (d.length > 0) {
      parts.push(d)
    }
    const st: StudioRefDto | undefined = g.studio
    if (st !== undefined && st !== null) {
      const sn: string = this.strOf(st.name)
      if (sn.length > 0) {
        parts.push(sn)
      }
    }
    return parts.join(' · ')
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

  @Builder
  fieldLabel(t: string) {
    Text(t).fontSize(11).fontColor(this.theme.textSecondary)
      .width('100%').margin({ top: GAP_S })
  }

  /** 新建集合内嵌面板 */
  @Builder
  newPanel() {
    Column() {
      Text('新建集合').fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary).width('100%')

      this.fieldLabel('名称')
      TextInput({ text: this.newName, placeholder: '集合名称' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: GAP_XS })
        .onChange((v: string) => {
          this.newName = v
        })
        .onSubmit(() => {
          this.createNew()
        })

      Row() {
        Text('取消')
          .fontSize(12).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Center).layoutWeight(1)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ top: 9, bottom: 9 })
          .margin({ right: 4 })
          .onClick(() => {
            this.newMode = false
            this.newName = ''
          })
        Text(this.newBusy ? '创建中…' : '创建')
          .fontSize(12).fontColor(Color.White)
          .textAlign(TextAlign.Center).layoutWeight(1)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ top: 9, bottom: 9 })
          .margin({ left: 4 })
          .onClick(() => {
            this.createNew()
          })
      }
      .width('100%').margin({ top: GAP_M })
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.brandColor })
    .backgroundEffect({ radius: 24, saturation: 1.35 })
    .margin({ left: PAD_PAGE, right: PAD_PAGE, top: GAP_S })
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0
  /** 详情页保存 / 删除集合后回到本页时刷新列表 */
  @StorageProp('sceneVersion') @Watch('onDataChanged') sceneVersion: number = 0

  /** 系统深浅色变化时即时跟随 */
  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  onDataChanged(): void {
    // 集合详情改名/编辑后 bump 版本：静默替换，不清空，列表才不会回顶
    this.softRefresh()
  }

  /** 只重拉已加载的页并原地替换，保住滚动位置 */
  private async softRefresh(): Promise<void> {
    if (this.loading) {
      return
    }
    this.loading = true
    try {
      const so: SortOption = GROUP_SORTS[this.sortIndex]
      const dir: string = this.sortDir.length > 0 ? this.sortDir : so.dir
      const pages: number = this.page > 1 ? this.page - 1 : 1
      const out: GroupDto[] = []
      let fetched: number = 1
      let full: boolean = true
      for (let p = 1; p <= pages; p++) {
        const raw: GroupDto[] = await this.api().findGroupsRich(p, 120, so.sort, dir, this.keyword.trim())
        for (let i = 0; i < raw.length; i++) {
          out.push(raw[i])
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
      console.error('[GroupsPage] softRefresh ' + (e as Error).message)
    }
    this.loading = false
  }
  /** 返回本页时刷新主题（设置页切换外观后立即生效） */
  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('集合'),
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
          TextInput({ text: this.keyword, placeholder: '搜索集合名' })
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
            options: GROUP_SORTS,
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
        Text('＋ 新建')
          .fontSize(12)
          .fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.openNew()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 8, bottom: 2 })

      if (this.newMode) {
        this.newPanel()
      }

      List({ space: 8 }) {
        ForEach(this.items, (item: GroupDto, idx: number) => {
          ListItem() {
            GlassCard({ style: GlassStyle.ULTRA_THIN, theme: this.theme }) {
              Row() {
                Column() {
                  AuthImage({ rawPath: this.coverOf(item) })
                }
                .width(60).height(80).clip(true).borderRadius(RADIUS_CHIP)
                .backgroundColor(this.theme.chipBg)

                Column() {
                  Text(this.nameOf(item))
                    .fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(this.metaOf(item))
                    .fontSize(11).fontColor(this.theme.textSecondary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%').margin({ top: GAP_XS })
                  if (item.rating100 !== undefined && item.rating100 > 0) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.star_fill'))
                        .fontSize(11)
                        .fontColor([this.theme.brandColor])
                      Text((item.rating100 / 20).toFixed(1))
                        .fontSize(11).fontColor(this.theme.textSecondary)
                        .margin({ left: 3 })
                    }
                    .margin({ top: GAP_XS })
                  }
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
                .margin({ left: GAP_M })
              }
              .width('100%').alignItems(VerticalAlign.Center)
            }
          }
          .onClick(() => {
            const id: string = item.id === undefined ? '' : item.id
            if (id.length > 0) {
              router.pushUrl({ url: 'pages/GroupDetailPage', params: { 'id': id } })
            }
          })
        }, (item: GroupDto, idx: number) => (item.id === undefined ? 'g' + idx.toString() : item.id))

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

        if (!this.loading && this.items.length === 0) {
          ListItem() {
            Text('还没有集合，点「＋ 新建」创建一个')
              .fontSize(12)
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
