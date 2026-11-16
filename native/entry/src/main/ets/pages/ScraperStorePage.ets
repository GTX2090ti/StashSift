/**
 * StashSift — 刮削器安装（Stash 刮削器包管理）
 *
 * 数据来源：
 *   已安装 —— installedPackages(type: Scraper)
 *   可安装 —— availablePackages(type: Scraper, source: <索引 index.yml>)
 *   安装 / 卸载 / 更新 —— installPackages / uninstallPackages / updatePackages
 *
 * 装完后 Stash 会重新加载 scrapers 目录，刮削页的刮削器列表随之变化，
 * 所以这里 bumpScrapers() 通知刮削页重新拉一次。
 */
import { router } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StashApi } from '../api/StashApi'
import { bumpScrapers } from '../common/DataVersion'
import { RADIUS_CHIP } from '../common/Responsive'
import { AppSettings } from '../settings/AppSettings'
import { PackageDto } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'

/** 社区刮削器索引（Stash 官方默认源） */
const DEFAULT_SOURCE: string = 'https://stashapp.github.io/CommunityScrapers/stable/index.yml'
/** 一次最多渲染多少行，避免 600+ 条同时创建组件 */
const MAX_ROWS: number = 120

@Entry
@Component
struct ScraperStorePage {
  /** 0 = 可安装，1 = 已安装 */
  @State tab: number = 0
  @State source: string = DEFAULT_SOURCE
  @State available: PackageDto[] = []
  @State installed: PackageDto[] = []
  @State query: string = ''
  @State loading: boolean = false
  @State busy: boolean = false
  @State status: string = ''
  @State statusError: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  private api(): StashApi {
    return new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
  }

  aboutToAppear(): void {
    this.loadAll()
  }

  private str(v: Object | undefined | null): string {
    if (v === undefined || v === null) {
      return ''
    }
    return v.toString()
  }

  private idOf(p: PackageDto): string {
    return this.str(p.package_id).length > 0 ? this.str(p.package_id) : this.str(p.name)
  }

  private nameOf(p: PackageDto): string {
    const n: string = this.str(p.name)
    return n.length > 0 ? n : this.idOf(p)
  }

  /** 已装版本（未安装返回空串） */
  private installedVersion(packageId: string): string {
    for (let i = 0; i < this.installed.length; i++) {
      if (this.idOf(this.installed[i]) === packageId) {
        return this.str(this.installed[i].version)
      }
    }
    return ''
  }

  private async loadAll(): Promise<void> {
    if (this.loading) {
      return
    }
    this.loading = true
    this.status = '读取已安装…'
    this.statusError = false
    try {
      this.installed = await this.api().installedScraperPackages()
      this.status = '读取可用列表（索引可能较慢）…'
      this.available = await this.api().availableScraperPackages(this.source.trim())
      this.status = '已安装 ' + this.installed.length.toString() +
        ' 个，可用 ' + this.available.length.toString() + ' 个'
    } catch (e) {
      const msg: string = (e as Error).message
      hilog.warn(0x0000, 'StashSift-Store', 'load failed: %{public}s', msg)
      this.statusError = true
      this.status = this.humanError(msg)
    }
    this.loading = false
  }

  private humanError(raw: string): string {
    const low: string = raw.toLowerCase()
    if (low.indexOf('eof') >= 0 || low.indexOf('timeout') >= 0 || low.indexOf('超时') >= 0) {
      return '连不上索引源（网络被墙或超时）：换一个能访问的索引地址再试。'
    }
    if (low.indexOf('404') >= 0) {
      return '索引地址 404：确认填的是 index.yml 的完整地址。'
    }
    if (low.indexOf('403') >= 0) {
      return '索引源返回 403：被反爬拦截，换镜像源再试。'
    }
    return '加载失败：' + raw
  }

