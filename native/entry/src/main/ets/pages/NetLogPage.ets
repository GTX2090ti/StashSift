/**
 * StashGo — 网络日志
 */
import { NetLog, NetLogEntry } from '../api/StashApi'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct NetLogPage {
  @State entries: NetLogEntry[] = []
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.entries = NetLog.instance.list()
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
    Column() {
      GlassNavBar({
        title: L10n.translate('网络日志'),
        subtitle: '共 ' + this.entries.length + ' 条',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      if (this.entries.length === 0) {
        Column() {
          Text('暂无日志').fontSize(16).fontColor(this.theme.textSecondary)
          Text('发起请求后这里会记录每一条 GraphQL 调用')
            .fontSize(12).fontColor(this.theme.textSecondary).margin({ top: 8 })
        }
        .layoutWeight(1).width('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.entries, (e: NetLogEntry, idx: number) => {
              Column() {
                GlassCard({ style: GlassStyle.ULTRA_THIN, theme: this.theme }) {
                  Column() {
                    Row() {
                      Text(e.title)
                        .fontSize(12)
                        .fontColor(e.level === 'ERROR' ? '#FFE84026' : this.theme.textPrimary)
                        .layoutWeight(1)
                        .maxLines(1)
                      Text(e.status.toString() + ' · ' + e.ms.toString() + 'ms')
                        .fontSize(10)
                        .fontColor(this.theme.textSecondary)
                    }
                    .width('100%')

                    if (e.message.length > 0) {
                      Text(e.message)
                        .fontSize(10)
                        .fontColor(this.theme.textSecondary)
                        .width('100%')
                        .maxLines(2)
                        .margin({ top: 3 })
                    }
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .margin({ bottom: 6 })
            }, (e: NetLogEntry, idx: number) => idx.toString())
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 24 })
        }
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
