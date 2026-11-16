/**
 * StashSift — 五星评分
 *
 * Stash 用 0–100 存评分，这里映射成 1 星 = 20 分。
 * 点当前星再点一次可清零。
 */
import { RADIUS_CHIP } from '../common/Responsive'

@Component
export struct StarRating {
  /** 0–100 */
  @Prop value: number = 0
  @Prop starSize: number = 22
  @Prop filledColor: string = '#FFFFB700'
  @Prop emptyColor: string = '#33000000'
  @Prop showValue: boolean = true
  onChange: (v: number) => void = () => {
  }

  private stars(): number {
    return Math.round(this.value / 20)
  }

  build() {
    Row() {
      ForEach([1, 2, 3, 4, 5], (i: number) => {
        SymbolGlyph(i <= this.stars() ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(this.starSize)
          .fontColor([i <= this.stars() ? this.filledColor : this.emptyColor])
          .margin({ right: 6 })
          .onClick(() => {
            this.onChange(this.value === i * 20 ? 0 : i * 20)
          })
      }, (i: number) => i.toString())

      if (this.showValue) {
        Text(this.value === 0 ? '未评分' : (this.value / 20).toFixed(1) + ' 星')
          .fontSize(11)
          .fontColor('#99333333')
          .margin({ left: 2 })
      }
    }
    .alignItems(VerticalAlign.Center)
  }
}
