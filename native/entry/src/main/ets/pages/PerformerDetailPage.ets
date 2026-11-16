/**
 * StashGo — 演员详情（资料 + 收藏/评分 + 参演短片）
 */
import { router, promptAction } from '@kit.ArkUI'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Performer, PerformerDto, PerformerUpdate, Scene, SceneDto, Tag } from '../models/Models'
import { bumpScenes } from '../common/DataVersion'
import { AuthImage } from '../components/AuthImage'
import { StarRating } from '../components/StarRating'
import { GlassNavBar } from '../components/GlassNavBar'
import {
  GlassStyle, GlassTheme, GlassBackdrop,
  currentGlassTheme, currentBackdrop
} from '../common/GlassUtils'
import { layoutFor, columnsTemplate, RADIUS_CARD, RADIUS_CHIP, PAD_PAGE, GAP_M, GAP_S, GAP_XS } from '../common/Responsive'
import { L10n } from '../settings/L10n'

/** 性别可选项（value 为空 = 不修改） */
class GenderOpt {
  value: string = ''
  label: string = ''

  constructor(value: string, label: string) {
    this.value = value
    this.label = label
  }
}

@Entry
@Component
struct PerformerDetailPage {
  @State performer: Performer = new Performer('', '')
  @State scenes: Scene[] = []
  @State loading: boolean = true
  @State scenesLoading: boolean = false
  @State hasMore: boolean = true
  @State errorText: string = ''
  @State openAlias: boolean = false
  @State openBody: boolean = false
  @State openCareer: boolean = false
  @State openLinks: boolean = false
  @State openScenes: boolean = true
  @State lastUrl: string = ''
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  @StorageProp('winWidthVp') winW: number = 360

  // ── 编辑面板状态 ──
  @State editMode: boolean = false
  @State busy: boolean = false
  @State toast: string = ''
  @State editName: string = ''
  @State editDisambiguation: string = ''
  @State editAliases: string = ''
  @State editUrls: string = ''
  @State editGender: string = ''
  @State editBirthdate: string = ''
  @State editDeathDate: string = ''
  @State editCountry: string = ''
  @State editEthnicity: string = ''
  @State editHair: string = ''
  @State editEye: string = ''
  @State editHeight: string = ''
  @State editWeight: string = ''
  @State editMeasurements: string = ''
  @State editFakeTits: string = ''
  @State editTattoos: string = ''
  @State editPiercings: string = ''
  @State editCareerStart: string = ''
  @State editCareerEnd: string = ''
  @State editDetails: string = ''
  @State editError: string = ''
  @State mergeError: string = ''

  // ── 合并面板状态 ──
  @State mergeMode: boolean = false
  @State mergeStep: number = 1          // 1=选保留目标，2=选并入项，3=确认
  @State mergeQuery: string = ''
  @State mergeList: Performer[] = []
  @State mergeLoading: boolean = false
  @State mergeDestId: string = ''
  @State mergeDestName: string = ''
  @State mergeSrcIds: string[] = []
  @State mergeSrcNames: string[] = []

  private performerId: string = ''
  private page: number = 1
  private pageSize: number = 24

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>
    if (params !== undefined && params !== null) {
      const id: string | undefined = params['id']
      if (id !== undefined) {
        this.performerId = id
      }
    }
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
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const dto: PerformerDto | null = await api.findPerformer(this.performerId)
      if (dto !== null) {
        this.performer = Performer.fromDto(dto)
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

  private async loadScenes(): Promise<void> {
    if (this.scenesLoading || !this.hasMore) {
      return
    }
    this.scenesLoading = true
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const raw: SceneDto[] = await api.findScenesByPerformer(this.performerId, this.page, this.pageSize)
      const list: Scene[] = Scene.listFromDto(raw)
      const merged: Scene[] = this.scenes.slice()
      for (let i = 0; i < list.length; i++) {
        merged.push(list[i])
      }
      this.scenes = merged
      this.hasMore = list.length >= this.pageSize
      this.page = this.page + 1
    } catch (e) {
      console.error('[PerformerDetail] ' + (e as Error).message)
    }
    this.scenesLoading = false
  }

