/**
 * StashGo — AppSettings（ArkTS 原生）
 */
import { preferences } from '@kit.ArkData'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { Profile, ProfileDto } from '../models/Models'

export enum Appearance {
  SYSTEM = 'system',
  LIGHT = 'light',
  DARK = 'dark'
}

export enum AddrSlot {
  LAN = 'lan',
  WAN = 'wan'
}

export class AppSettings {
  static instance: AppSettings = new AppSettings()

  private prefs: preferences.Preferences | null = null
  private abilityContext: common.UIAbilityContext | null = null

  profiles: Profile[] = []
  currentProfileName: string = ''
  appearance: Appearance = Appearance.SYSTEM
  activeSlot: AddrSlot = AddrSlot.LAN
  safeMode: boolean = false
  biometricLock: boolean = false
  unlockedThisSession: boolean = false
  storageAvailable: boolean = true
  loaded: boolean = false

  private static readonly STORE_NAME: string = 'stashgo_settings'

  init(context: common.UIAbilityContext): void {
    this.abilityContext = context
  }

  /** 系统当前是否深色（用于「跟随系统」，由 EntryAbility 发布到 AppStorage） */
  systemIsDark(): boolean {
    const v: boolean | undefined = AppStorage.get<boolean>('systemDark')
    if (v !== undefined) {
      return v
    }
    if (this.abilityContext === null) {
      return false
    }
    try {
      const mode: ConfigurationConstant.ColorMode | undefined = this.abilityContext.config.colorMode
      return mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    } catch (e) {
      return false
    }
  }

  /**
   * 让应用色彩模式跟随主题。
   * 系统据此自动决定状态栏/导航栏图标颜色（深色→白图标，浅色→黑图标），
   * 比单独设 statusBarContentColor 更可靠。
   */
  applyColorMode(dark: boolean): void {
    if (this.abilityContext === null) {
      return
    }
    try {
      const appCtx = this.abilityContext.getApplicationContext()
      appCtx.setColorMode(dark
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    } catch (e) {
      console.error('[AppSettings] setColorMode failed')
    }
  }

  get currentProfile(): Profile | null {
    if (this.profiles.length === 0) {
      return null
    }
    for (let i = 0; i < this.profiles.length; i++) {
      if (this.profiles[i].name === this.currentProfileName) {
        return this.profiles[i]
      }
    }
    return this.profiles[0]
  }

  get hasProfile(): boolean {
    const p: Profile | null = this.currentProfile
    if (p === null) {
      return false
    }
    return AppSettings.normalizeBase(p.lanUrl).length > 0 ||
      AppSettings.normalizeBase(p.wanUrl).length > 0
  }

  get lanUrl(): string {
    const p: Profile | null = this.currentProfile
    return p === null ? '' : AppSettings.normalizeBase(p.lanUrl)
  }

  get wanUrl(): string {
    const p: Profile | null = this.currentProfile
    return p === null ? '' : AppSettings.normalizeBase(p.wanUrl)
  }

  /** 手动指定内外网（自动切换用） */
  setSlot(slot: AddrSlot): void {
    this.activeSlot = slot
  }

  /** 当前是否在用内网 */
  isLan(): boolean {
    return this.activeSlot === AddrSlot.LAN
  }
  get baseUrl(): string {
    const cur: string = this.activeSlot === AddrSlot.LAN ? this.lanUrl : this.wanUrl
    if (cur.length > 0) {
      return cur
    }
    const other: string = this.activeSlot === AddrSlot.LAN ? this.wanUrl : this.lanUrl
    if (other.length > 0) {
      this.activeSlot = this.activeSlot === AddrSlot.LAN ? AddrSlot.WAN : AddrSlot.LAN
    }
    return other
  }

  get apiKey(): string {
    const p: Profile | null = this.currentProfile
    return p === null ? '' : p.apiKey
  }

  get profileName(): string {
    const p: Profile | null = this.currentProfile
    return p === null ? '' : p.name
  }

  static normalizeBase(base: string): string {
    let s: string = base === null || base === undefined ? '' : base.trim()
    if (s.length === 0) {
      return ''
    }
    if (s.indexOf('://') < 0) {
      s = 'http://' + s
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1)
    }
    return s
  }