  /** 搜索过滤 + 截断 */
  private rows(): PackageDto[] {
    const q: string = this.query.trim().toLowerCase()
    const src: PackageDto[] = this.tab === 0 ? this.available : this.installed
    const out: PackageDto[] = []
    for (let i = 0; i < src.length && out.length < MAX_ROWS; i++) {
      const id: string = this.idOf(src[i]).toLowerCase()
      const nm: string = this.nameOf(src[i]).toLowerCase()
      if (q.length === 0 || id.indexOf(q) >= 0 || nm.indexOf(q) >= 0) {
        out.push(src[i])
      }
    }
    return out
  }

  private matchedCount(): number {
    const q: string = this.query.trim().toLowerCase()
    if (q.length === 0) {
      return this.tab === 0 ? this.available.length : this.installed.length
    }
    const src: PackageDto[] = this.tab === 0 ? this.available : this.installed
    let n: number = 0
    for (let i = 0; i < src.length; i++) {
      const id: string = this.idOf(src[i]).toLowerCase()
      const nm: string = this.nameOf(src[i]).toLowerCase()
      if (id.indexOf(q) >= 0 || nm.indexOf(q) >= 0) {
        n = n + 1
      }
    }
    return n
  }

  private async doInstall(p: PackageDto): Promise<void> {
    if (this.busy) {
      return
    }
    const id: string = this.idOf(p)
    if (id.length === 0) {
      return
    }
    this.busy = true
    this.statusError = false
    this.status = '安装 ' + this.nameOf(p) + ' …'
    try {
      const r: string = await this.api().installScraperPackages([id], this.source.trim())
      if (r.length === 0) {
        this.statusError = true
        this.status = '安装失败：服务端没有返回结果'
      } else {
        this.installed = await this.api().installedScraperPackages()
        bumpScrapers()
        this.status = '已安装 ' + this.nameOf(p) + '（' + r + ' 个刮削器）'
      }
    } catch (e) {
      this.statusError = true
      this.status = '安装失败：' + (e as Error).message
    }
    this.busy = false
  }

  private async doUninstall(p: PackageDto): Promise<void> {
    if (this.busy) {
      return
    }
    const id: string = this.idOf(p)
    if (id.length === 0) {
      return
    }
    this.busy = true
    this.statusError = false
    this.status = '卸载 ' + this.nameOf(p) + ' …'
    try {
      const r: string = await this.api().uninstallScraperPackages([id], this.source.trim())
      if (r.length === 0) {
        this.statusError = true
        this.status = '卸载失败：服务端没有返回结果'
      } else {
        this.installed = await this.api().installedScraperPackages()
        bumpScrapers()
        this.status = '已卸载 ' + this.nameOf(p)
      }
    } catch (e) {
      this.statusError = true
      this.status = '卸载失败：' + (e as Error).message
    }
    this.busy = false
  }

  private async doUpdate(p: PackageDto): Promise<void> {
    if (this.busy) {
      return
    }
    const id: string = this.idOf(p)
    this.busy = true
    this.statusError = false
    this.status = '更新 ' + this.nameOf(p) + ' …'
    try {
      const r: string = await this.api().updateScraperPackages([id], this.source.trim())
      if (r.length === 0) {
        this.statusError = true
        this.status = '更新失败：服务端没有返回结果'
      } else {
        this.installed = await this.api().installedScraperPackages()
        bumpScrapers()
        this.status = '已更新 ' + this.nameOf(p)
      }
    } catch (e) {
      this.statusError = true
      this.status = '更新失败：' + (e as Error).message
    }
    this.busy = false
  }

