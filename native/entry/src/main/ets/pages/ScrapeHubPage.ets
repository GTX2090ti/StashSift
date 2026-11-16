/**
 * StashSift — 刮削总入口
 *
 * 刮削菜单：按名称/URL 刮削、Fantia 刮削。
 * 「刮削器安装」按用户要求留在设置页，不放进来。
 * 页面骨架与设置页一致（GlassNavBar + GlassCard + 渐变背景 + onPageShow 刷主题）。
 */
import { router } from '@kit.ArkUI'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'
import { PAD_PAGE } from '../common/Responsive'

@Entry
@Component
struct ScrapeHubPage {
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  /** 系统深浅色变化时即时跟随 */
  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  /** 返回本页时刷新主题 */
  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  /** 一行入口：图标 + 标题 + 说明 + 箭头 */
  @Builder
  entryRow(icon: Resource, title: string, desc: string, route: string) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.theme.brandColor])
        .margin({ right: 12 })
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor(this.theme.textPrimary)
          .width('100%')
        Text(desc)
          .fontSize(12)
          .fontColor(this.theme.textSecondary)
          .maxLines(2)
          .margin({ top: 2 })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([this.theme.textSecondary])
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      router.pushUrl({ url: route })
    })
  }

  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('刮削'),
        subtitle: '抓取 / 补充短片元数据',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          Column() {
            GlassCard({ style: GlassStyle.REGULAR, theme: this.theme }) {
              Column() {
                this.entryRow($r('sys.symbol.magnifyingglass'), L10n.translate('刮削'),
                  '按名称或 URL 抓取元数据，可写回指定短片', 'pages/ScrapePage')
                Divider().color(this.theme.divider).margin({ left: 34 })
                this.entryRow($r('sys.symbol.film'), L10n.translate('Fantia 刮削'),
                  '按 Fantia 作品 ID 单独刮削', 'pages/FantiaPage')
              }
              .width('100%')
            }
          }
          .width('100%')
          .margin({ bottom: 12 })
        }
        .width('100%')
        .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 12, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
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
