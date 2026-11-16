/**
 * StashSift — 工作室列表（ArkTS 原生）
 */
import { router, promptAction } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Studio, StudioDto } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'
import { RADIUS_CHIP, PAD_PAGE, GAP_S } from '../common/Responsive'
import { SortBar } from '../components/SortBar'
import { SortOption, STUDIO_SORTS, buildSortMenu } from '../common/Sorts'
import { PickCache } from '../common/OptionCache'

@Entry
@Component
struct StudioListPage {
  @State items: Studio[] = []
  @State loading: boolean = false
  @State hasMore: boolean = true
  private page: number = 1
  @State sortIndex: number = 0
  @State sortDir: string = ''
  @State searchMode: boolean = false
  @State keyword: string = ''
  @State showNew: boolean = false
  @State newName: string = ''
  @State busy: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    if (this.loading || !this.hasMore) {
      return
    }
    this.loading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const so: SortOption = STUDIO_SORTS[this.sortIndex]
      const dir: string = this.sortDir.length > 0 ? this.sortDir : so.dir
      const raw: StudioDto[] = await api.findStudiosLite(this.page, 60, so.sort, dir, this.keyword.trim())
      const list: Studio[] = Studio.listFromDto(raw)
      const merged: Studio[] = this.items.slice()
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i])
      }
      this.items = merged
      this.hasMore = list.length === 60
      this.page = this.page + 1
    } catch (e) {
      console.error('[StudioListPage] ' + (e as Error).message)
    }
    this.loading = false
  }

  private reloadWithSort(): void {
    this.items = []
    this.page = 1
    this.hasMore = true
    this.load()
  }
  /** 新建工作室后从头刷新列表 */
  private async createStudio(): Promise<void> {
    const nm: string = this.newName.trim()
    if (nm.length === 0) {
      this.say('请输入工作室名称')
      return
    }
    this.busy = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const id: string = await api.createStudio(nm)
      if (id.length === 0) {
        this.say('新建失败')
      } else {
        this.say('已新建：' + nm)
        this.showNew = false
        this.newName = ''
        // 新建后清掉选择器缓存，编辑页的「父工作室」候选才看得到新项
        PickCache.studios = []
        this.items = []
        this.page = 1
        this.hasMore = true
        await this.load()
      }
    } catch (e) {
      this.say('新建失败：' + (e as Error).message)
    }
    this.busy = false
  }

  private say(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 })
    } catch (e) {
      console.error(msg)
    }
  }
  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  /** 详情页改过名字 / 收藏 / 数量后回来要看到新值 */
  @StorageProp('sceneVersion') @Watch('onScenesChanged') sceneVersion: number = 0

  onScenesChanged(): void {
    this.items = []
    this.page = 1
    this.hasMore = true
    this.load()
  }

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
    Column() {
      GlassNavBar({
        title: L10n.translate('工作室'),
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

      // 排序芯片 / 搜索
      Row() {
        if (this.searchMode) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(15)
            .fontColor([this.theme.textSecondary])
            .margin({ right: 6 })
          TextInput({ text: this.keyword, placeholder: '搜索工作室名' })
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
            options: STUDIO_SORTS,
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
        // 新建入口：搜索态也保留，避免入口被隐藏
        Text(this.showNew ? '收起' : '新建')
          .fontSize(12)
          .fontColor(this.showNew ? this.theme.textSecondary : this.theme.brandColor)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.showNew = !this.showNew
            if (!this.showNew) {
              this.newName = ''
            }
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 8, bottom: 2 })
      List({ space: 10 }) {
        ForEach(this.items, (item: Studio) => {
          ListItem() {
            GlassCard({ style: GlassStyle.THIN, title: item.name, desc: item.details, theme: this.theme }) {
              Row() {
                // 短片数（DTO 已有字段，不额外查询）
                Row() {
                  SymbolGlyph($r('sys.symbol.film'))
                    .fontSize(11)
                    .fontColor([this.theme.textSecondary])
                  Text(item.scene_count.toString())
                    .margin({ left: 3 })
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                }
                .alignItems(VerticalAlign.Center)

                // 收藏标记
                if (item.favorite) {
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(11)
                    .fontColor(['#FFFFB700'])
                    .margin({ left: 10 })
                }

                Blank()

                // 评分（未评分不显示 0.0）
                if (item.rating100 > 0) {
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(11)
                    .fontColor(['#FFFFB700'])
                  Text((item.rating100 / 20).toFixed(1))
                    .margin({ left: 2 })
                    .fontSize(12)
                    .fontColor('#FFFFB700')
                } else {
                  Text('—')
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
          }
          .onClick(() => {
            router.pushUrl({ url: 'pages/StudioDetailPage', params: { 'id': item.id } })
          })
        }, (item: Studio) => item.id)

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

      // 新建面板
      if (this.showNew) {
        Column() {
          Row() {
            Text('新建工作室').fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.brandColor).layoutWeight(1)
            Text('关闭').fontSize(11).fontColor(this.theme.textSecondary)
              .onClick(() => {
                this.showNew = false
              })
          }
          .width('100%')

          Row() {
            TextInput({ text: this.newName, placeholder: '输入工作室名称' })
              .fontSize(13).fontColor(this.theme.textPrimary)
              .placeholderColor(this.theme.textSecondary)
              .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
              .height(40).layoutWeight(1)
              .onChange((v: string) => {
                this.newName = v
              })
            Text(this.busy ? '创建中…' : '创建')
              .fontSize(12).fontColor(Color.White)
              .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
              .padding({ left: 16, right: 16, top: 9, bottom: 9 })
              .margin({ left: GAP_S })
              .onClick(() => {
                this.createStudio()
              })
          }
          .width('100%').margin({ top: GAP_S })
        }
        .width('100%').padding(PAD_PAGE)
        .backgroundColor(this.theme.cardBg)
        .border({ width: { top: 1 }, color: this.theme.cardBorder })
        .backdropBlur(24)
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
}