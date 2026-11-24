/**
 * StashSift — 集合（Group）详情
 *
 * v1.0.7：只读区补评分 / URL / 标签 / 工作室（可跳转），
 * 并支持页面内嵌编辑（名称 / 别名 / 日期 / 时长 / 评分 / 导演 / 简介 / URL / 工作室 / 标签）与删除。
 */
import { router, promptAction } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { GroupDto, GroupUpdate, Scene, SceneDto, TagDto, StudioRefDto } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop, HMS_ERROR } from '../common/GlassUtils'
import { bumpScenes } from '../common/DataVersion'
import { layoutFor, RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S, GAP_XS } from '../common/Responsive'
import { L10n } from '../settings/L10n'
import { PickItem, loadOptions as loadOptionList } from '../common/OptionCache'

@Entry
@Component
struct GroupDetailPage {
  @State group: GroupDto = {}
  @State scenes: Scene[] = []
  @State loading: boolean = true
  @State busy: boolean = false
  @State errorText: string = ''
  @State toast: string = ''
  /** 编辑态 */
  @State editMode: boolean = false
  @State editName: string = ''
  @State editAliases: string = ''
  @State editDate: string = ''
  @State editDuration: string = ''
  @State editRating: string = ''
  @State editDirector: string = ''
  @State editSynopsis: string = ''
  @State editUrls: string = ''
  @State editStudioId: string = ''
  @State editStudioName: string = ''
  @State editTagIds: string[] = []
  @State editTagNames: string[] = []
  /** 选择浮层 */
  @State pickMode: string = ''
  @State pickQuery: string = ''
  @State pickList: PickItem[] = []
  @State pickLoading: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  @StorageProp('winWidthVp') winW: number = 360
  private groupId: string = ''
  private page: number = 1
  private hasMore: boolean = true

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string>
    if (p !== undefined && p !== null) {
      const id: string | undefined = p['id']
      if (id !== undefined) {
        this.groupId = id
      }
    }
    this.load()
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

  private api(): StashApi {
    return new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
  }

  private async load(): Promise<void> {
    this.loading = true
    try {
      const g: GroupDto | null = await this.api().findGroup(this.groupId)
      if (g !== null) {
        this.group = g
      }
      const sf: string = '{"groups":{"value":[' + JSON.stringify(this.groupId) + '],"modifier":"INCLUDES"}}'
      const raw: SceneDto[] = await this.api().findScenesFiltered(1, 24, '', 'date', 'DESC', sf)
      this.scenes = Scene.listFromDto(raw)
      this.hasMore = raw.length >= 24
      this.page = 2
    } catch (e) {
      this.errorText = '加载失败：' + (e as Error).message
      this.say(this.errorText)
    }
    this.loading = false
  }

  private async more(): Promise<void> {
    if (!this.hasMore) {
      return
    }
    const sf: string = '{"groups":{"value":[' + JSON.stringify(this.groupId) + '],"modifier":"INCLUDES"}}'
    const raw: SceneDto[] = await this.api().findScenesFiltered(this.page, 24, '', 'date', 'DESC', sf)
    const list: Scene[] = Scene.listFromDto(raw)
    const merged: Scene[] = this.scenes.slice()
    for (let i = 0; i < list.length; i++) {
      merged.push(list[i])
    }
    this.scenes = merged
    this.hasMore = list.length >= 24
    this.page = this.page + 1
  }

  /* ---------------- 展示辅助 ---------------- */

  private nameOf(): string {
    const n: string = this.strOf(this.group.name)
    return n.length === 0 ? '集合' : n
  }

  private sceneCount(): number {
    return this.group.scene_count === undefined || this.group.scene_count === null ? 0 : this.group.scene_count
  }

  private synopsisText(): string {
    return this.strOf(this.group.synopsis)
  }

  private urlsOf(): string[] {
    if (this.group.urls === undefined || this.group.urls === null) {
      return []
    }
    return this.group.urls
  }

  private tagsOf(): TagDto[] {
    if (this.group.tags === undefined || this.group.tags === null) {
      return []
    }
    return this.group.tags
  }

