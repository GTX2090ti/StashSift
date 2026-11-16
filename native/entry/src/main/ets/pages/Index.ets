/**
 * LiquidGlass Demo — 主页面（API 26）
 *
 * 演示：
 * - 顶部玻璃导航栏（沉浸式，内容穿透）
 * - 玻璃卡片画廊（不同材质厚度）
 * - 浅色/深色主题切换，玻璃效果随主题适配
 */
import { GlassCard, GlassStyle } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassTheme, GLASS_THEME_DARK, GLASS_THEME_LIGHT } from '../common/GlassUtils'

@Entry
@Component
struct Index {
  @State theme: GlassTheme = GLASS_THEME_LIGHT
  @State dark: boolean = false

  build() {
    Column() {
      // 顶部玻璃导航栏
      GlassNavBar({
        title: $r('app.string.app_name'),
        subtitle: $r('app.string.section_title'),
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          this.buildGlassGallery()
          this.buildThemeToggle()
        }
        .width('100%')
        .padding({ bottom: 24 })
      }
      .width('100%')
      .flexGrow(1)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private buildGlassGallery() {
    Column() {
      this.buildCardRow(GlassStyle.ULTRA_THIN, $r('app.string.style_thin'), '超薄材质，透明感最强，适合浮层提示')
      this.buildCardRow(GlassStyle.THIN, $r('app.string.style_thin'), '薄材质，轻微模糊，适合列表项')
      this.buildCardRow(GlassStyle.REGULAR, $r('app.string.style_regular'), '常规玻璃卡片，模糊与透明平衡')
      this.buildCardRow(GlassStyle.THICK, $r('app.string.style_thick'), '厚重材质，模糊感强，适合主卡片')
      this.buildCardRow(GlassStyle.ULTRA_THICK, 'Ultra Thick', '最厚材质，近似毛玻璃，适合弹窗背景')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }

  private buildCardRow(style: GlassStyle, label: string, desc: string) {
    GlassCard({
      style: style,
      title: label,
      desc: desc,
      theme: this.theme
    }) {
      Column() {
        Row() {
          Text('内容区')
            .fontSize(14)
            .fontColor('#33000000')
          Spacer()
          Image($r('app.media.icon'))
            .width(28).height(28)
            .borderRadius(8)
        }
        .padding({ top: 8 })
      }
      .width('100%')
      .height(120)
    }
    .margin({ bottom: 12 })
  }

  private buildThemeToggle() {
    Column() {
      Row() {
        Text($r('app.string.toggle_theme'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#33000000')
        Spacer()
        Button(this.dark ? $r('app.string.theme_light') : $r('app.string.theme_dark'))
          .fontSize(14)
          .width(80)
          .height(32)
          .backgroundColor(this.theme.brandColor)
          .fontColor(Color.White)
          .borderRadius(16)
          .onClick(() => {
            this.dark = !this.dark
            this.theme = this.dark ? GLASS_THEME_DARK : GLASS_THEME_LIGHT
          })
      }
      .padding({ left: 16, right: 16, top: 20, bottom: 24 })
    }
    .width('100%')
  }
}
