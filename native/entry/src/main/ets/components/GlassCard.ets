/**
 * StashSift — 玻璃卡片
 *
 * 三层叠出「液态玻璃」：
 * 1) backgroundEffect（真实高斯背景模糊 + 饱和度提升）负责模糊与色相透出
 * 2) 低不透明度底色（theme.cardBg，浅色 20% / 深色 18%）让底层色相透上来
 * 3) 1vp 顶部渐隐高光 + 一圈亮描边，给出玻璃边缘
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

  /** 材质厚度 → 模糊半径（与旧的 backdropBlur 档位一致，只是补了饱和度） */
  private blurRadius(): number {
    if (this.style === GlassStyle.THIN || this.style === GlassStyle.ULTRA_THIN) {
      return 18
    }
    if (this.style === GlassStyle.THICK || this.style === GlassStyle.ULTRA_THICK) {
      return 30
    }
    return 24
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
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

      // 顶部 1vp 高光：两端渐隐，中间最亮 —— 玻璃的上边缘反光
      Row()
        .width('100%')
        .height(1)
        .linearGradient({
          angle: 90,
          colors: [['#00FFFFFF', 0.0], [this.theme.cardEdgeHi, 0.5], ['#00FFFFFF', 1.0]]
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backgroundEffect({ radius: this.blurRadius(), saturation: 1.35 })
    .shadow({ radius: 24, color: this.theme.cardShadow })
    .clip(true)
  }
}