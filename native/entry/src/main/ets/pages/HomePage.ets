/**
 * StashSift — 主页（内容流：最新添加 + 继续观看，菜单入口已移入设置）
 */
import { router, window, display } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Scene, SceneDto, SceneFile } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassDock } from '../components/GlassDock'
import {
  GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop,
  currentGlassTheme, currentBackdrop
} from '../common/GlassUtils'
import { L10n } from '../settings/L10n'
import { layoutFor, itemWidthPercent } from '../common/Responsive'

@Entry
@Component
struct HomePage {
  @State tab: number = 0
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  @State navInset: number = 0
  @State dockWidth: number = 320
  @StorageProp('winWidthVp') winW: number = 360
  @State recent: Scene[] = []
  @State hero: Scene = new Scene('', '')
  @State heroList: Scene[] = []
  @State heroIdx: number = 0
  @State loading: boolean = true
  @State errorText: string = ''
  private titles: string[] = ['主页', '短片', '收藏', '资料库', '设置']
  private icons: Resource[] = [
    $r('sys.symbol.house'),
    $r('sys.symbol.film'),
    $r('sys.symbol.star'),
    $r('sys.symbol.book'),
    $r('sys.symbol.gearshape')
  ]
  private routes: string[] = [
    'pages/HomePage',
    'pages/SceneListPage',
    'pages/FavoritesPage',
    'pages/LibraryPage',
    'pages/SettingsPage'
  ]

  aboutToAppear(): void {
    this.measureDockWidth()
    this.measureNavInset()
    this.load()
  }

