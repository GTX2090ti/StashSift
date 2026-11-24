/**
 * StashSift — 玻璃材质与主题（API 26 沉浸式材质 + 明暗双主题）
 *
 * 真正「液态玻璃」三要素：
 * 1) 底层彩色渐变背景（提供可透出的内容）
 * 2) 面板半透明 + 系统材质模糊
 * 3) 亮色描边 + 投影，形成玻璃边缘
 */
import { uiMaterial, window } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppSettings } from '../settings/AppSettings'

/** 材质厚度档位 */
export enum GlassStyle {
  ULTRA_THIN = 0,
  THIN = 1,
  REGULAR = 2,
  THICK = 3,
  ULTRA_THICK = 4
}

/* ==================== HarmonyOS Design 设计令牌 ==================== */

/** 主色（官方品牌蓝） */
export const HMS_BRAND: string = '#FF0A59F7'
/** 主色-深色模式（提亮保证对比度） */
export const HMS_BRAND_DARK: string = '#FF5291FF'
/** 语义色 */
export const HMS_ERROR: string = '#FFE84026'
export const HMS_SUCCESS: string = '#FF64BB5C'
export const HMS_WARNING: string = '#FFFFB700'
/** 圆角：8vp 网格体系 */
export const HMS_RADIUS_CHIP: number = 8
export const HMS_RADIUS_CARD: number = 16
export const HMS_RADIUS_DIALOG: number = 24
/** 间距：8vp 网格 */
export const HMS_PAGE_H: number = 16
export const HMS_GAP_S: number = 8
export const HMS_GAP_M: number = 12
export const HMS_GAP_L: number = 16
/** 触控热区最小值 */
export const HMS_TOUCH_MIN: number = 40
/** 字号阶梯 */
export const HMS_FONT_TITLE: number = 20
export const HMS_FONT_SUBTITLE: number = 16
export const HMS_FONT_BODY: number = 14
export const HMS_FONT_CAPTION: number = 12
export const HMS_FONT_TINY: number = 10

/**
 * 玻璃边缘高光（1vp）——液态玻璃的「边」靠这一层认出来，不靠投影。
 * 顶部一条横向渐隐高光 + 四周一圈亮白描边。
 */
export const GLASS_EDGE_HI_LIGHT: string = '#B3FFFFFF'
export const GLASS_EDGE_HI_DARK: string = '#40FFFFFF'
/** 卡片局部遮罩：正文压在图/渐变上时垫在最底层，保证文字对比度 */
export const GLASS_SCRIM_LIGHT: string = '#26FFFFFF'
export const GLASS_SCRIM_DARK: string = '#33000000'

/** 玻璃主题色 */
export interface GlassTheme {
  cardBg: string
  cardBorder: string
  cardShadow: string
  dockBg: string
  scaffoldBg: string
  brandColor: string
  textPrimary: string
  textSecondary: string
  surfaceBg: string
  chipBg: string
  divider: string
  /** 1vp 顶部高光描边 */
  cardEdgeHi: string
  /** 顶栏玻璃底色（极淡，靠系统材质出雾感） */
  navBg: string
  /** 正文压图时的局部遮罩 */
  textScrim: string
  isDark: boolean
}

/** 浅色玻璃（卡片走低不透明度 + 系统材质，色相从底层渐变透上来） */
export const GLASS_THEME_LIGHT: GlassTheme = {
  cardBg: '#33FFFFFF',
  cardBorder: '#B8FFFFFF',
  cardShadow: '#1A000000',
  scaffoldBg: '#FFF2F4F8',
  dockBg: '#4DFFFFFF',
  brandColor: HMS_BRAND,
  textPrimary: '#FF000000',
  textSecondary: '#FF4A4A50',
  surfaceBg: '#F2FFFFFF',
  chipBg: '#CCF2F2F7',
  divider: '#FFF0F0F2',
  cardEdgeHi: GLASS_EDGE_HI_LIGHT,
  navBg: '#1FFFFFFF',
  textScrim: GLASS_SCRIM_LIGHT,
  isDark: false
}

/** 深色玻璃 */
export const GLASS_THEME_DARK: GlassTheme = {
  cardBg: '#2E333A4D',
  cardBorder: '#33FFFFFF',
  cardShadow: '#40000000',
  scaffoldBg: '#FF0E0F13',
  dockBg: '#8C1A1F2B',
  brandColor: HMS_BRAND_DARK,
  textPrimary: '#FFF5F5F7',
  textSecondary: '#FFB8B8C0',
  surfaceBg: '#F22A2F3D',
  chipBg: '#CC333A4A',
  divider: '#FF2C2F38',
  cardEdgeHi: GLASS_EDGE_HI_DARK,
  navBg: '#1A000000',
  textScrim: GLASS_SCRIM_DARK,
  isDark: true
}

