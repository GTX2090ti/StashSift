/**
 * StashSift — EntryAbility（沉浸式状态栏 + 明暗主题）
 */
import { UIAbility, Want, AbilityConstant, ConfigurationConstant, Configuration } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppSettings } from '../settings/AppSettings'
import { currentGlassTheme } from '../common/GlassUtils'
import { installErrorLogger } from '../common/ErrorLog'
import { NetSwitch } from '../common/NetSwitch'

const TAG: string = 'StashSift'

export default class EntryAbility extends UIAbility {
  private stage: window.WindowStage | null = null
  /** 曾经切到后台，回到前台需要上锁 */
  private needLock: boolean = false

  /** 多任务窗口 / 截屏模糊（跟生物识别锁联动，避免影响正常使用与无障碍读取） */
  private applyPrivacy(win: window.Window): void {
    const on: boolean = this.lockEnabled()
    try {
      win.setWindowPrivacyMode(on)
      hilog.info(0x0000, TAG, 'privacy mode=%{public}s', on.toString())
    } catch (e) {
      hilog.warn(0x0000, TAG, 'privacy mode failed')
    }
  }

  /** 是否开启了生物识别锁 */
  private lockEnabled(): boolean {
    return AppSettings.instance.biometricLock && AppSettings.instance.hasProfile
  }

  /** 回到前台时重新上锁 */
  private lockNow(): void {
    if (this.stage === null) {
      return
    }
    try {
      const win: window.Window = this.stage.getMainWindowSync()
      const ctx: UIContext = win.getUIContext()
      ctx.getRouter().replaceUrl({ url: 'pages/LockPage' }).catch(() => {
        hilog.warn(0x0000, TAG, 'lock route failed')
      })
    } catch (e) {
      hilog.warn(0x0000, TAG, 'lockNow failed')
    }
  }
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onCreate')
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'onWindowStageCreate')
    installErrorLogger()
    this.stage = windowStage

    AppSettings.instance.init(this.context)
    AppSettings.instance.load().then(async () => {
      // 内外网自动切换：启动时探一次内网，可达就用内网
      try {
        await NetSwitch.autoPick(true)
      } catch (e) {
        hilog.warn(0x0000, TAG, 'autoPick failed')
      }
      AppStorage.setOrCreate('systemDark',
        this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      const dark: boolean = currentGlassTheme().isDark
      // 让应用色彩模式跟随主题 → 系统状态栏图标自动明暗切换
      AppSettings.instance.applyColorMode(dark)
      windowStage.getMainWindow((err: BusinessError, win: window.Window) => {
        if (err !== undefined && err !== null && err.code !== 0) {
          hilog.error(0x0000, TAG, 'getMainWindow failed: %{public}s', JSON.stringify(err))
          return
        }
        // 1) 布局延伸到状态栏/导航栏下方
        win.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
          hilog.error(0x0000, TAG, 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(e))
        })
        // 2) 状态栏与导航栏完全透明，图标颜色跟随主题（深色白图标 / 浅色黑图标）
        const contentColor: string = dark ? '#FFFFFFFF' : '#FF000000'
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          isStatusBarLightIcon: dark,
          isNavigationBarLightIcon: dark,
          statusBarContentColor: contentColor,
          navigationBarContentColor: contentColor
        }).catch((e: BusinessError) => {
          hilog.error(0x0000, TAG, 'setWindowSystemBarProperties failed: %{public}s', JSON.stringify(e))
        })
        win.setWindowSystemBarEnable(['status', 'navigation']).catch(() => {
        })
        // 4) 记录底部导航条高度（vp），供悬浮导航贴合物理底边
        try {
          const avoid: window.AvoidArea =
            win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
          const vp: number = px2vp(avoid.bottomRect.height)
          AppStorage.setOrCreate('navInset', vp)
          hilog.info(0x0000, TAG, 'navInset vp=%{public}s', vp.toString())
        } catch (e) {
          hilog.warn(0x0000, TAG, 'getWindowAvoidArea failed')
        }
        // 多任务窗口模糊
        this.applyPrivacy(win)

        // 5) 响应式：发布窗口宽度（vp），并监听尺寸/方向变化
        try {
          const rect: window.Rect = win.getWindowProperties().windowRect
          AppStorage.setOrCreate('winWidthVp', px2vp(rect.width))
        AppStorage.setOrCreate('winHeightVp', px2vp(rect.height))
          const sysAvoid: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
          AppStorage.setOrCreate('statusInset', px2vp(sysAvoid.topRect.height))
          hilog.info(0x0000, TAG, 'winWidthVp=%{public}s', px2vp(rect.width).toString())
          win.on('windowSizeChange', (size: window.Size) => {
            AppStorage.setOrCreate('winWidthVp', px2vp(size.width))
        AppStorage.setOrCreate('winHeightVp', px2vp(size.height))
            hilog.info(0x0000, TAG, 'resize winWidthVp=%{public}s', px2vp(size.width).toString())
          })
          win.on('windowStatusChange', () => {
            const r: window.Rect = win.getWindowProperties().windowRect
            AppStorage.setOrCreate('winWidthVp', px2vp(r.width))
      AppStorage.setOrCreate('winHeightVp', px2vp(r.height))
          })
        } catch (e) {
          hilog.warn(0x0000, TAG, 'window size watch failed')
        }

      })

      AppStorage.setOrCreate('safeMode', AppSettings.instance.safeMode)
      let page: string = AppSettings.instance.hasProfile ? 'pages/HomePage' : 'pages/LoginPage'
      if (AppSettings.instance.biometricLock && AppSettings.instance.hasProfile) {
        page = 'pages/LockPage'
      }
      windowStage.loadContent(page, (err: BusinessError) => {
        if (err.code) {
          hilog.error(0x0000, TAG, 'loadContent failed: %{public}s', JSON.stringify(err))
        }
      })
    }).catch((e: BusinessError) => {
      hilog.error(0x0000, TAG, 'settings load failed: %{public}s', JSON.stringify(e))
      windowStage.loadContent('pages/LoginPage')
    })
  }

  /** 系统深浅色变化时通知所有页面 */
  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    AppStorage.setOrCreate('systemDark', isDark)
    hilog.info(0x0000, TAG, 'systemDark=%{public}s', isDark.toString())
    if (AppSettings.instance.appearance === 'system') {
      AppSettings.instance.applyColorMode(isDark)
      AppStorage.setOrCreate('themeVersion', Date.now())
    }
  }
  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, 'onForeground')
    // 从后台回来且开启了锁：立刻回锁屏
    if (this.needLock && this.lockEnabled()) {
      this.needLock = false
      this.lockNow()
    }
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, 'onBackground')
    // 切后台就标记需要上锁
    this.needLock = this.lockEnabled()
  }
}