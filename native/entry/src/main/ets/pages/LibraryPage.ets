/**
 * StashGo — 资料库（ArkTS 原生）
 */
import { router } from '@kit.ArkUI'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassDock } from '../components/GlassDock'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct LibraryPage {
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  private entries: string[] = ['演员', '工作室', '标签', '集合', '去重']
  private routes: string[] = [
    'pages/PerformerListPage',
    'pages/StudioListPage',
    'pages/TagsPage',
    'pages/GroupsPage',
    'pages/DedupePage'
  ]

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
        title: L10n.translate('资料库'),
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          ForEach(this.entries, (name: string, idx: number) => {
            Column() {
              GlassCard({ style: GlassStyle.REGULAR, title: L10n.translate(name), theme: this.theme }) {
                Row() {
                  Text('进入 ' + L10n.translate(name))
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ bottom: 12 })
            .onClick(() => {
              router.pushUrl({ url: this.routes[idx] })
            })
          }, (name: string) => name)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 96 })
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
      GlassDock({ current: 3, isRoot: false, theme: this.theme })
    }
  }
}