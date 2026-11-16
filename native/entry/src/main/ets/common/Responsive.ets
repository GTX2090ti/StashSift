/**
 * StashSift — 响应式布局（对齐鸿蒙断点体系）
 *
 * 断点（vp）：
 *   sm  < 600   手机，2 列
 *   md  600-839 折叠展开 / 小平板，3 列
 *   lg  840-1199 平板，4 列
 *   xl  >= 1200 大屏 / 2in1，6 列
 */

export enum Breakpoint {
  SM = 0,
  MD = 1,
  LG = 2,
  XL = 3
}

/** 某一断点下的布局参数 */
export class LayoutSpec {
  columns: number = 2
  pagePadding: number = 16
  gap: number = 10
  /** 内容最大宽度，超宽屏时居中 */
  maxContentWidth: number = 9999
  /** 悬浮 dock 最大宽度 */
  dockMaxWidth: number = 9999
  /** 字号缩放（保持与手机一致） */
  titleSize: number = 16

  constructor(columns: number, pagePadding: number, gap: number,
    maxContentWidth: number, dockMaxWidth: number, titleSize: number) {
    this.columns = columns
    this.pagePadding = pagePadding
    this.gap = gap
    this.maxContentWidth = maxContentWidth
    this.dockMaxWidth = dockMaxWidth
    this.titleSize = titleSize
  }
}

export function breakpointOf(widthVp: number): Breakpoint {
  if (widthVp >= 1200) {
    return Breakpoint.XL
  }
  if (widthVp >= 840) {
    return Breakpoint.LG
  }
  if (widthVp >= 600) {
    return Breakpoint.MD
  }
  return Breakpoint.SM
}

export function layoutFor(widthVp: number): LayoutSpec {
  const bp: Breakpoint = breakpointOf(widthVp)
  if (bp === Breakpoint.XL) {
    return new LayoutSpec(6, 32, 16, 1440, 560, 18)
  }
  if (bp === Breakpoint.LG) {
    return new LayoutSpec(4, 24, 14, 1200, 520, 18)
  }
  if (bp === Breakpoint.MD) {
    return new LayoutSpec(3, 20, 12, 900, 480, 16)
  }
  return new LayoutSpec(2, 16, 10, 9999, 9999, 16)
}

/** 生成 columnsTemplate 字符串 */
export function columnsTemplate(n: number): string {
  let s: string = ''
  for (let i = 0; i < n; i++) {
    if (i > 0) {
      s = s + ' '
    }
    s = s + '1fr'
  }
  return s
}

/** 计算双列/多列卡片宽度百分比（用于 Flex 布局） */
export function itemWidthPercent(n: number): string {
  const w: number = (100 / n) - 1.5
  return w.toFixed(1) + '%'
}

/* ==================== 尺寸令牌（替代散落的固定值） ==================== */

/** 页面内边距（vp） */
export const PAD_PAGE: number = 16
/** 元素间距 */
export const GAP_XS: number = 4
export const GAP_S: number = 8
export const GAP_M: number = 12
export const GAP_L: number = 16
/** 圆角 */
export const RADIUS_XS: number = 4
export const RADIUS_S: number = 6
export const RADIUS_CHIP: number = 8
export const RADIUS_CARD: number = 16
export const RADIUS_DOCK: number = 28
/** 顶栏 */
export const NAV_PAD_V: number = 10
export const NAV_TITLE: number = 20
export const NAV_SUB: number = 12
/** 悬浮 dock */
export const DOCK_H: number = 56
export const DOCK_ITEM_W: number = 64
export const DOCK_ITEM_H: number = 48
export const DOCK_ICON: number = 19
export const DOCK_LABEL: number = 10
export const DOCK_MARGIN: number = 24
/** 卡片文字 */
export const CARD_TITLE: number = 13
export const CARD_META: number = 11
/** 触控最小高度 */
export const TOUCH_MIN: number = 44