  private studioId(): string {
    const st: StudioRefDto | undefined = this.group.studio
    if (st === undefined || st === null) {
      return ''
    }
    return this.strOf(st.id)
  }

  private studioName(): string {
    const st: StudioRefDto | undefined = this.group.studio
    if (st === undefined || st === null) {
      return ''
    }
    return this.strOf(st.name)
  }

  private aliasesText(): string {
    return this.strOf(this.group.aliases)
  }

  private ratingText(): string {
    const r: number = this.group.rating100 === undefined || this.group.rating100 === null ? 0 : this.group.rating100
    return r <= 0 ? '未评分' : (r / 20).toFixed(1) + ' 星（' + r.toString() + '/100）'
  }

  /** 秒 → h:mm:ss / m:ss */
  private durText(sec: number): string {
    if (sec <= 0) {
      return '—'
    }
    const t: number = Math.round(sec)
    const h: number = Math.floor(t / 3600)
    const m: number = Math.floor((t % 3600) / 60)
    const s: number = t % 60
    const ss: string = s < 10 ? '0' + s.toString() : s.toString()
    if (h > 0) {
      const mm: string = m < 10 ? '0' + m.toString() : m.toString()
      return h.toString() + ':' + mm + ':' + ss
    }
    return m.toString() + ':' + ss
  }

  private durValue(): number {
    return this.group.duration === undefined ? 0 : this.group.duration
  }

  /** 封面路径：front 优先，回退 back（都可为 null） */
  private coverPath(): string {
    const f: string = this.strOf(this.group.front_image_path)
    if (f.length > 0) {
      return f
    }
    return this.strOf(this.group.back_image_path)
  }

  /** DTO 里字符串字段可能是 null（GraphQL 可空），统一走这里取值 */
  private strOf(v: string | undefined): string {
    if (v === undefined || v === null) {
      return ''
    }
    return v
  }

