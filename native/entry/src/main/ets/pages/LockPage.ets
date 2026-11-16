/**
 * StashSift — 锁屏（生物识别解锁后才能进入资料库）
 */
import { router } from '@kit.ArkUI'
import { authenticateBiometric, BiometricResult, biometricAvailable } from '../common/Biometric'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'

@Entry
@Component
struct LockPage {
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  @State message: string = '需要验证身份才能继续'
  @State busy: boolean = false
  @State supported: boolean = true

  aboutToAppear(): void {
    this.supported = biometricAvailable()
    if (!this.supported) {
      this.message = '此设备未录入人脸或指纹'
    } else {
      this.unlock()
    }
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

  private unlock(): void {
    if (this.busy) {
      return
    }
    this.busy = true
    this.message = '正在验证…'
    authenticateBiometric('解锁 StashSift', (r: BiometricResult) => {
      this.busy = false
      if (r.ok) {
        this.message = '验证通过'
        router.replaceUrl({ url: 'pages/HomePage' })
      } else {
        this.message = r.message
      }
    })
  }

  build() {
    Column() {
      Blank()

      Column() {
        SymbolGlyph($r('sys.symbol.lock_fill'))
          .fontSize(44)
          .fontColor([this.theme.brandColor])
          .margin({ bottom: GAP_M })

        Text(L10n.translate('StashSift'))
          .fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)

        Text(this.message)
          .fontSize(12)
          .fontColor(this.theme.textSecondary)
          .margin({ top: GAP_S })
          .textAlign(TextAlign.Center)

        Text(this.busy ? '验证中…' : (this.supported ? '点击验证身份' : '设备不支持'))
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(this.supported ? this.theme.brandColor : this.theme.chipBg)
          .borderRadius(RADIUS_CHIP)
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .margin({ top: GAP_M + 4 })
          .onClick(() => {
            if (this.supported) {
              this.unlock()
            }
          })

        if (!this.supported) {
          Text('可在「设置 → 生物识别锁」中关闭')
            .fontSize(11).fontColor(this.theme.textSecondary)
            .margin({ top: GAP_M })
          Text('直接进入')
            .fontSize(13).fontColor(this.theme.brandColor)
            .margin({ top: GAP_S })
            .onClick(() => {
              router.replaceUrl({ url: 'pages/HomePage' })
            })
        }
      }
      .width('100%')
      .padding(PAD_PAGE + 8)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.theme.cardBg)
      .borderRadius(RADIUS_CARD)
      .border({ width: 1, color: this.theme.cardBorder })
      .backdropBlur(24)
      .margin({ left: PAD_PAGE + 8, right: PAD_PAGE + 8 })

      Blank()
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
