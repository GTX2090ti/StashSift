/**
 * StashSift — 扫描（二级页面）
 *
 * 从「设置 → 扫描」进入：
 *  - 扫描媒体库（增量）
 *  - 全量重扫
 *  - 扫描指定文件夹（多选，只列媒体库已配置路径 → 选择性扫描）
 *  - 清理缺失文件（支持预演）
 *  - 任务队列入口
 */
import { router, promptAction } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { FolderOption } from '../models/Models'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassCard } from '../components/GlassCard'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct ScanPage {
  @State scanning: boolean = false
  @State lastAction: string = ''
  @State folders: FolderOption[] = []
  @State foldersLoading: boolean = false
  @State pickerOpen: boolean = false
  @State pickerQuery: string = ''
  @State picked: string[] = []
  @State cleaning: boolean = false
  @State cleanScope: boolean = false
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

  /* ---------------- 全库扫描 ---------------- */

  private confirm(rescan: boolean): void {
    AlertDialog.show({
      title: rescan ? '全量重扫' : '扫描媒体库',
      message: rescan
        ? '会重新读取所有文件并重建元数据，耗时较长。确定继续？'
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
      this.lastAction = ok ? ((rescan ? '全量重扫' : '增量扫描') + ' 已提交') : '提交失败'
      promptAction.showToast({
        message: ok ? '已提交，可在任务队列查看进度' : '提交失败',
        duration: 2200
      })
    } catch (e) {
      this.lastAction = '失败：' + (e as Error).message
      promptAction.showToast({ message: '扫描失败：' + (e as Error).message, duration: 2500 })
    }
    this.scanning = false
  }

  /* ---------------- 指定文件夹（多选） ---------------- */

  private async loadFolders(): Promise<void> {
    this.foldersLoading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      this.folders = await api.libraryPaths()
    } catch (e) {
      promptAction.showToast({ message: '读取库路径失败：' + (e as Error).message, duration: 2200 })
    }
    this.foldersLoading = false
  }

  private openPicker(): void {
    this.pickerOpen = true
    this.pickerQuery = ''
    if (this.folders.length === 0) {
      this.loadFolders()
    }
  }

  private filteredFolders(): FolderOption[] {
    const q: string = this.pickerQuery.trim().toLowerCase()
    const out: FolderOption[] = []
    for (let i = 0; i < this.folders.length; i++) {
      const f: FolderOption = this.folders[i]
      if (q.length === 0 || f.path.toLowerCase().indexOf(q) >= 0) {
        out.push(f)
      }
    }
    return out
  }

  private isPicked(path: string): boolean {
    return this.picked.indexOf(path) >= 0
  }

  private togglePick(path: string): void {
    if (this.isPicked(path)) {
      const out: string[] = []
      for (let i = 0; i < this.picked.length; i++) {
        if (this.picked[i] !== path) {
          out.push(this.picked[i])
        }
      }
      this.picked = out
    } else {
      this.picked = this.picked.concat([path])
    }
  }

  private scanMultiple(): void {
    const paths: string[] = this.picked.slice()
    if (paths.length === 0) {
      promptAction.showToast({ message: '请先选择文件夹', duration: 1800 })
      return
    }
    this.pickerOpen = false
    AlertDialog.show({
      title: '选择性扫描',
      message: '将扫描 ' + paths.length.toString() + ' 个文件夹，其余目录不受影响。',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '开始',
        action: () => {
          this.runSelectiveMulti(paths)
        }
      }
    })
  }

  private async runSelectiveMulti(paths: string[]): Promise<void> {
    this.folderBusyOn()
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      hilog.info(0x0000, 'StashSift-Scan', 'selective scan dirs=%{public}d', paths.length)
      const ok: boolean = await api.scanLibrary(false, paths)
      this.lastAction = ok ? ('选择性扫描 ' + paths.length.toString() + ' 个目录 已提交') : '提交失败'
      promptAction.showToast({ message: ok ? '已提交' : '提交失败', duration: 2200 })
    } catch (e) {
      this.lastAction = '失败：' + (e as Error).message
      promptAction.showToast({ message: '扫描失败：' + (e as Error).message, duration: 2500 })
    }
    this.folderBusyOff()
  }

  @State busyFolder: boolean = false

  private folderBusyOn(): void {
    this.busyFolder = true
  }

  private folderBusyOff(): void {
    this.busyFolder = false
  }

  private shortPath(p: string): string {
    return p.length <= 34 ? p : '...' + p.substring(p.length - 31)
  }

  /* ---------------- 清理缺失文件 ---------------- */

  private confirmClean(dryRun: boolean): void {
    const scope: string = (this.cleanScope && this.picked.length > 0)
      ? ('\n范围：已选 ' + this.picked.length.toString() + ' 个文件夹') : '\n范围：整个媒体库'
    AlertDialog.show({
      title: dryRun ? '预演清理' : '清理缺失文件',
      message: (dryRun
        ? '只统计会被清理的条目，不会真的删除。'
        : '会移除库中已不存在的文件记录，不会动磁盘上的文件。') + scope,
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: dryRun ? '开始预演' : '开始清理',
        action: () => {
          this.runClean(dryRun)
        }
      }
    })
  }

  private async runClean(dryRun: boolean): Promise<void> {
    this.cleaning = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const paths: string[] = (this.cleanScope && this.picked.length > 0) ? this.picked.slice() : []
      const ok: boolean = await api.cleanLibrary(paths, dryRun)
      this.lastAction = ok ? ((dryRun ? '预演清理' : '清理') + ' 已提交') : '提交失败'
      promptAction.showToast({ message: ok ? '已提交，结果见任务队列' : '提交失败', duration: 2200 })
    } catch (e) {
      this.lastAction = '失败：' + (e as Error).message
      promptAction.showToast({ message: '清理失败：' + (e as Error).message, duration: 2500 })
    }
    this.cleaning = false
  }

  /* ---------------- UI ---------------- */

  @Builder
  actionCard(icon: Resource, title: string, desc: string, primary: boolean,
    onTap: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([primary ? this.theme.brandColor : this.theme.textSecondary])
        .margin({ right: 12 })
      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
        Text(desc)
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.scanning) {
        LoadingProgress().width(18).height(18)
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([this.theme.textSecondary])
      }
    }
    .width('100%')
    .padding(PAD_PAGE)
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(20)
    .onClick(onTap)
  }

  @Builder
  folderPicker() {
    Column() {
      Column() {
        Row() {
          Text('选择扫描文件夹（可多选）')
            .fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
            .layoutWeight(1)
          Text('关闭')
            .fontSize(12).fontColor(this.theme.textSecondary)
            .onClick(() => {
              this.pickerOpen = false
            })
        }
        .width('100%')

        TextInput({ text: this.pickerQuery, placeholder: '搜索文件夹' })
          .fontSize(12)
          .fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textSecondary)
          .backgroundColor(this.theme.chipBg)
          .borderRadius(RADIUS_CHIP)
          .height(38)
          .width('100%')
          .margin({ top: GAP_S })
          .onChange((v: string) => {
            this.pickerQuery = v
          })

        Row() {
          Text('全选')
            .fontSize(12).fontColor(this.theme.brandColor)
            .onClick(() => {
              const all: FolderOption[] = this.filteredFolders()
              const next: string[] = this.picked.slice()
              for (let i = 0; i < all.length; i++) {
                if (next.indexOf(all[i].path) < 0) {
                  next.push(all[i].path)
                }
              }
              this.picked = next
            })
          Text('清空')
            .fontSize(12).fontColor(this.theme.brandColor)
            .margin({ left: 16 })
            .onClick(() => {
              this.picked = []
            })
          Blank()
          Text('已选 ' + this.picked.length.toString() + ' 个')
            .fontSize(11).fontColor(this.theme.textSecondary)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: GAP_S })

        Divider().color(this.theme.divider).margin({ top: GAP_S })

        if (this.foldersLoading) {
          Row() {
            LoadingProgress().width(16).height(16)
            Text('读取中…').fontSize(11).fontColor(this.theme.textSecondary).margin({ left: 6 })
          }.margin({ top: GAP_M })
        }

        List() {
          ForEach(this.filteredFolders(), (f: FolderOption) => {
            ListItem() {
              Row() {
                SymbolGlyph(this.isPicked(f.path)
                  ? $r('sys.symbol.checkmark_circle_fill')
                  : $r('sys.symbol.circle'))
                  .fontSize(19)
                  .fontColor([this.isPicked(f.path) ? this.theme.brandColor : this.theme.textSecondary])
                Text(this.shortPath(f.path))
                  .fontSize(11)
                  .fontColor(this.isPicked(f.path) ? this.theme.brandColor : this.theme.textPrimary)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 8 })
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .onClick(() => {
                this.togglePick(f.path)
              })
            }
          }, (f: FolderOption) => f.path)
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ top: GAP_S })
        .scrollBar(BarState.Off)

        Button(this.busyFolder ? '提交中…' : '扫描选中文件夹')
          .width('100%')
          .height(46)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(this.busyFolder ? this.theme.textSecondary : this.theme.brandColor)
          .borderRadius(12)
          .margin({ top: GAP_S })
          .enabled(!this.busyFolder)
          .onClick(() => {
            this.scanMultiple()
          })
      }
      .width('90%')
      .height('72%')
      .padding(PAD_PAGE)
      .backgroundColor(this.theme.cardBg)
      .borderRadius(RADIUS_CARD)
      .border({ width: 1, color: this.theme.cardBorder })
      .backdropBlur(30)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#99000000')
    .onClick(() => {
      this.pickerOpen = false
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        GlassNavBar({
          title: L10n.translate('扫描'),
          subtitle: this.scanning ? '正在提交…' : '媒体库扫描',
          theme: this.theme,
          style: GlassStyle.REGULAR
        })

        Scroll() {
          Column() {
            this.actionCard($r('sys.symbol.arrow_clockwise'), '扫描媒体库',
              '只处理新增或变更的文件，速度较快', true, () => {
                this.confirm(false)
              })

            Column() {
              this.actionCard($r('sys.symbol.arrow_counterclockwise'), '全量重扫',
                '重新读取全部文件并重建元数据，耗时较长', false, () => {
                  this.confirm(true)
                })
            }
            .width('100%').margin({ top: GAP_M })

            // 扫描指定文件夹（只从库路径里选）
            Column() {
              GlassCard({ style: GlassStyle.REGULAR, title: '扫描指定文件夹', theme: this.theme }) {
                Column() {
                  if (this.picked.length === 0) {
                    Row() {
                      Text('未选择文件夹')
                        .fontSize(12)
                        .fontColor(this.theme.textSecondary)
                        .layoutWeight(1)
                      Text('选择文件夹')
                        .fontSize(12)
                        .fontColor(Color.White)
                        .backgroundColor(this.theme.brandColor)
                        .borderRadius(RADIUS_CHIP)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .onClick(() => {
                          this.openPicker()
                        })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                  } else {
                    ForEach(this.picked, (p: string) => {
                      Row() {
                        Text(this.shortPath(p))
                          .fontSize(11)
                          .fontColor(this.theme.textPrimary)
                          .layoutWeight(1)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text('×')
                          .fontSize(13)
                          .fontColor(this.theme.textSecondary)
                          .padding({ left: 10 })
                          .onClick(() => {
                            this.togglePick(p)
                          })
                      }
                      .width('100%')
                      .padding({ top: 6, bottom: 6 })
                      .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
                    }, (p: string) => p)

                    Row() {
                      Text('已选 ' + this.picked.length.toString() + ' 个')
                        .fontSize(11)
                        .fontColor(this.theme.textSecondary)
                        .layoutWeight(1)
                      Text('重新选择')
                        .fontSize(11)
                        .fontColor(this.theme.brandColor)
                        .onClick(() => {
                          this.openPicker()
                        })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .margin({ top: GAP_S })

                    Button(this.busyFolder ? '提交中…' : '扫描选中文件夹')
                      .width('100%')
                      .height(44)
                      .fontSize(14)
                      .fontColor(Color.White)
                      .backgroundColor(this.busyFolder ? this.theme.textSecondary : this.theme.brandColor)
                      .borderRadius(12)
                      .margin({ top: GAP_S })
                      .enabled(!this.busyFolder)
                      .onClick(() => {
                        this.scanMultiple()
                      })
                  }
                }
                .width('100%')
              }
            }
            .width('100%').margin({ top: GAP_M })

            // 清理缺失文件
            Column() {
              GlassCard({ style: GlassStyle.REGULAR, title: '清理缺失文件', theme: this.theme }) {
                Column() {
                  Text('移除库中已不存在的文件记录。磁盘上的文件不会被删除。')
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .width('100%')

                  Row() {
                    Text(this.picked.length > 0
                      ? ('只清理已选的 ' + this.picked.length.toString() + ' 个文件夹')
                      : '只清理已选文件夹（未选择则整库）')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Toggle({ type: ToggleType.Switch, isOn: this.cleanScope })
                      .onChange((on: boolean) => {
                        this.cleanScope = on
                      })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .margin({ top: GAP_S })

                  Row() {
                    Text(this.cleaning ? '提交中…' : '预演')
                      .fontSize(12)
                      .fontColor(this.theme.brandColor)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(this.theme.chipBg)
                      .borderRadius(RADIUS_CHIP)
                      .padding({ top: 9, bottom: 9 })
                      .layoutWeight(1)
                      .onClick(() => {
                        this.confirmClean(true)
                      })
                    Text(this.cleaning ? '提交中…' : '清理')
                      .fontSize(12)
                      .fontColor(Color.White)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(this.cleaning ? this.theme.textSecondary : '#FFE84026')
                      .borderRadius(RADIUS_CHIP)
                      .padding({ top: 9, bottom: 9 })
                      .layoutWeight(1)
                      .margin({ left: GAP_S })
                      .onClick(() => {
                        this.confirmClean(false)
                      })
                  }
                  .width('100%')
                  .margin({ top: GAP_S })
                }
                .width('100%')
              }
            }
            .width('100%').margin({ top: GAP_M })

            // 任务队列入口
            Column() {
              GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.clock'))
                    .fontSize(18)
                    .fontColor([this.theme.brandColor])
                    .margin({ right: 10 })
                  Text('查看任务队列进度')
                    .fontSize(13)
                    .fontColor(this.theme.textPrimary)
                    .layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(14)
                    .fontColor([this.theme.textSecondary])
                }
                .width('100%')
                .onClick(() => {
                  router.pushUrl({ url: 'pages/StashTasksPage' })
                })
              }
            }
            .width('100%').margin({ top: GAP_M })

            if (this.lastAction.length > 0) {
              Text('上次操作：' + this.lastAction)
                .fontSize(11)
                .fontColor(this.theme.textSecondary)
                .width('100%')
                .margin({ top: GAP_M })
            }

            Text('扫描在 Stash 服务端后台执行，提交后可以离开此页；进度请到「任务队列」查看。')
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .width('100%')
              .margin({ top: GAP_S })
          }
          .width('100%')
          .padding({ left: PAD_PAGE, right: PAD_PAGE, top: GAP_M, bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 160,
        colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      if (this.pickerOpen) {
        this.folderPicker()
      }
    }
    .width('100%')
    .height('100%')
  }
}