  private syncText(): string {
    const s: string[] = []
    const d: string = this.strOf(this.group.director)
    if (d.length > 0) {
      s.push('导演 ' + d)
    }
    const dt: string = this.strOf(this.group.date)
    if (dt.length > 0) {
      s.push(dt)
    }
    const st: StudioRefDto | undefined = this.group.studio
    if (st !== undefined && st !== null) {
      const sn: string = this.strOf(st.name)
      if (sn.length > 0) {
        s.push(sn)
      }
    }
    return s.join(' · ')
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

  /* ---------------- 编辑 ---------------- */

  /** 日期输入自动格式化：只保留数字，按 YYYY-MM-DD 逐段补 - */
  private fmtDate(raw: string): string {
    let digits: string = ''
    for (let i = 0; i < raw.length; i++) {
      const ch: string = raw.charAt(i)
      if (ch >= '0' && ch <= '9') {
        digits = digits + ch
      }
    }
    if (digits.length > 8) {
      digits = digits.substring(0, 8)
    }
    if (digits.length <= 4) {
      return digits
    }
    if (digits.length <= 6) {
      return digits.substring(0, 4) + '-' + digits.substring(4)
    }
    return digits.substring(0, 4) + '-' + digits.substring(4, 6) + '-' + digits.substring(6)
  }

  private startEdit(): void {
    this.editName = this.nameOf()
    this.editAliases = this.aliasesText()
    this.editDate = this.strOf(this.group.date)
    this.editDuration = this.durValue() > 0 ? Math.round(this.durValue()).toString() : ''
    this.editRating = this.group.rating100 === undefined || this.group.rating100 === null ? '' : this.group.rating100.toString()
    this.editDirector = this.strOf(this.group.director)
    this.editSynopsis = this.synopsisText()
    this.editUrls = this.urlsOf().join('\n')
    this.editStudioId = this.studioId()
    this.editStudioName = this.studioName()
    const ids: string[] = []
    const nms: string[] = []
    const tags: TagDto[] = this.tagsOf()
    for (let i = 0; i < tags.length; i++) {
      const td: TagDto = tags[i]
      const id: string | undefined = td.id
      if (id !== undefined && id !== null) {
        ids.push(id)
        const nm: string | undefined = td.name
        nms.push(nm === undefined || nm === null ? '' : nm)
      }
    }
    this.editTagIds = ids
    this.editTagNames = nms
    this.pickMode = ''
    this.pickList = []
    this.editMode = true
  }

  private cancelEdit(): void {
    this.editMode = false
    this.pickMode = ''
    this.pickList = []
  }

  /** 文本 → 数字（空串/非法 → 0） */
  private numOf(text: string): number {
    const t: string = text.trim()
    if (t.length === 0) {
      return 0
    }
    const v: number = Number.parseInt(t)
    if (Number.isNaN(v) || v < 0) {
      return 0
    }
    return Math.round(v)
  }

  private async saveEdit(): Promise<void> {
    if (this.busy) {
      return
    }
    const nm: string = this.editName.trim()
    if (nm.length === 0) {
      this.say('名称不能为空')
      return
    }
    // 数字字段校验
    const durRaw: string = this.editDuration.trim()
    if (durRaw.length > 0 && Number.isNaN(Number.parseInt(durRaw))) {
      this.say('时长请填数字（单位：秒）')
      return
    }
    const ratRaw: string = this.editRating.trim()
    if (ratRaw.length > 0 && Number.isNaN(Number.parseInt(ratRaw))) {
      this.say('评分请填 0–100 的数字')
      return
    }
    this.busy = true
    try {
      const u = new GroupUpdate()
      u.name = nm
      // 注意：GroupUpdate.aliases 是单个字符串（不是数组）
      u.aliases = this.editAliases.trim()
      u.date = this.editDate.trim()
      u.duration = this.numOf(durRaw)
      let rat: number = this.numOf(ratRaw)
      if (rat > 100) {
        rat = 100
      }
      u.rating100 = rat
      u.director = this.editDirector.trim()
      u.synopsis = this.editSynopsis
      const urls: string[] = []
      const lines: string[] = this.editUrls.split('\n')
      for (let i = 0; i < lines.length; i++) {
        const one: string = lines[i].trim()
        if (one.length > 0) {
          urls.push(one)
        }
      }
      u.urls = urls
      u.studioId = this.editStudioId
      u.setStudio = true
      u.tagIds = this.editTagIds.slice()
      u.setTags = true

      await this.api().updateGroup(this.groupId, u)
      this.editMode = false
      this.pickMode = ''
      this.pickList = []
      this.say('已保存')
      bumpScenes()
      await this.load()
    } catch (e) {
      this.say('保存失败：' + (e as Error).message)
    }
    this.busy = false
  }

  /* ---------------- 删除 ---------------- */

  private confirmDelete(): void {
    AlertDialog.show({
      title: '删除集合',
      message: '将删除「' + this.nameOf() + '」。集合里的短片不会被删除，只是解除关联。确定继续？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: HMS_ERROR,
        action: () => {
          this.doDelete()
        }
      }
    })
  }

