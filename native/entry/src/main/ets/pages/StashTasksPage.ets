/**
 * StashSift — 任务队列
 *
 * 展示 Stash 的 jobQueue：状态、描述、子任务进度，3 秒自动刷新。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { JobDto } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { BatchQueue, BatchJob } from '../common/BatchQueue'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct StashTasksPage {
  @State jobs: JobDto[] = []
  @State loading: boolean = true
  @State errorText: string = ''
  private timerId: number = -1
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    this.load()
    this.timerId = setInterval(() => {
      this.load()
    }, 3000)
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /** 两次任务列表是否完全一致（id + 状态 + 子任务） */
  private sameJobs(a: JobDto[], b: JobDto[]): boolean {
    if (a.length !== b.length) {
      return false
    }
    for (let i = 0; i < a.length; i++) {
      const x: JobDto = a[i]
      const y: JobDto = b[i]
      if ((x.id === undefined ? '' : x.id) !== (y.id === undefined ? '' : y.id)) {
        return false
      }
      if ((x.status === undefined ? '' : x.status) !== (y.status === undefined ? '' : y.status)) {
        return false
      }
      const sx: string[] = x.subTasks === undefined ? [] : x.subTasks
      const sy: string[] = y.subTasks === undefined ? [] : y.subTasks
      if (sx.length !== sy.length) {
        return false
      }
      for (let k = 0; k < sx.length; k++) {
        if (sx[k] !== sy[k]) {
          return false
        }
      }
    }
    return true
  }
  /** 按任务号升序：先提交的排上面（进行中的自然在最顶） */
  private sortJobs(list: JobDto[]): JobDto[] {
    try {
      const out: JobDto[] = list.slice()
      out.sort((a: JobDto, b: JobDto) => {
        const sa: string = a.id === undefined ? '0' : a.id
        const sb: string = b.id === undefined ? '0' : b.id
        const na: number = parseInt(sa, 10)
        const nb: number = parseInt(sb, 10)
        const va: number = isNaN(na) ? 0 : na
        const vb: number = isNaN(nb) ? 0 : nb
        return va - vb
      })
      return out
    } catch (e) {
      hilog.warn(0x0000, 'StashSift-Tasks', 'sort failed, keep原始顺序')
      return list
    }
  }
  private async load(): Promise<void> {
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const next: JobDto[] = this.sortJobs(await api.jobQueue())
      // 数据没变就不刷新，避免每 3 秒整表重绘（看起来像一直转圈）
      if (!this.sameJobs(this.jobs, next)) {
        this.jobs = next
      }
      this.errorText = ''
    } catch (e) {
      const msg: string = (e as Error).message
      this.errorText = '加载失败：' + msg
      hilog.error(0x0000, 'StashSift-Tasks', 'load failed: %{public}s', msg)
    }
    this.loading = false
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0
  @StorageProp('batchVersion') @Watch('onBatchChanged') batchVersion: number = 0
  @State localJobs: BatchJob[] = []

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  private statusColor(s: string): string {
    if (s === 'FINISHED') {
      return '#FF3FA45B'
    }
    if (s === 'RUNNING') {
      return '#FF0A59F7'
    }
    if (s === 'FAILED' || s === 'CANCELLED') {
      return '#FFE84026'
    }
    return '#FF999999'
  }

  /** 状态中文标签 */
  private statusLabel(s: string): string {
    if (s === 'FINISHED') {
      return '已完成'
    }
    if (s === 'RUNNING') {
      return '进行中'
    }
    if (s === 'FAILED') {
      return '失败'
    }
    if (s === 'CANCELLED') {
      return '已取消'
    }
    if (s === 'READY') {
      return '排队中'
    }
    return s
  }

  /** 任务标题：取描述首段 */
  private jobTitle(j: JobDto): string {
    const d: string = j.description === undefined ? '' : j.description
    if (d.length === 0) {
      return '任务'
    }
    const cut: number = d.indexOf('\n')
    return cut > 0 ? d.substring(0, cut) : d
  }

  /** 任务详情：描述剩余部分 */
  private jobDetail(j: JobDto): string {
    const d: string = j.description === undefined ? '' : j.description
    const cut: number = d.indexOf('\n')
    return cut > 0 ? d.substring(cut + 1).trim() : ''
  }

  @Builder
  jobCard(j: JobDto) {
    Column() {
      GlassCard({ style: GlassStyle.REGULAR, theme: this.theme }) {
        Column() {
          // 标题行
          Row() {
            Text(this.jobTitle(j))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.statusLabel(j.status === undefined ? '' : j.status))
              .fontSize(11)
              .fontColor(Color.White)
              .backgroundColor(this.statusColor(j.status === undefined ? '' : j.status))
              .borderRadius(RADIUS_CHIP)
              .padding({ left: 9, right: 9, top: 3, bottom: 3 })
              .margin({ left: GAP_S })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          // 详情（路径等）
          if (this.jobDetail(j).length > 0) {
            Text(this.jobDetail(j))
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 6 })
          }

          // 子任务
          if (j.subTasks !== undefined && j.subTasks.length > 0) {
            Column() {
              ForEach(j.subTasks, (sub: string, i: number) => {
                Row() {
                  Text('·')
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .width(10)
                  Text(sub)
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .layoutWeight(1)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .margin({ top: 4 })
              }, (sub: string, i: number) => sub + i.toString())
            }
            .width('100%')
            .padding({ top: GAP_S, left: 2 })
          }

          // 进行中动画条
          if (j.status === 'RUNNING') {
            Row() {
              LoadingProgress().width(14).height(14)
              Text('正在处理…')
                .fontSize(11)
                .fontColor(this.theme.brandColor)
                .margin({ left: 6 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: GAP_S })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .margin({ bottom: GAP_M - 4 })
  }

  @Builder
  localJobCard(j: BatchJob) {
    GlassCard({ style: GlassStyle.ULTRA_THIN, title: j.title, theme: this.theme }) {
      Column() {
        Row() {
          Text(j.running ? '进行中' : '已结束')
            .fontSize(11)
            .fontColor(j.running ? this.theme.brandColor : this.theme.textSecondary)
          Blank()
          Text(j.done.toString() + '/' + j.total.toString() +
            (j.failed > 0 ? (' · 失败 ' + j.failed.toString()) : ''))
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
        }
        .width('100%')
        Progress({ value: j.done + j.failed, total: j.total, type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color(this.theme.brandColor)
          .margin({ top: 6 })
        if (j.message.length > 0) {
          Text(j.message)
            .fontSize(10)
            .fontColor(this.theme.textSecondary)
            .width('100%')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  onBatchChanged(): void {
    this.localJobs = BatchQueue.instance.list().slice()
  }

  aboutToAppear_extra(): void {
    this.localJobs = BatchQueue.instance.list().slice()
  }

  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('任务队列'),
        subtitle: this.jobs.length === 0 ? '空闲' : ('共 ' + this.jobs.length.toString() + ' 个任务'),
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      // 本地批量任务（标签 / 演员 / 工作室 / 集合 / 合并）
      if (this.localJobs.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.localJobs, (j: BatchJob) => {
              this.localJobCard(j)
            }, (j: BatchJob) => j.id)
          }
          .width('100%')
          .padding({ left: PAD_PAGE, right: PAD_PAGE, top: GAP_S })
        }
        .constraintSize({ maxHeight: 200 })
        .width('100%')
        .scrollBar(BarState.Off)
      }

      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.errorText.length > 0) {
        Column() {
          Text(this.errorText).fontSize(13).fontColor('#FFE84026')
          Text('下拉或稍后重试').fontSize(11).fontColor(this.theme.textSecondary).margin({ top: 6 })
        }
        .layoutWeight(1).width('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.jobs.length === 0) {
        Scroll() {
          Column() {
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize(40)
              .fontColor([this.theme.textSecondary])
            Text('空闲')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .margin({ top: GAP_M })
            Text('当前没有排队中的任务')
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .margin({ top: GAP_S })
            Text('扫描 / 生成 / 清理任务会实时显示在这里')
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .margin({ top: GAP_S })
          }
          .width('100%')
          .padding({ left: PAD_PAGE, right: PAD_PAGE, top: GAP_M })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      } else {
        Scroll() {
          Column() {
            ForEach(this.jobs, (j: JobDto, idx: number) => {
              this.jobCard(j)
            }, (j: JobDto, idx: number) => (j.id === undefined ? idx.toString() : j.id))
          }
          .width('100%')
          .padding({ left: PAD_PAGE, right: PAD_PAGE, top: GAP_M, bottom: 32 })
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
  }
}