/** 背景渐变 */
export interface GlassBackdrop {
  top: string
  mid: string
  bottom: string
  /** 图垫底时顶部压幕（半透明 top 色）——保证顶栏文字压在照片上仍可读 */
  veilTop: string
  /** 压幕过渡档 */
  veilMid: string
}

/**
 * 背景渐变：玻璃后面的「桌面」。
 * 提高色阶饱和度而不是堆白——卡片压在饱和渐变上，透过来的才是有色玻璃，
 * 压在浅灰白上永远是奶白板。
 */
export const GLASS_BG_LIGHT: GlassBackdrop = {
  top: '#FF86B7FF',
  mid: '#FFC0A6FF',
  bottom: '#FFFFA8CC',
  veilTop: '#D986B7FF',
  veilMid: '#7A86B7FF'
}

export const GLASS_BG_DARK: GlassBackdrop = {
  top: '#FF16244F',
  mid: '#FF0E0C16',
  bottom: '#FF3A1846',
  veilTop: '#D916244F',
  veilMid: '#7A16244F'
}

/** 当前主题（跟随设置） */
export function currentGlassTheme(): GlassTheme {
  try {
    const a: string = AppSettings.instance.appearance
    if (a === 'dark') {
      return GLASS_THEME_DARK
    }
    if (a === 'system' && AppSettings.instance.systemIsDark()) {
      return GLASS_THEME_DARK
    }
  } catch (e) {
    return GLASS_THEME_LIGHT
  }
  return GLASS_THEME_LIGHT
}

/** 当前背景渐变 */
export function currentBackdrop(): GlassBackdrop {
  try {
    const a: string = AppSettings.instance.appearance
    if (a === 'dark') {
      return GLASS_BG_DARK
    }
    if (a === 'system' && AppSettings.instance.systemIsDark()) {
      return GLASS_BG_DARK
    }
  } catch (e) {
    return GLASS_BG_LIGHT
  }
  return GLASS_BG_LIGHT
}

/**
 * 同步状态栏/导航栏：透明底 + 图标颜色跟随主题
 * 深色 → 白色图标；浅色 → 黑色图标
 */
export function syncSystemBar(ctx: common.UIAbilityContext, dark: boolean): void {
  // 先让应用色彩模式跟随主题（系统据此切换状态栏图标明暗）
  AppSettings.instance.applyColorMode(dark)
  try {
    window.getLastWindow(ctx).then((win: window.Window) => {
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: dark,
        isNavigationBarLightIcon: dark,
        statusBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
        navigationBarContentColor: dark ? '#FFFFFFFF' : '#FF000000'
      }).catch((e: BusinessError) => {
        console.error('[syncSystemBar] failed: ' + e.message)
      })
    }).catch(() => {
    })
  } catch (e) {
    console.error('[syncSystemBar] out of context')
  }
}

/** 是否支持沉浸式材质 */
export function isImmersiveSupported(): boolean {
  try {
    return uiMaterial.isImmersiveMaterialSupported()
  } catch (e) {
    return false
  }
}

/** 构造沉浸式材质 */
export function buildMaterial(style: GlassStyle): uiMaterial.Material {
  let s: uiMaterial.ImmersiveStyle = uiMaterial.ImmersiveStyle.REGULAR
  if (style === GlassStyle.ULTRA_THIN) {
    s = uiMaterial.ImmersiveStyle.ULTRA_THIN
  } else if (style === GlassStyle.THIN) {
    s = uiMaterial.ImmersiveStyle.THIN
  } else if (style === GlassStyle.THICK) {
    s = uiMaterial.ImmersiveStyle.THICK
  } else if (style === GlassStyle.ULTRA_THICK) {
    s = uiMaterial.ImmersiveStyle.ULTRA_THICK
  }

  if (!isImmersiveSupported()) {
    return uiMaterial.Material.empty
  }

  const options: uiMaterial.ImmersiveOptions = {
    style: s,
    materialColor: '#33FFFFFF',
    colorInvert: false,
    applyShadow: true,
    interactive: true
  }
  return new uiMaterial.ImmersiveMaterial(options)
}