  /** 用屏幕宽度算胶囊宽度，避免百分比嵌套解析问题 */
  private measureDockWidth(): void {
    try {
      const d: display.Display = display.getDefaultDisplaySync()
      const w: number = px2vp(d.width)
      this.dockWidth = w - 32
    } catch (e) {
      this.dockWidth = 320
    }
  }
  private measureNavInset(): void {
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        try {
          const avoid: window.AvoidArea =
            win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
          this.navInset = px2vp(avoid.bottomRect.height)
        } catch (e) {
          console.error('[HomePage] getWindowAvoidArea failed')
        }
      }).catch(() => {
      })
    } catch (e) {
      console.error('[HomePage] getLastWindow failed')
    }
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorText = ''
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      // 顶部轮播取随机 8 条；下面列表取最近添加
      const pair: SceneDto[][] = await Promise.all([
        api.findScenesAdvanced(1, 8, '', 'random', 'DESC', false),
        api.findScenesAdvanced(1, 24, '', 'created_at', 'DESC', false)
      ])
      const heroes: Scene[] = Scene.listFromDto(pair[0])
      this.heroList = heroes
      if (heroes.length > 0) {
        this.hero = heroes[0]
        this.heroIdx = 0
      }
      this.recent = Scene.listFromDto(pair[1])
    } catch (e) {
      this.errorText = (e as Error).message
    }
    this.loading = false
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
    return s.files.length > 0 ? s.files[0].height : 0
  }

  private artistOf(s: Scene): string {
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
  tagBadge(count: number) {
    Row() {
      SymbolGlyph($r('sys.symbol.label'))
        .fontSize(11)
        .fontColor([this.theme.textSecondary])
      Text(count.toString())
        .fontSize(10)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 2 })
    }
    .backgroundColor('#33000000')
    .borderRadius(8)
    .padding({ left: 7, right: 7, top: 3, bottom: 3 })
    .margin({ right: 6, bottom: 6 })
  }
  @Builder
  badge(text: string, bg: string) {
    Text(text)
      .fontSize(10)
      .fontColor(Color.White)
      .backgroundColor(bg)
      .borderRadius(8)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
  }

  /** 顶部主卡片（大封面 + 信息） */
  /** 第 idx 张主卡片内容（封面 + 信息 + 按钮） */
  @Builder
  heroSlide(s: Scene) {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          AuthImage({ rawPath: s.poster })
        }
        .width('100%')
        .aspectRatio(16 / 9)
        .clip(true)

        if (this.resText(this.heightOf(s)).length > 0) {
          Row() {
            this.badge(this.resText(this.heightOf(s)), '#E60A59F7')
          }
          .margin({ left: 10, top: 10 })
        }
        if (this.durText(s.duration).length > 0) {
          Text(this.durText(s.duration))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .position({ right: 10, bottom: 10 })
        }
      }
      .width('100%')

      Column() {
        Text(s.title.length === 0 ? '（无标题）' : s.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          Text(this.artistOf(s))
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (s.rating100 > 0) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(10)
              .fontColor(['#FFFFB700'])
            Text((s.rating100 / 20).toFixed(1))
              .fontSize(11)
              .fontColor('#FFFFB700')
              .margin({ left: 2 })
          }
        }
        .width('100%')
        .margin({ top: 4 })

        Row() {
          if (s.play_count > 0) {
            this.badge('已看 ' + s.play_count.toString(), '#330A59F7')
          }
          if (s.organized) {
            this.badge('已整理', '#3364BB5C')
          }
          if (s.hasCaption) {
            this.badge('字幕', '#330A59F7')
          }
          if (s.tagNames.length > 0) {
            this.tagBadge(s.tagNames.length)
          }
        }
        .width('100%')
        .margin({ top: 6 })

        Row() {
          Text('查看详情')
            .fontSize(13)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(34)
        .backgroundColor(this.theme.brandColor)
        .borderRadius(17)
        .margin({ top: 10 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/SceneDetailPage', params: { 'id': s.id } })
        })
      }
      .width('100%')
      .padding(12)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .clip(true)
  }

  /** 顶部主卡片：随机 8 条短片循环播放 */
  @Builder
  heroCard() {
    Column() {
      Swiper() {
        ForEach(this.heroList, (s: Scene) => {
          this.heroSlide(s)
        }, (s: Scene) => s.id)
      }
      .autoPlay(this.heroList.length > 1)
      .interval(4000)
      .loop(this.heroList.length > 1)
      .indicator(this.heroList.length > 1
        ? new DotIndicator()
            .color('#66FFFFFF')
            .selectedColor(this.theme.brandColor)
        : false)
      .onChange((idx: number) => {
        this.heroIdx = idx
      })
      .height(this.dockWidth * 9 / 16 + 168)
      .width('100%')
    }
    .width('100%')
    .backgroundColor(this.theme.cardBg)
    .borderRadius(16)
    .border({ width: 1, color: this.theme.cardBorder })
    .shadow({ radius: 20, color: this.theme.cardShadow })
    .backdropBlur(20)
    .clip(true)
  }

  /** 列表小卡片 */
  @Builder
  smallCard(s: Scene) {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          AuthImage({ rawPath: s.poster })
        }
        .width('100%')
        .aspectRatio(16 / 9)
        .clip(true)
        if (s.hasCaption) {
          Text('字幕')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(6)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .position({ left: 6, bottom: 6 })
        }
        if (this.durText(s.duration).length > 0) {
          Text(this.durText(s.duration))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(6)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .margin({ right: 6, bottom: 6 })
        }
      }
      .width('100%')

      Text(s.title.length === 0 ? '（无标题）' : s.title)
        .fontSize(12)
        .fontColor(this.theme.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 8 })
        .align(Alignment.TopStart)
    }
    .width('100%')
    .backgroundColor(this.theme.cardBg)
    .borderRadius(16)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(18)
    .clip(true)
    .onClick(() => {
      router.pushUrl({ url: 'pages/SceneDetailPage', params: { 'id': s.id } })
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
      GlassNavBar({
        title: 'StashSift',
        subtitle: AppSettings.instance.profileName.length > 0
          ? AppSettings.instance.profileName
          : '鸿蒙原生 · 液态玻璃',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorText.length > 0) {
        Column() {
          Text(this.errorText).fontSize(14).fontColor('#FFE84026')
          Button('重试')
            .height(40)
            .fontSize(14)
            .backgroundColor(this.theme.brandColor)
            .fontColor(Color.White)
            .borderRadius(20)
            .margin({ top: 12 })
            .onClick(() => {
              this.load()
            })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.hero.id.length > 0) {
              this.heroCard()
            }
            if (this.recent.length > 0) {
              Text('最近添加')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary)
                .width('100%')
                .margin({ top: 20, bottom: 10 })

              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.recent, (s: Scene) => {
                  Column() {
                    this.smallCard(s)
                  }
                  .width(itemWidthPercent(layoutFor(this.winW).columns))
                  .margin({ bottom: 10 })
                }, (s: Scene) => s.id)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: layoutFor(this.winW).pagePadding, right: layoutFor(this.winW).pagePadding, top: 8, bottom: 100 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      GlassDock({ current: 0, isRoot: true, theme: this.theme })
    }
  }
}