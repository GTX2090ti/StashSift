/**
 * StashSift — 标签详情
 *
 * v1.0.7：只读区补齐 名称 / 简介 / 别名 / 父标签 / 短片数；
 * 新增「编辑」面板（name / sort_name / description / aliases / favorite / 父标签多选）
 * 与「合并」流程（选目标 → 选多个来源 → 二次确认 → tagsMerge）。
 */
import { router, promptAction } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { TagDto, TagUpdate, Scene, SceneDto } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { layoutFor, RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'
import { bumpScenes } from '../common/DataVersion'
import { PickItem, PickCache, loadOptions } from '../common/OptionCache'

@Entry
@Component
struct TagDetailPage {
  @State tag: TagDto = {}
  @State scenes: Scene[] = []
  @State loading: boolean = true
  @State errorText: string = ''
  @State toast: string = ''
  @State busy: boolean = false

  // ── 编辑面板 ──
  @State editMode: boolean = false
  @State editName: string = ''
  @State editSortName: string = ''
  @State editDescription: string = ''
  @State editAliases: string = ''
  @State editFavorite: boolean = false
  @State editParentIds: string[] = []
  @State editParentNames: string[] = []

  // ── 父标签选择器 ──
  @State pickMode: string = ''
  @State pickQuery: string = ''
  @State pickList: PickItem[] = []
  @State pickLoading: boolean = false

  // ── 合并面板 ──
  @State mergeMode: boolean = false
  @State mergeStep: number = 1
  @State mergeQuery: string = ''
  @State mergeList: PickItem[] = []
  @State mergeLoading: boolean = false
  @State mergeDestId: string = ''
  @State mergeDestName: string = ''
  @State mergeSrcIds: string[] = []
  @State mergeSrcNames: string[] = []

  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  @StorageProp('winWidthVp') winW: number = 360
  private tagId: string = ''
  private page: number = 1
  private hasMore: boolean = true

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string>
    if (p !== undefined && p !== null) {
      const id: string | undefined = p['id']
      if (id !== undefined) {
        this.tagId = id
      }
    }
    this.load()
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
    // 从父/子标签或短片详情返回时补刷（编辑中不打断表单）
    if (this.tagId.length > 0 && !this.loading && !this.editMode && !this.mergeMode) {
      this.load()
    }
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
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

  private async load(): Promise<void> {
    this.loading = true
    this.errorText = ''
    try {
      const api = this.api()
      const t: TagDto | null = await api.findTag(this.tagId)
      if (t !== null) {
        this.tag = t
      }
      const sf: string = '{"tags":{"value":[' + JSON.stringify(this.tagId) + '],"modifier":"INCLUDES","depth":0}}'
      const raw: SceneDto[] = await api.findScenesFiltered(1, 24, '', 'date', 'DESC', sf)
      this.scenes = Scene.listFromDto(raw)
      this.hasMore = raw.length >= 24
      this.page = 2
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
    }
    this.loading = false
  }

  private async more(): Promise<void> {
    if (!this.hasMore) {
      return
    }
    const api = this.api()
    const sf: string = '{"tags":{"value":[' + JSON.stringify(this.tagId) + '],"modifier":"INCLUDES","depth":0}}'
    const raw: SceneDto[] = await api.findScenesFiltered(this.page, 24, '', 'date', 'DESC', sf)
    const list: Scene[] = Scene.listFromDto(raw)
    const merged: Scene[] = this.scenes.slice()
    for (let i = 0; i < list.length; i++) {
      merged.push(list[i])
    }
    this.scenes = merged
    this.hasMore = list.length >= 24
    this.page = this.page + 1
  }

  /* ---------------- 只读区取值 ---------------- */

  private tagName(): string {
    return this.tag.name === undefined || this.tag.name === null ? '' : this.tag.name
  }

  private tagDesc(): string {
    return this.tag.description === undefined || this.tag.description === null ? '' : this.tag.description
  }

  private tagCount(): number {
    return this.tag.scene_count === undefined || this.tag.scene_count === null ? 0 : this.tag.scene_count
  }

  private tagAliases(): string[] {
    return this.tag.aliases === undefined || this.tag.aliases === null ? [] : this.tag.aliases
  }

  private parentRefs(): TagDto[] {
    return this.tag.parents === undefined || this.tag.parents === null ? [] : this.tag.parents
  }

  private childRefs(): TagDto[] {
    return this.tag.children === undefined || this.tag.children === null ? [] : this.tag.children
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

  /** 标签被改名/合并后，选择器缓存里的旧名字就过期了，清掉让下次重新拉取 */
  private dropTagCache(): void {
    PickCache.tags = []
  }

  /* ---------------- 编辑 ---------------- */

  private startEdit(): void {
    this.editName = this.tagName()
    const sn: string | undefined = this.tag.sort_name
    this.editSortName = sn === undefined || sn === null ? '' : sn
    this.editDescription = this.tagDesc()
    this.editAliases = this.tagAliases().join('\n')
    this.editFavorite = this.tag.favorite === true
    const ids: string[] = []
    const nms: string[] = []
    const ps: TagDto[] = this.parentRefs()
    for (let i = 0; i < ps.length; i++) {
      const d: TagDto = ps[i]
      const pid: string = d.id === undefined || d.id === null ? '' : d.id
      if (pid.length > 0) {
        ids.push(pid)
        nms.push(d.name === undefined || d.name === null ? pid : d.name)
      }
    }
    this.editParentIds = ids
    this.editParentNames = nms
    this.pickMode = ''
    this.pickList = []
    this.mergeMode = false
    this.editMode = true
  }

  private async saveEdit(): Promise<void> {
    if (this.busy) {
      return
    }
    const name: string = this.editName.trim()
    if (name.length === 0) {
      this.say('名称不能为空')
      return
    }
    const u = new TagUpdate()
    u.name = name
    u.sort_name = this.editSortName.trim()
    u.description = this.editDescription
    u.aliases = this.linesToArr(this.editAliases)
    u.favorite = this.editFavorite
    u.parentIds = this.editParentIds.slice()
    // 编辑面板里父标签是完整展示的，保存时按当前选择整体覆盖
    u.setParents = true

    this.busy = true
    try {
      await this.api().updateTag(this.tagId, u)
      this.editMode = false
      this.pickMode = ''
      this.dropTagCache()
      this.say('已保存')
      bumpScenes()
      await this.load()
    } catch (e) {
      // 失败留在编辑态，直接显示服务端原因
      this.say('保存失败：' + (e as Error).message)
    }
    this.busy = false
  }

  /* ---------------- 候选标签（父标签 / 合并共用） ---------------- */

  /** 全部标签（含本页这个） */
  private async allTags(): Promise<PickItem[]> {
    return loadOptions(this.api(), 'tag')
  }

  /** 去掉本页标签自己 */
  private withoutSelf(list: PickItem[]): PickItem[] {
    const out: PickItem[] = []
    for (let i = 0; i < list.length; i++) {
      if (list[i].id !== this.tagId) {
        out.push(list[i])
      }
    }
    return out
  }

  /**
   * 合并第 2 步的可勾选来源：排除本页标签自己（契约要求「排除自己」），
   * 也排除已选定的保留目标。
   */
  private srcCandidates(): PickItem[] {
    const out: PickItem[] = []
    for (let i = 0; i < this.mergeList.length; i++) {
      const it: PickItem = this.mergeList[i]
      if (it.id !== this.tagId && it.id !== this.mergeDestId) {
        out.push(it)
      }
    }
    return out
  }

  private filterByQuery(all: PickItem[], q: string): PickItem[] {
    if (q.length === 0) {
      return all
    }
    const low: string = q.toLowerCase()
    const out: PickItem[] = []
    for (let i = 0; i < all.length; i++) {
      if (all[i].name.toLowerCase().indexOf(low) >= 0) {
        out.push(all[i])
      }
    }
    return out
  }

  private async openPicker(mode: string): Promise<void> {
    this.pickMode = mode
    this.pickQuery = ''
    this.pickList = []
    await this.loadPickList()
  }

  private async loadPickList(): Promise<void> {
    this.pickLoading = true
    try {
      const all: PickItem[] = await this.allTags()
      this.pickList = this.filterByQuery(this.withoutSelf(all), this.pickQuery.trim())
    } catch (e) {
      this.pickList = []
      this.say('加载候选失败：' + (e as Error).message)
    }
    this.pickLoading = false
  }

  private isParentSelected(id: string): boolean {
    return this.editParentIds.indexOf(id) >= 0
  }

  /** 父标签多选：点一下切换 */
  private toggleParent(it: PickItem): void {
    const ids: string[] = []
    const nms: string[] = []
    let hit: boolean = false
    for (let i = 0; i < this.editParentIds.length; i++) {
      if (this.editParentIds[i] === it.id) {
        hit = true
      } else {
        ids.push(this.editParentIds[i])
        nms.push(this.editParentNames[i])
      }
    }
    if (!hit) {
      ids.push(it.id)
      nms.push(it.name)
    }
    this.editParentIds = ids
    this.editParentNames = nms
  }

  private removeParent(i: number): void {
    const ids: string[] = []
    const nms: string[] = []
    for (let k = 0; k < this.editParentIds.length; k++) {
      if (k !== i) {
        ids.push(this.editParentIds[k])
        nms.push(this.editParentNames[k])
      }
    }
    this.editParentIds = ids
    this.editParentNames = nms
  }

  /* ---------------- 合并 ---------------- */

  private openMerge(): void {
    this.editMode = false
    this.pickMode = ''
    this.mergeMode = true
    this.mergeStep = 1
    this.mergeDestId = ''
    this.mergeDestName = ''
    this.mergeSrcIds = []
    this.mergeSrcNames = []
    this.mergeQuery = ''
    this.fetchMergeList()
  }

  private async fetchMergeList(): Promise<void> {
    this.mergeLoading = true
    try {
      // 第 1 步选「保留目标」：允许选本页这个标签（把别的标签并进来是最常见用法）
      const all: PickItem[] = await this.allTags()
      this.mergeList = this.filterByQuery(all, this.mergeQuery.trim())
    } catch (e) {
      this.mergeList = []
      this.say('加载标签列表失败：' + (e as Error).message)
    }
    this.mergeLoading = false
  }

  private async searchMerge(): Promise<void> {
    await this.fetchMergeList()
  }

  /** 第 1 步：选定保留目标 */
  private pickDest(it: PickItem): void {
    this.mergeDestId = it.id
    this.mergeDestName = it.name.length === 0 ? ('#' + it.id) : it.name
    this.mergeSrcIds = []
    this.mergeSrcNames = []
    this.mergeStep = 2
    this.say('已选保留：' + this.mergeDestName + '，再选要并入的标签')
  }

  /** 第 2 步：切换某个来源的勾选（目标本身不能当来源） */
  private toggleSrc(it: PickItem): void {
    if (it.id === this.mergeDestId) {
      this.say('不能把「保留的标签」自己并进去')
      return
    }
    const ids: string[] = []
    const nms: string[] = []
    let hit: boolean = false
    for (let i = 0; i < this.mergeSrcIds.length; i++) {
      if (this.mergeSrcIds[i] === it.id) {
        hit = true
      } else {
        ids.push(this.mergeSrcIds[i])
        nms.push(this.mergeSrcNames[i])
      }
    }
    if (!hit) {
      ids.push(it.id)
      nms.push(it.name.length === 0 ? ('#' + it.id) : it.name)
    }
    this.mergeSrcIds = ids
    this.mergeSrcNames = nms
  }

  private isSrcSelected(id: string): boolean {
    return this.mergeSrcIds.indexOf(id) >= 0
  }

  /** 第 3 步：二次确认 */
  private askConfirmMerge(): void {
    if (this.mergeDestId.length === 0) {
      this.say('请先选择要保留的标签')
      return
    }
    if (this.mergeSrcIds.length === 0) {
      this.say('请至少选择 1 个要并入的标签')
      return
    }
    this.mergeStep = 3
  }

  private async doMerge(): Promise<void> {
    if (this.busy) {
      return
    }
    if (this.mergeSrcIds.length === 0 || this.mergeDestId.length === 0) {
      this.say('请先选择要保留的标签，并至少选 1 个要并入的标签')
      return
    }
    this.busy = true
    try {
      await this.api().mergeTags(this.mergeSrcIds.slice(), this.mergeDestId)
      this.mergeMode = false
      this.mergeStep = 1
      this.dropTagCache()
      this.say('已合并')
      bumpScenes()
      // 合并会删除来源标签（也可能包括本页这个），统一回列表；
      // 列表页 onPageShow 检测到版本号变化会自动重新拉取。
      router.back()
    } catch (e) {
      this.say('合并失败：' + (e as Error).message)
    }
    this.busy = false
  }

  /* ---------------- UI ---------------- */

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
  infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(this.theme.textSecondary).width(64)
      Text(value.length === 0 ? '—' : value)
        .fontSize(12)
        .fontColor(value.length === 0 ? this.theme.textSecondary : this.theme.textPrimary)
        .layoutWeight(1)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').alignItems(VerticalAlign.Top).margin({ top: 6 })
  }

  @Builder
  infoCard() {
    Column() {
      Text(this.tagName().length === 0 ? '标签' : this.tagName())
        .fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary).width('100%')
      Row() {
        Text(this.tagCount().toString() + ' 部短片')
          .fontSize(12).fontColor(this.theme.textSecondary)
        if (this.tag.favorite === true) {
          SymbolGlyph($r('sys.symbol.star_fill')).fontSize(12).fontColor([this.theme.brandColor]).margin({ left: 8 })
        }
      }.width('100%').margin({ top: 4 })

      // 简介 / 别名 / 父标签 / 子标签
      this.infoRow('简介', this.tagDesc())
      this.infoRow('别名', this.tagAliases().join(' / '))

      Text('父标签').fontSize(12).fontColor(this.theme.textSecondary)
        .width('100%').margin({ top: 6 })
      if (this.parentRefs().length === 0) {
        Text('—').fontSize(12).fontColor(this.theme.textSecondary).width('100%').margin({ top: 2 })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.parentRefs(), (p: TagDto) => {
            Text(p.name === undefined || p.name === null ? '—' : p.name)
              .fontSize(11).fontColor(this.theme.brandColor)
              .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
              .padding({ left: 9, right: 9, top: 4, bottom: 4 })
              .margin({ right: 6, bottom: 6, top: 4 })
              .onClick(() => {
                const pid: string = p.id === undefined || p.id === null ? '' : p.id
                if (pid.length > 0 && pid !== this.tagId) {
                  router.pushUrl({ url: 'pages/TagDetailPage', params: { 'id': pid } })
                }
              })
          }, (p: TagDto) => (p.id === undefined ? '' : p.id))
        }.width('100%')
      }

      if (this.childRefs().length > 0) {
        Text('子标签').fontSize(12).fontColor(this.theme.textSecondary)
          .width('100%').margin({ top: 2 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.childRefs(), (p: TagDto) => {
            Text(p.name === undefined || p.name === null ? '—' : p.name)
              .fontSize(11).fontColor(this.theme.textSecondary)
              .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
              .padding({ left: 9, right: 9, top: 4, bottom: 4 })
              .margin({ right: 6, bottom: 6, top: 4 })
              .onClick(() => {
                const cid: string = p.id === undefined || p.id === null ? '' : p.id
                if (cid.length > 0 && cid !== this.tagId) {
                  router.pushUrl({ url: 'pages/TagDetailPage', params: { 'id': cid } })
                }
              })
          }, (p: TagDto) => (p.id === undefined ? '' : p.id))
        }.width('100%')
      }
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder }).backgroundEffect({ radius: 24, saturation: 1.35 })
  }

  @Builder
  editCard() {
    Column() {
      Row() {
        Text('编辑标签').fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textSecondary).layoutWeight(1)
        Text(this.busy ? '保存中…' : '')
          .fontSize(11).fontColor(this.theme.textSecondary)
      }
      .width('100%')

      this.fieldLabel('名称 *')
      TextInput({ text: this.editName, placeholder: '标签名称' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editName = v
        })

      this.fieldLabel('排序名（sort_name）')
      TextInput({ text: this.editSortName, placeholder: '如：AAA 前缀' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editSortName = v
        })
      // 保存是整表写回，留空即清空服务端已有的排序名，这里明确告知。
      Text('留空保存会清空该字段')
        .fontSize(10).fontColor(this.theme.textSecondary)
        .width('100%').margin({ top: 4 })

      this.fieldLabel('简介')
      TextArea({ text: this.editDescription, placeholder: '简介 / 备注' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(88).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editDescription = v
        })

      this.fieldLabel('别名（换行分隔，每行一个）')
      TextArea({ text: this.editAliases, placeholder: '每行一个别名' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(80).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editAliases = v
        })

      Row() {
        Text('收藏').fontSize(12).fontColor(this.theme.textSecondary)
        Toggle({ type: ToggleType.Switch, isOn: this.editFavorite })
          .margin({ left: GAP_S })
          .onChange((on: boolean) => {
            this.editFavorite = on
          })
      }
      .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_S })

      // 父标签（多选）
      this.fieldLabel('父标签 (' + this.editParentNames.length.toString() + ')')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.editParentNames, (nm: string, idx: number) => {
          Row() {
            Text(nm).fontSize(11).fontColor(this.theme.textPrimary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('×')
              .fontSize(12).fontColor(this.theme.textSecondary)
              .margin({ left: 6 })
              .onClick(() => {
                this.removeParent(idx)
              })
          }
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
        }, (nm: string, idx: number) => nm + idx.toString())
        Text(this.pickMode === 'parent' ? '收起候选' : '选择父标签')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            if (this.pickMode === 'parent') {
              this.pickMode = ''
              this.pickList = []
            } else {
              this.openPicker('parent')
            }
          })
      }
      .width('100%').margin({ top: 4 })

      if (this.pickMode === 'parent') {
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
            this.pickMode = ''
            this.pickList = []
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
    .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
  }

  /** 父标签候选浮层（页面内嵌，不新建页面） */
  @Builder
  pickerPanel() {
    Column() {
      Row() {
        Text('选择父标签（可多选，' + this.editParentIds.length.toString() + ' 已选）')
          .fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.brandColor).layoutWeight(1)
        Text('关闭')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .onClick(() => {
            this.pickMode = ''
            this.pickList = []
          })
      }
      .width('100%')

      Row() {
        TextInput({ text: this.pickQuery, placeholder: '搜索标签名' })
          .fontSize(12).fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textSecondary)
          .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CHIP)
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
      if (!this.pickLoading && this.pickList.length === 0) {
        Text('没有可选标签').fontSize(11).fontColor(this.theme.textSecondary).margin({ top: GAP_S })
      }
      ForEach(this.pickList, (it: PickItem) => {
        Row() {
          Text(this.isParentSelected(it.id) ? '☑' : '☐')
            .fontSize(16)
            .fontColor(this.isParentSelected(it.id) ? this.theme.brandColor : this.theme.textSecondary)
            .width(24)
          Text(it.name).fontSize(12).fontColor(this.theme.textPrimary)
            .layoutWeight(1).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%').alignItems(VerticalAlign.Center)
        .padding({ top: 8, bottom: 8 })
        .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
        .onClick(() => {
          this.toggleParent(it)
        })
      }, (it: PickItem) => it.id)
    }
    .width('100%').padding(GAP_S + 2)
    .backgroundColor(this.theme.chipBg)
    .borderRadius(RADIUS_CHIP)
    .margin({ top: GAP_S })
  }

  @Builder
  mergeCard() {
    Column() {
      Row() {
        Text('合并标签').fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textSecondary).layoutWeight(1)
        Text('取消')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .onClick(() => {
            this.mergeMode = false
            this.mergeStep = 1
          })
      }
      .width('100%')

      Text(this.mergeStep === 1
        ? '第 1 步 / 3：选择要「保留」的标签（合并后的记录挂在它下面）'
        : (this.mergeStep === 2
          ? '第 2 步 / 3：勾选要「并入」的标签（可多选），它们会被删除'
          : '第 3 步 / 3：确认合并'))
        .fontSize(11).fontColor(this.theme.textSecondary)
        .width('100%').margin({ top: 4 })

      if (this.mergeStep !== 3) {
        Row() {
          TextInput({ text: this.mergeQuery, placeholder: '搜索标签名' })
            .fontSize(12).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(36).layoutWeight(1)
            .onChange((v: string) => {
              this.mergeQuery = v
            })
            .onSubmit(() => {
              this.searchMerge()
            })
          Text('搜索')
            .fontSize(12).fontColor(Color.White)
            .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .margin({ left: GAP_S })
            .onClick(() => {
              this.searchMerge()
            })
        }
        .width('100%').margin({ top: GAP_S })

        if (this.mergeLoading) {
          Row() {
            LoadingProgress().width(18).height(18)
            Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
          }.margin({ top: GAP_S })
        }
        if (!this.mergeLoading) {
          if (this.mergeStep === 1 && this.mergeList.length === 0) {
            Text('没有可选标签').fontSize(12).fontColor(this.theme.textSecondary).margin({ top: GAP_S })
          }
          if (this.mergeStep === 2 && this.srcCandidates().length === 0) {
            Text('没有其他可选的标签').fontSize(12).fontColor(this.theme.textSecondary).margin({ top: GAP_S })
          }
        }
      }

      if (this.mergeStep === 1) {
        ForEach(this.mergeList, (it: PickItem) => {
          Row() {
            Text(it.name.length === 0 ? ('#' + it.id) : it.name)
              .fontSize(12).fontColor(this.theme.textPrimary)
              .layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('保留它')
              .fontSize(11).fontColor(Color.White)
              .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .margin({ left: GAP_S })
              .onClick(() => {
                this.pickDest(it)
              })
          }
          .width('100%').alignItems(VerticalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
        }, (it: PickItem) => it.id)
      }

      if (this.mergeStep === 2) {
        Row() {
          Text('保留：' + this.mergeDestName)
            .fontSize(12).fontColor(this.theme.brandColor).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('重选')
            .fontSize(11).fontColor(this.theme.textSecondary)
            .onClick(() => {
              this.mergeStep = 1
            })
        }
        .width('100%').margin({ top: GAP_S })

        Text('已选并入 ' + this.mergeSrcIds.length.toString() + ' 个')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .width('100%').margin({ top: 4 })

        ForEach(this.srcCandidates(), (it: PickItem) => {
          Row() {
            Text(this.isSrcSelected(it.id) ? '☑' : '☐')
              .fontSize(16)
              .fontColor(this.isSrcSelected(it.id) ? this.theme.brandColor : this.theme.textSecondary)
              .width(24)
            Text(it.name.length === 0 ? ('#' + it.id) : it.name)
              .fontSize(12).fontColor(this.theme.textPrimary)
              .layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%').alignItems(VerticalAlign.Center)
          .padding({ top: 9, bottom: 9 })
          .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
          .onClick(() => {
            this.toggleSrc(it)
          })
        }, (it: PickItem) => it.id)

        Row() {
          Text('上一步')
            .fontSize(12).fontColor(this.theme.textPrimary)
            .textAlign(TextAlign.Center).layoutWeight(1)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .padding({ top: 9, bottom: 9 })
            .margin({ right: 4 })
            .onClick(() => {
              this.mergeStep = 1
            })
          Text('下一步')
            .fontSize(12).fontColor(Color.White)
            .textAlign(TextAlign.Center).layoutWeight(1)
            .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
            .padding({ top: 9, bottom: 9 })
            .margin({ left: 4 })
            .onClick(() => {
              this.askConfirmMerge()
            })
        }
        .width('100%').margin({ top: GAP_M })
      }

      if (this.mergeStep === 3) {
        Column() {
          Text('确认合并')
            .fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
            .width('100%')
          Text('保留：' + this.mergeDestName)
            .fontSize(12).fontColor(this.theme.brandColor)
            .width('100%').margin({ top: 6 })
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('并入（' + this.mergeSrcIds.length.toString() + ' 个）：' + this.mergeSrcNames.join('、'))
            .fontSize(12).fontColor(this.theme.textPrimary)
            .width('100%').margin({ top: 4 })
            .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('并入的标签会被删除，其短片关联会转到保留的标签。此操作不可撤销。')
            .fontSize(11).fontColor(this.theme.textSecondary)
            .width('100%').margin({ top: 6 })
        }
        .width('100%').padding(GAP_S + 2).margin({ top: GAP_S })
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text('返回修改')
            .fontSize(12).fontColor(this.theme.textPrimary)
            .textAlign(TextAlign.Center).layoutWeight(1)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .padding({ top: 9, bottom: 9 })
            .margin({ right: 4 })
            .onClick(() => {
              this.mergeStep = 2
            })
          Text(this.busy ? '合并中…' : '确认合并')
            .fontSize(12).fontColor(Color.White)
            .textAlign(TextAlign.Center).layoutWeight(1)
            .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
            .padding({ top: 9, bottom: 9 })
            .margin({ left: 4 })
            .onClick(() => {
              this.doMerge()
            })
        }
        .width('100%').margin({ top: GAP_M })
      }
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.brandColor })
    .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
  }

  @Builder
  sceneCard(s: Scene) {
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
        title: this.tagName().length === 0 ? L10n.translate('标签') : this.tagName(),
        subtitle: this.tagCount().toString() + ' 部短片',
        theme: this.theme, style: GlassStyle.REGULAR
      })
      if (this.loading) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.infoCard()

            // 操作行：编辑 / 合并
            Row() {
              this.actionBtn(this.editMode ? '编辑中' : '编辑', this.theme.brandColor, () => {
                if (this.editMode) {
                  this.editMode = false
                  this.pickMode = ''
                  this.pickList = []
                } else {
                  this.startEdit()
                }
              })
              this.actionBtn(this.mergeMode ? '合并中' : '合并', this.theme.brandColor, () => {
                if (this.mergeMode) {
                  this.mergeMode = false
                  this.mergeStep = 1
                } else {
                  this.openMerge()
                }
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
            .margin({ top: GAP_M })

            if (this.editMode) {
              this.editCard()
            }
            if (this.mergeMode) {
              this.mergeCard()
            }

            if (this.errorText.length > 0) {
              Text(this.errorText).fontSize(12).fontColor(this.theme.textSecondary)
                .width('100%').margin({ top: GAP_S })
            }

            Text('短片').fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary).width('100%').margin({ top: GAP_M + 4, bottom: GAP_S })
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              ForEach(this.scenes, (s: Scene) => {
                Column() { this.sceneCard(s) }
                  .width(layoutFor(this.winW).columns === 2 ? '48.5%' : '32%')
                  .margin({ bottom: GAP_S })
              }, (s: Scene) => s.id)
            }.width('100%')
          }
          .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 4, bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .onReachEnd(() => { this.more() })
      }
    }
    .width('100%').height('100%')
    .linearGradient({ angle: 160, colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
