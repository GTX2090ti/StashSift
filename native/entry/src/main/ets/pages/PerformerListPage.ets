/**
 * StashSift — 演员列表（头像网格 + 搜索 + 排序 + 无限滚动）
 */
import { router } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Performer, PerformerDto } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import {
  GlassStyle, GlassTheme, GlassBackdrop,
  currentGlassTheme, currentBackdrop
} from '../common/GlassUtils'
import { layoutFor, columnsTemplate, RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'
import { SortBar } from '../components/SortBar'
import { SortOption, PERFORMER_SORTS } from '../common/Sorts'
import { scenesVersion } from '../common/DataVersion'

interface PerformerSort {
  label: string
  field: string
}

@Entry
@Component
struct PerformerListPage {
  @State items: Performer[] = []
  @State loading: boolean = false
  @State hasMore: boolean = true
  @State keyword: string = ''
  @State searchMode: boolean = false
  @State sortIndex: number = 0
  @State sortDir: string = 'ASC'
  @State errorText: string = ''
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  @StorageProp('winWidthVp') winW: number = 360

  private page: number = 1
  private pageSize: number = 48
  /** 跳详情节流标记（防连点重复压栈） */
  private pushing: boolean = false
  private sorts: PerformerSort[] = [
    { label: '名字', field: 'name' },
    { label: '参演数', field: 'scenes_count' },
    { label: '最近更新', field: 'updated_at' },
    { label: '评分', field: 'rating' }
  ]

  aboutToAppear(): void {
    this.reload()
  }

  /** 上次看到的数据版本号：详情页改名/合并后返回，列表要跟着刷新 */
  private lastVersion: number = scenesVersion()

  onPageShow(): void {
    // 从详情页返回：解锁跳转节流
    this.pushing = false
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
    const v: number = scenesVersion()
    if (v !== this.lastVersion) {
      this.lastVersion = v
      this.reload()
    }
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  private spec(): number {
    // 头像偏竖版，比短片多一列
    const c: number = layoutFor(this.winW).columns + 1
    return c > 6 ? 6 : c
  }

  private async reload(): Promise<void> {
    this.page = 1
    this.hasMore = true
    this.items = []
    this.errorText = ''
    await this.load()
  }

  /** 点卡片进详情：节流，避免连点把同一个详情页压两层 */
  private openDetail(id: string): void {
    if (this.pushing || id.length === 0) {
      return
    }
    this.pushing = true
    router.pushUrl({ url: 'pages/PerformerDetailPage', params: { 'id': id } })
      .catch(() => {
        this.pushing = false
      })
    // 兜底解锁：正常返回时 onPageShow 也会解锁
    setTimeout(() => {
      this.pushing = false
    }, 800)
  }

  private async load(): Promise<void> {
    if (this.loading || !this.hasMore) {
      return
    }
    this.loading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const sort: SortOption = PERFORMER_SORTS[this.sortIndex]
      const raw: PerformerDto[] = await api.findPerformersEx(
        this.page, this.pageSize, this.keyword.trim(), sort.sort, this.sortDir)
      const list: Performer[] = Performer.listFromDto(raw)
      const merged: Performer[] = this.items.slice()
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i])
      }
      this.items = merged
      this.hasMore = list.length >= this.pageSize
      this.page = this.page + 1
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
    }
    this.loading = false
  }

  private metaText(p: Performer): string {
    const parts: string[] = []
    if (p.scene_count > 0) {
      parts.push(p.scene_count.toString() + ' 部')
    }
    if (p.country.length > 0) {
      parts.push(p.country)
    }
    if (p.rating100 > 0) {
      parts.push('★ ' + (p.rating100 / 20).toFixed(1))
    }
    if (parts.length === 0) {
      return '暂无资料'
    }
    return parts.join(' · ')
  }

  @Builder
  avatarCard(p: Performer) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          if (p.image_path.length > 0) {
            AuthImage({ rawPath: p.image_path })
          } else {
            Column() {
              Text(p.name.length > 0 ? p.name.substring(0, 1) : '?')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textSecondary)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme.chipBg)
          }
        }
        .width('100%')
        .aspectRatio(3 / 4)
        .clip(true)

        if (p.favorite) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(13)
            .fontColor(['#FFFFB700'])
            .backgroundColor('#80000000')
            .borderRadius(RADIUS_CHIP)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .margin({ right: 5, top: 5 })
        }
      }
      .width('100%')

      Column() {
        Text(p.name.length === 0 ? '（无名）' : p.name)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.metaText(p))
          .fontSize(10)
          .fontColor(this.theme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .height(14)
          .margin({ top: 2 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 8, right: 8, top: 6, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(18)
    .clip(true)
    .onClick(() => {
      this.openDetail(p.id)
    })
  }

  @Builder
  toolRow() {
    Row() {
      if (this.searchMode) {
        // 搜索态：顶栏内联输入框
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(15)
          .fontColor([this.theme.textSecondary])
          .margin({ right: 6 })
        TextInput({ text: this.keyword, placeholder: '搜索演员名' })
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
            this.reload()
          })
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(14)
          .fontColor([this.theme.textSecondary])
          .padding(6)
          .onClick(() => {
            this.searchMode = false
            this.keyword = ''
            this.reload()
          })
      } else {
        // 排序条（与资料库其他列表同一套组件）
        SortBar({
          options: PERFORMER_SORTS,
          index: this.sortIndex,
          dirOverride: this.sortDir,
          theme: this.theme,
          onIndexChange: (idx: number) => {
            this.sortIndex = idx
            this.sortDir = PERFORMER_SORTS[idx].dir
            this.reload()
          },
          onDirChange: (d: string) => {
            this.sortDir = d
            this.reload()
          }
        })
        Blank().width(GAP_M)

        Text('共 ' + this.items.length.toString() + ' 人')
          .fontSize(12)
          .fontColor(this.theme.textSecondary)
          .layoutWeight(1)

        if (this.keyword.length > 0) {
          Text(this.keyword)
            .fontSize(11)
            .fontColor(this.theme.brandColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 90 })
            .margin({ right: GAP_S })
        }
        // 顶部放大镜图标

      }
    }
    .width('100%')
    .height(40)
    .padding({ left: PAD_PAGE, right: PAD_PAGE })
    .margin({ top: 8, bottom: 6 })
  }

  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('演员'),
        subtitle: this.loading && this.items.length === 0
          ? '加载中…'
          : ('共 ' + this.items.length.toString() + ' 人'),
        theme: this.theme,
        style: GlassStyle.REGULAR,
        showSearch: true,
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

      this.toolRow()

      if (this.errorText.length > 0) {
        Column() {
          Text(this.errorText).fontSize(13).fontColor('#FFE84026')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0 && !this.loading) {
        Column() {
          Text('没有找到演员').fontSize(14).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          ForEach(this.items, (p: Performer) => {
            GridItem() {
              this.avatarCard(p)
            }
          }, (p: Performer) => p.id)

          if (this.loading) {
            GridItem() {
              Row() {
                LoadingProgress().width(20).height(20)
                Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
              }
              .width('100%')
              .height(40)
              .justifyContent(FlexAlign.Center)
            }
            .columnStart(0)
            .columnEnd(this.spec() - 1)
          }
        }
        .columnsTemplate(columnsTemplate(this.spec()))
        .columnsGap(GAP_S)
        .rowsGap(GAP_S + 2)
        .width('100%')
        .layoutWeight(1)
        .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 4, bottom: 24 })
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          this.load()
        })
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