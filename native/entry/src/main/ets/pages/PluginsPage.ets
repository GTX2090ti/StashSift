/**
 * StashSift — 插件（列表 / 启停 / 任务运行）
 */
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { PluginDto, PluginTaskDto } from '../models/Models'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct PluginsPage {
  @State plugins: PluginDto[] = []
  @State tasks: PluginTaskDto[] = []
  @State loading: boolean = true
  @State message: string = ''
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.load()
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  private async load(): Promise<void> {
    this.loading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      this.plugins = await api.listPlugins()
      this.tasks = await api.listPluginTasks()
      this.message = this.plugins.length.toString() + ' 个插件 · ' +
        this.tasks.length.toString() + ' 个任务'
    } catch (e) {
      this.message = '加载失败：' + (e as Error).message
    }
    this.loading = false
  }

  private async toggle(p: PluginDto): Promise<void> {
    const id: string = p.id === undefined ? '' : p.id
    if (id.length === 0) {
      return
    }
    const next: boolean = !(p.enabled === true)
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      await api.setPluginEnabled(id, next)
      p.enabled = next
      this.plugins = this.plugins.slice()
    } catch (e) {
      this.message = '切换失败：' + (e as Error).message
    }
  }

  private async run(t: PluginTaskDto): Promise<void> {
    const pid: string = (t.plugin !== undefined && t.plugin.id !== undefined) ? t.plugin.id : ''
    const name: string = t.name === undefined ? '' : t.name
    if (pid.length === 0 || name.length === 0) {
      return
    }
    this.message = '正在运行 ' + name + ' …'
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      await api.runPluginTask(pid, name)
      this.message = name + ' 已执行'
    } catch (e) {
      this.message = '运行失败：' + (e as Error).message
    }
  }

  @Builder
  pluginRow(p: PluginDto) {
    Row() {
      Column() {
        Text(p.name === undefined ? '(未命名)' : p.name)
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text((p.version === undefined ? '' : ('v' + p.version)) +
          (p.description === undefined ? '' : (' · ' + p.description)))
          .fontSize(11).fontColor(this.theme.textSecondary)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').margin({ top: 2 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: p.enabled === true })
        .width(48).height(28)
        .selectedColor(this.theme.brandColor)
        .onChange(() => {
          this.toggle(p)
        })
    }
    .width('100%').padding(GAP_M)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(18).margin({ bottom: GAP_S })
  }

  @Builder
  taskRow(t: PluginTaskDto) {
    Row() {
      Column() {
        Text(t.name === undefined ? '' : t.name)
          .fontSize(13).fontColor(this.theme.textPrimary).width('100%')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(t.description === undefined ? '' : t.description)
          .fontSize(11).fontColor(this.theme.textSecondary).width('100%')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)

      Text('运行')
        .fontSize(12).fontColor(Color.White)
        .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .onClick(() => {
          this.run(t)
        })
    }
    .width('100%').padding(GAP_M)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(18).margin({ bottom: GAP_S })
  }

  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('插件'),
        subtitle: this.message,
        theme: this.theme, style: GlassStyle.REGULAR
      })
      if (this.loading) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Text('插件').fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary).width('100%').margin({ bottom: GAP_S })
            ForEach(this.plugins, (p: PluginDto) => {
              this.pluginRow(p)
            }, (p: PluginDto) => p.id === undefined ? '' : p.id)

            Text('任务').fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary).width('100%')
              .margin({ top: GAP_M, bottom: GAP_S })
            if (this.tasks.length === 0) {
              Text('这个 Stash 没有可运行的插件任务')
                .fontSize(12).fontColor(this.theme.textSecondary).width('100%')
            }
            ForEach(this.tasks, (t: PluginTaskDto) => {
              this.taskRow(t)
            }, (t: PluginTaskDto) => (t.plugin === undefined ? '' : (t.plugin.id === undefined ? '' : t.plugin.id)) +
              '_' + (t.name === undefined ? '' : t.name))
          }
          .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 4, bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .linearGradient({ angle: 160, colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
