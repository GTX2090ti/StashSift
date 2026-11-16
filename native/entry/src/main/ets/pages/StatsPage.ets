/**
 * StashSift — 统计页
 */
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { StatsDto } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'

class StatRow {
  label: string = ''
  value: string = ''

  constructor(label: string, value: string) {
    this.label = label
    this.value = value
  }
}

@Entry
@Component
struct StatsPage {
  @State rows: StatRow[] = []
  @State loading: boolean = true
  @State errorText: string = ''
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.load()
  }

  private fmtSize(bytes: number): string {
    if (bytes <= 0) {
      return '0 B'
    }
    const gb: number = bytes / (1024 * 1024 * 1024)
    if (gb >= 1) {
      return gb.toFixed(2) + ' GB'
    }
    const mb: number = bytes / (1024 * 1024)
    if (mb >= 1) {
      return mb.toFixed(1) + ' MB'
    }
    return (bytes / 1024).toFixed(0) + ' KB'
  }

  private fmtDur(sec: number): string {
    const h: number = Math.floor(sec / 3600)
    const m: number = Math.floor((sec % 3600) / 60)
    if (h > 0) {
      return h.toString() + ' 小时 ' + m.toString() + ' 分'
    }
    return m.toString() + ' 分钟'
  }

  private async load(): Promise<void> {
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const s: StatsDto | null = await api.stats()
      if (s === null) {
        this.errorText = '未能获取统计数据'
        this.loading = false
        return
      }
      const list: StatRow[] = []
      list.push(new StatRow('短片数量', (s.scene_count === undefined ? 0 : s.scene_count).toString()))
      list.push(new StatRow('短片总大小', this.fmtSize(s.scenes_size === undefined ? 0 : s.scenes_size)))
      list.push(new StatRow('短片总时长', this.fmtDur(s.scenes_duration === undefined ? 0 : s.scenes_duration)))
      list.push(new StatRow('图片数量', (s.image_count === undefined ? 0 : s.image_count).toString()))
      list.push(new StatRow('图库数量', (s.gallery_count === undefined ? 0 : s.gallery_count).toString()))
      list.push(new StatRow('演员数量', (s.performer_count === undefined ? 0 : s.performer_count).toString()))
      list.push(new StatRow('工作室数量', (s.studio_count === undefined ? 0 : s.studio_count).toString()))
      list.push(new StatRow('集合数量', (s.group_count === undefined ? 0 : s.group_count).toString()))
      list.push(new StatRow('标签数量', (s.tag_count === undefined ? 0 : s.tag_count).toString()))
      list.push(new StatRow('累计播放次数', (s.total_play_count === undefined ? 0 : s.total_play_count).toString()))
      list.push(new StatRow('累计播放时长', this.fmtDur(s.total_play_duration === undefined ? 0 : s.total_play_duration)))
      list.push(new StatRow('已看短片数', (s.scenes_played === undefined ? 0 : s.scenes_played).toString()))
      this.rows = list
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
    }
    this.loading = false
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
        title: L10n.translate('统计'),
        subtitle: '媒体库汇总',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      if (this.loading) {
        Column() {
          Text(L10n.translate('加载中…')).fontSize(16).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).width('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.errorText.length > 0) {
        Column() {
          Text(this.errorText).fontSize(14).fontColor('#FFE84026')
        }
        .layoutWeight(1).width('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.rows, (r: StatRow, idx: number) => {
              Column() {
                GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
                  Row() {
                    Text(r.label)
                      .fontSize(14)
                      .fontColor(this.theme.textSecondary)
                    Blank()
                    Text(r.value)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme.textPrimary)
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .margin({ bottom: 8 })
            }, (r: StatRow, idx: number) => r.label)
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
