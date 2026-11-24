/**
 * StashSift — 玻璃导航栏
 *
 * 页面根容器会 expandSafeArea 到状态栏下方（背景渐变铺满），
 * 所以这里必须自己补上状态栏高度的顶部内边距，标题才不会被状态栏盖住。
 * 尺寸全部走令牌，不再写死。
 */
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT } from '../common/GlassUtils'
import { PAD_PAGE, NAV_PAD_V, NAV_TITLE, NAV_SUB, GAP_XS } from '../common/Responsive'

@Component
export struct GlassNavBar {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop theme: GlassTheme = GLASS_THEME_LIGHT
  @Prop style: GlassStyle = GlassStyle.REGULAR
  /** 是否在顶栏右侧显示搜索图标 */
  @Prop showSearch: boolean = false
  /** 搜索是否已展开（展开时图标变成关闭） */
  @Prop searchActive: boolean = false
  onSearchTap: () => void = () => {}
  /** 后台任务数（>0 时顶栏显示任务按钮） */
  @Prop taskCount: number = 0
  onTaskTap: () => void = () => {}
  @StorageProp('statusInset') statusInset: number = 0

  build() {
    Row() {
      Column() {
        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(NAV_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(NAV_SUB)
            .fontColor(this.theme.textSecondary)
            .maxLines(1)
            .margin({ top: GAP_XS })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.taskCount > 0) {
        Row() {
          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(17)
            .fontColor([this.theme.brandColor])
          Text(this.taskCount.toString())
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor(this.theme.brandColor)
            .borderRadius(8)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .margin({ left: 2 })
        }
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .onClick(() => {
          this.onTaskTap()
        })
      }
      if (this.showSearch) {
        // 一下展开、再一下收起
        SymbolGlyph(this.searchActive
          ? $r('sys.symbol.xmark')
          : $r('sys.symbol.magnifyingglass'))
          .fontSize(19)
          .fontColor([this.theme.textPrimary])
          .padding({ left: 10, right: 0, top: 6, bottom: 6 })
          .onClick(() => {
            this.onSearchTap()
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: PAD_PAGE,
      right: PAD_PAGE,
      top: this.statusInset + NAV_PAD_V,
      bottom: NAV_PAD_V
    })
    // 极淡玻璃条：压在纯渐变上几乎看不见，压在图/内容上才有雾面和底边
    .backgroundColor(this.theme.navBg)
    .backgroundEffect({ radius: 20, saturation: 1.35 })
    .border({ width: { bottom: 1 }, color: this.theme.divider })
  }
}