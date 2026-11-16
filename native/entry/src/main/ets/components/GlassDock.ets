/**
 * StashSift — 悬浮胶囊底部导航（公共组件）
 *
 * isRoot = true  用于主页：点击其它标签走 pushUrl（主页始终在栈底）
 * isRoot = false 用于其它标签页：点主页走 back()，点其它标签走 replaceUrl（避免栈无限增长）
 */
import { router } from '@kit.ArkUI'
import { GlassTheme, GLASS_THEME_LIGHT } from '../common/GlassUtils'
import {
  DOCK_H, DOCK_ITEM_W, DOCK_ITEM_H, DOCK_ICON, DOCK_LABEL,
  DOCK_MARGIN, RADIUS_DOCK, PAD_PAGE, GAP_XS
} from '../common/Responsive'
import { L10n } from '../settings/L10n'

@Component
export struct GlassDock {
  /** 当前选中项：0 主页 / 1 短片 / 2 收藏 / 3 资料库 / 4 设置 */
  @Prop current: number = 0
  @Prop isRoot: boolean = false
  @Prop theme: GlassTheme = GLASS_THEME_LIGHT
  @StorageProp('winWidthVp') winW: number = 360

  private icons: Resource[] = [
    $r('sys.symbol.house'),
    $r('sys.symbol.film'),
    $r('sys.symbol.star'),
    $r('sys.symbol.book'),
    $r('sys.symbol.gearshape')
  ]
  private titles: string[] = ['主页', '短片', '收藏', '资料库', '设置']
  private routes: string[] = [
    'pages/HomePage',
    'pages/SceneListPage',
    'pages/FavoritesPage',
    'pages/LibraryPage',
    'pages/SettingsPage'
  ]

  private go(index: number): void {
    if (index === this.current) {
      return
    }
    if (!this.isRoot && index === 0) {
      // 标签页返回主页：首页始终在栈底
      router.back()
      return
    }
    if (this.isRoot) {
      router.pushUrl({ url: this.routes[index] })
    } else {
      router.replaceUrl({ url: this.routes[index] })
    }
  }

  @Builder
  navItem(index: number) {
    Column() {
      SymbolGlyph(this.icons[index])
        .fontSize(DOCK_ICON)
        .fontColor([this.current === index ? this.theme.brandColor : this.theme.textSecondary])
      Text(L10n.translate(this.titles[index]))
        .fontSize(DOCK_LABEL)
        .fontColor(this.current === index ? this.theme.brandColor : this.theme.textSecondary)
        .margin({ top: GAP_XS / 2 })
    }
    .width(DOCK_ITEM_W)
    .height(DOCK_ITEM_H)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(DOCK_ITEM_H / 2)
    .backgroundColor(this.current === index ? this.theme.chipBg : Color.Transparent)
    .onClick(() => {
      this.go(index)
    })
  }

  build() {
    Column() {
      Row() {
        this.navItem(0)
        this.navItem(1)
        this.navItem(2)
        this.navItem(3)
        this.navItem(4)
      }
      .width('100%')
      .height(DOCK_H)
      .padding({ left: GAP_XS, right: GAP_XS })
      .justifyContent(FlexAlign.SpaceEvenly)
      .backgroundColor(this.theme.dockBg)
      .borderRadius(RADIUS_DOCK)
      .border({ width: 1, color: this.theme.cardBorder })
      .shadow({ radius: 24, color: this.theme.cardShadow })
      .backdropBlur(30)
    }
    .width('100%')
    .padding({ left: PAD_PAGE, right: PAD_PAGE })
    .margin({ bottom: DOCK_MARGIN })
  }
}
