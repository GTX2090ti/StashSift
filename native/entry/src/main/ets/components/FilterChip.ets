/**
 * StashSift — 筛选用的可选标签块（chip）
 *
 * 为什么单独做成 @Component 而不是页面里的 @Builder：
 * ArkUI 的 @Builder 按值传参不会订阅状态变化，参数里的 active 会永远停在首屏渲染的值，
 * 表现就是「点了没反应」。组件用 @Prop 才能跟随父页面状态刷新。
 */
import { GlassTheme, GLASS_THEME_LIGHT } from '../common/GlassUtils'
import { RADIUS_CHIP, GAP_S } from '../common/Responsive'

@Component
export struct FilterChip {
  @Prop label: string = ''
  @Prop active: boolean = false
  @Prop theme: GlassTheme = GLASS_THEME_LIGHT
  onTap: () => void = () => {}

  build() {
    Text(this.label)
      .fontSize(12)
      .fontColor(this.active ? Color.White : this.theme.textPrimary)
      .backgroundColor(this.active ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .margin({ right: GAP_S, bottom: GAP_S })
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .onClick(() => {
        this.onTap()
      })
  }
}
