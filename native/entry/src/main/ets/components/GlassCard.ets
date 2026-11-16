/**
 * StashGo — 玻璃卡片（半透明 + 背景模糊，尺寸走令牌）
 */
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT } from '../common/GlassUtils'
import { PAD_PAGE, RADIUS_CARD, GAP_XS, GAP_S, NAV_SUB, GAP_L } from '../common/Responsive'

@Builder
function emptyBuilder() {
}

@Component
export struct GlassCard {
  @Prop style: GlassStyle = GlassStyle.REGULAR
  @Prop title: string = ''
  @Prop desc: string = ''
  @Prop theme: GlassTheme = GLASS_THEME_LIGHT
  @BuilderParam contentBuilder: () => void = emptyBuilder

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(GAP_L)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .width('100%')
          .margin({ bottom: GAP_XS })
      }
      if (this.desc.length > 0) {
        Text(this.desc)
          .fontSize(NAV_SUB)
          .fontColor(this.theme.textSecondary)
          .width('100%')
          .maxLines(2)
          .margin({ bottom: GAP_S })
      }
      this.contentBuilder()
    }
    .width('100%')
    .padding(PAD_PAGE)
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .shadow({ radius: 24, color: this.theme.cardShadow })
    .backdropBlur(24)
  }
}
