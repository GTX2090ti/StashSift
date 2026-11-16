/**
 * StashSift — 登录页（ArkTS 原生）
 */
import { router } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Profile } from '../models/Models'
import { L10n } from '../settings/L10n'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'

@Entry
@Component
struct LoginPage {
  @State nameText: string = ''
  @State lanText: string = ''
  @State wanText: string = ''
  @State keyText: string = ''
  @State testing: boolean = false
  @State saving: boolean = false
  @State status: string = ''
  @State statusError: boolean = false
  @State profileNames: string[] = []
  @State profileDesc: string[] = []

  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    const p: Profile | null = AppSettings.instance.currentProfile
    if (p !== null) {
      this.nameText = p.name
      this.lanText = p.lanUrl
      this.wanText = p.wanUrl
      this.keyText = p.apiKey
    } else {
      this.nameText = 'Stash'
    }
    this.refreshProfiles()
  }

  private refreshProfiles(): void {
    const names: string[] = []
    const descs: string[] = []
    for (let i = 0; i < AppSettings.instance.profiles.length; i++) {
      const p: Profile = AppSettings.instance.profiles[i]
      names.push(p.name)
      const parts: string[] = []
      if (p.lanUrl.length > 0) {
        parts.push(p.lanUrl)
      }
      if (p.wanUrl.length > 0) {
        parts.push(p.wanUrl)
      }
      descs.push(parts.join('  ·  '))
    }
    this.profileNames = names
    this.profileDesc = descs
  }

  private collect(): Profile {
    const name: string = this.nameText.trim().length > 0 ? this.nameText.trim() : 'Stash'
    return new Profile(
      name,
      AppSettings.normalizeBase(this.lanText),
      AppSettings.normalizeBase(this.wanText),
      this.keyText.trim()
    )
  }

  private valid(): boolean {
    return this.lanText.trim().length > 0 || this.wanText.trim().length > 0
  }

  private async doTest(): Promise<void> {
    if (!this.valid()) {
      this.statusError = true
      this.status = L10n.translate('请至少填写一个地址')
      return
    }
    this.testing = true
    this.statusError = false
    this.status = L10n.translate('测试中…')
    const p: Profile = this.collect()
    const base: string = p.lanUrl.length > 0 ? p.lanUrl : p.wanUrl
    try {
      const api = new StashApi(base, p.apiKey)
      const v: string = await api.version()
      this.statusError = false
      this.status = '连接成功，Stash 版本 ' + v
    } catch (e) {
      this.statusError = true
      this.status = '连接失败：' + (e as Error).message
    }
    this.testing = false
  }

  private async doSave(): Promise<void> {
    if (!this.valid()) {
      this.statusError = true
      this.status = L10n.translate('请至少填写一个地址')
      return
    }
    this.saving = true
    await AppSettings.instance.upsertProfile(this.collect())
    this.saving = false
    router.replaceUrl({ url: 'pages/HomePage' })
  }

  @Builder
  fieldRow(label: string, hint: string, value: string, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.theme.textSecondary)
        .width(80)
      TextInput({ text: value, placeholder: hint })
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.theme.cardBg)
    .borderRadius(8)
    .margin({ bottom: 10 })
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  /** 系统深浅色变化时即时跟随 */
  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }
  /** 返回本页时刷新主题（设置页切换外观后立即生效） */
  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }
  build() {
    Column() {
      GlassNavBar({
        title: 'StashSift',
        subtitle: L10n.translate('连接到 Stash 服务器'),
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          this.fieldRow(L10n.translate('档案名称'), 'Stash', this.nameText, (v: string) => {
            this.nameText = v
          })
          this.fieldRow(L10n.translate('内网地址'), 'http://192.168.1.10:9999', this.lanText, (v: string) => {
            this.lanText = v
          })
          this.fieldRow(L10n.translate('外网地址'), 'http://example.com:9999', this.wanText, (v: string) => {
            this.wanText = v
          })
          this.fieldRow('ApiKey', '点击 Stash 设置获取', this.keyText, (v: string) => {
            this.keyText = v
          })

          Row() {
            Button(this.testing ? L10n.translate('测试中…') : L10n.translate('测试连接'))
              .layoutWeight(1)
              .height(44)
              .backgroundColor('#FF0A59F7')
              .fontColor(Color.White)
              .fontSize(16)
              .borderRadius(8)
              .enabled(!this.testing)
              .onClick(() => {
                this.doTest()
              })
            Blank().width(10)
            Button(this.saving ? L10n.translate('加载中…') : L10n.translate('保存并进入'))
              .layoutWeight(1)
              .height(44)
              .backgroundColor('#FF0A59F7')
              .fontColor(Color.White)
              .fontSize(16)
              .borderRadius(8)
              .enabled(!this.saving)
              .onClick(() => {
                this.doSave()
              })
          }
          .width('100%')
          .margin({ top: 8 })

          if (this.status.length > 0) {
            Text(this.status)
              .fontSize(12)
              .fontColor(this.statusError ? '#FFE84026' : '#FF64BB5C')
              .width('100%')
              .margin({ top: 10 })
          }

          if (this.profileNames.length > 1) {
            Text(L10n.translate('已有档案'))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
              .width('100%')
              .margin({ top: 20, bottom: 8 })
            ForEach(this.profileNames, (name: string, idx: number) => {
              Row() {
                Column() {
                  Text(name)
                    .fontSize(14)
                    .fontColor(this.theme.textPrimary)
                  Text(this.profileDesc[idx])
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(name === AppSettings.instance.currentProfileName ? this.theme.chipBg : this.theme.cardBg)
              .borderRadius(8)
              .margin({ bottom: 6 })
              .onClick(() => {
                const p: Profile | null = AppSettings.instance.currentProfile
                if (p !== null) {
                  this.nameText = p.name
                  this.lanText = p.lanUrl
                  this.wanText = p.wanUrl
                  this.keyText = p.apiKey
                }
              })
            }, (name: string) => name)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .layoutWeight(1)
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
