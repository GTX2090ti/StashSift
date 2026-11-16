/**
 * StashSift — 设置页（ArkTS 原生）
 */
import { router, window, promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppSettings, Appearance } from '../settings/AppSettings'
import { Profile } from '../models/Models'
import { StashApi } from '../api/StashApi'
import { NetSwitch } from '../common/NetSwitch'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial, syncSystemBar } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct SettingsPage {
  @State appearance: string = 'system'
  @State safeMode: boolean = false
  @State bioLock: boolean = false
  @State autoSwitch: boolean = true
  @State profileNames: string[] = []
  @State profileDescs: string[] = []
  @State scanning: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.appearance = AppSettings.instance.appearance
    this.safeMode = AppSettings.instance.safeMode
    this.bioLock = AppSettings.instance.biometricLock
    const names: string[] = []
    const descs: string[] = []
    for (let i = 0; i < AppSettings.instance.profiles.length; i++) {
      const p: Profile = AppSettings.instance.profiles[i]
      names.push(p.name)
      const parts: string[] = []
      if (p.lanUrl.length > 0) {
        parts.push(p.lanUrl)
      }
      if (p.wanUrl.length > 0) {
        parts.push(p.wanUrl)
      }
      descs.push(parts.join('  ·  '))
    }
    this.profileNames = names
    this.profileDescs = descs
  }

  private async setAppearance(a: Appearance): Promise<void> {
    AppSettings.instance.appearance = a
    this.appearance = a
    await AppSettings.instance.flush()
    // 立即刷新主题与背景（无需重启）
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
    this.syncSystemBar()
  }

  /** 同步状态栏/导航栏图标颜色 */
  private syncSystemBar(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      syncSystemBar(ctx, this.theme.isDark)
    } catch (e) {
      console.error('[SettingsPage] syncSystemBar failed')
    }
  }

  @Builder
  appearanceChip(a: Appearance, label: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.appearance === a ? Color.White : this.theme.textSecondary)
      .backgroundColor(this.appearance === a ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(8)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .onClick(() => {
        this.setAppearance(a)
      })
  }

  /** 触发扫描（先确认） */
  private doScan(rescan: boolean): void {
    AlertDialog.show({
      title: rescan ? '全量重扫' : '扫描媒体库',
      message: rescan
        ? '重新读取所有文件并重建元数据，耗时较长。确定继续？'
        : '只扫描新增或变更的文件，速度较快。确定继续？',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '开始',
        action: () => {
          this.runScan(rescan)
        }
      }
    })
  }

  private async runScan(rescan: boolean): Promise<void> {
    this.scanning = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const ok: boolean = await api.scanLibrary(rescan)
      const msg: string = ok ? '扫描已提交，可在「任务队列」查看进度' : '扫描提交失败'
      promptAction.showToast({ message: msg, duration: 2200 })
    } catch (e) {
      promptAction.showToast({ message: '扫描失败：' + (e as Error).message, duration: 2500 })
    }
    this.scanning = false
  }

  /** 动作型条目（点击执行，不跳页） */
  @Builder
  actionRow(icon: Resource, title: string, desc: string, divider: boolean, onTap: () => void) {
    Column() {
      Row() {
        SymbolGlyph(icon).fontSize(22).fontColor([this.theme.brandColor]).margin({ right: 12 })
        Column() {
          Text(title).fontSize(14).fontColor(this.theme.textPrimary)
          Text(desc).fontSize(12).fontColor(this.theme.textSecondary).margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.scanning) {
          LoadingProgress().width(18).height(18)
        } else {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([this.theme.textSecondary])
        }
      }
      .width('100%')
      .height(60)
      .padding({ left: 14, right: 14 })
      .onClick(onTap)

      if (divider) {
        Divider().color(this.theme.divider).margin({ left: 48 })
      }
    }
  }

  /** 功能条目（官方符号图标 + 标题 + 说明 + 箭头） */
  @Builder
  funcRow(icon: Resource, title: string, desc: string, route: string, divider: boolean) {
    Column() {
      Row() {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([this.theme.brandColor])
          .margin({ right: 12 })
        Column() {
          Text(title)
            .fontSize(14)
            .fontColor(this.theme.textPrimary)
          Text(desc)
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([this.theme.textSecondary])
      }
      .width('100%')
      .height(60)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        router.pushUrl({ url: route })
      })

      if (divider) {
        Divider()
          .color(this.theme.divider)
          .margin({ left: 48 })
      }
    }
    .width('100%')
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
        title: L10n.translate('设置'),
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          Column() {
            GlassCard({ style: GlassStyle.REGULAR, title: L10n.translate('外观'), theme: this.theme }) {
              Row() {
                this.appearanceChip(Appearance.LIGHT, L10n.translate('浅色'))
                Blank().width(8)
                this.appearanceChip(Appearance.DARK, L10n.translate('深色'))
                Blank().width(8)
                this.appearanceChip(Appearance.SYSTEM, L10n.translate('跟随系统'))
              }
              .width('100%')
            }
          }
          .width('100%')
          .margin({ bottom: 12 })

          Column() {
            GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
              Row() {
                Text(L10n.translate('安全模式'))
                  .fontSize(14)
                  .fontColor(this.theme.textPrimary)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.safeMode })
                  .onChange((isOn: boolean) => {
                    this.safeMode = isOn
                    AppSettings.instance.safeMode = isOn
                    AppStorage.setOrCreate('safeMode', isOn)
                    AppSettings.instance.flush()
                  })
              }
              .width('100%')
            }
          }
          .width('100%')
          .margin({ bottom: 12 })

          Column() {
            GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
              Row() {
                Text(L10n.translate('生物识别锁'))
                  .fontSize(14)
                  .fontColor(this.theme.textPrimary)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.bioLock })
                  .onChange((isOn: boolean) => {
                    this.bioLock = isOn
                    AppSettings.instance.biometricLock = isOn
                    AppSettings.instance.flush()
                  })
              }
              .width('100%')
            }
          }
          .width('100%')
          .margin({ bottom: 12 })
          // 内外网自动切换
          Column() {
            GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
              Column() {
                Row() {
                  Text('自动切换内外网')
                    .fontSize(14)
                    .fontColor(this.theme.textPrimary)
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: this.autoSwitch })
                    .onChange((isOn: boolean) => {
                      this.autoSwitch = isOn
                      if (isOn) {
                        NetSwitch.autoPick(true)
                      }
                    })
                }
                .width('100%')
                Text(this.autoSwitch
                  ? ('当前：' + (AppSettings.instance.isLan() ? '内网' : '外网'))
                  : '已关闭自动切换，使用上次选择的地址')
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .width('100%')
                  .margin({ top: 4 })
                Text('内网 ' + (AppSettings.instance.lanUrl.length > 0 ? AppSettings.instance.lanUrl : '未配置'))
                  .fontSize(10)
                  .fontColor(this.theme.textSecondary)
                  .width('100%')
                  .maxLines(1)
                  .margin({ top: 2 })
                Text('外网 ' + (AppSettings.instance.wanUrl.length > 0 ? AppSettings.instance.wanUrl : '未配置'))
                  .fontSize(10)
                  .fontColor(this.theme.textSecondary)
                  .width('100%')
                  .maxLines(1)
                  .margin({ top: 2 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .margin({ bottom: 12 })


          if (this.profileNames.length > 0) {
            Column() {
              GlassCard({ style: GlassStyle.REGULAR, title: L10n.translate('已有档案'), theme: this.theme }) {
                Column() {
                  ForEach(this.profileNames, (name: string, idx: number) => {
                    Row() {
                      Column() {
                        Text(name)
                          .fontSize(14)
                          .fontColor(this.theme.textPrimary)
                        Text(this.profileDescs[idx])
                          .fontSize(12)
                          .fontColor(this.theme.textSecondary)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                    }
                    .width('100%')
                    .padding({ top: 6, bottom: 6 })
                  }, (name: string) => name)
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ bottom: 12 })
          }

          Button('切换服务器档案')
            .width('100%')
            .height(44)
            .backgroundColor(this.theme.brandColor)
            .fontColor(Color.White)
            .borderRadius(8)
            .onClick(() => {
              router.replaceUrl({ url: 'pages/LoginPage' })
            })

          // 功能入口
          Text('功能')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
            .width('100%').margin({ top: 20, bottom: 10 })

          Column() {
            this.funcRow($r('sys.symbol.clock'), '任务队列', '扫描 / 生成 / 清理任务进度',
              'pages/StashTasksPage', true)
            this.funcRow($r('sys.symbol.arrow_clockwise'), '扫描', '增量 / 全量 / 指定文件夹扫描',
              'pages/ScanPage', true)
            this.funcRow($r('sys.symbol.histogram'), '媒体库统计', '查看数量 / 大小 / 时长汇总',
              'pages/StatsPage', true)
            this.funcRow($r('sys.symbol.magnifyingglass'), '刮削', '刮削 / Fantia 刮削',
              'pages/ScrapeHubPage', true)
            this.funcRow($r('sys.symbol.arrow_clockwise'), '刮削器安装', '从索引源安装 / 卸载刮削器包',
              'pages/ScraperStorePage', true)
            this.funcRow($r('sys.symbol.gearshape'), '插件', '管理 Stash 插件与插件任务',
              'pages/PluginsPage', true)
            this.funcRow($r('sys.symbol.doc_text'), '网络日志', '查看 GraphQL 请求记录',
              'pages/NetLogPage', false)
          }
          .width('100%')
          .backgroundColor(this.theme.cardBg)
          .borderRadius(16)
          .border({ width: 1, color: this.theme.cardBorder })
          .backdropBlur(20)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
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