/**
 * StashSift — 通用排序条
 *
 * 「[字段 ⌄] [↓ 降序]」两个芯片，所有列表页共用这一份实现。
 * 使用方只需传入选项数组、当前索引、方向覆盖值，以及两个回调。
 */
import { GlassTheme, currentGlassTheme } from '../common/GlassUtils'
import { SortOption, buildSortMenu } from '../common/Sorts'
import { RADIUS_CHIP, GAP_M, GAP_S } from '../common/Responsive'

@Component
export struct SortBar {
  @Prop options: SortOption[] = []
  @Prop index: number = 0
  /** 空字符串 = 跟随选项自带的默认方向 */
  @Prop dirOverride: string = ''
  theme: GlassTheme = currentGlassTheme()

  onIndexChange: (idx: number) => void = () => {
  }
  onDirChange: (dir: string) => void = () => {
  }

  /** 当前生效的方向 */
  private currentDir(): string {
    if (this.dirOverride.length > 0) {
      return this.dirOverride
    }
    if (this.options.length === 0 || this.index >= this.options.length) {
      return 'ASC'
    }
    return this.options[this.index].dir
  }

  private currentLabel(): string {
    if (this.options.length === 0 || this.index >= this.options.length) {
      return ''
    }
    return this.options[this.index].label
  }

  build() {
    Row() {
      // 排序字段
      Row() {
        Text(this.currentLabel())
          .fontSize(12)
          .fontColor(this.theme.textPrimary)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(11)
          .fontColor([this.theme.textSecondary])
          .margin({ left: 3 })
      }
      .padding({ left: GAP_M, right: GAP_S, top: 7, bottom: 7 })
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .margin({ right: 6 })
      .bindMenu(buildSortMenu(this.options, this.index, this.theme, (idx: number) => {
        this.onIndexChange(idx)
      }))

      // 排序方向
      Text(this.currentDir() === 'DESC' ? '↓ 降序' : '↑ 升序')
        .fontSize(12)
        .fontColor(this.theme.brandColor)
        .padding({ left: GAP_M, right: GAP_M, top: 7, bottom: 7 })
        .backgroundColor(this.theme.chipBg)
        .borderRadius(RADIUS_CHIP)
        .onClick(() => {
          this.onDirChange(this.currentDir() === 'DESC' ? 'ASC' : 'DESC')
        })
    }
  }
}