  private confirmUninstall(p: PackageDto): void {
    AlertDialog.show({
      title: '卸载刮削器包',
      message: '会从 Stash 删除「' + this.nameOf(p) + '」的所有刮削器文件，之后刮削页里就不再有它。',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '卸载',
        fontColor: '#FFE84026',
        action: () => {
          this.doUninstall(p)
        }
      }
    })
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  @Builder
  tabChip(t: number, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.tab === t ? Color.White : this.theme.textSecondary)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.tab === t ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(8)
      .padding({ top: 9, bottom: 9 })
      .layoutWeight(1)
      .margin({ left: 3, right: 3 })
      .onClick(() => {
        this.tab = t
        this.query = ''
      })
  }

  @Builder
  packageRow(p: PackageDto) {
    Row() {
      Column() {
        Text(this.nameOf(p))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.idOf(p) + (this.str(p.version).length > 0 ? '  ·  v' + this.str(p.version) : ''))
          .fontSize(10)
          .fontColor(this.theme.textSecondary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.tab === 1) {
        Text('卸载')
          .fontSize(11)
          .fontColor('#FFE84026')
          .backgroundColor(this.theme.chipBg)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .margin({ left: 8 })
          .onClick(() => {
            this.confirmUninstall(p)
          })
      } else if (this.installedVersion(this.idOf(p)).length > 0) {
        Text('已安装')
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .margin({ left: 8 })
      } else {
        Text(this.busy ? '…' : '安装')
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor(this.busy ? this.theme.textSecondary : this.theme.brandColor)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .margin({ left: 8 })
          .onClick(() => {
            this.doInstall(p)
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
  }

  build() {
    Column() {
      GlassNavBar({
        title: '刮削器安装',
        subtitle: '已安装 ' + this.installed.length.toString() + ' 个 · 可用 ' +
          this.available.length.toString() + ' 个',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Column() {
        Row() {
          this.tabChip(0, '可安装')
          this.tabChip(1, '已安装')
        }
        .width('100%')
        .margin({ bottom: 10 })

        GlassCard({ style: GlassStyle.THIN, title: '索引源', theme: this.theme }) {
          Column() {
            TextInput({ text: this.source, placeholder: 'index.yml 地址' })
              .fontSize(11)
              .fontColor(this.theme.textPrimary)
              .placeholderColor(this.theme.textSecondary)
              .backgroundColor(this.theme.chipBg)
              .borderRadius(RADIUS_CHIP)
              .height(38)
              .width('100%')
              .onChange((v: string) => {
                this.source = v
              })
            Row() {
              Text('官方源连不上时，换一个能访问的 index.yml 镜像地址')
                .fontSize(10)
                .fontColor(this.theme.textSecondary)
                .layoutWeight(1)
                .maxLines(2)
              Text('重置')
                .fontSize(11)
                .fontColor(this.theme.brandColor)
                .margin({ left: 8 })
                .onClick(() => {
                  this.source = DEFAULT_SOURCE
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 6 })
          }
          .width('100%')
        }

        Row() {
          TextInput({ text: this.query, placeholder: '搜索包名 / 刮削器 ID' })
            .fontSize(12)
            .fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg)
            .borderRadius(RADIUS_CHIP)
            .height(36)
            .layoutWeight(1)
            .onChange((v: string) => {
              this.query = v
            })
        }
        .width('100%')
        .margin({ top: 10 })

        if (this.status.length > 0) {
          Text(this.status)
            .fontSize(11)
            .fontColor(this.statusError ? '#FFE84026' : '#FF64BB5C')
            .width('100%')
            .margin({ top: 8 })
            .maxLines(3)
        }
        if (this.matchedCount() > MAX_ROWS) {
          Text('匹配 ' + this.matchedCount().toString() + ' 个，只显示前 ' +
            MAX_ROWS.toString() + ' 个：输入关键字缩小范围')
            .fontSize(10)
            .fontColor(this.theme.textSecondary)
            .width('100%')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10 })

      List() {
        ForEach(this.rows(), (p: PackageDto) => {
          ListItem() {
            this.packageRow(p)
          }
        }, (p: PackageDto) => this.idOf(p))
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 12 })
      .scrollBar(BarState.Off)

      Row() {
        Button(this.loading ? '刷新中…' : '刷新列表')
          .layoutWeight(2)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(this.loading ? this.theme.textSecondary : this.theme.brandColor)
          .borderRadius(12)
          .enabled(!this.loading)
          .onClick(() => {
            this.loadAll()
          })
        Button('返回')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(12)
          .margin({ left: 8 })
          .onClick(() => {
            router.back()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      .backgroundColor(this.theme.cardBg)
      .border({ width: { top: 1 }, color: this.theme.cardBorder })
      .backdropBlur(24)
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
