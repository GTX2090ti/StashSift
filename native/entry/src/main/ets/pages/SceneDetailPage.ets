/**
 * StashSift — 短片详情（参考 stashscrubber 的信息分区结构）
 *
 * 结构：横幅 → 标题 → 操作行 → 基本情報 → 工作室 → 演员 → 标签 → URL → 文件
 */
import { router, promptAction } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'
import { Scene, SceneDto, ScenePerformer, SceneFile, Performer, PerformerDto, StudioDto, TagDto, GroupDto, StashBoxSource } from '../models/Models'
import { AuthImage } from '../components/AuthImage'
import { StarRating } from '../components/StarRating'
import { bumpScenes } from '../common/DataVersion'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { RADIUS_CARD, RADIUS_CHIP, RADIUS_XS, PAD_PAGE, GAP_M, GAP_S } from '../common/Responsive'
import { L10n } from '../settings/L10n'
import { PickItem, PickCache, loadOptions as loadOptionList } from '../common/OptionCache'

@Entry
@Component
struct SceneDetailPage {
  @State scene: Scene = new Scene('', '')
  @State loading: boolean = true
  /** 下拉刷新中（Refresh 双向绑定） */
  @State refreshing: boolean = false
  @State busy: boolean = false
  @State toast: string = ''
  @State editMode: boolean = false
  @State editTitle: string = ''
  @State editDate: string = ''
  @State editCode: string = ''
  @State editDirector: string = ''
  @State editDetails: string = ''
  @State editOrganized: boolean = false
  @State mergeQuery: string = ''
  // 关联编辑
  @State editStudioId: string = ''
  @State editStudioName: string = ''
  @State editStudioCleared: boolean = false
  @State editPerfIds: string[] = []
  @State editPerfNames: string[] = []
  @State editTagIds: string[] = []
  @State editTagNames: string[] = []
  // 集合关联（独立 mutation setSceneGroups）
  @State editGroupIds: string[] = []
  @State editGroupNames: string[] = []
  @State pickMode: string = ''
  @State pickQuery: string = ''
  @State pickList: PickItem[] = []
  @State pickGroups: GroupDto[] = []
  @State pickLoading: boolean = false
  @State newMode: string = ''
  @State newName: string = ''
  @State newBusy: boolean = false
  @State editUrls: string = ''
  @State mergeMode: boolean = false
  /** stash-box 识别：源选择面板 */
  @State identifyMode: boolean = false
  @State identifyBusy: boolean = false
  @State stashBoxes: StashBoxSource[] = []
  /** 识别时是否允许新建工作室/演员/标签（默认关，避免造出重复演员） */
  @State identifyCreateMissing: boolean = false
  @State isFav: boolean = false
  /** 刮削方式下拉菜单：展开状态 */
  @State scrapeMenuOpen: boolean = false
  /** 选中的刮削方式（-1 = 无；0 名称/URL，1 Fantia，2 Stash-box），等菜单关闭后再执行 */
  @State pendingScrape: number = -1
  /** FAVORITE 标签 id（收藏 = 带这个标签） */
  private favTagId: string = ''
  @State mergeList: Scene[] = []
  @State mergeLoading: boolean = false
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()
  private sceneId: string = ''

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string>
    if (p !== undefined && p !== null) {
      const id: string | undefined = p['id']
      if (id !== undefined) {
        this.sceneId = id
      }

    }
    this.load()
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
    if (this.sceneId.length > 0 && !this.loading) {
      this.load()
    }
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0
  @StorageProp('winWidthVp') winW: number = 365

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
      const dto: SceneDto | null = await this.api().findScene(this.sceneId)
      if (dto !== null) {
        this.scene = Scene.fromDto(dto)
        this.favTagId = await this.api().favoriteTagId()
        await this.loadFavState()
      }
    } catch (e) {
      this.say('加载失败：' + (e as Error).message)
    }
    this.loading = false
  }

  /** 下拉刷新：重新拉这条的元数据（刮削写回后立刻看到最新数据） */
  private async pullRefresh(): Promise<void> {
    if (this.loading) {
      this.refreshing = false
      return
    }
    try {
      const dto: SceneDto | null = await this.api().findScene(this.sceneId)
      if (dto !== null) {
        this.scene = Scene.fromDto(dto)
        await this.loadFavState()
        this.say('已刷新')
      } else {
        this.say('刷新失败：这条已不存在')
      }
    } catch (e) {
      this.say('刷新失败：' + (e as Error).message)
    }
    this.refreshing = false
  }

  /* ---------------- 格式化 ---------------- */

  /** 从完整路径取上级文件夹名 */
  private folderOf(path: string): string {
    const p: string = path.length > 0 ? path : ''
    const slash: number = p.lastIndexOf('/')
    if (slash <= 0) {
      return ''
    }
    const dir: string = p.substring(0, slash)
    const s2: number = dir.lastIndexOf('/')
    return s2 >= 0 ? dir.substring(s2 + 1) : dir
  }
  private durText(sec: number): string {
    if (sec <= 0) {
      return '—'
    }
    const s: number = Math.floor(sec)
    const h: number = Math.floor(s / 3600)
    const m: number = Math.floor((s % 3600) / 60)
    const ss: number = s % 60
    const mm: string = m < 10 ? '0' + m.toString() : m.toString()
    const sx: string = ss < 10 ? '0' + ss.toString() : ss.toString()
    return h > 0 ? (h.toString() + ':' + mm + ':' + sx) : (m.toString() + ':' + sx)
  }

  private sizeText(bytes: number): string {
    if (bytes <= 0) {
      return '—'
    }
    const gb: number = bytes / 1073741824
    if (gb >= 1) {
      return gb.toFixed(2) + ' GB'
    }
    const mb: number = bytes / 1048576
    return mb.toFixed(0) + ' MB'
  }

  /** Stash 的 mod_time 是 "YYYY/MM/DD HH:mm:ss" 格式 */
  private modText(t: string): string {
    if (t.length === 0) {
      return '—'
    }
    return t.length >= 16 ? t.substring(0, 16) : t
  }

  private resText(h: number): string {
    if (h >= 2160) {
      return '4K'
    }
    if (h >= 1080) {
      return '1080P'
    }
    if (h >= 720) {
      return '720P'
    }
    return h > 0 ? (h.toString() + 'P') : ''
  }

  private resHeight(): number {
    return this.scene.files.length > 0 ? this.scene.files[0].height : 0
  }

  /** 拍摄时年龄：用短片日期与生日精确到月日；短片没有日期时回退到当前年龄 */
  private ageOf(birth: string): string {
    if (birth.length < 10) {
      return ''
    }
    const by: number = Number.parseInt(birth.substring(0, 4))
    const bm: number = Number.parseInt(birth.substring(5, 7))
    const bd: number = Number.parseInt(birth.substring(8, 10))
    if (Number.isNaN(by) || Number.isNaN(bm) || Number.isNaN(bd)) {
      return ''
    }
    // 参照日期：短片拍摄日期（优先），否则今天
    let ry: number = new Date().getFullYear()
    let rm: number = new Date().getMonth() + 1
    let rd: number = new Date().getDate()
    const date: string = this.scene.date
    if (date.length >= 10) {
      const dy: number = Number.parseInt(date.substring(0, 4))
      const dm: number = Number.parseInt(date.substring(5, 7))
      const dd: number = Number.parseInt(date.substring(8, 10))
      if (!Number.isNaN(dy) && !Number.isNaN(dm) && !Number.isNaN(dd) && dy > 1900) {
        ry = dy
        rm = dm
        rd = dd
      }
    }
    let age: number = ry - by
    // 生日还没到就减一岁
    if (rm < bm || (rm === bm && rd < bd)) {
      age = age - 1
    }
    return (age > 0 && age < 120) ? (age.toString() + ' 岁') : ''
  }

  /* ---------------- 动作 ---------------- */

  private async markOrganized(): Promise<void> {
    this.busy = true
    try {
      const next: boolean = !this.scene.organized
      await this.api().bulkUpdateScenes([this.sceneId], next, this.scene.rating100)
      this.scene.organized = next
      this.say(next ? '已标记整理' : '已取消整理')
      bumpScenes()
    } catch (e) {
      this.say('操作失败：' + (e as Error).message)
    }
    this.busy = false
  }

  private async markPlayed(): Promise<void> {
    this.busy = true
    try {
      await this.api().markScenePlayed(this.sceneId)
      this.scene.play_count = this.scene.play_count + 1
      this.say('已标记已看')
    } catch (e) {
      this.say('操作失败：' + (e as Error).message)
    }
    this.busy = false
  }

  private async clearHistory(): Promise<void> {
    this.busy = true
    try {
      await this.api().resetScenePlayCount(this.sceneId)
      this.scene.play_count = 0
      this.scene.o_counter = 0
      this.say('已清除观看记录')
    } catch (e) {
      this.say('操作失败：' + (e as Error).message)
    }
    this.busy = false
  }

  private async genCover(): Promise<void> {
    this.busy = true
    try {
      await this.api().generateCovers([this.sceneId])
      this.say('已提交生成封面')
    } catch (e) {
      this.say('操作失败：' + (e as Error).message)
    }
    this.busy = false
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: '删除短片',
      message: '将从资料库移除这条记录，视频文件保留。确定继续？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FFE84026',
        action: () => {
          this.doDelete()
        }
      }
    })
  }

  private async doDelete(): Promise<void> {
    this.busy = true
    try {
      await this.api().destroyScene(this.sceneId, false)
      this.say('已删除')
      bumpScenes()
      router.back()
    } catch (e) {
      this.say('删除失败：' + (e as Error).message)
    }
    this.busy = false
  }

  private setRating(v: number): void {
    this.scene.rating100 = v
    this.api().updateScene(this.sceneId, v, this.scene.organized, this.scene.title, this.scene.details).catch((e: Error) => {
      this.say('评分失败：' + e.message)
    })
  }

  /* ---------------- 编辑 / 合并 ---------------- */

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
    this.editTitle = this.scene.title
    this.editDate = this.scene.date
    this.editCode = this.scene.code
    this.editDirector = this.scene.director
    this.editDetails = this.scene.details
    this.editOrganized = this.scene.organized
    this.editStudioId = this.scene.studioId
    this.editStudioName = this.scene.studioNames.length > 0 ? this.scene.studioNames[0] : ''
    this.editStudioCleared = false
    const pid: string[] = []
    const pnm: string[] = []
    for (let i = 0; i < this.scene.performerRefs.length; i++) {
      pid.push(this.scene.performerRefs[i].id)
      pnm.push(this.scene.performerRefs[i].name)
    }
    this.editPerfIds = pid
    this.editPerfNames = pnm
    this.editTagNames = this.scene.tagNames.slice()
    this.editTagIds = this.scene.tagIds.slice()
    this.editGroupIds = this.scene.groupIds.slice()
    this.editGroupNames = this.scene.groupNames.slice()
    this.editUrls = this.scene.urls.join('\n')
    this.pickMode = ''
    this.pickGroups = []
    this.editMode = true
    this.mergeMode = false
  }

  private async saveEdit(): Promise<void> {
    this.busy = true
    let fieldsOk: boolean = true
    try {
      await this.api().updateScene(this.sceneId, this.scene.rating100,
        this.editOrganized, this.editTitle, this.editDetails,
        this.editDate, this.editCode, this.editDirector)
      const urlLines: string[] = []
      const rawLines: string[] = this.editUrls.split('\n')
      for (let i = 0; i < rawLines.length; i++) {
        const u: string = rawLines[i].trim()
        if (u.length > 0) {
          urlLines.push(u)
        }
      }
      await this.api().updateSceneMeta(this.sceneId, this.editStudioId,
        this.editPerfIds, this.editTagIds, this.editStudioCleared, urlLines)
      this.scene.title = this.editTitle
      this.scene.date = this.editDate
      this.scene.code = this.editCode
      this.scene.director = this.editDirector
      this.scene.details = this.editDetails
      this.scene.organized = this.editOrganized
    } catch (e) {
      fieldsOk = false
      this.say('保存失败：' + (e as Error).message)
    }

    if (fieldsOk) {
      // 集合关联是独立 mutation：它失败不能吞掉上面已经保存成功的字段
      let groupsOk: boolean = true
      let groupErr: string = ''
      try {
        const ok: boolean = await this.api().setSceneGroups(this.sceneId, this.editGroupIds)
        if (!ok) {
          groupsOk = false
        }
      } catch (e) {
        groupsOk = false
        groupErr = (e as Error).message
      }
      if (groupsOk) {
        this.scene.groupIds = this.editGroupIds.slice()
        this.scene.groupNames = this.editGroupNames.slice()
        this.editMode = false
        this.say('已保存')
      } else {
        // 留在编辑态，方便只重试集合
        this.say(groupErr.length > 0 ? ('字段已保存，集合保存失败：' + groupErr) : '字段已保存，但集合关联保存失败')
      }
      bumpScenes()
      await this.load()
    }
    this.busy = false
  }

  /* ---------------- 关联选择器 ---------------- */

  private async openPicker(mode: string): Promise<void> {
    this.pickMode = mode
    this.pickQuery = ''
    // 立刻清空，避免加载完成前显示上一次的列表（演员列表串到工作室里）
    this.pickList = []
    await this.loadPickList()
  }

  private async searchPick(): Promise<void> {
    await this.loadPickList()
  }

  /** 取某一类的候选（共享缓存，只拉 id+name） */
  private async loadOptions(mode: string): Promise<PickItem[]> {
    return loadOptionList(this.api(), mode)
  }

  private async loadPickList(): Promise<void> {
    this.pickLoading = true
    try {
      const q: string = this.pickQuery.toLowerCase()
      const all: PickItem[] = await this.loadOptions(this.pickMode)
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
    } else if (this.pickMode === 'performer') {
      if (this.editPerfIds.indexOf(it.id) < 0) {
        this.editPerfIds = this.editPerfIds.concat([it.id])
        this.editPerfNames = this.editPerfNames.concat([it.name])
      }
    } else if (this.pickMode === 'tag') {
      if (this.editTagIds.indexOf(it.id) < 0) {
        this.editTagIds = this.editTagIds.concat([it.id])
        this.editTagNames = this.editTagNames.concat([it.name])
      }
    }
    this.pickMode = ''
    this.pickList = []
  }

  private removePerf(i: number): void {
    const ids: string[] = []
    const nms: string[] = []
    for (let k = 0; k < this.editPerfIds.length; k++) {
      if (k !== i) {
        ids.push(this.editPerfIds[k])
        nms.push(this.editPerfNames[k])
      }
    }
    this.editPerfIds = ids
    this.editPerfNames = nms
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

  /* ---------------- 集合选择（独立于 OptionCache） ---------------- */

  private removeGroup(i: number): void {
    const ids: string[] = []
    const nms: string[] = []
    for (let k = 0; k < this.editGroupIds.length; k++) {
      if (k !== i) {
        ids.push(this.editGroupIds[k])
        nms.push(this.editGroupNames[k])
      }
    }
    this.editGroupIds = ids
    this.editGroupNames = nms
  }

  private groupIdOf(g: GroupDto): string {
    return (g.id === undefined || g.id === null) ? '' : g.id
  }

  private groupNameOf(g: GroupDto): string {
    return (g.name === undefined || g.name === null) ? '' : g.name
  }

  /** 已在编辑列表里的集合 → 置灰不可重复添加 */
  private isGroupPicked(g: GroupDto): boolean {
    return this.editGroupIds.indexOf(this.groupIdOf(g)) >= 0
  }

  private async openGroupPicker(): Promise<void> {
    this.newMode = ''
    this.pickList = []
    this.pickGroups = []
    this.pickQuery = ''
    this.pickMode = 'group'
    await this.searchGroupPick()
  }

  /** 集合候选：走 findGroupsRich（带封面/数量的重查询，上限 300 条） */
  private async searchGroupPick(): Promise<void> {
    this.pickLoading = true
    try {
      const q: string = this.pickQuery.trim()
      const raw: GroupDto[] = await this.api().findGroupsRich(1, 300, 'name', 'ASC', q)
      const out: GroupDto[] = []
      for (let i = 0; i < raw.length; i++) {
        if (this.groupIdOf(raw[i]).length > 0) {
          out.push(raw[i])
        }
      }
      this.pickGroups = out
    } catch (e) {
      this.say('加载集合失败：' + (e as Error).message)
    }
    this.pickLoading = false
  }

  private chooseGroup(g: GroupDto): void {
    const gid: string = this.groupIdOf(g)
    if (gid.length === 0) {
      return
    }
    if (this.editGroupIds.indexOf(gid) < 0) {
      this.editGroupIds = this.editGroupIds.concat([gid])
      this.editGroupNames = this.editGroupNames.concat([this.groupNameOf(g)])
    }
    this.pickMode = ''
    this.pickGroups = []
  }
  private async openMerge(): Promise<void> {
    this.editMode = false
    this.mergeMode = true
    this.mergeQuery = ''
    await this.fetchMergeList('')
  }

  private async searchMerge(): Promise<void> {
    await this.fetchMergeList(this.mergeQuery)
  }

  private async fetchMergeList(q: string): Promise<void> {
    this.mergeLoading = true
    try {
      const raw: SceneDto[] = await this.api().findScenesFiltered(
        1, 30, q, 'created_at', 'DESC', '{}')
      const all: Scene[] = Scene.listFromDto(raw)
      const out: Scene[] = []
      for (let i = 0; i < all.length; i++) {
        if (all[i].id !== this.sceneId) {
          out.push(all[i])
        }
      }
      this.mergeList = out
    } catch (e) {
      this.say('加载列表失败：' + (e as Error).message)
    }
    this.mergeLoading = false
  }

  /** 收藏状态 = 这条短片是否带 FAVORITE 标签（与 SJP 一致） */
  private loadFavState(): void {
    this.isFav = this.favTagId.length > 0 && this.scene.tagIds.indexOf(this.favTagId) >= 0
  }

  /** 切换收藏：直接切「已整理」标记 */
  /* ---------------- stash-box 识别 ---------------- */

  /** 打开 stash-box 源选择（源列表来自服务端配置） */
  private async openIdentify(): Promise<void> {
    if (this.identifyBusy) {
      return
    }
    if (this.stashBoxes.length === 0) {
      try {
        this.stashBoxes = await this.api().stashBoxSources()
      } catch (e) {
        this.say('读取 BOX 配置失败：' + (e as Error).message)
        return
      }
    }
    if (this.stashBoxes.length === 0) {
      this.say('服务端没有配置 BOX 源')
      return
    }
    this.identifyMode = true
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (v: void) => void) => {
      setTimeout(() => {
        resolve()
      }, ms)
    })
  }

  /** 用选中源识别这条短片，等任务结束后重新载入 */
  private async runIdentify(box: StashBoxSource): Promise<void> {
    if (this.identifyBusy) {
      return
    }
    this.identifyMode = false
    this.identifyBusy = true
    this.say('正在用 ' + box.name + ' 识别…')
    try {
      const jobId: string = await this.api().identifyScene(this.sceneId, box.endpoint, this.identifyCreateMissing)
      if (jobId.length === 0) {
        this.say('识别任务没有提交成功')
        this.identifyBusy = false
        return
      }
      let status: string = 'RUNNING'
      for (let i = 0; i < 45; i++) {
        await this.sleep(2000)
        status = await this.api().jobStatus(jobId)
        if (status.length > 0 && status !== 'RUNNING' && status !== 'READY') {
          break
        }
      }
      if (status === 'FINISHED') {
        await this.load()
        bumpScenes()
        this.sayDialog(box.name + ' 识别完成', '已用 ' + box.name + ' 完成识别，详情页数据已刷新。\n标题、简介、日期、URL 只补空缺，已有内容不覆盖。')
      } else if (status === 'RUNNING' || status === 'READY' || status.length === 0) {
        this.sayDialog(box.name + ' 识别还在跑', '任务仍在执行，稍后下拉刷新查看结果。\n识别中不会阻塞其他操作。')
      } else {
        this.sayDialog(box.name + ' 识别失败', '服务端返回：' + status + '\n请稍后重试，或换一个识别源。')
      }
    } catch (e) {
      this.sayDialog(box.name + ' 识别失败', (e as Error).message)
    }
    this.identifyBusy = false
  }

  /** 弹窗提示（识别等关键结果用弹窗，避免 toast 一闪而过） */
  private sayDialog(title: string, message: string): void {
    AlertDialog.show({
      title: title,
      message: message,
      alignment: DialogAlignment.Center,
      primaryButton: { value: '知道了', action: () => { } }
    })
  }

  /** 清除刮削：清空标题/详情/日期/番号/导演/URL/工作室/演员/标签 */
  private confirmClearScrape(): void {
    AlertDialog.show({
      title: '清除刮削数据',
      message: '会清空这条的标题、简介、日期、番号、导演、URL、工作室、演员、标签。\n文件本身不受影响。',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '清除',
        fontColor: '#FFE84026',
        action: () => {
          this.doClearScrape()
        }
      }
    })
  }

  private async doClearScrape(): Promise<void> {
    this.busy = true
    try {
      const api = this.api()
      // 1) 文本字段清空
      const ok1: boolean = await api.updateScene(
        this.sceneId, this.scene.rating100, this.scene.organized, '', '', '', '', '')
      // 2) 关联与链接清空
      const ok2: boolean = await api.clearSceneMeta(this.sceneId)
      bumpScenes()
      if (ok1 && ok2) {
        this.say('已清除刮削数据')
        await this.load()
      } else {
        this.say('清除失败')
      }
    } catch (e) {
      this.say('清除失败：' + (e as Error).message)
    }
    this.busy = false
  }
  private async toggleFavorite(): Promise<void> {
    this.busy = true
    try {
      // 对齐 SJP：收藏 = FAVORITE 标签（整理是另一个独立标记，不在这里动）
      const next: boolean = !this.isFav
      const ok: boolean = await this.api().setSceneFavorite(this.sceneId, next)
      if (ok) {
        this.isFav = next
        bumpScenes()
        this.say(next ? '已收藏' : '已取消收藏')
        await this.load()
      } else {
        this.say('操作失败')
      }
    } catch (e) {
      this.say('操作失败：' + (e as Error).message)
    }
    this.busy = false
  }

  private confirmMerge(destId: string, destTitle: string): void {
    AlertDialog.show({
      title: '确认合并',
      message: '会与「' + (destTitle.length === 0 ? '（无标题）' : destTitle) +
        '」合并：刮削更完整的那条留作主文件，另一条随后被删除。此操作不可撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '合并',
        fontColor: '#FFE84026',
        action: () => {
          this.doMerge(destId, destTitle)
        }
      }
    })
  }

  /** 判断哪条更适合作为展示数据：已刮削（有标题/封面/演员/标签）的优先 */
  private scrapedScore(s: Scene): number {
    let n: number = 0
    if (s.title.length > 0) {
      n = n + 5
    }
    if (s.poster.length > 0) {
      n = n + 4
    }
    if (s.details.length > 0) {
      n = n + 2
    }
    if (s.date.length > 0) {
      n = n + 1
    }
    if (s.studioId.length > 0) {
      n = n + 3
    }
    n = n + Math.min(s.performerRefs.length, 5)
    n = n + Math.min(s.tagIds.length, 5)
    if (s.rating100 > 0) {
      n = n + 2
    }
    return n
  }

  /** 用已刮削的那条数据生成 SceneUpdateInput.values */
  private buildMergeValues(s: Scene): string {
    let v: string = '{"id":' + JSON.stringify(s.id)
    if (s.title.length > 0) {
      v = v + ',"title":' + JSON.stringify(s.title)
    }
    if (s.date.length > 0) {
      v = v + ',"date":' + JSON.stringify(s.date)
    }
    if (s.details.length > 0) {
      v = v + ',"details":' + JSON.stringify(s.details)
    }
    if (s.code.length > 0) {
      v = v + ',"code":' + JSON.stringify(s.code)
    }
    if (s.director.length > 0) {
      v = v + ',"director":' + JSON.stringify(s.director)
    }
    if (s.poster.length > 0) {
      v = v + ',"cover_image":' + JSON.stringify(s.poster)
    }
    if (s.urls.length > 0) {
      v = v + ',"urls":' + JSON.stringify(s.urls)
    }
    if (s.studioId.length > 0) {
      v = v + ',"studio_id":' + JSON.stringify(s.studioId)
    }
    const pids: string[] = []
    for (let i = 0; i < s.performerRefs.length; i++) {
      if (s.performerRefs[i].id.length > 0) {
        pids.push(s.performerRefs[i].id)
      }
    }
    if (pids.length > 0) {
      v = v + ',"performer_ids":' + JSON.stringify(pids)
    }
    if (s.tagIds.length > 0) {
      v = v + ',"tag_ids":' + JSON.stringify(s.tagIds)
    }
    v = v + '}'
    return v
  }

  private async doMerge(destId: string, destTitle: string): Promise<void> {
    this.busy = true
    try {
      // 取目标条目的元数据，决定合并后谁当主文件
      const destDto: SceneDto | null = await this.api().findScene(destId)
      const curScore: number = this.scrapedScore(this.scene)
      let destScore: number = -1
      if (destDto !== null) {
        destScore = this.scrapedScore(Scene.fromDto(destDto))
      }
      if (curScore > destScore) {
        // 当前这条刮得更完整：以它为主文件，把对方并进来
        await this.api().mergeScenes([destId], this.sceneId, true, true, '')
        this.say('已合并，已刮削的这条作为主文件')
      } else {
        // 对方更完整（或一样）：并到对方，必要时把当前数据覆盖过去
        const values: string = curScore > destScore ? this.buildMergeValues(this.scene) : ''
        await this.api().mergeScenes([this.sceneId], destId, true, true, values)
        this.say('已合并到：' + destTitle)
      }
      bumpScenes()
      this.mergeMode = false
      router.back()
    } catch (e) {
      this.say('合并失败：' + (e as Error).message)
    }
    this.busy = false
  }

  /** 把某个文件设为主文件（多文件条目里决定用哪个文件名/路径/播放） */
  private async setPrimaryFile(fileId: string): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      const ok: boolean = await this.api().setPrimaryFile(this.sceneId, fileId)
      if (ok) {
        bumpScenes()
        await this.load()
        this.say('已设为主文件')
      } else {
        this.say('设置失败：服务端未返回 id')
      }
    } catch (e) {
      this.say('设置失败：' + (e as Error).message)
    }
    this.busy = false
  }
  /* ---------------- UI ---------------- */

  @Builder
  actionBtn(label: string, color: ResourceColor, onTap: () => void) {
    Text(label)
      .fontSize(14)
      .fontColor(color)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 4, right: 4, top: 8, bottom: 8 })
      .layoutWeight(1)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .onClick(onTap)
  }

  /**
   * 刮削方式菜单：锚定在「刮削」按钮下方的自定义下拉菜单。
   *
   * 为什么不用 bindMenu / showActionSheet：
   * - showActionSheet 是系统底部操作表，样式跟 App 不统一（用户要求改回小菜单）。
   * - bindMenu 的菜单项在本页丢过点击：Menu 的选项是框架在独立弹层里渲染的，
   *   选项回调里直接 router.pushUrl 时，菜单关闭动画会和页面转场抢同一帧，
   *   表现就是「点了没反应」。MenuOptions 也没有 onStateChange 钩子，
   *   没法把动作推迟到弹层彻底关闭之后。
   * - bindPopup 的选项是我们自己画的普通 Text + onClick，不走 Menu 的手势机制，
   *   并且有 onStateChange，可以等弹层真正关闭后再执行跳转。
   */
  private runScrapeAction(idx: number): void {
    if (idx === 0) {
      router.pushUrl({
        url: 'pages/ScrapePage',
        params: { 'id': this.sceneId, 'sceneTitle': this.scene.title }
      })
    } else {
      router.pushUrl({ url: 'pages/FantiaPage', params: { 'sceneId': this.sceneId } })
    }
  }

  /** 下拉菜单里的一个选项 */
  @Builder
  scrapeMenuItem(label: string, idx: number) {
    Text(label)
      .fontSize(14)
      .fontColor(this.theme.textPrimary)
      .textAlign(TextAlign.Start)
      .width('100%')
      .padding({ left: 14, right: 14, top: 11, bottom: 11 })
      .onClick(() => {
        // 只记下选择并关掉弹层，真正的动作等弹层关闭（onStateChange）后再做
        this.pendingScrape = idx
        this.scrapeMenuOpen = false
      })
  }

  /** 下拉菜单面板：跟 App 主题一致，字号 14（Stash-box 已提为独立按钮，不在这里） */
  @Builder
  scrapeMenuPanel() {
    Column() {
      this.scrapeMenuItem('按名称 / URL 刮削', 0)
      Divider().color(this.theme.divider).margin({ left: 12, right: 12 })
      this.scrapeMenuItem('Fantia 刮削', 1)
    }
    .width(196)
    .padding({ top: 6, bottom: 6 })
    .backgroundColor(this.theme.cardBg)
    .borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.cardBorder })
    .shadow({ radius: 16, color: this.theme.cardShadow, offsetY: 4 })
  }

  /** 刮削按钮：三种刮削方式统一收在这一个入口里 */
  @Builder
  scrapeBtn() {
    Text(this.identifyBusy ? '识别中…' : '刮削')
      .fontSize(14)
      .fontColor(this.identifyBusy ? this.theme.textSecondary : this.theme.brandColor)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 4, right: 4, top: 8, bottom: 8 })
      .layoutWeight(1)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .onClick(() => {
        if (this.identifyBusy) {
          return
        }
        this.scrapeMenuOpen = !this.scrapeMenuOpen
      })
      .bindPopup(this.scrapeMenuOpen, {
        builder: this.scrapeMenuPanel,
        placement: Placement.Bottom,
        showInSubWindow: false,
        mask: false,
        autoCancel: true,
        enableArrow: true,
        popupColor: Color.Transparent,
        onStateChange: (e) => {
          if (!e.isVisible) {
            this.scrapeMenuOpen = false
            const idx: number = this.pendingScrape
            if (idx >= 0) {
              this.pendingScrape = -1
              // 弹层已彻底关闭，此时跳转不会被关闭动画吞掉
              this.runScrapeAction(idx)
            }
          }
        }
      })
  }

  @Builder
  editCard() {
    Column() {
      Text('编辑短片').fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary).width('100%')

      this.fieldLabel('标题')
      TextInput({ text: this.editTitle, placeholder: '标题' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editTitle = v
        })

      this.fieldLabel('日期')
      TextInput({ text: this.editDate, placeholder: 'YYYY-MM-DD' })
        .fontSize(13).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(40).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editDate = this.fmtDate(v)
        })

      Row() {
        Column() {
          this.fieldLabel('编号')
          TextInput({ text: this.editCode, placeholder: '如 ABC-123' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: 4 })
            .onChange((v: string) => {
              this.editCode = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)

        Column() {
          this.fieldLabel('导演')
          TextInput({ text: this.editDirector, placeholder: '导演' })
            .fontSize(13).fontColor(this.theme.textPrimary)
            .placeholderColor(this.theme.textSecondary)
            .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
            .height(40).width('100%').margin({ top: 4 })
            .onChange((v: string) => {
              this.editDirector = v
            })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: GAP_S })
      }
      .width('100%').alignItems(VerticalAlign.Top).margin({ top: GAP_S })

      this.fieldLabel('详情')
      TextArea({ text: this.editDetails, placeholder: '简介 / 备注' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(88).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editDetails = v
        })

      Row() {
        Text('已整理').fontSize(12).fontColor(this.theme.textSecondary)
        Toggle({ type: ToggleType.Switch, isOn: this.editOrganized })
          .margin({ left: GAP_S })
          .onChange((on: boolean) => {
            this.editOrganized = on
          })
      }
      .width('100%').margin({ top: GAP_S })

      // 工作室
      this.fieldLabel('工作室')
      Flex({ wrap: FlexWrap.Wrap }) {
        if (this.editStudioName.length > 0) {
          Row() {
            Text(this.editStudioName).fontSize(11).fontColor(this.theme.textPrimary)
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('×')
              .fontSize(12).fontColor(this.theme.textSecondary)
              .margin({ left: 6 })
              .onClick(() => {
                this.editStudioId = ''
                this.editStudioName = ''
                this.editStudioCleared = true
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
        Text('新建')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ bottom: 6 })
          .onClick(() => {
            this.openNew('studio')
          })
      }
      .width('100%').margin({ top: 4 })

      // 演员
      this.fieldLabel('演员 (' + this.editPerfNames.length.toString() + ')')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.editPerfNames, (nm: string, idx: number) => {
          Row() {
            Text(nm).fontSize(11).fontColor(this.theme.textPrimary)
            Text('×')
              .fontSize(12).fontColor(this.theme.textSecondary)
              .margin({ left: 6 })
              .onClick(() => {
                this.removePerf(idx)
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
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            this.openPicker('performer')
          })
        Text('新建')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ bottom: 6 })
          .onClick(() => {
            this.openNew('performer')
          })
      }
      .width('100%').margin({ top: 4 })

      // 标签
      this.fieldLabel('标签 (' + this.editTagNames.length.toString() + ')')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.editTagNames, (nm: string, idx: number) => {
          Row() {
            Text(nm).fontSize(11).fontColor(this.theme.textPrimary)
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
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            this.openPicker('tag')
          })
        Text('新建')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ bottom: 6 })
          .onClick(() => {
            this.openNew('tag')
          })
      }
      .width('100%').margin({ top: 4 })

      // 集合
      this.fieldLabel('集合 (' + this.editGroupNames.length.toString() + ')')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.editGroupNames, (nm: string, idx: number) => {
          Row() {
            Text(nm).fontSize(11).fontColor(this.theme.textPrimary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('×')
              .fontSize(12).fontColor(this.theme.textSecondary)
              .margin({ left: 6 })
              .onClick(() => {
                this.removeGroup(idx)
              })
          }
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
        }, (nm: string, idx: number) => 'g' + nm + idx.toString())
        Text('+ 添加')
          .fontSize(11).fontColor(this.theme.brandColor)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            this.openGroupPicker()
          })
      }
      .width('100%').margin({ top: 4 })

      // URL（每行一个）
      this.fieldLabel('URL（每行一个）')
      TextArea({ text: this.editUrls, placeholder: 'https://…' })
        .fontSize(12).fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textSecondary)
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .height(64).width('100%').margin({ top: 4 })
        .onChange((v: string) => {
          this.editUrls = v
        })

      if (this.pickMode === 'group') {
        this.groupPickerPanel()
      } else if (this.pickMode.length > 0) {
        this.pickerPanel()
      }
      if (this.newMode.length > 0) {
        this.newPanel()
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

  @Builder
  fieldLabel(t: string) {
    Text(t).fontSize(11).fontColor(this.theme.textSecondary)
      .width('100%').margin({ top: GAP_S })
  }

  /* ---------------- 新建关联项 ---------------- */

  private openNew(mode: string): void {
    this.newMode = mode
    this.newName = ''
    this.pickMode = ''
    this.pickList = []
  }

  private async createNew(): Promise<void> {
    const nm: string = this.newName.trim()
    if (nm.length === 0) {
      this.say('请输入名称')
      return
    }
    this.newBusy = true
    try {
      const api = this.api()
      if (this.newMode === 'studio') {
        const id: string = await api.createStudio(nm)
        if (id.length > 0) {
          this.editStudioId = id
          this.editStudioName = nm
          this.editStudioCleared = false
          this.say('已新建工作室：' + nm)
          this.newMode = ''
        } else {
          this.say('新建工作室失败')
        }
      } else if (this.newMode === 'performer') {
        const id: string = await api.createPerformer(nm)
        if (id.length > 0) {
          if (this.editPerfIds.indexOf(id) < 0) {
            this.editPerfIds = this.editPerfIds.concat([id])
            this.editPerfNames = this.editPerfNames.concat([nm])
          }
          PickCache.performers = PickCache.performers.concat([new PickItem(id, nm)])
          this.say('已新建演员：' + nm)
          this.newMode = ''
        } else {
          this.say('新建演员失败')
        }
      } else if (this.newMode === 'tag') {
        const id: string = await api.createTag(nm)
        if (id.length > 0) {
          if (this.editTagIds.indexOf(id) < 0) {
            this.editTagIds = this.editTagIds.concat([id])
            this.editTagNames = this.editTagNames.concat([nm])
          }
          PickCache.tags = PickCache.tags.concat([new PickItem(id, nm)])
          this.say('已新建标签：' + nm)
          this.newMode = ''
        } else {
          this.say('新建标签失败')
        }
      }
    } catch (e) {
      this.say('新建失败：' + (e as Error).message)
    }
    this.newBusy = false
  }

  @Builder
  newPanel() {
    Column() {
      Row() {
        Text(this.newMode === 'studio' ? '新建工作室' : (this.newMode === 'performer' ? '新建演员' : '新建标签'))
          .fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.brandColor).layoutWeight(1)
        Text('关闭')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .onClick(() => {
            this.newMode = ''
          })
      }
      .width('100%')

      Row() {
        TextInput({ text: this.newName, placeholder: '输入名称' })
          .fontSize(12).fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textSecondary)
          .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CHIP)
          .height(36).layoutWeight(1)
          .onChange((v: string) => {
            this.newName = v
          })
        Text(this.newBusy ? '创建中…' : '创建')
          .fontSize(11).fontColor(Color.White)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.createNew()
          })
      }
      .width('100%').margin({ top: GAP_S })
    }
    .width('100%').padding(GAP_S + 2)
    .backgroundColor(this.theme.chipBg)
    .borderRadius(RADIUS_CHIP)
    .margin({ top: GAP_S })
  }
  @Builder
  pickerPanel() {
    Column() {
      Row() {
        Text((this.pickMode === 'studio' ? '选择工作室' : (this.pickMode === 'performer' ? '选择演员' : '选择标签'))
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
        Text('搜索')
          .fontSize(11).fontColor(Color.White)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.searchPick()
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
  groupPickerPanel() {
    Column() {
      Row() {
        Text('选择集合（' + this.pickGroups.length.toString() + '）')
          .fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.brandColor).layoutWeight(1)
        Text('关闭')
          .fontSize(11).fontColor(this.theme.textSecondary)
          .onClick(() => {
            this.pickMode = ''
            this.pickGroups = []
          })
      }
      .width('100%')

      Row() {
        TextInput({ text: this.pickQuery, placeholder: '搜索集合名称' })
          .fontSize(12).fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textSecondary)
          .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
          .height(34).layoutWeight(1)
          .onChange((v: string) => {
            this.pickQuery = v
          })
        Text('搜索')
          .fontSize(11).fontColor(Color.White)
          .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .margin({ left: GAP_S })
          .onClick(() => {
            this.searchGroupPick()
          })
      }
      .width('100%').margin({ top: GAP_S })

      if (this.pickLoading) {
        Row() {
          LoadingProgress().width(16).height(16)
          Text('加载中…').fontSize(11).fontColor(this.theme.textSecondary).margin({ left: 6 })
        }.margin({ top: GAP_S })
      }
      if (!this.pickLoading && this.pickGroups.length === 0) {
        Text('没有匹配的集合').fontSize(11).fontColor(this.theme.textSecondary).margin({ top: GAP_S })
      }
      ForEach(this.pickGroups, (g: GroupDto) => {
        Row() {
          Text(this.groupNameOf(g).length === 0 ? '（无名称）' : this.groupNameOf(g))
            .fontSize(12).layoutWeight(1).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.isGroupPicked(g) ? this.theme.textSecondary : this.theme.textPrimary)
          if (this.isGroupPicked(g)) {
            Text('已选')
              .fontSize(11).fontColor(this.theme.textSecondary)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          } else {
            Text('选择')
              .fontSize(11).fontColor(this.theme.brandColor)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .onClick(() => {
                this.chooseGroup(g)
              })
          }
        }
        .width('100%').alignItems(VerticalAlign.Center)
        .padding({ top: 7, bottom: 7 })
        .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
      }, (g: GroupDto) => this.groupIdOf(g))
    }
    .width('100%').padding(GAP_S + 2)
    .backgroundColor(this.theme.chipBg)
    .borderRadius(RADIUS_CHIP)
    .margin({ top: GAP_S })
  }
  @Builder
  mergeCard() {
    Column() {
      Text('合并到另一条短片').fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary).width('100%')
      Text('当前这条会并入你选中的目标，播放记录与 O 计数一起带过去')
        .fontSize(11).fontColor(this.theme.textSecondary).width('100%').margin({ top: 4 })

      Row() {
        TextInput({ text: this.mergeQuery, placeholder: '搜索标题 / 编号' })
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
      if (!this.mergeLoading && this.mergeList.length === 0) {
        Text('没有可选短片').fontSize(12).fontColor(this.theme.textSecondary).margin({ top: GAP_S })
      }
      ForEach(this.mergeList, (s: Scene) => {
        Row() {
          Column() {
            AuthImage({ rawPath: s.poster })
          }
          .width(72).height(40.5).clip(true).borderRadius(RADIUS_CHIP)
          Text(s.title.length === 0 ? '（无标题）' : s.title)
            .fontSize(11).fontColor(this.theme.textPrimary)
            .layoutWeight(1).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: GAP_S })
          Text('选它')
            .fontSize(11).fontColor(Color.White)
            .backgroundColor(this.theme.brandColor).borderRadius(RADIUS_CHIP)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .margin({ left: GAP_S })
            .onClick(() => {
              this.confirmMerge(s.id, s.title)
            })
        }
        .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_S })
      }, (s: Scene) => s.id)
      Text('取消')
        .fontSize(12).fontColor(this.theme.textPrimary)
        .textAlign(TextAlign.Center).width('100%')
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .padding({ top: 9, bottom: 9 })
        .margin({ top: GAP_M })
        .onClick(() => {
          this.mergeMode = false
        })
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.brandColor })
    .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
  }

  @Builder
  identifyCard() {
    Column() {
      Text('BOX 刮削').fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary).width('100%')
      Text('按文件指纹在 BOX 源里找匹配。标题、简介、日期、URL 只补空缺，已有内容不覆盖。')
        .fontSize(11).fontColor(this.theme.textSecondary).width('100%').margin({ top: 4 })

      // 「允许新建」：stash-box 的演员名多为英文，和库里已有的日文名对不上，
      // 默认不新建，避免造出重复演员；确实需要补建时再打开。
      Row() {
        Text('允许新建工作室 / 演员 / 标签')
          .fontSize(12).fontColor(this.theme.textPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.identifyCreateMissing })
          .selectedColor(this.theme.brandColor)
          .width(44).height(22)
          .onChange((v: boolean) => {
            this.identifyCreateMissing = v
          })
      }
      .width('100%').alignItems(VerticalAlign.Center).margin({ top: GAP_S })

      if (this.identifyBusy) {
        Row() {
          LoadingProgress().width(18).height(18)
          Text('识别中…').fontSize(12).fontColor(this.theme.textSecondary).margin({ left: 6 })
        }.margin({ top: GAP_M })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.stashBoxes, (b: StashBoxSource) => {
            Text(b.name)
              .fontSize(12).fontColor(this.theme.brandColor)
              .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .margin({ right: GAP_S, top: GAP_S })
              .onClick(() => {
                this.runIdentify(b)
              })
          }, (b: StashBoxSource) => b.endpoint)
        }
        .width('100%')
      }

      Text('取消')
        .fontSize(12).fontColor(this.theme.textPrimary)
        .textAlign(TextAlign.Center).width('100%')
        .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
        .padding({ top: 9, bottom: 9 })
        .margin({ top: GAP_M })
        .onClick(() => {
          this.identifyMode = false
        })
    }
    .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
    .border({ width: 1, color: this.theme.brandColor })
    .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(this.theme.textSecondary).width(76)
      Text(value.length === 0 ? '—' : value)
        .fontSize(12)
        .fontColor(value.length === 0 ? this.theme.textSecondary : this.theme.textPrimary)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').alignItems(VerticalAlign.Top).margin({ top: 8 })
  }

  @Builder
  sectionTitle(t: string) {
    Text(t)
      .fontSize(13).fontWeight(FontWeight.Bold)
      .fontColor(this.theme.textSecondary)
      .width('100%').margin({ bottom: 2 })
  }


  /** 视频文件名（含扩展名） */
  private fileName(): string {
    const p: string = this.scene.filePath
    if (p.length === 0) {
      return ''
    }
    const i: number = p.lastIndexOf('/')
    return i >= 0 ? p.substring(i + 1) : p
  }

  /** 视频所在的上一级文件夹名 */
  private folderName(): string {
    const p: string = this.scene.filePath
    if (p.length === 0) {
      return ''
    }
    let end: number = p.lastIndexOf('/')
    if (end <= 0) {
      return ''
    }
    const head: string = p.substring(0, end)
    const start: number = head.lastIndexOf('/')
    return start >= 0 ? head.substring(start + 1) : head
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
  /** 复制文本到系统剪贴板 */
  private copyText(text: string): void {
    if (text.length === 0) {
      this.say('没有可复制的内容')
      return
    }
    try {
      const board = pasteboard.getSystemPasteboard()
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      board.setData(data).then(() => {
        this.say('已复制：' + (text.length > 24 ? text.substring(0, 24) + '…' : text))
      }).catch((e: Error) => {
        this.say('复制失败：' + e.message)
      })
    } catch (e) {
      this.say('复制失败：' + (e as Error).message)
    }
  }

  @Builder
  copyChip(label: string, value: string) {
    Text(label)
      .fontSize(11)
      .fontColor(this.theme.brandColor)
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .margin({ left: GAP_S })
      .onClick(() => {
        this.copyText(value)
      })
  }
  @Builder
  fileChip(label: string, onTap: () => void) {
    Text(label)
      .fontSize(11)
      .fontColor(this.theme.brandColor)
      .backgroundColor(this.theme.chipBg)
      .borderRadius(RADIUS_CHIP)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .margin({ left: GAP_S })
      .onClick(onTap)
  }

  @Builder
  bannerBlock() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      AuthImage({ rawPath: this.scene.poster })

      if (this.resText(this.resHeight()).length > 0) {
        Text(this.resText(this.resHeight()))
          .fontSize(10).fontColor(Color.White)
          .backgroundColor('#E60A59F7').borderRadius(RADIUS_CHIP)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .position({ left: 8, top: 8 })
      }
      if (this.scene.duration > 0) {
        Text(this.durText(this.scene.duration))
          .fontSize(10).fontColor(Color.White)
          .backgroundColor('#9E000000').borderRadius(RADIUS_CHIP)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ right: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height(this.bannerHeight())
    .clip(true)
    .borderRadius(RADIUS_CARD)
    .backgroundColor(this.theme.chipBg)
  }

  /** 横幅高度 = (窗口宽 - 左右内边距) * 9/16，避免 aspectRatio 与子节点 100% 高度互相依赖 */
  private bannerHeight(): number {
    const w: number = this.winW - PAD_PAGE * 2
    return w * 9 / 16
  }

  /** 封面垫底高度：覆盖状态栏 + 顶栏 + 横幅，再往下交给渐变 */
  private heroHeight(): number {
    return this.winW * 1.05
  }

  /**
   * 真实封面垫底 —— 「透」的前提。
   * 模糊 + 放大超出屏幕（裁掉模糊软边）+ 自上而下的遮罩（保证顶栏文字对比度，
   * 并在内容区平滑交回页面渐变）。
   */
  @Builder
  heroBackdrop() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.scene.poster.length > 0) {
        Column() {
          AuthImage({ rawPath: this.scene.poster })
        }
        .width('112%')
        .height(this.heroHeight())
        .margin({ left: '-6%' })
        .blur(8)
      }
      Column()
        .width('100%')
        .height(this.heroHeight())
        .linearGradient({
          angle: 180,
          colors: [
            [this.bd.veilTop, 0.0],
            [this.bd.veilMid, 0.22],
            ['#00000000', 0.40],
            [this.bd.mid, 0.72],
            [this.bd.mid, 1.0]
          ]
        })
    }
    .width('100%')
    .height(this.heroHeight())
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 页面底色
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 160, colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]] })

      this.heroBackdrop()

      Column() {
      GlassNavBar({
        title: this.scene.title.length === 0 ? L10n.translate('短片详情') : this.scene.title,
        subtitle: this.scene.studioNames.length > 0 ? this.scene.studioNames[0] : '',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.refreshing, promptText: '下拉刷新详情' }) {
        Scroll() {
          Column() {
            this.bannerBlock()

            Text(this.scene.title.length === 0 ? '（无标题）' : this.scene.title)
              .fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
              .width('100%').margin({ top: GAP_M })

            // 操作行（刮削 / Stash-box / 编辑 / 合并 / 删除）——一行五个等宽 chip
            Row({ space: 6 }) {
              this.scrapeBtn()
              this.actionBtn(this.identifyBusy ? '识别中…' : 'BOX',
                this.identifyBusy ? this.theme.textSecondary : this.theme.brandColor, () => {
                  if (!this.identifyBusy) {
                    this.openIdentify()
                  }
                })
              this.actionBtn(this.editMode ? '编辑中' : '编辑', this.theme.brandColor, () => {
                if (this.editMode) {
                  this.editMode = false
                } else {
                  this.startEdit()
                }
              })
              this.actionBtn(this.mergeMode ? '合并中' : '合并', this.theme.brandColor, () => {
                if (this.mergeMode) {
                  this.mergeMode = false
                } else {
                  this.openMerge()
                }
              })
              this.actionBtn('删除', '#FFE84026', () => {
                this.confirmDelete()
              })
            }
            .width('100%')
            // +1：卡片自带 1vp 边框，补上这一条让按钮行与卡片内容严格等齐
            .padding({ left: PAD_PAGE + 1, right: PAD_PAGE + 1 })
            .margin({ top: GAP_M - 2 })

            // 编辑 / 合并 / 识别 面板
            if (this.editMode) {
              this.editCard()
            }
            if (this.mergeMode) {
              this.mergeCard()
            }
            if (this.identifyMode || this.identifyBusy) {
              this.identifyCard()
            }

            // 基本情報
            Column() {
              this.sectionTitle('基本情報')
              this.infoRow('日期', this.scene.date)
              this.infoRow('O 计数', this.scene.o_counter.toString())
              this.infoRow('已看次数', this.scene.play_count.toString())
              this.infoRow('分辨率', this.resText(this.resHeight()))
              this.infoRow('时长', this.durText(this.scene.duration))
              this.infoRow('整理', this.scene.organized ? '已整理' : '未整理')
              Row() {
                Text('评分').fontSize(12).fontColor(this.theme.textSecondary).width(56)
                StarRating({
                  value: this.scene.rating100,
                  starSize: 24,
                  showValue: true,
                  onChange: (v: number) => {
                    this.setRating(v)
                  }
                })
                Blank()
              }
              .width('100%').alignItems(VerticalAlign.Center).margin({ top: 8 })

              // 清除刮削 / 收藏 / 整理 / 封面
              Row({ space: 6 }) {
                this.actionBtn('清除刮削', '#FFE84026', () => {
                  this.confirmClearScrape()
                })
                this.actionBtn(this.isFav ? '已收藏' : '收藏',
                  this.isFav ? '#FFFFB700' : this.theme.textPrimary, () => {
                    this.toggleFavorite()
                  })
                this.actionBtn(this.scene.organized ? '已整理' : '整理',
                  this.scene.organized ? '#FF3FA45B' : this.theme.textPrimary, () => {
                    this.markOrganized()
                  })
                this.actionBtn('封面', this.theme.textPrimary, () => {
                  this.genCover()
                })
              }
              .width('100%')
              .margin({ top: GAP_M - 2 })
            }
            .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
            .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
            .border({ width: 1, color: this.theme.cardBorder })
            .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })

            // 工作室
            Column() {
              this.sectionTitle('工作室')
              if (this.scene.studioNames.length === 0) {
                Text('未知工作室').fontSize(12).fontColor(this.theme.textSecondary)
                  .margin({ top: 6 })
              } else {
                Text(this.scene.studioNames[0])
                  .fontSize(13).fontColor(this.theme.brandColor)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ top: 6 })
                  .onClick(() => {
                    if (this.scene.studioId.length > 0) {
                      router.pushUrl({ url: 'pages/StudioDetailPage', params: { 'id': this.scene.studioId } })
                    }
                  })
              }
            }
            .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
            .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
            .border({ width: 1, color: this.theme.cardBorder })
            .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })

            // 所属集合
            if (this.scene.groupIds.length > 0) {
              Column() {
                this.sectionTitle('所属集合 (' + this.scene.groupIds.length.toString() + ')')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.scene.groupIds, (gid: string, gi: number) => {
                    Text(gi < this.scene.groupNames.length ? this.scene.groupNames[gi] : gid)
                      .fontSize(11).fontColor(this.theme.brandColor)
                      .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .margin({ right: 6, bottom: 6, top: 6 })
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .onClick(() => {
                        if (gid.length > 0) {
                          router.pushUrl({ url: 'pages/GroupDetailPage', params: { 'id': gid } })
                        }
                      })
                  }, (gid: string) => gid)
                }.width('100%')
              }
              .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
              .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
              .border({ width: 1, color: this.theme.cardBorder })
              .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
            }

            // 演员
            Column() {
              this.sectionTitle('演员 (' + this.scene.performerRefs.length.toString() + ')' + (this.scene.date.length >= 10 ? ' · 拍摄时年龄' : ''))
              if (this.scene.performerRefs.length === 0) {
                Text('没有演员信息').fontSize(12).fontColor(this.theme.textSecondary)
                  .margin({ top: 6 })
              }
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.scene.performerRefs, (p: ScenePerformer) => {
                  Row() {
                    Text(p.name).fontSize(12).fontColor(this.theme.textPrimary)
                    if (this.ageOf(p.birthdate).length > 0) {
                      Text(' · ' + this.ageOf(p.birthdate))
                        .fontSize(11).fontColor(this.theme.textSecondary)
                    }
                  }
                  .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .margin({ right: 6, bottom: 6, top: 6 })
                  .onClick(() => {
                    if (p.id.length > 0) {
                      router.pushUrl({ url: 'pages/PerformerDetailPage', params: { 'id': p.id } })
                    }
                  })
                }, (p: ScenePerformer) => p.id)
              }.width('100%')
            }
            .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
            .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
            .border({ width: 1, color: this.theme.cardBorder })
            .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })

            // 标签
            if (this.scene.tagNames.length > 0) {
              Column() {
                this.sectionTitle('标签 (' + this.scene.tagNames.length.toString() + ')')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.scene.tagNames, (t: string, i: number) => {
                    Text(t)
                      .fontSize(11).fontColor(this.theme.brandColor)
                      .backgroundColor(this.theme.chipBg).borderRadius(RADIUS_CHIP)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .margin({ right: 6, bottom: 6, top: 6 })
                      .onClick(() => {
                        const tid: string = i < this.scene.tagIds.length ? this.scene.tagIds[i] : ''
                        if (tid.length > 0) {
                          router.pushUrl({ url: 'pages/TagDetailPage', params: { 'id': tid } })
                        }
                      })
                  }, (t: string, i: number) => t + i.toString())
                }.width('100%')
              }
              .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
              .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
              .border({ width: 1, color: this.theme.cardBorder })
              .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
            }

            // URL
            if (this.scene.urls.length > 0) {
              Column() {
                this.sectionTitle('URL')
                ForEach(this.scene.urls, (u: string) => {
                  Text(u)
                    .fontSize(11).fontColor(this.theme.brandColor)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%').margin({ top: 6 })
                }, (u: string) => u)
              }
              .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
              .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
              .border({ width: 1, color: this.theme.cardBorder })
              .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
            }

            // 文件
            Column() {
              this.sectionTitle(this.scene.files.length > 1
                ? ('文件（' + this.scene.files.length.toString() + ' 个）')
                : '文件')
              if (this.scene.files.length > 1) {
                Text('该条目合并了多个文件')
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .margin({ bottom: 6 })
                ForEach(this.scene.files, (f: SceneFile, i: number) => {
                  Column() {
                    Row() {
                      Text(i === 0 ? '主' : (i + 1).toString())
                        .fontSize(10)
                        .fontColor(Color.White)
                        .backgroundColor(i === 0 ? '#FFE8A21A' : this.theme.brandColor)
                        .borderRadius(RADIUS_XS)
                        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      Text(f.basename)
                        .fontSize(11)
                        .fontColor(this.theme.textPrimary)
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ left: 6 })
                      if (i > 0) {
                        this.fileChip('设为主文件', () => {
                          this.setPrimaryFile(f.id)
                        })
                      }
                      this.copyChip('复制', f.basename)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .padding({ top: 6, bottom: 6 })

                    Text(f.path)
                      .fontSize(10)
                      .fontColor(this.theme.textSecondary)
                      .width('100%')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(this.sizeText(f.size) + '  ·  ' + this.durText(f.duration))
                      .fontSize(10)
                      .fontColor(this.theme.textSecondary)
                      .width('100%')

                    Row() {
                      Text('文件夹')
                        .fontSize(10)
                        .fontColor(this.theme.textSecondary)
                        .width(46)
                      Text(this.folderOf(f.path))
                        .fontSize(10)
                        .fontColor(this.theme.textPrimary)
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      this.copyChip('复制', this.folderOf(f.path))
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .margin({ top: 4 })
                      .margin({ top: 2 })
                  }
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                  .border({ width: { bottom: 1 }, color: this.theme.cardBorder })
                }, (f: SceneFile, i: number) => f.path + i.toString())
              } else {
                this.infoRow('路径', this.scene.filePath)
                this.infoRow('大小', this.sizeText(this.scene.fileSize))
                this.infoRow('时长', this.durText(this.scene.duration))
                this.infoRow('修改时间', this.modText(this.scene.fileModTime))

                Row() {
                  Text('文件名')
                    .fontSize(11).fontColor(this.theme.textSecondary)
                    .width(56)
                  Text(this.fileName())
                    .fontSize(11).fontColor(this.theme.textPrimary)
                    .layoutWeight(1).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  this.copyChip('复制', this.fileName())
                }
                .width('100%').alignItems(VerticalAlign.Center).margin({ top: 8 })

                Row() {
                  Text('文件夹')
                    .fontSize(11).fontColor(this.theme.textSecondary)
                    .width(56)
                  Text(this.folderName())
                    .fontSize(11).fontColor(this.theme.textPrimary)
                    .layoutWeight(1).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  this.copyChip('复制', this.folderName())
                }
                .width('100%').alignItems(VerticalAlign.Center).margin({ top: 6 })
              }
            }
            .width('100%').padding(PAD_PAGE).alignItems(HorizontalAlign.Start)
            .backgroundColor(this.theme.cardBg).borderRadius(RADIUS_CARD)
            .border({ width: 1, color: this.theme.cardBorder })
            .backgroundEffect({ radius: 24, saturation: 1.35 }).margin({ top: GAP_M })
          }
          .width('100%').padding({ left: PAD_PAGE, right: PAD_PAGE, top: 4, bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
        .layoutWeight(1).width('100%')
        .onRefreshing(() => {
          this.pullRefresh()
        })
      }
    }
    .width('100%').height('100%')
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}