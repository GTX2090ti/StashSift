/**
 * StashSift — 去重 / 合并（基于 phash 距离）
 */
import { router } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Scene, SceneDto } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct DedupePage {
  @State groups: Scene[][] = []
  @State distance: number = 0
  @State loading: boolean = false
  @State message: string = ''
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  private async scan(): Promise<void> {
    this.loading = true
    this.message = ''
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const raw: SceneDto[][] = await api.findDuplicateScenes(this.distance)
      const out: Scene[][] = []
      for (let i = 0; i < raw.length; i++) {
        out.push(Scene.listFromDto(raw[i]))
      }
      this.groups = out
      this.message = out.length === 0 ? '没有找到重复项（距离越小越严格）' : ('找到 ' + out.length.toString() + ' 组重复')
    } catch (e) {
      this.message = '扫描失败：' + (e as Error).message
    }
    this.loading = false
  }

  /** 保留第一个，删除其余 */
  private async keepFirst(g: Scene[]): Promise<void> {
    if (g.length < 2) {
      return
    }
    const ids: string[] = []
    for (let i = 1; i < g.length; i++) {
      ids.push(g[i].id)
    }
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      await api.destroyScenes(ids, false)
      this.message = '已删除 ' + ids.length.toString() + ' 个重复项（文件保留）'
      await this.scan()
    } catch (e) {
      this.message = '删除失败：' + (e as Error).message
    }
  }

  /** 其余合并到第一个 */
  private async mergeIntoFirst(g: Scene[]): Promise<void> {
    if (g.length < 2) {
      return
    }
    const ids: string[] = []
    for (let i = 1; i < g.length; i++) {
      ids.push(g[i].id)
    }
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      await api.mergeScenes(ids, g[0].id, true, true)
      this.message = '已合并 ' + ids.length.toString() + ' 个到第一个'
      await this.scan()
    } catch (e) {
      this.message = '合并失败：' + (e as Error).message
    }
  }

  @Builder
  chip(label: string, active: boolean, onTap: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(active ? Color.White : this.theme.textSecondary)
      .backgroundColor(active ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .margin({ right: GAP_S, bottom: GAP_S })
      .onClick(onTap)
  }

  @Builder
  groupCard(g: Scene[]) {
    Column() {
      Scroll() {
        Row() {
          ForEach(g, (s: Scene) => {
            Column() {
              Column() { AuthImage({ rawPath: s.poster }) }.width(140).aspectRatio(16 / 9).clip(true)
              Text(s.title.length === 0 ? '（无标题）' : s.title)
                .fontSize(10).fontColor(this.theme.textSecondary)
                .maxLines(2).width(140).margin({ top: 4 })
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .margin({ right: GAP_S })
            .onClick(() => {
              router.pushUrl({ url: 'pages/SceneDetailPage', params: { 'id': s.id } })
            })
          }, (s: Scene) => s.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Row() {
        Text('保留第一个，删其余')
          .fontSize(12).fontColor(this.theme.textPrimary)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .margin({ right: GAP_S })
          .onClick(() => { this.keepFirst(g) })
        Text('合并到第一个')
          .fontSize(12).fontColor(Color.White)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .onClick(() => { this.mergeIntoFirst(g) })
      }
      .width('100%').margin({ top: GAP_S })
    }
    .width('100%').padding(GAP_M)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(18).margin({ bottom: GAP_S })
  }

  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('去重'),
        subtitle: this.message,
        theme: this.theme, style: GlassStyle.REGULAR
      })

      Flex({ wrap: FlexWrap.Wrap }) {
        this.chip('完全一致 (0)', this.distance === 0, () => { this.distance = 0 })
        this.chip('距离 5', this.distance === 5, () => { this.distance = 5 })
        this.chip('距离 10', this.distance === 10, () => { this.distance = 10 })
        this.chip('距离 20', this.distance === 20, () => { this.distance = 20 })
        Text(this.loading ? '扫描中…' : '开始扫描')
          .fontSize(12).fontColor(Color.White)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .onClick(() => { this.scan() })
      }
      .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, bottom: GAP_S })

      if (this.groups.length === 0) {
        Column() {
          Text(this.loading ? '正在扫描…' : (this.message.length > 0 ? this.message : '选择距离后点「开始扫描」'))
            .fontSize(13).fontColor(this.theme.textSecondary)
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.groups, (g: Scene[]) => {
            ListItem() {
              this.groupCard(g)
            }
          }, (g: Scene[]) => g.length > 0 ? g[0].id : '')
        }
        .layoutWeight(1).width('100%')
        .padding({ left: PAD_PAGE, right: PAD_PAGE, bottom: 24 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .linearGradient({ angle: 160, colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