  private async doDelete(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      await this.api().destroyGroup(this.groupId)
      this.say('已删除集合')
      bumpScenes()
      router.back()
    } catch (e) {
      this.say('删除失败：' + (e as Error).message)
    }
    this.busy = false
  }

  /* ---------------- 选择浮层（工作室 / 标签） ---------------- */

  private async openPicker(mode: string): Promise<void> {
    this.pickMode = mode
    this.pickQuery = ''
    this.pickList = []
    await this.loadPickList()
  }

  private async loadPickList(): Promise<void> {
    this.pickLoading = true
    try {
      const all: PickItem[] = await loadOptionList(this.api(), this.pickMode)
      const q: string = this.pickQuery.trim().toLowerCase()
      if (q.length === 0) {
        this.pickList = all
      } else {
        const out: PickItem[] = []
        for (let i = 0; i < all.length; i++) {
          const it: PickItem = all[i]
          if (it.name.toLowerCase().indexOf(q) >= 0) {
            out.push(it)
          }
        }
        this.pickList = out
      }
    } catch (e) {
      this.say('加载失败：' + (e as Error).message)
    }
    this.pickLoading = false
  }

  private choosePick(it: PickItem): void {
    if (this.pickMode === 'studio') {
      this.editStudioId = it.id
      this.editStudioName = it.name
      this.pickMode = ''
      this.pickList = []
      return
    }
    // 标签多选：点一下加入 / 取消，浮层不关
    const idx: number = this.editTagIds.indexOf(it.id)
    if (idx >= 0) {
      this.removeTag(idx)
    } else {
      this.editTagIds = this.editTagIds.concat([it.id])
      this.editTagNames = this.editTagNames.concat([it.name])
    }
  }

  private isPicked(id: string): boolean {
    return this.editTagIds.indexOf(id) >= 0
  }

  private removeTag(i: number): void {
    const ids: string[] = []
    const nms: string[] = []
    for (let k = 0; k < this.editTagIds.length; k++) {
      if (k !== i) {
        ids.push(this.editTagIds[k])
        nms.push(this.editTagNames[k])
      }
    }
    this.editTagIds = ids
    this.editTagNames = nms
  }

  /* ---------------- UI ---------------- */

  /** 只读星级 */
  @Builder
  starRow(value: number) {
    Row() {
      ForEach([1, 2, 3, 4, 5], (i: number) => {
        SymbolGlyph(i <= Math.round(value / 20) ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(14)
          .fontColor([i <= Math.round(value / 20) ? this.theme.brandColor : this.theme.textSecondary])
          .margin({ right: 3 })
      }, (i: number) => i.toString())
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  fieldLabel(t: string) {
    Text(t).fontSize(11).fontColor(this.theme.textSecondary)
      .width('100%').margin({ top: GAP_S })
  }

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
  infoCard() {
    Column() {
      Row() {
        Column() {
          if (this.coverPath().length > 0) {
            AuthImage({ rawPath: this.coverPath() })
          }
        }
        .width(96).aspectRatio(3 / 4).clip(true).borderRadius(RADIUS_CHIP)

        Column() {
          Text(this.nameOf())
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          Text(this.sceneCount().toString() + ' 部短片')
            .fontSize(12).fontColor(this.theme.textSecondary).margin({ top: 2 }).width('100%')
          if (this.syncText().length > 0) {
            Text(this.syncText()).fontSize(11).fontColor(this.theme.textSecondary)
              .margin({ top: 4 }).width('100%').maxLines(2)
          }
          if (this.durValue() > 0) {
            Text('时长 ' + this.durText(this.durValue()))
              .fontSize(11).fontColor(this.theme.textSecondary)
              .margin({ top: 4 }).width('100%')
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_M })
      }.width('100%').alignItems(VerticalAlign.Top)

      // 评分
      Row() {
        Text('评分').fontSize(11).fontColor(this.theme.textSecondary)
        Row() {
          this.starRow(this.group.rating100 === undefined ? 0 : this.group.rating100)
        }.margin({ left: GAP_S })
        Text(this.ratingText()).fontSize(11).fontColor(this.theme.textSecondary)
          .margin({ left: GAP_S }).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_M })

      // 工作室
      Row() {
        Text('工作室').fontSize(11).fontColor(this.theme.textSecondary)
        if (this.studioName().length > 0) {
          Text(this.studioName())
            .fontSize(11).fontColor(this.theme.brandColor)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .margin({ left: GAP_S })
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              if (this.studioId().length > 0) {
                router.pushUrl({ url: 'pages/StudioDetailPage', params: { 'id': this.studioId() } })
              }
            })
        } else {
          Text('—').fontSize(11).fontColor(this.theme.textSecondary).margin({ left: GAP_S })
        }
      }
      .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_S })

      // 标签
      Column() {
        Text('标签').fontSize(11).fontColor(this.theme.textSecondary).width('100%')
        if (this.tagsOf().length === 0) {
          Text('—').fontSize(11).fontColor(this.theme.textSecondary).margin({ top: GAP_XS })
        } else {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.tagsOf(), (t: TagDto, idx: number) => {
              Text(this.strOf(t.name).length === 0 ? '—' : this.strOf(t.name))
                .fontSize(11).fontColor(this.theme.brandColor)
                .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .margin({ right: 6, top: 6 })
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  const tid: string = t.id === undefined ? '' : t.id
                  if (tid.length > 0) {
                    router.pushUrl({ url: 'pages/TagDetailPage', params: { 'id': tid } })
                  }
                })
            }, (t: TagDto, idx: number) => (t.id === undefined ? 't' + idx.toString() : t.id))
          }.width('100%')
        }
      }
      .width('100%').alignItems(HorizontalAlign.Start).margin({ top: GAP_S })

      // 别名
      if (this.aliasesText().length > 0) {
        Column() {
          Text('别名').fontSize(11).fontColor(this.theme.textSecondary).width('100%')
          Text(this.aliasesText()).fontSize(12).fontColor(this.theme.textPrimary)
            .width('100%').maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: GAP_XS })
        }
        .width('100%').alignItems(HorizontalAlign.Start).margin({ top: GAP_S })
      }

      // 简介
      if (this.synopsisText().length > 0) {
        Text(this.synopsisText())
          .fontSize(12).fontColor(this.theme.textSecondary).width('100%')
          .margin({ top: GAP_M }).lineHeight(18).maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      // URL
      Column() {
        Text('链接').fontSize(11).fontColor(this.theme.textSecondary).width('100%')
        if (this.urlsOf().length === 0) {
          Text('—').fontSize(11).fontColor(this.theme.textSecondary).margin({ top: GAP_XS })
        } else {
          ForEach(this.urlsOf(), (u: string, idx: number) => {
            Text(u).fontSize(12).fontColor(this.theme.brandColor)
              .width('100%').maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: GAP_XS })
          }, (u: string, idx: number) => idx.toString() + u)
        }
      }
      .width('100%').alignItems(HorizontalAlign.Start).margin({ top: GAP_S })

      // 操作行
      Row() {
        this.actionBtn('编辑', this.theme.brandColor, () => {
          this.startEdit()
        })
        Row() {
          this.actionBtn('删除', HMS_ERROR, () => {
            this.confirmDelete()
          })
        }.margin({ left: GAP_S })
      }
      .width('100%').margin({ top: GAP_M })
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder }).backgroundEffect({ radius: 24, saturation: 1.35 })
  }

  @Builder
  editCard() {
    Column() {
      Text('编辑集合').fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary).width('100%')

      this.fieldLabel('名称')
      TextInput({ text: this.editName, placeholder: '名称' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: GAP_XS })
        .onChange((v: string) => {
          this.editName = v
        })

      this.fieldLabel('别名（单个字符串，用逗号分隔）')
      TextInput({ text: this.editAliases, placeholder: '如 别名A, 别名B' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: GAP_XS })
        .onChange((v: string) => {
          this.editAliases = v
        })

      Row() {
        Column() {
          this.fieldLabel('日期')
          TextInput({ text: this.editDate, placeholder: 'YYYY-MM-DD' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: GAP_XS })
            .onChange((v: string) => {
              this.editDate = this.fmtDate(v)
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)

        Column() {
          this.fieldLabel('时长（秒）')
          TextInput({ text: this.editDuration, placeholder: '如 5400' })
            .type(InputType.Number)
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: GAP_XS })
            .onChange((v: string) => {
              this.editDuration = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_S })
      }
      .width('100%').alignItems(VerticalAlign.Top)

      Row() {
        Column() {
          this.fieldLabel('评分（0–100）')
          TextInput({ text: this.editRating, placeholder: '0–100' })
            .type(InputType.Number)
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: GAP_XS })
            .onChange((v: string) => {
              this.editRating = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)

        Column() {
          this.fieldLabel('导演')
          TextInput({ text: this.editDirector, placeholder: '导演' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: GAP_XS })
            .onChange((v: string) => {
              this.editDirector = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_S })
      }
      .width('100%').alignItems(VerticalAlign.Top)

      this.fieldLabel('简介')
      TextArea({ text: this.editSynopsis, placeholder: '简介 / 剧情概要' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(96).width('100%').margin({ top: GAP_XS })
        .onChange((v: string) => {
          this.editSynopsis = v
        })

      // 工作室（单选，可清除）
      this.fieldLabel('工作室')
      Flex({ wrap: FlexWrap.Wrap }) {
        if (this.editStudioName.length > 0) {
          Row() {
            Text(this.editStudioName).fontSize(11).fontColor(this.theme.textPrimary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('×')
              .fontSize(12).fontColor(this.theme.textSecondary)
              .margin({ left: 6 })
              .onClick(() => {
                this.editStudioId = ''
                this.editStudioName = ''
              })
          }
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
        }
        Text('选择')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            this.openPicker('studio')
          })
      }
      .width('100%').margin({ top: GAP_XS })

      // 标签（多选）
      this.fieldLabel('标签 (' + this.editTagNames.length.toString() + ')')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.editTagNames, (nm: string, idx: number) => {
          Row() {
            Text(nm).fontSize(11).fontColor(this.theme.textPrimary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('×')
              .fontSize(12).fontColor(this.theme.textSecondary)
              .margin({ left: 6 })
              .onClick(() => {
                this.removeTag(idx)
              })
          }
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
        }, (nm: string, idx: number) => nm + idx.toString())
        Text('选择')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ bottom: 6 })
          .onClick(() => {
            this.openPicker('tag')
          })
      }
      .width('100%').margin({ top: GAP_XS })

      // URL（每行一个）
      this.fieldLabel('URL（每行一个）')
      TextArea({ text: this.editUrls, placeholder: 'https://…' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(72).width('100%').margin({ top: GAP_XS })
        .onChange((v: string) => {
          this.editUrls = v
        })

      if (this.pickMode.length > 0) {
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
            this.cancelEdit()
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
    .backgroundEffect({ radius: 24, saturation: 1.35 })
  }

  @Builder
  pickerPanel() {
    Column() {
      Row() {
        Text((this.pickMode === 'studio' ? '选择工作室' : '选择标签')
          + '（' + this.pickList.length.toString() + '）')
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
        TextInput({ text: this.pickQuery, placeholder: '搜索名称' })
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
          if (this.pickMode === 'tag') {
            SymbolGlyph(this.isPicked(it.id)
              ? $r('sys.symbol.checkmark_circle_fill')
              : $r('sys.symbol.circle'))
              .fontSize(16)
              .fontColor([this.isPicked(it.id) ? this.theme.brandColor : this.theme.textSecondary])
          } else {
            Text('选择')
              .fontSize(11).fontColor(this.theme.brandColor)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          }
        }
        .width('100%').alignItems(VerticalAlign.Center)
        .padding({ top: 7, bottom: 7 })
        .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
        .onClick(() => {
          this.choosePick(it)
        })
      }, (it: PickItem) => it.id)
    }
    .width('100%').padding(GAP_S + 2)
    .backgroundColor(this.theme.chipBg)
    .borderRadius(RADIUS_CHIP)
    .margin({ top: GAP_S })
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
        title: this.nameOf(),
        subtitle: this.sceneCount().toString() + ' 部短片',
        theme: this.theme, style: GlassStyle.REGULAR
      })
      if (this.loading) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.editMode) {
              this.editCard()
            } else {
              this.infoCard()
            }
            if (!this.editMode) {
              Text('短片').fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary).width('100%').margin({ top: GAP_M + 4, bottom: GAP_S })
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.scenes, (s: Scene) => {
                  Column() { this.sceneCard(s) }
                    .width(layoutFor(this.winW).columns === 2 ? '48.5%' : '32%')
                    .margin({ bottom: GAP_S })
                }, (s: Scene) => s.id)
              }.width('100%')
              if (this.scenes.length === 0) {
                Text('这个集合还没有短片')
                  .fontSize(12).fontColor(this.theme.textSecondary)
                  .width('100%').textAlign(TextAlign.Center).padding(GAP_M)
              }
            }
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
