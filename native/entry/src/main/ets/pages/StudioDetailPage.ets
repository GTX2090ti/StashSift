/**
 * StashSift — 工作室详情（分组折叠结构，与演员详情一致）
 */
import { router, promptAction } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Studio, StudioDto, StudioRefDto, StudioUpdate, Scene, SceneDto, Tag } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { layoutFor, RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'
import { bumpScenes } from '../common/DataVersion'
import { PickItem, loadOptions as loadOptionList } from '../common/OptionCache'

@Entry
@Component
struct StudioDetailPage {
  @State studio: Studio = new Studio('', '')
  @State scenes: Scene[] = []
  @State loading: boolean = true
  @State scenesLoading: boolean = false
  @State hasMore: boolean = true
  @State errorText: string = ''
  @State openStats: boolean = false
  @State openTree: boolean = false
  @State openLinks: boolean = false
  @State openTags: boolean = false
  /** 入场参数校验：拿不到 id 时置 false，页面不渲染内容（随即退回上一页） */
  @State paramOk: boolean = true
  /** 作品列表搜索（服务端 q 过滤，不是本地筛已加载的页） */
  @State searchMode: boolean = false
  @State keyword: string = ''
  // ── 编辑态 ───────────────────────────────────────────
  @State editMode: boolean = false
  @State busy: boolean = false
  @State toast: string = ''
  @State editName: string = ''
  @State editAliases: string = ''
  @State editUrls: string = ''
  @State editDetails: string = ''
  @State editFavorite: boolean = false
  @State editOrganized: boolean = false
  @State editRating: string = ''
  @State editParentId: string = ''
  @State editParentName: string = ''
  @State pickOpen: boolean = false
  @State pickQuery: string = ''
  @State pickList: PickItem[] = []
  @State pickLoading: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  @StorageProp('winWidthVp') winW: number = 360
  private studioId: string = ''
  /** 当前父工作室 id（Studio 模型只带名字，id 从 DTO 里取） */
  private parentIdOf: string = ''
  private page: number = 1
  private pageSize: number = 24

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string>
    let id: string = ''
    if (p !== undefined && p !== null) {
      const raw: string | undefined = p['id']
      if (raw !== undefined && raw !== null) {
        id = raw.trim()
      }
    }
    // 没有 id 就是无效进入：不渲染空壳、不发任何 GraphQL 请求，直接退回上一页
    if (id.length === 0) {
      this.paramOk = false
      this.say('缺少工作室参数，已返回')
      try {
        router.back()
      } catch (e) {
        console.error('[StudioDetail] back failed')
      }
      return
    }
    this.studioId = id
    this.loadAll()
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

  private async loadAll(): Promise<void> {
    this.loading = true
    this.errorText = ''
    try {
      const api = this.api()
      const dto: StudioDto | null = await api.findStudio(this.studioId)
      if (dto !== null) {
        this.studio = Studio.fromDto(dto)
        const pst: StudioRefDto | undefined = dto.parent_studio
        this.parentIdOf = (pst === undefined || pst === null || pst.id === undefined
          || pst.id === null) ? '' : pst.id
      }
      this.page = 1
      this.hasMore = true
      this.scenes = []
      await this.loadScenes()
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
    }
    this.loading = false
  }

  /** 关键词变了：回到第一页重拉（服务端过滤，翻页语义才正确） */
  private async reloadScenesByKeyword(): Promise<void> {
    this.page = 1
    this.hasMore = true
    this.scenes = []
    await this.loadScenes()
  }

  /** 短片区块标题：搜索态带上关键词，让用户明确当前是筛选结果 */
  private sceneSectionTitle(): string {
    const n: string = this.scenes.length.toString()
    if (this.searchMode && this.keyword.trim().length > 0) {
      return '作品 (' + n + ') · 搜索「' + this.keyword.trim() + '」'
    }
    return '作品 (' + n + ')'
  }

  /**
   * 短片区块标题（自己读状态，不走 sectionHeader 的值传参）。
   * ArkUI 的 @Builder 参数按值传递时，传方法返回值不会触发重渲染，
   * 标题里的搜索关键词就会一直是旧值，所以这里单独写一个读状态的 builder。
   */
  /** 作品区块标题：不可折叠，无箭头、无点击切换；搜索态带上关键词 */
  @Builder
  sceneSectionHeader() {
    Row() {
      Text(this.sceneSectionTitle())
        .fontSize(12).fontWeight(FontWeight.Medium)
        .fontColor(this.theme.textPrimary).layoutWeight(1)
    }
    .width('100%').padding({ top: 8, bottom: 2, left: 2, right: 2 })
  }

  /**
   * 搜索态的内联输入框。
   * 左右各内缩 2vp，与 sectionHeader 的 padding 一致，图标和标题文字严格同一条竖线；
   * 底部加 chip 背景，让它看起来是一个输入框，而不是浮在卡片上的文字。
   */
  @Builder
  sceneSearchRow() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(15)
        .fontColor([this.theme.textSecondary])
        .margin({ right: 8 })
      TextInput({ text: this.keyword, placeholder: '搜索作品名' })
        .layoutWeight(1)
        .fontSize(13)
        .height(32)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .placeholderColor(this.theme.textSecondary)
        .fontColor(this.theme.textPrimary)
        .onChange((v: string) => {
          this.keyword = v
        })
        .onSubmit(() => {
          this.reloadScenesByKeyword()
        })
      if (this.keyword.length > 0) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(14)
          .fontColor([this.theme.textSecondary])
          .padding({ left: 6 })
          .onClick(() => {
            this.keyword = ''
            this.reloadScenesByKeyword()
          })
      }
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 10, right: 10 })
    .margin({ left: 2, right: 2, top: 6, bottom: 2 })
    .backgroundColor(this.theme.chipBg)
    .borderRadius(RADIUS_CHIP)
  }

  private async loadScenes(): Promise<void> {
    if (this.scenesLoading || !this.hasMore) {
      return
    }
    this.scenesLoading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const sf: string = '{"studios":{"value":[' + JSON.stringify(this.studioId) +
        '],"modifier":"INCLUDES","depth":0}}'
      const raw: SceneDto[] = await api.findScenesFiltered(
        this.page, this.pageSize, this.keyword.trim(), 'date', 'DESC', sf)
      const list: Scene[] = Scene.listFromDto(raw)
      const merged: Scene[] = this.scenes.slice()
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i])
      }
      this.scenes = merged
      this.hasMore = list.length >= this.pageSize
      this.page = this.page + 1
    } catch (e) {
      console.error('[StudioDetail] ' + (e as Error).message)
    }
    this.scenesLoading = false
  }

  private aliasText(): string {
    return this.studio.aliases.join(' / ')
  }

  private api(): StashApi {
    return new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
  }

  /** 统一提示：系统 Toast + 记录到状态 */
  private say(msg: string): void {
    this.toast = msg
    try {
      promptAction.showToast({ message: msg, duration: 2000 })
    } catch (e) {
      // Toast 不可用时仅记录状态
    }
  }

  /** 换行文本 → 字符串数组（去空行 / 去首尾空格） */
  private linesToArr(raw: string): string[] {
    const out: string[] = []
    const lines: string[] = raw.split('\n')
    for (let i = 0; i < lines.length; i++) {
      const v: string = lines[i].trim()
      if (v.length > 0) {
        out.push(v)
      }
    }
    return out
  }

  /** 评分文本 → 0–100（非法 / 越界夹紧） */
  private ratingOf(raw: string): number {
    const n: number = Number.parseInt(raw.trim())
    if (Number.isNaN(n) || n < 0) {
      return 0
    }
    return n > 100 ? 100 : n
  }

  /* ---------------- 编辑 ---------------- */

  /** 进入编辑：StudioUpdate.from 预填当前值 */
  private startEdit(): void {
    const u: StudioUpdate = StudioUpdate.from(this.studio)
    this.editName = u.name
    this.editAliases = u.aliases.join('\n')
    this.editUrls = u.urls.join('\n')
    this.editDetails = u.details
    this.editFavorite = u.favorite
    this.editRating = u.rating100 > 0 ? u.rating100.toString() : ''
    this.editOrganized = u.organized
    this.editParentId = this.parentIdOf
    this.editParentName = this.studio.parentName
    this.pickOpen = false
    this.pickQuery = ''
    this.pickList = []
    this.editMode = true
  }

  private async saveEdit(): Promise<void> {
    if (this.busy) {
      return
    }
    const nm: string = this.editName.trim()
    if (nm.length === 0) {
      this.say('工作室名称不能为空')
      return
    }
    const u = new StudioUpdate()
    u.name = nm
    u.aliases = this.linesToArr(this.editAliases)
    u.urls = this.linesToArr(this.editUrls)
    u.details = this.editDetails
    u.favorite = this.editFavorite
    u.rating100 = this.ratingOf(this.editRating)
    u.organized = this.editOrganized
    // 整表写回父工作室：parentId 空串 = 清除父级
    u.setParent = true
    u.parentId = this.editParentId
    this.busy = true
    try {
      await this.api().updateStudio(this.studioId, u)
      this.editMode = false
      this.say('已保存')
      bumpScenes()
      await this.loadAll()
    } catch (e) {
      // 失败留在编辑态，显示服务端原因
      this.say('保存失败：' + (e as Error).message)
    }
    this.busy = false
  }

  /* ---------------- 父工作室选择器 ---------------- */

  private async openPicker(): Promise<void> {
    this.pickOpen = true
    this.pickQuery = ''
    this.pickList = []
    await this.loadPickList()
  }

  private async loadPickList(): Promise<void> {
    this.pickLoading = true
    try {
      const all: PickItem[] = await loadOptionList(this.api(), 'studio')
      const q: string = this.pickQuery.toLowerCase()
      const out: PickItem[] = []
      for (let i = 0; i < all.length; i++) {
        const it: PickItem = all[i]
        // 不能把自己设为父级
        if (it.id === this.studioId) {
          continue
        }
        if (q.length === 0 || it.name.toLowerCase().indexOf(q) >= 0) {
          out.push(it)
        }
      }
      this.pickList = out
    } catch (e) {
      this.say('加载失败：' + (e as Error).message)
    }
    this.pickLoading = false
  }

  private choosePick(it: PickItem): void {
    this.editParentId = it.id
    this.editParentName = it.name
    this.pickOpen = false
    this.pickList = []
  }

  private clearParent(): void {
    this.editParentId = ''
    this.editParentName = ''
  }

  @Builder
  basicRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(this.theme.textSecondary).width(64)
      Text(value.length === 0 ? '—' : value)
        .fontSize(12)
        .fontColor(value.length === 0 ? this.theme.textSecondary : this.theme.textPrimary)
        .layoutWeight(1).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').alignItems(VerticalAlign.Top).margin({ top: 8 })
  }

  @Builder
  sectionHeader(title: string, open: boolean, onToggle: () => void) {
    Row() {
      Text(title)
        .fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
        .layoutWeight(1)
      SymbolGlyph(open ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
        .fontSize(10).fontColor([this.theme.textSecondary])
    }
    .width('100%').padding({ top: 8, bottom: 2, left: 2, right: 2 })
    .onClick(onToggle)
  }

  /* ---------------- 编辑 UI ---------------- */

  @Builder
  actionBtn(label: string, color: ResourceColor, onTap: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(color)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .onClick(onTap)
  }

  @Builder
  fieldLabel(t: string) {
    Text(t).fontSize(11).fontColor(this.theme.textSecondary)
      .width('100%').margin({ top: GAP_S })
  }

  @Builder
  pickerPanel() {
    Column() {
      Row() {
        Text('选择父工作室（' + this.pickList.length.toString() + '）')
          .fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.brandColor).layoutWeight(1)
        Text('关闭')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .onClick(() => {
            this.pickOpen = false
            this.pickList = []
          })
      }
      .width('100%')

      Row() {
        TextInput({ text: this.pickQuery, placeholder: '搜索工作室名' })
          .fontSize(12).fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textSecondary)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .height(34).layoutWeight(1)
          .onChange((v: string) => {
            this.pickQuery = v
          })
          .onSubmit(() => {
            this.loadPickList()
          })
        Text('搜索')
          .fontSize(11).fontColor(Color.White)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.loadPickList()
          })
      }
      .width('100%').margin({ top: GAP_S })

      if (this.pickLoading) {
        Row() {
          LoadingProgress().width(16).height(16)
          Text('加载中…').fontSize(11).fontColor(this.theme.textSecondary).margin({ left: 6 })
        }.margin({ top: GAP_S })
      }
      ForEach(this.pickList, (it: PickItem) => {
        Row() {
          Text(it.name).fontSize(12).fontColor(this.theme.textPrimary)
            .layoutWeight(1).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('选择')
            .fontSize(11).fontColor(this.theme.brandColor)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .onClick(() => {
              this.choosePick(it)
            })
        }
        .width('100%').alignItems(VerticalAlign.Center)
        .padding({ top: 7, bottom: 7 })
        .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
      }, (it: PickItem) => it.id)
    }
    .width('100%').padding(GAP_S + 2)
    .backgroundColor(this.theme.chipBg)
    .borderRadius(RADIUS_CHIP)
    .margin({ top: GAP_S })
  }

  @Builder
  editCard() {
    Column() {
      Row() {
        Text('编辑工作室').fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textSecondary).layoutWeight(1)
        Text(this.busy ? '保存中…' : '')
          .fontSize(11).fontColor(this.theme.textSecondary)
      }
      .width('100%')

      this.fieldLabel('名称 *')
      TextInput({ text: this.editName, placeholder: '工作室名称' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editName = v
        })

      this.fieldLabel('别名（每行一个）')
      TextArea({ text: this.editAliases, placeholder: '每行一个别名' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(72).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editAliases = v
        })

      this.fieldLabel('URL（每行一个）')
      TextArea({ text: this.editUrls, placeholder: 'https://…' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(72).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editUrls = v
        })

      this.fieldLabel('详情')
      TextArea({ text: this.editDetails, placeholder: '简介 / 备注' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(96).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editDetails = v
        })

      this.fieldLabel('评分（0–100，0 = 未评分）')
      Row() {
        SymbolGlyph($r('sys.symbol.star_fill'))
          .fontSize(14).fontColor([this.theme.brandColor])
        TextInput({ text: this.editRating, placeholder: '0' })
          .fontSize(13).fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textSecondary)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .height(40).layoutWeight(1).margin({ left: GAP_S })
          .type(InputType.Number)
          .onChange((v: string) => {
            this.editRating = v
          })
        Text('清空')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.editRating = ''
          })
      }
      .width('100%').alignItems(VerticalAlign.Center).margin({ top: 4 })

      // 星级快捷打分
      Row() {
        Text('星级').fontSize(11).fontColor(this.theme.textSecondary).width(40)
        ForEach([1, 2, 3, 4, 5], (i: number) => {
          SymbolGlyph(i * 20 <= this.ratingOf(this.editRating)
            ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(18)
            .fontColor([i * 20 <= this.ratingOf(this.editRating)
              ? this.theme.brandColor : this.theme.textSecondary])
            .margin({ right: 6 })
            .onClick(() => {
              this.editRating = (this.ratingOf(this.editRating) === i * 20 ? 0 : i * 20).toString()
            })
        }, (i: number) => 'star' + i.toString())
      }
      .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_S })

      Row() {
        Text('收藏').fontSize(12).fontColor(this.theme.textSecondary)
        Toggle({ type: ToggleType.Switch, isOn: this.editFavorite })
          .margin({ left: GAP_S })
          .onChange((on: boolean) => {
            this.editFavorite = on
          })
        Text('已整理').fontSize(12).fontColor(this.theme.textSecondary)
          .margin({ left: GAP_M })
        Toggle({ type: ToggleType.Switch, isOn: this.editOrganized })
          .margin({ left: GAP_S })
          .onChange((on: boolean) => {
            this.editOrganized = on
          })
      }
      .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_S })

      // 父工作室
      this.fieldLabel('父工作室')
      Flex({ wrap: FlexWrap.Wrap }) {
        if (this.editParentName.length > 0) {
          Row() {
            Text(this.editParentName).fontSize(11).fontColor(this.theme.textPrimary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('×')
              .fontSize(12).fontColor(this.theme.textSecondary)
              .margin({ left: 6 })
              .onClick(() => {
                this.clearParent()
              })
          }
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
        }
        Text(this.editParentName.length > 0 ? '更换' : '选择父工作室')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            this.openPicker()
          })
        if (this.editParentName.length > 0) {
          Text('清除父工作室')
            .fontSize(11).fontColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .margin({ bottom: 6 })
            .onClick(() => {
              this.clearParent()
            })
        }
      }
      .width('100%').margin({ top: 4 })

      if (this.pickOpen) {
        this.pickerPanel()
      }

      Row() {
        Text('取消')
          .fontSize(12).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Center).layoutWeight(1)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ top: 9, bottom: 9 })
          .margin({ right: 4 })
          .onClick(() => {
            this.editMode = false
            this.pickOpen = false
          })
        Text(this.busy ? '保存中…' : '保存')
          .fontSize(12).fontColor(Color.White)
          .textAlign(TextAlign.Center).layoutWeight(1)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ top: 9, bottom: 9 })
          .margin({ left: 4 })
          .onClick(() => {
            this.saveEdit()
          })
      }
      .width('100%').margin({ top: GAP_M })
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.brandColor })
    .backdropBlur(24).margin({ top: GAP_M })
  }

  @Builder
  headerCard() {
    Row() {
      Column() {
        if (this.studio.image_path.length > 0) {
          AuthImage({ rawPath: this.studio.image_path })
        } else {
          Column() {
            Text(this.studio.name.length > 0 ? this.studio.name.substring(0, 1) : '?')
              .fontSize(36).fontWeight(FontWeight.Bold).fontColor(this.theme.textSecondary)
          }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme.chipBg)
        }
      }
      .width(96).aspectRatio(3 / 4).clip(true).borderRadius(RADIUS_CHIP)

      Column() {
        Row() {
          Text(this.studio.name.length === 0 ? '（无名）' : this.studio.name)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (this.studio.favorite) {
            SymbolGlyph($r('sys.symbol.star_fill')).fontSize(18).fontColor(['#FFFFB700'])
          }
        }.width('100%')

        Text(this.studio.scene_count.toString() + ' 部作品')
          .fontSize(12).fontColor(this.theme.textSecondary).width('100%').margin({ top: 2 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_M })
    }
    .width('100%').alignItems(VerticalAlign.Top)
    .padding(PAD_PAGE)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder }).backdropBlur(24)
  }

  /** 作品卡：归属信息（别名 / 已整理 / 评分）+ 作品数 + 简介，全部在一张折叠卡里 */
  @Builder
  statsCard() {
    Column() {
      this.sectionHeader('统计', this.openStats, () => {
        this.openStats = !this.openStats
      })
      if (this.openStats) {
        this.basicRow('别名', this.aliasText())
        this.basicRow('已整理', this.studio.organized ? '是' : '否')
        this.basicRow('评分', this.studio.rating100 > 0
          ? (this.studio.rating100 / 20).toFixed(1) + ' / 5.0' : '')
        this.basicRow('短片', this.studio.scene_count.toString() + ' 部')
        this.basicRow('图片', this.studio.image_count.toString() + ' 张')
        this.basicRow('画廊', this.studio.gallery_count.toString() + ' 个')
        this.basicRow('演员', this.studio.performer_count.toString() + ' 位')
        this.basicRow('集合', this.studio.group_count.toString() + ' 个')
        this.basicRow('射精', this.studio.o_counter.toString() + ' 次')
        if (this.studio.details.length > 0) {
          Text(this.studio.details)
            .fontSize(12).fontColor(this.theme.textSecondary)
            .width('100%').margin({ top: 10 }).lineHeight(18)
        }
      }
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  @Builder
  treeCard() {
    Column() {
      this.sectionHeader('层级', this.openTree, () => {
        this.openTree = !this.openTree
      })
      if (this.openTree) {
        this.basicRow('父工作室', this.studio.parentName)
        this.basicRow('子工作室', this.studio.childNames.join(' / '))
      }
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  @Builder
  linksCard() {
    Column() {
      this.sectionHeader('链接 (' + this.studio.urls.length.toString() + ')', this.openLinks, () => {
        this.openLinks = !this.openLinks
      })
      if (this.openLinks) {
        if (this.studio.urls.length === 0) {
          Text('没有链接').fontSize(12).fontColor(this.theme.textSecondary).margin({ top: 6 })
        }
        ForEach(this.studio.urls, (u: string) => {
          Text(u)
            .fontSize(11).fontColor(this.theme.brandColor)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ top: 6 })
        }, (u: string) => u)
      }
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  @Builder
  tagsCard() {
    Column() {
      this.sectionHeader('标签 (' + this.studio.tags.length.toString() + ')', this.openTags, () => {
        this.openTags = !this.openTags
      })
      if (this.openTags) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.studio.tags, (t: Tag) => {
            Text(t.name)
              .fontSize(11).fontColor(this.theme.textPrimary)
              .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .margin({ right: 6, bottom: 6 })
          }, (t: Tag) => t.id)
        }.width('100%')
      }
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  @Builder
  smallSceneCard(s: Scene) {
    Column() {
      Column() { AuthImage({ rawPath: s.poster }) }.width('100%').aspectRatio(16 / 9).clip(true)
      Text(s.title.length === 0 ? '（无标题）' : s.title)
        .fontSize(12).fontColor(this.theme.textPrimary).maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 8 })
        .align(Alignment.TopStart)
    }
    .width('100%').backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder }).clip(true)
    .onClick(() => {
      router.pushUrl({ url: 'pages/SceneDetailPage', params: { 'id': s.id } })
    })
  }

  build() {
    Column() {
      GlassNavBar({
        title: this.studio.name.length === 0 ? L10n.translate('工作室') : this.studio.name,
        subtitle: this.studio.scene_count > 0 ? (this.studio.scene_count.toString() + ' 部作品') : '',
        theme: this.theme, style: GlassStyle.REGULAR,
        showSearch: true,
        searchActive: this.searchMode,
        onSearchTap: () => {
          // 一下展开、再一下收起（收起时清空关键词并恢复全量）
          this.searchMode = !this.searchMode
          if (!this.searchMode && this.keyword.length > 0) {
            this.keyword = ''
            this.reloadScenesByKeyword()
          }
        }
      })

      if (!this.paramOk) {
        // 缺参数：什么都不渲染，避免闪出一个空壳详情页（此时已 router.back()）
        Column() { }.layoutWeight(1).width('100%')
      } else if (this.loading) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.errorText.length > 0) {
        Column() { Text(this.errorText).fontSize(13).fontColor('#FFE84026') }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.headerCard()

            // 操作行：编辑 / 刷新
            Row() {
              this.actionBtn(this.editMode ? '编辑中' : '编辑', this.theme.brandColor, () => {
                if (this.editMode) {
                  this.editMode = false
                  this.pickOpen = false
                } else {
                  this.startEdit()
                }
              })
              this.actionBtn('刷新', this.theme.textPrimary, () => {
                this.loadAll()
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
            .margin({ top: GAP_M })

            if (this.editMode) {
              this.editCard()
            }

            this.statsCard()
            this.treeCard()
            this.linksCard()
            this.tagsCard()

            Column() {
              this.sceneSectionHeader()
              if (this.searchMode) {
                this.sceneSearchRow()
              }
              // 网格与加载行放在同一张卡里（和演员详情页一致），
              // 否则卡片背景只包住标题行，网格会直接压在页面背景上。
              // 作品区块不折叠：内容始终渲染。
              if (this.searchMode && !this.scenesLoading && this.scenes.length === 0) {
                Text('没有匹配「' + this.keyword.trim() + '」的作品')
                  .fontSize(12).fontColor(this.theme.textSecondary)
                  .width('100%').padding({ top: 8, bottom: 4 })
              }
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.scenes, (s: Scene) => {
                  Column() { this.smallSceneCard(s) }
                    .width(layoutFor(this.winW).columns === 2 ? '48.5%' : '32%')
                    .margin({ bottom: GAP_S })
                }, (s: Scene) => s.id)
              }
              .width('100%')
              .margin({ top: 8 })

              if (this.scenesLoading) {
                Row() {
                  LoadingProgress().width(20).height(20)
                  Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
                }.width('100%').justifyContent(FlexAlign.Center).padding(12)
              }
            }
            .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 })
            .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
            .border({ width: 1, color: this.theme.cardBorder })
            .backdropBlur(24).margin({ top: GAP_S })
          }
          .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 4, bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .onReachEnd(() => { this.loadScenes() })
      }
    }
    .width('100%').height('100%')
    .linearGradient({ angle: 160, colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