  private async toggleFavorite(): Promise<void> {
    const next: boolean = !this.performer.favorite
    this.performer.favorite = next
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      await api.updatePerformerFavorite(this.performerId, next)
    } catch (e) {
      this.performer.favorite = !next
    }
  }

  private async setRating(v: number): Promise<void> {
    const old: number = this.performer.rating100
    this.performer.rating100 = v
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      await api.updatePerformerRating(this.performerId, v)
    } catch (e) {
      this.performer.rating100 = old
    }
  }

  /* ---------------- 通用 ---------------- */

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

  /** 安全数字解析：NaN / 负数 → 0 */
  private numOf(raw: string): number {
    const n: number = Number.parseInt(raw.trim())
    if (Number.isNaN(n) || n < 0) {
      return 0
    }
    return n
  }

  private genderOptions(): GenderOpt[] {
    return [
      new GenderOpt('', '不修改'),
      new GenderOpt('FEMALE', '女'),
      new GenderOpt('MALE', '男'),
      new GenderOpt('TRANSGENDER_FEMALE', '跨性别女'),
      new GenderOpt('TRANSGENDER_MALE', '跨性别男'),
      new GenderOpt('INTERSEX', '间性'),
      new GenderOpt('NON_BINARY', '非二元')
    ]
  }

  /* ---------------- 编辑资料 ---------------- */

  /** 进入编辑：用 PerformerUpdate.from 预填当前值 */
  private startEdit(): void {
    const u: PerformerUpdate = PerformerUpdate.from(this.performer)
    this.editName = u.name
    this.editDisambiguation = u.disambiguation
    this.editAliases = u.aliases.join('\n')
    this.editUrls = u.urls.join('\n')
    this.editGender = u.gender
    this.editBirthdate = u.birthdate
    this.editDeathDate = u.death_date
    this.editCountry = u.country
    this.editEthnicity = u.ethnicity
    this.editHair = u.hair_color
    this.editEye = u.eye_color
    this.editHeight = u.height_cm > 0 ? u.height_cm.toString() : ''
    this.editWeight = u.weight > 0 ? u.weight.toString() : ''
    this.editMeasurements = u.measurements
    this.editFakeTits = u.fake_tits
    this.editTattoos = u.tattoos
    this.editPiercings = u.piercings
    this.editCareerStart = u.career_start
    this.editCareerEnd = u.career_end
    this.editDetails = u.details
    this.editError = ''
    this.mergeMode = false
    this.editMode = true
  }

  private async saveEdit(): Promise<void> {
    if (this.busy) {
      return
    }
    const name: string = this.editName.trim()
    if (name.length === 0) {
      this.say('姓名不能为空')
      return
    }
    const u = new PerformerUpdate()
    u.name = name
    u.disambiguation = this.editDisambiguation.trim()
    u.aliases = this.linesToArr(this.editAliases)
    u.urls = this.linesToArr(this.editUrls)
    u.gender = this.editGender
    u.birthdate = this.editBirthdate.trim()
    u.death_date = this.editDeathDate.trim()
    u.country = this.editCountry.trim()
    u.ethnicity = this.editEthnicity.trim()
    u.hair_color = this.editHair.trim()
    u.eye_color = this.editEye.trim()
    u.height_cm = this.numOf(this.editHeight)
    u.weight = this.numOf(this.editWeight)
    u.measurements = this.editMeasurements.trim()
    u.fake_tits = this.editFakeTits.trim()
    u.tattoos = this.editTattoos.trim()
    u.piercings = this.editPiercings.trim()
    u.career_start = this.editCareerStart.trim()
    u.career_end = this.editCareerEnd.trim()
    u.details = this.editDetails

    this.busy = true
    try {
      await this.api().updatePerformer(this.performerId, u)
      this.editMode = false
      this.editError = ''
      this.say('已保存')
      bumpScenes()
      await this.loadAll()
    } catch (e) {
      // 失败留在编辑态，显示服务端原因
      this.editError = '保存失败：' + (e as Error).message
      this.say(this.editError)
    }
    this.busy = false
  }

  /* ---------------- 合并演员 ---------------- */

  private openMerge(): void {
    this.editMode = false
    this.mergeMode = true
    this.mergeStep = 1
    this.mergeError = ''
    this.mergeDestId = ''
    this.mergeDestName = ''
    this.mergeSrcIds = []
    this.mergeSrcNames = []
    this.mergeQuery = ''
    this.fetchMergeList('')
  }

  private async fetchMergeList(q: string): Promise<void> {
    this.mergeLoading = true
    try {
      const raw: PerformerDto[] = await this.api().findPerformersEx(1, 40, q, 'name', 'ASC')
      this.mergeList = this.withSelf(Performer.listFromDto(raw))
    } catch (e) {
      this.mergeList = this.withSelf([])
      this.say('加载列表失败：' + (e as Error).message)
    }
    this.mergeLoading = false
  }

  /** 保证当前页演员在候选里（搜索命中不到时也能把它选成保留项） */
  private withSelf(list: Performer[]): Performer[] {
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.performerId) {
        return list
      }
    }
    const out: Performer[] = [this.performer]
    for (let i = 0; i < list.length; i++) {
      out.push(list[i])
    }
    return out
  }

  private async searchMerge(): Promise<void> {
    await this.fetchMergeList(this.mergeQuery.trim())
  }

  /** 列表里显示的名称（空名回退到 id） */
  private nameOf(p: Performer): string {
    return p.name.length === 0 ? ('#' + p.id) : p.name
  }

  /** 第 1 步的候选保留项：全部演员（本页演员也可以作为保留项） */
  private destCandidates(): Performer[] {
    return this.mergeList
  }

  /** 第 1 步：选定保留目标，进入第 2 步 */
  private pickDest(p: Performer): void {
    this.mergeDestId = p.id
    this.mergeDestName = this.nameOf(p)
    // 换目标时清掉已选的并入项（新目标可能正躺在里面）
    this.mergeSrcIds = []
    this.mergeSrcNames = []
    this.mergeStep = 2
  }

  /** 第 2 步：切换某个并入项的勾选（「排除自己」= 排除刚选的保留项） */
  private toggleSrc(p: Performer): void {
    if (p.id === this.mergeDestId) {
      this.say('保留项不能同时作为并入项')
      return
    }
    const ids: string[] = []
    const nms: string[] = []
    let hit: boolean = false
    for (let i = 0; i < this.mergeSrcIds.length; i++) {
      if (this.mergeSrcIds[i] === p.id) {
        hit = true
      } else {
        ids.push(this.mergeSrcIds[i])
        nms.push(this.mergeSrcNames[i])
      }
    }
    if (!hit) {
      ids.push(p.id)
      nms.push(this.nameOf(p))
    }
    this.mergeSrcIds = ids
    this.mergeSrcNames = nms
  }

  private isSrcSelected(id: string): boolean {
    return this.mergeSrcIds.indexOf(id) >= 0
  }

  /** 第 2 步的候选并入项：排除已选的保留项 */
  private srcCandidates(): Performer[] {
    const out: Performer[] = []
    for (let i = 0; i < this.mergeList.length; i++) {
      const p: Performer = this.mergeList[i]
      if (p.id !== this.mergeDestId) {
        out.push(p)
      }
    }
    return out
  }

  /** 第 3 步：二次确认 */
  private askConfirmMerge(): void {
    if (this.mergeDestId.length === 0) {
      this.say('请先选择要保留的演员')
      return
    }
    if (this.mergeSrcIds.length === 0) {
      this.say('请至少选择 1 个要并入的演员')
      return
    }
    this.mergeStep = 3
  }

  private async doMerge(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      await this.api().mergePerformers(this.mergeSrcIds.slice(), this.mergeDestId)
      this.mergeMode = false
      this.mergeStep = 1
      this.mergeError = ''
      bumpScenes()
      this.say('已合并到：' + this.mergeDestName)
      // 合并后列表/详情数据都可能变化：回上一页，列表靠 bumpScenes 刷新
      router.back()
    } catch (e) {
      this.mergeError = '合并失败：' + (e as Error).message
      this.say(this.mergeError)
    }
    this.busy = false
  }

  /** 以某个日期为参照算周岁（生日还没到就减一岁），返回纯数字串 */
  private ageAt(reference: string): string {
    const b: string = this.performer.birthdate
    if (b.length < 10 || reference.length < 10) {
      return ''
    }
    const by: number = Number.parseInt(b.substring(0, 4))
    const bm: number = Number.parseInt(b.substring(5, 7))
    const bd: number = Number.parseInt(b.substring(8, 10))
    const ry: number = Number.parseInt(reference.substring(0, 4))
    const rm: number = Number.parseInt(reference.substring(5, 7))
    const rd: number = Number.parseInt(reference.substring(8, 10))
    if (Number.isNaN(by) || Number.isNaN(bm) || Number.isNaN(bd) ||
      Number.isNaN(ry) || Number.isNaN(rm) || Number.isNaN(rd)) {
      return ''
    }
    let age: number = ry - by
    if (rm < bm || (rm === bm && rd < bd)) {
      age = age - 1
    }
    return (age > 0 && age < 120) ? age.toString() : ''
  }

  private ageText(): string {
    const b: string = this.performer.birthdate
    if (b.length < 10) {
      return ''
    }
    // 已去世：按逝世日期算「享年」，不能拿今天当现在算「N 岁」
    if (this.performer.death_date.length >= 10) {
      const n: string = this.ageAt(this.performer.death_date)
      return n.length > 0 ? ('享年 ' + n + ' 岁') : ''
    }
    const y: number = Number.parseInt(b.substring(0, 4))
    if (Number.isNaN(y)) {
      return ''
    }
    const now: Date = new Date()
    const age: number = now.getFullYear() - y
    if (age <= 0 || age > 120) {
      return ''
    }
    return age.toString() + ' 岁'
  }

  private durText(sec: number): string {
    if (sec <= 0) {
      return ''
    }
    const s: number = Math.floor(sec)
    const h: number = Math.floor(s / 3600)
    const m: number = Math.floor((s % 3600) / 60)
    const ss: number = s % 60
    if (h > 0) {
      return h.toString() + ':' + (m < 10 ? '0' + m.toString() : m.toString()) +
        ':' + (ss < 10 ? '0' + ss.toString() : ss.toString())
    }
    return m.toString() + ':' + (ss < 10 ? '0' + ss.toString() : ss.toString())
  }

  /** 别名（含 disambiguation） */
  private aliasText(): string {
    const parts: string[] = []
    if (this.performer.disambiguation.length > 0) {
      parts.push(this.performer.disambiguation)
    }
    for (let i = 0; i < this.performer.aliases.length; i++) {
      parts.push(this.performer.aliases[i])
    }
    return parts.join(' / ')
  }

  /* ---------------- 编辑 / 合并 UI ---------------- */

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
  editCard() {
    Column() {
      Row() {
        Text('编辑演员资料').fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textSecondary).layoutWeight(1)
        Text(this.busy ? '保存中…' : '')
          .fontSize(11).fontColor(this.theme.textSecondary)
      }
      .width('100%')

      // 失败原因直接留在面板里（Toast 之外的兜底）
      if (this.editError.length > 0) {
        Text(this.editError)
          .fontSize(11).fontColor('#FFE84026')
          .width('100%').margin({ top: 6 })
      }

      this.fieldLabel('姓名 *')
      TextInput({ text: this.editName, placeholder: '姓名' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editName = v
        })

      this.fieldLabel('消歧义')
      TextInput({ text: this.editDisambiguation, placeholder: '用于区分同名演员' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editDisambiguation = v
        })

      // 性别（可选项，空=不改）
      this.fieldLabel('性别')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.genderOptions(), (g: GenderOpt) => {
          Text(g.label)
            .fontSize(11)
            .fontColor(this.editGender === g.value ? Color.White : this.theme.textPrimary)
            .backgroundColor(this.editGender === g.value ? this.theme.brandColor : this.theme.chipBg)
            .borderRadius(RADIUS_CHIP)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .margin({ right: 6, bottom: 6 })
            .onClick(() => {
              this.editGender = g.value
            })
        }, (g: GenderOpt) => g.value.length === 0 ? '__none' : g.value)
      }
      .width('100%').margin({ top: 4 })

      this.fieldLabel('生日')
      TextInput({ text: this.editBirthdate, placeholder: 'YYYY-MM-DD' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editBirthdate = v
        })

      this.fieldLabel('逝世日期')
      TextInput({ text: this.editDeathDate, placeholder: 'YYYY-MM-DD' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editDeathDate = v
        })

      this.fieldLabel('国家')
      TextInput({ text: this.editCountry, placeholder: '如 Japan' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editCountry = v
        })

      this.fieldLabel('种族')
      TextInput({ text: this.editEthnicity, placeholder: '如 Asian' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editEthnicity = v
        })

      this.fieldLabel('发色')
      TextInput({ text: this.editHair, placeholder: '如 Black' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editHair = v
        })

      this.fieldLabel('瞳色')
      TextInput({ text: this.editEye, placeholder: '如 Brown' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editEye = v
        })

      Row() {
        Column() {
          this.fieldLabel('身高 (cm)')
          TextInput({ text: this.editHeight, placeholder: '如 165' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: 4 })
            .type(InputType.Number)
            .onChange((v: string) => {
              this.editHeight = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)

        Column() {
          this.fieldLabel('体重 (kg)')
          TextInput({ text: this.editWeight, placeholder: '如 50' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: 4 })
            .type(InputType.Number)
            .onChange((v: string) => {
              this.editWeight = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_S })
      }
      .width('100%').alignItems(VerticalAlign.Top)

      this.fieldLabel('三围')
      TextInput({ text: this.editMeasurements, placeholder: '如 90-60-90' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editMeasurements = v
        })

      this.fieldLabel('胸部')
      TextInput({ text: this.editFakeTits, placeholder: '如 Natural / Fake' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editFakeTits = v
        })

      this.fieldLabel('纹身')
      TextInput({ text: this.editTattoos, placeholder: '纹身描述' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editTattoos = v
        })

      this.fieldLabel('穿孔')
      TextInput({ text: this.editPiercings, placeholder: '穿孔描述' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editPiercings = v
        })

      Row() {
        Column() {
          this.fieldLabel('出道年份')
          TextInput({ text: this.editCareerStart, placeholder: 'YYYY' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: 4 })
            .onChange((v: string) => {
              this.editCareerStart = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)

        Column() {
          this.fieldLabel('引退年份')
          TextInput({ text: this.editCareerEnd, placeholder: 'YYYY' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: 4 })
            .onChange((v: string) => {
              this.editCareerEnd = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_S })
      }
      .width('100%').alignItems(VerticalAlign.Top)

      this.fieldLabel('别名（每行一个）')
      TextArea({ text: this.editAliases, placeholder: '每行一个别名' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(80).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editAliases = v
        })

      this.fieldLabel('URL（每行一个）')
      TextArea({ text: this.editUrls, placeholder: 'https://…' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(64).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editUrls = v
        })

      this.fieldLabel('简介')
      TextArea({ text: this.editDetails, placeholder: '简介 / 备注' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(110).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editDetails = v
        })

      Row() {
        Text('取消')
          .fontSize(12).fontColor(this.theme.textPrimary)
          .textAlign(TextAlign.Center).layoutWeight(1)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ top: 9, bottom: 9 })
          .margin({ right: 4 })
          .onClick(() => {
            this.editMode = false
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
  mergeCard() {
    Column() {
      Row() {
        Text('合并演员').fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textSecondary).layoutWeight(1)
        Text('取消')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .onClick(() => {
            this.mergeMode = false
            this.mergeStep = 1
          })
      }
      .width('100%')

      // 步骤指示
      Text(this.mergeStep === 1
        ? '第 1 步 / 3：选择要「保留」的演员（合并后的数据以它为准）'
        : (this.mergeStep === 2
          ? '第 2 步 / 3：勾选要「并入」保留项的演员（可多选）'
          : '第 3 步 / 3：确认合并'))
        .fontSize(11).fontColor(this.theme.textSecondary)
        .width('100%').margin({ top: 4 })

      if (this.mergeStep === 1) {
        Text('提示：当前页的演员（' + this.nameOf(this.performer) + '）也可以作为保留项')
          .fontSize(11).fontColor(this.theme.brandColor)
          .width('100%').margin({ top: 4 })
      }

      if (this.mergeError.length > 0) {
        Text(this.mergeError)
          .fontSize(11).fontColor('#FFE84026')
          .width('100%').margin({ top: 6 })
      }

      if (this.mergeStep !== 3) {
        Row() {
          TextInput({ text: this.mergeQuery, placeholder: '搜索演员姓名' })
            .fontSize(12).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(36).layoutWeight(1)
            .onChange((v: string) => {
              this.mergeQuery = v
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
          if (this.mergeStep === 1 && this.destCandidates().length === 0) {
            Text('没有可选演员').fontSize(12).fontColor(this.theme.textSecondary).margin({ top: GAP_S })
          }
          if (this.mergeStep === 2 && this.srcCandidates().length === 0) {
            Text('没有其他演员可选')
              .fontSize(12).fontColor(this.theme.textSecondary).margin({ top: GAP_S })
          }
        }
      }

      if (this.mergeStep === 1) {
        ForEach(this.destCandidates(), (p: Performer) => {
          Row() {
            Column() {
              AuthImage({ rawPath: p.image_path })
            }
            .width(36).height(48).clip(true).borderRadius(RADIUS_CHIP)

            Column() {
              Text(this.nameOf(p))
                .fontSize(12).fontColor(this.theme.textPrimary)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text((p.id === this.performerId ? '当前演员 · ' : '') + p.scene_count.toString() + ' 部')
                .fontSize(10)
                .fontColor(p.id === this.performerId ? this.theme.brandColor : this.theme.textSecondary)
                .width('100%').margin({ top: 2 })
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_S })

            Text('保留它')
              .fontSize(11).fontColor(Color.White)
              .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .margin({ left: GAP_S })
              .onClick(() => {
                this.pickDest(p)
              })
          }
          .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_S })
        }, (p: Performer) => p.id)
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

        ForEach(this.srcCandidates(), (p: Performer) => {
          Row() {
            Text(this.isSrcSelected(p.id) ? '☑' : '☐')
              .fontSize(16)
              .fontColor(this.isSrcSelected(p.id) ? this.theme.brandColor : this.theme.textSecondary)
              .width(24)
            Text(this.nameOf(p))
              .fontSize(12).fontColor(this.theme.textPrimary)
              .layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(p.scene_count.toString() + ' 部')
              .fontSize(10).fontColor(this.theme.textSecondary)
          }
          .width('100%').alignItems(VerticalAlign.Center)
          .padding({ top: 9, bottom: 9 })
          .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
          .onClick(() => {
            this.toggleSrc(p)
          })
        }, (p: Performer) => p.id)

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
          Text('并入的演员会被删除，其短片 / 图片 / 标签会转到保留项。此操作不可撤销。')
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
            .backgroundColor('#FFE84026').borderRadius(RADIUS_CHIP)
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
    .backdropBlur(24).margin({ top: GAP_M })
  }

  /** 基础信息行 */
  @Builder
  basicRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(11).fontColor(this.theme.textSecondary).width(56)
      Text(value.length === 0 ? '—' : value)
        .fontSize(11)
        .fontColor(value.length === 0 ? this.theme.textSecondary : this.theme.textPrimary)
        .layoutWeight(1)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').alignItems(VerticalAlign.Top).margin({ top: 5 })
  }

  /** 分组标题（可折叠，紧凑版） */
  @Builder
  sectionHeader(title: string, open: boolean, onToggle: () => void) {
    Row() {
      Text(title)
        .fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
        .layoutWeight(1)
      SymbolGlyph(open ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
        .fontSize(11).fontColor([this.theme.textSecondary])
    }
    .width('100%')
    .padding({ top: 8, bottom: 2, left: 2, right: 2 })
    .onClick(onToggle)
  }

  /** 基础信息卡：性别 / 生日 / 年龄（或享年）/ 逝世 / 国家 / 种族 */
  @Builder
  basicCard() {
    Column() {
      this.basicRow('性别', this.genderText(this.performer.gender))
      this.basicRow('生日', this.performer.birthdate)
      this.basicRow('年龄', this.ageText())
      if (this.performer.death_date.length > 0) {
        this.basicRow('逝世', this.performer.death_date)
      }
      this.basicRow('国家', this.performer.country)
      this.basicRow('种族', this.performer.ethnicity)
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_M })
  }

  /** 身体数据（折叠） */
  /** 别名（折叠，收起时只显示一行） */
  @Builder
  aliasCard() {
    Column() {
      this.sectionHeader('别名 (' + this.performer.aliases.length.toString() + ')',
        this.openAlias, () => {
          this.openAlias = !this.openAlias
        })
      Text(this.aliasText())
        .fontSize(11)
        .fontColor(this.theme.textSecondary)
        .maxLines(this.openAlias ? 12 : 1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 2 })
        .onClick(() => {
          this.openAlias = !this.openAlias
        })
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  @Builder
  bodyCard() {
    Column() {
      this.sectionHeader('身体数据', this.openBody, () => {
        this.openBody = !this.openBody
      })
      if (this.openBody) {
        this.basicRow('身高', this.performer.height_cm > 0 ? this.performer.height_cm.toString() + ' cm' : '')
        this.basicRow('体重', this.performer.weight > 0 ? this.performer.weight.toString() + ' kg' : '')
        this.basicRow('三围', this.performer.measurements)
        this.basicRow('胸部', this.performer.fake_tits)
        this.basicRow('发色', this.performer.hair_color)
        this.basicRow('瞳色', this.performer.eye_color)
        this.basicRow('纹身', this.performer.tattoos)
        this.basicRow('穿孔', this.performer.piercings)
      }
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  /** 职业（折叠） */
  @Builder
  careerCard() {
    Column() {
      this.sectionHeader('职业', this.openCareer, () => {
        this.openCareer = !this.openCareer
      })
      if (this.openCareer) {
        this.basicRow('出道', this.performer.career_start)
        this.basicRow('引退', this.performer.career_end)
        this.basicRow('短片', this.performer.scene_count.toString() + ' 部')
        this.basicRow('图片', this.performer.image_count.toString() + ' 张')
        this.basicRow('画廊', this.performer.gallery_count.toString() + ' 个')
        this.basicRow('集合', this.performer.group_count.toString() + ' 个')
        this.basicRow('射精', this.performer.o_counter.toString() + ' 次')
        this.basicRow('评分', this.performer.rating100 > 0
          ? (this.performer.rating100 / 20).toFixed(1) + ' / 5.0' : '')
      }
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  /** 链接（折叠） */
  @Builder
  linksCard() {
    Column() {
      this.sectionHeader('链接 (' + this.performer.urls.length.toString() + ')', this.openLinks, () => {
        this.openLinks = !this.openLinks
      })
      if (this.openLinks) {
        if (this.performer.urls.length === 0) {
          Text('没有链接').fontSize(12).fontColor(this.theme.textSecondary)
            .margin({ top: 6 })
        }
        ForEach(this.performer.urls, (u: string) => {
          Text(u)
            .fontSize(11).fontColor(this.theme.brandColor)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ top: 6 })
            .onClick(() => {
              this.lastUrl = u
            })
        }, (u: string) => u)
      }
    }
    .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 }).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_S })
  }

  /** 统计条目 */
  @Builder
  statCell(value: string, label: string) {
    Column() {
      Text(value).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme.textPrimary)
      Text(label).fontSize(10).fontColor(this.theme.textSecondary).margin({ top: 2 })
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  /** 统计行 */
  @Builder
  statsCard() {
    Row() {
      this.statCell(this.performer.scene_count.toString(), '短片')
      this.statCell(this.performer.image_count.toString(), '图片')
      this.statCell(this.performer.gallery_count.toString(), '画廊')
      this.statCell(this.performer.group_count.toString(), '集合')
      this.statCell(this.performer.o_counter.toString(), '射精')
    }
    .width('100%').padding(PAD_PAGE)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24).margin({ top: GAP_M })
  }

  @Builder
  headerCard() {
    Column() {
      Row() {
        Column() {
          if (this.performer.image_path.length > 0) {
            AuthImage({ rawPath: this.performer.image_path })
          } else {
            Column() {
              Text(this.performer.name.length > 0 ? this.performer.name.substring(0, 1) : '?')
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textSecondary)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme.chipBg)
          }
        }
        .width(96)
        .aspectRatio(3 / 4)
        .clip(true)
        .borderRadius(RADIUS_CHIP)

        Column() {
          Row() {
            Text(this.performer.name.length === 0 ? '（无名）' : this.performer.name)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(this.performer.favorite ? '★' : '☆')
              .fontSize(20)
              .fontColor(this.performer.favorite ? '#FFFFB700' : this.theme.textSecondary)
              .padding(4)
              .onClick(() => {
                this.toggleFavorite()
              })
          }
          .width('100%')

          Text(this.performer.scene_count.toString() + ' 部作品')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
            .width('100%')
            .margin({ top: 2 })

          Flex({ wrap: FlexWrap.Wrap }) {
            if (this.ageText().length > 0) {
              this.chip(this.ageText())
            }
            if (this.performer.country.length > 0) {
              this.chip(this.performer.country)
            }
            if (this.performer.height_cm > 0) {
              this.chip(this.performer.height_cm.toString() + ' cm')
            }
            if (this.performer.gender.length > 0) {
              this.chip(this.genderText(this.performer.gender))
            }
            if (this.performer.rating100 > 0) {
              this.chip('★ ' + (this.performer.rating100 / 20).toFixed(1))
            }
          }
          .width('100%')
          .margin({ top: 6 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: GAP_M })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(PAD_PAGE)
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24)
  }

  private genderText(g: string): string {
    if (g === 'FEMALE') {
      return '女'
    }
    if (g === 'MALE') {
      return '男'
    }
    if (g === 'TRANSGENDER_FEMALE') {
      return '跨性别女'
    }
    if (g === 'TRANSGENDER_MALE') {
      return '跨性别男'
    }
    return '其他'
  }

  @Builder
  chip(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor(this.theme.textPrimary)
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .margin({ right: 6, bottom: 6 })
  }

  @Builder
  ratingCard() {
    Column() {
      Text('评分')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .width('100%')
        .margin({ bottom: 8 })
      StarRating({
        value: this.performer.rating100,
        starSize: 26,
        showValue: true,
        onChange: (v: number) => {
          this.setRating(v)
        }
      })
      .width('100%')
    }
    .width('100%')
    .padding(PAD_PAGE)
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(24)
  }

  @Builder
  smallSceneCard(s: Scene) {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          AuthImage({ rawPath: s.poster })
        }
        .width('100%')
        .aspectRatio(16 / 9)
        .clip(true)

        if (this.durText(s.duration).length > 0) {
          Text(this.durText(s.duration))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(GAP_XS)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .margin({ right: 5, bottom: 5 })
        }
        if (s.hasCaption) {
          Text('字幕')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#9E000000')
            .borderRadius(GAP_XS)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .position({ left: 5, bottom: 5 })
        }
      }
      .width('100%')

      Text(s.title.length === 0 ? '（无标题）' : s.title)
        .fontSize(12)
        .fontColor(this.theme.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 8 })
        .align(Alignment.TopStart)
    }
    .width('100%')
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .backdropBlur(18)
    .clip(true)
    .onClick(() => {
      router.pushUrl({ url: 'pages/SceneDetailPage', params: { 'id': s.id } })
    })
  }

  private gridColumns(): number {
    return layoutFor(this.winW).columns
  }

  /** 参演短片卡片宽度：按列数留出 gap */
  private cardWidthPercent(): string {
    const n: number = this.gridColumns()
    if (n <= 2) {
      return '48.5%'
    }
    if (n === 3) {
      return '32%'
    }
    return '23.5%'
  }

  build() {
    Column() {
      GlassNavBar({
        title: this.performer.name.length === 0 ? L10n.translate('演员') : this.performer.name,
        subtitle: this.performer.scene_count > 0
          ? (this.performer.scene_count.toString() + ' 部作品')
          : '',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorText.length > 0) {
        Column() {
          Text(this.errorText).fontSize(13).fontColor('#FFE84026')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.headerCard()

            // 操作行（编辑资料 / 合并）
            Row() {
              this.actionBtn(this.editMode ? '编辑中' : '编辑资料', this.theme.brandColor, () => {
                if (this.editMode) {
                  this.editMode = false
                } else {
                  this.startEdit()
                }
              })
              this.actionBtn(this.mergeMode ? '合并中' : '合并', this.theme.textPrimary, () => {
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

            // 编辑 / 合并 面板
            if (this.editMode) {
              this.editCard()
            }
            if (this.mergeMode) {
              this.mergeCard()
            }

            this.basicCard()
            this.aliasCard()
            this.bodyCard()
            this.careerCard()
            this.linksCard()

            if (this.performer.details.length > 0) {
              Column() {
                Text('简介')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.textPrimary)
                  .width('100%')
                  .margin({ bottom: 6 })
                Text(this.performer.details)
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
                  .width('100%')
                  .lineHeight(18)
              }
              .width('100%')
              .padding(PAD_PAGE)
              .margin({ top: GAP_M })
              .backgroundColor(this.theme.cardBg)
              .borderRadius(RADIUS_CARD)
              .border({ width: 1, color: this.theme.cardBorder })
              .backdropBlur(24)
            }

            if (this.performer.tags.length > 0) {
              Column() {
                Text('标签')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.textPrimary)
                  .width('100%')
                  .margin({ bottom: 8 })
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.performer.tags, (t: Tag) => {
                    this.chip(t.name)
                  }, (t: Tag) => t.id)
                }
                .width('100%')
              }
              .width('100%')
              .padding(PAD_PAGE)
              .margin({ top: GAP_M })
              .backgroundColor(this.theme.cardBg)
              .borderRadius(RADIUS_CARD)
              .border({ width: 1, color: this.theme.cardBorder })
              .backdropBlur(24)
            }

            Column() {
              this.ratingCard()
            }
            .width('100%')
            .margin({ top: GAP_M })

            // 参演短片（折叠，内容与标题同卡片）
            Column() {
              this.sectionHeader('参演短片 (' + this.scenes.length.toString() + ')', this.openScenes, () => {
                this.openScenes = !this.openScenes
              })

              if (this.openScenes) {
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                  ForEach(this.scenes, (s: Scene) => {
                    Column() {
                      this.smallSceneCard(s)
                    }
                    .width(this.cardWidthPercent())
                    .margin({ bottom: GAP_S + 2 })
                  }, (s: Scene) => s.id)
                }
                .width('100%')

                if (this.scenesLoading) {
                  Row() {
                    LoadingProgress().width(20).height(20)
                    Text('加载中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .padding(10)
                }
              }
            }
            .width('100%')
            .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 6, bottom: 10 })
            .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
            .border({ width: 1, color: this.theme.cardBorder })
            .backdropBlur(24).margin({ top: GAP_S })
          }
          .width('100%')
          .padding({ left: PAD_PAGE, right: PAD_PAGE, top: 4, bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          this.loadScenes()
        })
      }
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