  async load(): Promise<void> {
    try {
      if (this.abilityContext === null) {
        this.storageAvailable = false
        this.loaded = true
        return
      }
      this.prefs = await preferences.getPreferences(this.abilityContext, AppSettings.STORE_NAME)
      const raw: preferences.ValueType = await this.prefs.get('profiles_v1', '')
      const rawStr: string = raw as string
      if (rawStr.length > 0) {
        const arr = JSON.parse(rawStr) as ProfileDto[]
        const list: Profile[] = []
        for (let i = 0; i < arr.length; i++) {
          list.push(Profile.fromDto(arr[i]))
        }
        this.profiles = list
      }
      const cur: preferences.ValueType = await this.prefs.get('current_profile', '')
      const curStr: string = cur as string
      if (curStr.length > 0) {
        this.currentProfileName = curStr
      } else if (this.profiles.length > 0) {
        this.currentProfileName = this.profiles[0].name
      }
      const ap: preferences.ValueType = await this.prefs.get('appearance', 'system')
      const apStr: string = ap as string
      if (apStr === 'light') {
        this.appearance = Appearance.LIGHT
      } else if (apStr === 'dark') {
        this.appearance = Appearance.DARK
      } else {
        this.appearance = Appearance.SYSTEM
      }
      const slot: preferences.ValueType = await this.prefs.get('active_slot', 'lan')
      this.activeSlot = (slot as string) === 'wan' ? AddrSlot.WAN : AddrSlot.LAN
      const safe: preferences.ValueType = await this.prefs.get('safe_mode', false)
      this.safeMode = safe as boolean
      const bio: preferences.ValueType = await this.prefs.get('biometric_lock', false)
      this.biometricLock = bio as boolean
      this.storageAvailable = true
    } catch (e) {
      this.storageAvailable = false
      this.profiles = []
    }
    this.loaded = true
  }

  async upsertProfile(p: Profile): Promise<void> {
    let found: boolean = false
    for (let i = 0; i < this.profiles.length; i++) {
      if (this.profiles[i].name === p.name) {
        this.profiles[i] = p
        found = true
        break
      }
    }
    if (!found) {
      this.profiles.push(p)
    }
    if (this.currentProfileName.length === 0) {
      this.currentProfileName = p.name
    }
    await this.flush()
  }

  async removeProfile(name: string): Promise<void> {
    const list: Profile[] = []
    for (let i = 0; i < this.profiles.length; i++) {
      if (this.profiles[i].name !== name) {
        list.push(this.profiles[i])
      }
    }
    this.profiles = list
    if (this.currentProfileName === name) {
      this.currentProfileName = this.profiles.length > 0 ? this.profiles[0].name : ''
    }
    await this.flush()
  }

  async switchTo(name: string): Promise<void> {
    this.currentProfileName = name
    await this.flush()
  }

  async flush(): Promise<void> {
    if (!this.storageAvailable || this.prefs === null) {
      return
    }
    try {
      const arr: ProfileDto[] = []
      for (let i = 0; i < this.profiles.length; i++) {
        const p: Profile = this.profiles[i]
        const dto: ProfileDto = {
          'name': p.name,
          'lanUrl': p.lanUrl,
          'wanUrl': p.wanUrl,
          'apiKey': p.apiKey
        }
        arr.push(dto)
      }
      await this.prefs.put('profiles_v1', JSON.stringify(arr))
      await this.prefs.put('current_profile', this.currentProfileName)
      await this.prefs.put('appearance', this.appearance)
      await this.prefs.put('active_slot', this.activeSlot)
      await this.prefs.put('safe_mode', this.safeMode)
      await this.prefs.put('biometric_lock', this.biometricLock)
      await this.prefs.flush()
    } catch (e) {
      this.storageAvailable = false
    }
  }
}
