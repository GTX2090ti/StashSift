/**
 * StashSift — 剪刮页（名称 / URL 两种模式 + 写回）
 */
import { router } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StashApi } from '../api/StashApi'
import { bumpScenes } from '../common/DataVersion'
import { RADIUS_CHIP } from '../common/Responsive'
import { AppSettings } from '../settings/AppSettings'
import { ScrapedSceneDto, ScraperDto, ScraperSpecDto, SceneDto, Scene } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GLASS_THEME_LIGHT, GlassBackdrop, currentGlassTheme, currentBackdrop, buildMaterial } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'

interface ScrapeParams {
  sceneId?: string
  id?: string
  sceneTitle?: string
}

@Entry
@Component
struct ScrapePage {
  @State scraperNames: string[] = []
  @State scraperIds: string[] = []
  /** URL 模式下列出的站点 URL 前缀（来自各刮削器的 scene.urls） */
  @State urlHints: string[] = []
  @State selectedScraper: number = 0
  @State suggestUrl: boolean = false
  /** 全量刮削器 + 各自的能力标记（按模式过滤后放进上面两个 @State 供 UI 用） */
  private allNames: string[] = []
  private allIds: string[] = []
  private allNameOk: boolean[] = []
  private allUrlOk: boolean[] = []
  private allFragOk: boolean[] = []
  private allUrls: string[][] = []
  @State mode: number = 0
  @State nameText: string = ''
  @State urlText: string = ''
  @State fileText: string = ''
  @State showScrapers: boolean = true
  @State busy: boolean = false
  @State status: string = ''
  @State statusError: boolean = false
  @State hasResult: boolean = false
  @State rTitle: string = ''
  @State rDate: string = ''
  @State rStudio: string = ''
  @State rPerformers: string = ''
  @State rTags: string = ''
  @State rDetails: string = ''
  @State rCode: string = ''
  @State rDirector: string = ''
  @State rUrls: string[] = []
  @State rImage: string = ''
  @State rPerfNames: string[] = []
  @State rTagNames: string[] = []
  private sceneId: string = ''
  @StorageProp('winHeightVp') winH: number = 809
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    const p = router.getParams() as ScrapeParams
    if (p !== null && p !== undefined) {
      if (p.sceneId !== undefined) {
        this.sceneId = p.sceneId
      }
      if (p.id !== undefined) {
        this.sceneId = p.id
      }
      if (p.sceneTitle !== undefined) {
        this.nameText = p.sceneTitle
        this.fileText = p.sceneTitle
      }
    }
    this.loadScrapers()
    if (this.sceneId.length > 0) {
      this.loadFileName()
    }
  }

  private async loadScrapers(): Promise<void> {
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const list: ScraperDto[] = await api.scrapers()
      const names: string[] = []
      const ids: string[] = []
      const nameOk: boolean[] = []
      const urlOk: boolean[] = []
      const fragOk: boolean[] = []
      const urls: string[][] = []
      for (let i = 0; i < list.length; i++) {
        const one: ScraperDto = list[i]
        const n: string | undefined = one.name
        const idv: string | undefined = one.id
        names.push(n === undefined || n === null ? '未命名' : n)
        ids.push(idv === undefined || idv === null ? '' : idv)
        // supported_scrapes：NAME 按名称、URL 按链接、FRAGMENT 按短片本身（scene_id）
        let canName: boolean = false
        let canUrl: boolean = false
        let canFrag: boolean = false
        const us: string[] = []
        const sp: ScraperSpecDto | undefined = one.scene
        if (sp !== undefined && sp !== null) {
          const caps: string[] | undefined = sp.supported_scrapes
          if (caps !== undefined && caps !== null) {
            for (let k = 0; k < caps.length; k++) {
              const c: string = caps[k]
              if (c === 'NAME') {
                canName = true
              } else if (c === 'URL') {
                canUrl = true
              } else if (c === 'FRAGMENT') {
                canFrag = true
              }
            }
          }
          const uu: string[] | undefined = sp.urls
          if (uu !== undefined && uu !== null) {
            for (let k = 0; k < uu.length; k++) {
              const u: string = uu[k]
              if (u !== undefined && u !== null && u.length > 0) {
                us.push(u)
              }
            }
          }
        }
        nameOk.push(canName)
        urlOk.push(canUrl)
        fragOk.push(canFrag)
        urls.push(us)
      }
      this.allNames = names
      this.allIds = ids
      this.allNameOk = nameOk
      this.allUrlOk = urlOk
      this.allFragOk = fragOk
      this.allUrls = urls
      this.applyModeFilter()
    } catch (e) {
      this.statusError = true
      this.status = '刮削器加载失败：' + (e as Error).message
    }
  }

  /**
   * 按当前模式筛出可用刮削器：
   *   0 短片标题 → 走 fragment（scene_id），只要支持 FRAGMENT
   *   1 名称     → 走 query 搜索，要支持 NAME
   *   2 URL      → 走链接匹配，要支持 URL
   */
  private applyModeFilter(): void {
    const names: string[] = []
    const ids: string[] = []
    const hints: string[] = []
    for (let i = 0; i < this.allIds.length; i++) {
      let ok: boolean = false
      if (this.mode === 0) {
        ok = this.allFragOk[i]
      } else if (this.mode === 1) {
        ok = this.allNameOk[i]
      } else {
        ok = this.allUrlOk[i]
      }
      if (!ok) {
        continue
      }
      names.push(this.allNames[i])
      ids.push(this.allIds[i])
      if (this.mode === 2) {
        const u: string[] = this.allUrls[i]
        for (let k = 0; k < u.length; k++) {
          const n: string = this.normUrl(u[k])
          if (n.length > 0 && hints.indexOf(n) < 0) {
            hints.push(n)
          }
        }
      }
    }
    this.scraperNames = names
    this.scraperIds = ids
    this.urlHints = hints
    if (this.selectedScraper >= names.length) {
      this.selectedScraper = 0
    }
  }

  /** URL 前缀统一成人看得懂的样子：去掉协议头与结尾斜杠 */
  private normUrl(u: string): string {
    let s: string = u.trim()
    if (s.startsWith('https://')) {
      s = s.substring(8)
    } else if (s.startsWith('http://')) {
      s = s.substring(7)
    }
    while (s.length > 0 && s.endsWith('/')) {
      s = s.substring(0, s.length - 1)
    }
    return s
  }

  /** 切换模式：重算可用刮削器，清掉上一条建议 */
  private setMode(m: number): void {
    if (this.mode === m) {
      return
    }
    this.mode = m
    this.suggestUrl = false
    this.status = ''
    this.applyModeFilter()
    if (m === 0 && this.sceneId.length > 0 && this.fileText.length === 0) {
      this.loadFileName()
    }
  }

  /** 服务端说「这个刮削器不能按名称刮」 */
  private isNameUnsupported(raw: string): boolean {
    const low: string = raw.toLowerCase()
    return low.indexOf('cannot load scene by name') >= 0 || low.indexOf('operation not supported') >= 0
  }

  /** 把服务端/网络原文翻译成用户能照着做的中文 */
  private humanError(raw: string): string {
    const low: string = raw.toLowerCase()
    if (this.isNameUnsupported(raw)) {
      return '这个刮削器只能按 URL 刮，不支持按名称搜：复制作品网页链接，切到「URL」模式再试。'
    }
    if (low.indexOf('403') >= 0 || low.indexOf('forbidden') >= 0) {
      return '源站拒绝访问（403 反爬）。换一个刮削器试试；或让 Stash 走 FlareSolverr 再刮。'
    }
    if (low.indexOf('400') >= 0) {
      return '请求被网关 / 代理拒绝（400）。检查 Stash 容器的代理是否可用后再试。'
    }
    if (low.indexOf('timeout') >= 0 || low.indexOf('timed out') >= 0 || low.indexOf('超时') >= 0) {
      return '刮削超时：站点响应太慢，换一个刮削器或稍后重试。'
    }
    if (low.indexOf('网络错误') >= 0 || low.indexOf('network') >= 0) {
      return raw
    }
    if (low.indexOf('cannot read property') >= 0) {
      return '刮削器返回了空结果，换一个刮削器试试。'
    }
    return '刮削失败：' + raw
  }

  /** 从关联短片取文件名（去目录、去扩展名）作为刮削关键词 */
  /** 把可能为 null / undefined 的字段安全转成字符串 */
  private toStr(v: Object | undefined): string {
    if (v === undefined) {
      return ''
    }
    if (v === null) {
      return ''
    }
    return v.toString()
  }
  private async loadFileName(): Promise<void> {
    if (this.sceneId.length === 0) {
      return
    }
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const dto: SceneDto | null = await api.findScene(this.sceneId)
      if (dto === null) {
        this.statusError = true
        this.status = '读取短片失败'
        return
      }
      const sc: Scene = Scene.fromDto(dto)
      // 优先用你编辑过的标题，没有标题才退回文件名
      const edited: string = sc.title.trim()
      if (edited.length > 0) {
        this.fileText = edited
        this.statusError = false
        this.status = '已读取标题'
        return
      }
      let p: string = sc.filePath
      if (p.length === 0) {
        this.statusError = true
        this.status = '该短片没有文件路径'
        return
      }
      // 去目录
      const slash: number = p.lastIndexOf('/')
      if (slash >= 0) {
        p = p.substring(slash + 1)
      }
      // 去扩展名
      const dot: number = p.lastIndexOf('.')
      if (dot > 0) {
        p = p.substring(0, dot)
      }
      this.fileText = p
      this.statusError = false
      this.status = ''
    } catch (e) {
      this.statusError = true
      this.status = '读取文件名失败：' + (e as Error).message
    }
  }
  private async doScrape(): Promise<void> {
    if (this.scraperIds.length === 0) {
      this.statusError = true
      this.status = this.mode === 2
        ? '没有可用的刮削器：先去「刮削器安装」装一个，或检查服务端'
        : '当前模式没有可用刮削器：切到「URL」模式再试，或去装一个支持该模式的刮削器。'
      this.suggestUrl = true
      return
    }
    const keyword: string = this.mode === 0 ? this.fileText.trim()
      : (this.mode === 1 ? this.nameText.trim() : this.urlText.trim())
    if (keyword.length === 0) {
      this.statusError = true
      this.status = this.mode === 0 ? '请输入标题（未关联短片时需手填）'
        : (this.mode === 1 ? '请输入名称' : '请输入 URL')
      return
    }
    // 标题模式必须有短片才能走 fragment
    if (this.mode === 0 && this.sceneId.length === 0) {
      this.statusError = true
      this.status = '「短片标题」模式需要先关联一条短片：从短片详情页进刮削，或改用「名称」/「URL」模式。'
      return
    }
    this.busy = true
    this.statusError = false
    this.suggestUrl = false
    this.status = '刮削中…'
    this.hasResult = false
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const sid: string = this.scraperIds[this.selectedScraper]
      let r: ScrapedSceneDto | null
      if (this.mode === 2) {
        r = await api.scrapeSceneURL(keyword)
      } else if (this.mode === 0) {
        r = await api.scrapeSceneByFragment(this.sceneId, sid, keyword)
      } else {
        r = await api.scrapeSceneByName(keyword, sid)
      }
      if (r === null) {
        this.statusError = true
        this.status = this.mode === 2
          ? '这个链接没刮到内容：确认链接是作品页而不是列表页，或换个站点'
          : '没有匹配结果：换一个刮削器，或把作品链接贴到「URL」模式再刮'
        this.suggestUrl = this.mode !== 2
      } else {
        this.showScrapers = false   // 刮削成功：收起刮削器列表，把结果露出来
        this.rTitle = this.toStr(r.title)
        this.rDate = this.toStr(r.date)
        this.rDetails = this.toStr(r.details)
        this.rCode = this.toStr(r.code)
        this.rDirector = this.toStr(r.director)
        // 工作室（可能整个为 null）
        let studioName: string = ''
        if (r.studio !== undefined && r.studio !== null) {
          studioName = this.toStr(r.studio.name)
        }
        this.rStudio = studioName
        // 演员
        const ps: string[] = []
        if (r.performers !== undefined && r.performers !== null) {
          for (let i = 0; i < r.performers.length; i++) {
            const one: string = this.toStr(r.performers[i].name)
            if (one.length > 0) {
              ps.push(one)
            }
          }
        }
        this.rPerfNames = ps
        this.rPerformers = ps.join(' · ')
        // 标签
        const ts: string[] = []
        if (r.tags !== undefined && r.tags !== null) {
          for (let i = 0; i < r.tags.length; i++) {
            const one: string = this.toStr(r.tags[i].name)
            if (one.length > 0) {
              ts.push(one)
            }
          }
        }
        this.rTags = ts.join(' · ')
        this.rTagNames = ts
        // 链接（可能为 null）
        const us: string[] = []
        if (r.urls !== undefined && r.urls !== null) {
          for (let i = 0; i < r.urls.length; i++) {
            const one: string = this.toStr(r.urls[i])
            if (one.length > 0) {
              us.push(one)
            }
          }
        }
        this.rUrls = us
        this.rImage = this.toStr(r.image)
        this.showScrapers = false   // 刮削成功：收起刮削器列表
        this.hasResult = true
        this.status = '刮削成功'
      }
    } catch (e) {
      const raw: string = (e as Error).message
      hilog.warn(0x0000, 'StashSift-Scrape', 'scrape failed: %{public}s', raw)
      this.statusError = true
      this.status = this.humanError(raw)
      this.suggestUrl = this.isNameUnsupported(raw)
    }
    this.busy = false
  }

  private async applyResult(): Promise<void> {
    if (this.sceneId.length === 0) {
      this.statusError = true
      this.status = '缺少短片 ID，无法写回'
      return
    }
    this.busy = true
    this.status = '写回中…'
    const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)

    // 1) 读当前短片：已有内容的字段一律不覆盖
    let rating: number = 0
    let organized: boolean = false
    let curTitle: string = ''
    let curDetails: string = ''
    let curDate: string = ''
    let curCode: string = ''
    let curDirector: string = ''
    let curImage: string = ''
    let hasStudio: boolean = false
    let curPerfIds: string[] = []
    let curTagIds: string[] = []
    let curUrls: string[] = []
    try {
      const cur: SceneDto | null = await api.findScene(this.sceneId)
      if (cur !== null && cur !== undefined) {
        const rv: number | undefined = cur.rating100
        rating = (rv === undefined || rv === null) ? 0 : rv
        organized = cur.organized === true
        curTitle = this.safe(cur.title)
        curDetails = this.safe(cur.details)
        curDate = this.safe(cur.date)
        curCode = this.safe(cur.code)
        curDirector = this.safe(cur.director)
        const st = cur.studio
        if (st !== undefined && st !== null) {
          hasStudio = this.safe(st.id).length > 0
        }
        const pf = cur.performers
        if (pf !== undefined && pf !== null) {
          for (let i = 0; i < pf.length; i++) {
            const pid = pf[i].id
            if (pid !== undefined && pid !== null && pid.length > 0) {
              curPerfIds.push(pid)
            }
          }
        }
        const tg = cur.tags
        if (tg !== undefined && tg !== null) {
          for (let i = 0; i < tg.length; i++) {
            const tid = tg[i].id
            if (tid !== undefined && tid !== null && tid.length > 0) {
              curTagIds.push(tid)
            }
          }
        }
        const us = cur.urls
        if (us !== undefined && us !== null) {
          for (let i = 0; i < us.length; i++) {
            const u: string = us[i]
            if (u.length > 0) {
              curUrls.push(u)
            }
          }
        }
      }
    } catch (e) {
      hilog.warn(0x0000, 'StashSift-Scrape', 'read scene failed: %{public}s', (e as Error).message)
    }

    // 2) 基础字段：标题允许用刮削结果覆盖（与现有完全相同＝重复，不写）；其余只补空
    const scrapedTitle: string = this.rTitle.trim()
    const titleDup: boolean = scrapedTitle.length === 0 || scrapedTitle === curTitle
    const fTitle: string = titleDup ? curTitle : scrapedTitle
    const fDetails: string = curDetails.length > 0 ? curDetails : this.rDetails
    const fDate: string = curDate.length > 0 ? curDate : this.rDate
    const fCode: string = curCode.length > 0 ? curCode : this.rCode
    const fDirector: string = curDirector.length > 0 ? curDirector : this.rDirector
    const fImage: string = curImage.length > 0 ? curImage : this.rImage
    const kept: string[] = []
    if (titleDup && curTitle.length > 0) {
      kept.push('标题')
    }
    if (curDetails.length > 0) {
      kept.push('简介')
    }
    if (curDate.length > 0) {
      kept.push('日期')
    }
    if (curCode.length > 0) {
      kept.push('番号')
    }
    if (curDirector.length > 0) {
      kept.push('导演')
    }

    try {
      const ok: boolean = await api.updateScene(this.sceneId, rating, organized,
        fTitle, fDetails, fDate, fCode, fDirector, fImage)
      if (!ok) {
        this.statusError = true
        this.status = '基础字段写回失败（服务端未返回 id）'
        this.busy = false
        return
      }
    } catch (e) {
      const msg: string = (e as Error).message
      hilog.error(0x0000, 'StashSift-Scrape', 'base fields failed: %{public}s', msg)
      this.statusError = true
      this.status = '基础字段写回失败：' + msg
      this.busy = false
      return
    }

    // 3) 关联字段：工作室「有则保留、无则写入」；演员 / 标签并集追加，已存在的同名项不再写
    let perfIds: string[] = []
    let tagIds: string[] = []
    let studioToWrite: string = ''
    try {
      const perfJobs: Promise<string>[] = []
      for (let i = 0; i < this.rPerfNames.length; i++) {
        perfJobs.push(api.resolveId('performer', this.rPerfNames[i]))
      }
      const tagJobs: Promise<string>[] = []
      for (let i = 0; i < this.rTagNames.length; i++) {
        tagJobs.push(api.resolveId('tag', this.rTagNames[i]))
      }
      if (this.rTagNames.length > 0) {
        this.status = '解析关联（' + this.rTagNames.length.toString() + ' 个标签）…'
      }
      const all: string[][] = await Promise.all([
        Promise.all(perfJobs),
        Promise.all(tagJobs)
      ])
      // 演员 / 标签：与已有并集去重（重复项直接跳过，不重复写）
      perfIds = curPerfIds.slice()
      for (let i = 0; i < all[0].length; i++) {
        const pid: string = all[0][i]
        if (pid.length > 0 && perfIds.indexOf(pid) < 0) {
          perfIds.push(pid)
        }
      }
      tagIds = curTagIds.slice()
      for (let i = 0; i < all[1].length; i++) {
        const tid: string = all[1][i]
        if (tid.length > 0 && tagIds.indexOf(tid) < 0) {
          tagIds.push(tid)
        }
      }
      // 工作室：当前为空才补刮削结果；已有工作室则保持不动
      if (!hasStudio && this.rStudio.length > 0) {
        studioToWrite = await api.resolveId('studio', this.rStudio)
      }
    } catch (e) {
      const msg: string = (e as Error).message
      hilog.error(0x0000, 'StashSift-Scrape', 'resolve ids failed: %{public}s', msg)
      this.statusError = true
      this.status = '名字转 ID 失败：' + msg
      this.busy = false
      return
    }

    // 4) 写回关联（空数组 / 空字符串在 API 层会被忽略，等价于「不修改」）
    try {
      // 链接：与已有并集去重（允许追加）
      const urls: string[] = curUrls.slice()
      for (let i = 0; i < this.rUrls.length; i++) {
        const u: string = this.rUrls[i]
        if (u.length > 0 && urls.indexOf(u) < 0) {
          urls.push(u)
        }
      }
      const ok2: boolean = await api.updateSceneMeta(this.sceneId, studioToWrite,
        perfIds, tagIds, false, urls)
      bumpScenes()
      let studioText: string = ''
      if (studioToWrite.length > 0) {
        studioText = '　写入工作室'
      } else if (hasStudio) {
        studioText = '　保留原有工作室'
      }
      const head: string = ok2 ? '写回成功' : '关联字段写回失败（服务端未返回 id）'
      const added: string = titleDup ? '标题未变　演员 ' + perfIds.length.toString() +
        ' · 标签 ' + tagIds.length.toString()
        : '标题已更新　演员 ' + perfIds.length.toString() +
        ' · 标签 ' + tagIds.length.toString()
      const keepText: string = kept.length > 0 ? ('　保留原有：' + kept.join('、')) : ''
      this.statusError = !ok2
      this.status = head + '　' + added + keepText + studioText
    } catch (e) {
      const msg: string = (e as Error).message
      hilog.error(0x0000, 'StashSift-Scrape', 'meta failed: %{public}s', msg)
      this.statusError = true
      this.status = '关联字段写回失败：' + msg
    }
    this.busy = false
  }

  /** 安全取字符串（null/undefined → ''） */
  private safe(v: string | undefined | null): string {
    if (v === undefined || v === null) {
      return ''
    }
    return v
  }
  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  /** 系统深浅色变化时即时跟随 */
  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }
  /** 返回本页时刷新主题（设置页切换外观后立即生效） */
  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  /** 装 / 卸刮削器包后自动重拉列表 */
  @StorageProp('scraperVersion') @Watch('onScrapersChanged') scraperVersion: number = 0

  onScrapersChanged(): void {
    this.loadScrapers()
  }
  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('刮削'),
        subtitle: this.sceneId.length > 0 ? '写回目标已就绪' : '从详情页进入可写回',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          // 模式切换：文件名优先
          Row() {
            this.modeChip(0, '短片标题')
            this.modeChip(1, '名称')
            this.modeChip(2, 'URL')
          }
          .width('100%')
          .margin({ bottom: 12 })

          // 刮削器选择（可折叠）：URL 模式下由服务端按链接自动选站，不需要手选
          if (this.mode !== 2 && this.scraperNames.length > 0) {
            Column() {
              GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
                Column() {
                  Row() {
                    Text('刮削器')
                      .fontSize(12)
                      .fontColor(this.theme.textSecondary)
                    Text(this.scraperNames[this.selectedScraper])
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme.brandColor)
                      .margin({ left: 8 })
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('安装')
                      .fontSize(11)
                      .fontColor(this.theme.brandColor)
                      .backgroundColor(this.theme.chipBg)
                      .borderRadius(RADIUS_CHIP)
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .margin({ right: 8 })
                      .onClick(() => {
                        router.pushUrl({ url: 'pages/ScraperStorePage' })
                      })
                    SymbolGlyph(this.showScrapers ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
                      .fontSize(10)
                      .fontColor([this.theme.textSecondary])
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .onClick(() => {
                    this.showScrapers = !this.showScrapers
                  })

                  if (this.showScrapers) {
                    // 不套内层 Scroll：页面本身可滚，内层再套一层会抢手势、只露出一截
                    Column() {
                      ForEach(this.scraperNames, (n: string, idx: number) => {
                        Row() {
                          Text(n)
                            .fontSize(13)
                            .fontColor(this.selectedScraper === idx ? this.theme.brandColor : this.theme.textPrimary)
                            .layoutWeight(1)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          if (this.selectedScraper === idx) {
                            Text('已选').fontSize(11).fontColor(this.theme.brandColor)
                          }
                        }
                        .width('100%')
                        .padding({ top: 7, bottom: 7 })
                        .onClick(() => {
                          this.selectedScraper = idx
                        })
                      }, (n: string) => n)
                    }
                    .width('100%')
                    .margin({ top: 6 })
                  }
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ bottom: 12 })
          }

          // URL 模式：列出各站点认得的链接前缀（服务端按链接自动选站，不用手选刮削器）
          if (this.mode === 2 && this.urlHints.length > 0) {
            Column() {
              GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
                Column() {
                  Text('可刮站点：点标签自动填入链接前缀，再补上作品 ID')
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.urlHints, (u: string) => {
                      Text(u)
                        .fontSize(10)
                        .fontColor(this.theme.brandColor)
                        .backgroundColor(this.theme.chipBg)
                        .borderRadius(RADIUS_CHIP)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .margin({ right: 6, top: 6 })
                        .onClick(() => {
                          // Fantia 有专用页（只收数字 ID，且写回规则独立），直接跳过去
                          if (u.startsWith('fantia.jp')) {
                            router.pushUrl({
                              url: 'pages/FantiaPage',
                              params: { 'sceneId': this.sceneId }
                            })
                            return
                          }
                          // 其它站点：先填协议头和前缀，ID 留给用户补
                          this.urlText = 'https://' + u + '/'
                          this.statusError = false
                          this.status = '已填入前缀，补上作品 ID 后点「开始刮削」'
                        })
                    }, (u: string, i: number) => u + i.toString())
                  }
                  .width('100%')
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ bottom: 12 })
          }

          // 输入
          Column() {
            GlassCard({ style: GlassStyle.REGULAR, theme: this.theme }) {
              Column() {
                if (this.mode === 0) {
                  TextInput({ text: this.fileText, placeholder: '读取短片标题' })
                    .fontSize(13)
                    .fontColor(this.theme.textPrimary)
                    .placeholderColor(this.theme.textSecondary)
                    .backgroundColor(this.theme.chipBg)
                    .borderRadius(RADIUS_CHIP)
                    .height(44)
                    .width('100%')
                    .padding({ left: 12, right: 12 })
                    .onChange((v: string) => {
                      this.fileText = v
                    })
                  Row() {
                    Text(this.sceneId.length > 0 ? '已关联短片，自动读取标题' : '未关联短片，可手动输入')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .layoutWeight(1)
                    if (this.sceneId.length > 0) {
                      Text('重新读取标题')
                        .fontSize(11)
                        .fontColor(this.theme.brandColor)
                        .onClick(() => {
                          this.loadFileName()
                        })
                    }
                  }
                  .width('100%')
                  .margin({ top: 8 })
                } else if (this.mode === 1) {
                  TextInput({ text: this.nameText, placeholder: '输入片名进行刮削' })
                    .fontSize(13)
                    .fontColor(this.theme.textPrimary)
                    .placeholderColor(this.theme.textSecondary)
                    .backgroundColor(this.theme.chipBg)
                    .borderRadius(RADIUS_CHIP)
                    .height(44)
                    .width('100%')
                    .padding({ left: 12, right: 12 })
                    .onChange((v: string) => {
                      this.nameText = v
                    })
                } else {
                  TextInput({ text: this.urlText, placeholder: '输入网页 URL' })
                    .fontSize(13)
                    .fontColor(this.theme.textPrimary)
                    .placeholderColor(this.theme.textSecondary)
                    .backgroundColor(this.theme.chipBg)
                    .borderRadius(RADIUS_CHIP)
                    .height(44)
                    .width('100%')
                    .padding({ left: 12, right: 12 })
                    .onChange((v: string) => {
                      this.urlText = v
                    })
                }
              }
              .width('100%')
            }
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.status.length > 0) {
            Text(this.status)
              .fontSize(12)
              .fontColor(this.statusError ? '#FFE84026' : '#FF64BB5C')
              .width('100%')
              .margin({ top: 10 })
          }

          // 名称模式刮不动时，一键切到 URL 模式
          if (this.suggestUrl) {
            Button('切到「URL」模式')
              .fontSize(12)
              .height(34)
              .fontColor(this.theme.brandColor)
              .backgroundColor(this.theme.chipBg)
              .borderRadius(RADIUS_CHIP)
              .margin({ top: 8 })
              .onClick(() => {
                this.setMode(2)
              })
          }

          if (this.hasResult) {
            Column() {
              GlassCard({ style: GlassStyle.THICK, title: '刮削结果', theme: this.theme }) {
                Column() {
                  // 封面预览
                  if (this.rImage.length > 0) {
                    Image(this.rImage)
                      .width('100%')
                      .height(180)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(10)
                      .margin({ bottom: 10 })
                  } else {
                    Row() {
                      SymbolGlyph($r('sys.symbol.film'))
                        .fontSize(18)
                        .fontColor([this.theme.textSecondary])
                      Text('刮削器未提供封面')
                        .fontSize(11)
                        .fontColor(this.theme.textSecondary)
                        .margin({ left: 6 })
                    }
                    .width('100%')
                    .height(52)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(this.theme.chipBg)
                    .borderRadius(10)
                    .margin({ bottom: 10 })
                  }

                  Text(this.rTitle.length > 0 ? this.rTitle : '(无标题)')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                    .width('100%')
                    .maxLines(3)

                  Text('日期 ' + (this.rDate.length > 0 ? this.rDate : '—') +
                    (this.rCode.length > 0 ? '   番号 ' + this.rCode : '') +
                    (this.rDirector.length > 0 ? '   导演 ' + this.rDirector : ''))
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .width('100%')
                    .margin({ top: 6 })

                  // 工作室
                  Row() {
                    Text('工作室')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width(52)
                    if (this.rStudio.length > 0) {
                      Text(this.rStudio)
                        .fontSize(11)
                        .fontColor(this.theme.brandColor)
                        .backgroundColor(this.theme.chipBg)
                        .borderRadius(RADIUS_CHIP)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                    } else {
                      Text('—').fontSize(11).fontColor(this.theme.textSecondary)
                    }
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .margin({ top: 8 })

                  // 标签 chips
                  Row() {
                    Text('标签')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width(52)
                    if (this.rTagNames.length > 0) {
                      Flex({ wrap: FlexWrap.Wrap }) {
                        ForEach(this.rTagNames, (t: string) => {
                          Text(t)
                            .fontSize(10)
                            .fontColor(this.theme.textPrimary)
                            .backgroundColor(this.theme.chipBg)
                            .borderRadius(RADIUS_CHIP)
                            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                            .margin({ right: 6, bottom: 6 })
                        }, (t: string, i: number) => t + i.toString())
                      }
                      .layoutWeight(1)
                    } else {
                      Text('—').fontSize(11).fontColor(this.theme.textSecondary)
                    }
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                  .margin({ top: 4 })

                  // 演员 chips
                  Row() {
                    Text('演员')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width(52)
                    if (this.rPerfNames.length > 0) {
                      Flex({ wrap: FlexWrap.Wrap }) {
                        ForEach(this.rPerfNames, (t: string) => {
                          Text(t)
                            .fontSize(10)
                            .fontColor(this.theme.textPrimary)
                            .backgroundColor(this.theme.chipBg)
                            .borderRadius(RADIUS_CHIP)
                            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                            .margin({ right: 6, bottom: 6 })
                        }, (t: string, i: number) => t + i.toString())
                      }
                      .layoutWeight(1)
                    } else {
                      Text('—').fontSize(11).fontColor(this.theme.textSecondary)
                    }
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                  .margin({ top: 4 })

                  if (this.rDetails.length > 0) {
                    Text(this.rDetails)
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width('100%')
                      .maxLines(5)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 8 })
                  }
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ top: 12 })

            Button(this.busy ? '写回中…' : '写回该短片')
              .width('100%')
              .height(44)
              .backgroundColor('#FF0A59F7')
              .fontColor(Color.White)
              .borderRadius(8)
              .margin({ top: 10 })
              .enabled(!this.busy)
              .onClick(() => {
                this.applyResult()
              })
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }
      .layoutWeight(1).width('100%')
      .scrollBar(BarState.Off)

      // 底部固定操作条
      Column() {
        if (this.hasResult) {
          Row() {
            Button(this.busy ? '处理中…' : '重新刮削')
              .layoutWeight(2)
              .height(46)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor(this.busy ? this.theme.textSecondary : this.theme.brandColor)
              .borderRadius(12)
              .enabled(!this.busy)
              .onClick(() => {
                this.doScrape()
              })
            Button('返回')
              .layoutWeight(1)
              .height(46)
              .fontSize(15)
              .fontColor(this.theme.textPrimary)
              .backgroundColor(this.theme.chipBg)
              .borderRadius(12)
              .margin({ left: 8 })
              .onClick(() => {
                router.back()
              })
          }
          .width('100%')
        } else {
          Button(this.busy ? '处理中…' : '开始刮削')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(this.busy ? this.theme.textSecondary : this.theme.brandColor)
            .borderRadius(12)
            .enabled(!this.busy)
            .onClick(() => {
              this.doScrape()
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      .backgroundColor(this.theme.cardBg)
      .border({ width: { top: 1 }, color: this.theme.cardBorder })
      .backdropBlur(24)
    }
    .width('100%').height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  modeChip(m: number, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.mode === m ? Color.White : this.theme.textSecondary)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.mode === m ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(8)
      .padding({ top: 9, bottom: 9 })
      .layoutWeight(1)
      .margin({ left: 3, right: 3 })
      .onClick(() => {
        this.setMode(m)
      })
  }
}
