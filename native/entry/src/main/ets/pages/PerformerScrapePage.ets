/**
 * StashSift — 演员刮削页（按名称 / 按 URL 两种模式 + 预览 + 写回）
 *
 * 写回规则（用户定）：
 * - 主名一律不改：本地已有 name 就保留；刮到的不同名字去重并进 alias_list。
 * - 其余字段只补空缺，不覆盖已有。
 * - 标签追加（与原有并集去重）。
 * - 封面有则补（本地没封面才写）。
 * - URL 追加去重。
 */
import { router } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StashApi } from '../api/StashApi'
import { bumpScenes } from '../common/DataVersion'
import { RADIUS_CHIP } from '../common/Responsive'
import { AppSettings } from '../settings/AppSettings'
import { ScrapedPerformerDto, ScraperDto, ScraperSpecDto, PerformerDto, Performer, PerformerUpdate, StashBoxSource } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'
import { L10n } from '../settings/L10n'

interface ScrapeParams {
  performerId?: string
  id?: string
  performerName?: string
  name?: string
  mode?: string
}

@Entry
@Component
struct PerformerScrapePage {
  private performerId: string = ''
  @State performerName: string = ''
  /** 0 = 按名称，1 = 按 URL，2 = Stash-box 识别 */
  @State mode: number = 0
  @State nameText: string = ''
  @State urlText: string = ''
  @State scraperNames: string[] = []
  @State scraperIds: string[] = []
  @State selectedScraper: number = 0
  @State showScrapers: boolean = false
  @State boxLoadError: string = ''
  /** stash-box 源（StashDB / PMV Stash / ThePornDB…） */
  @State boxNames: string[] = []
  @State boxEndpoints: string[] = []
  @State selectedBox: number = 0
  @State busy: boolean = false
  @State status: string = ''
  @State statusError: boolean = false
  @State hasResult: boolean = false

  /* 刮削结果 */
  @State rName: string = ''
  @State rAliases: string[] = []
  @State rGender: string = ''
  @State rBirthdate: string = ''
  @State rDeathDate: string = ''
  @State rCountry: string = ''
  @State rEthnicity: string = ''
  @State rEyeColor: string = ''
  @State rHairColor: string = ''
  @State rHeight: string = ''
  @State rWeight: string = ''
  @State rMeasurements: string = ''
  @State rFakeTits: string = ''
  @State rTattoos: string = ''
  @State rPiercings: string = ''
  @State rCareerStart: string = ''
  @State rCareerEnd: string = ''
  @State rDetails: string = ''
  @State rTagNames: string[] = []
  @State rUrls: string[] = []
  @State rImage: string = ''

  @StorageProp('winHeightVp') winH: number = 809
  @StorageProp('scraperVersion') @Watch('onScrapersChanged') scraperVersion: number = 0

  onScrapersChanged(): void {
    this.loadScrapers()
  }
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    const p = router.getParams() as ScrapeParams
    if (p !== null && p !== undefined) {
      if (p.performerId !== undefined) {
        this.performerId = p.performerId
      }
      if (p.id !== undefined) {
        this.performerId = p.id
      }
      if (p.performerName !== undefined) {
        this.performerName = p.performerName
        this.nameText = p.performerName
      }
      if (p.name !== undefined) {
        this.performerName = p.name
        this.nameText = p.name
      }
      if (p.mode !== undefined) {
        // 从演员页菜单带过来的初始模式：0 按名称 / 1 按 URL / 2 Stash-box
        const m: number = parseInt(p.mode)
        if (m === 0 || m === 1 || m === 2) {
          this.mode = m
        }
      }
    }
    this.loadScrapers()
    this.loadBoxes()
  }

  /** 加载服务端配置的 stash-box 源 */
  private async loadBoxes(): Promise<void> {
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const list: StashBoxSource[] = await api.stashBoxSources()
      const names: string[] = []
      const eps: string[] = []
      for (let i = 0; i < list.length; i++) {
        names.push(list[i].name)
        eps.push(list[i].endpoint)
      }
      this.boxNames = names
      this.boxEndpoints = eps
      this.boxLoadError = ''
    } catch (e) {
      this.boxLoadError = (e as Error).message
      this.boxNames = []
      this.boxEndpoints = []
    }
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  /** 把可能为 null / undefined 的字段安全转成字符串 */
  private toStr(v: Object | undefined | null): string {
    if (v === undefined || v === null) {
      return ''
    }
    return v.toString()
  }

  /** 加载演员刮削器：只保留支持按名称搜索的（URL 模式由服务端自动选站） */
  private async loadScrapers(): Promise<void> {
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const list: ScraperDto[] = await api.performerScrapers()
      const names: string[] = []
      const ids: string[] = []
      for (let i = 0; i < list.length; i++) {
        const one: ScraperDto = list[i]
        const sp: ScraperSpecDto | undefined = one.performer
        let canName: boolean = false
        if (sp !== undefined && sp !== null) {
          const caps: string[] | undefined = sp.supported_scrapes
          if (caps !== undefined && caps !== null) {
            for (let k = 0; k < caps.length; k++) {
              if (caps[k] === 'NAME') {
                canName = true
              }
            }
          }
        }
        if (!canName) {
          continue
        }
        const n: string | undefined = one.name
        const idv: string | undefined = one.id
        names.push(n === undefined || n === null ? '未命名' : n)
        ids.push(idv === undefined || idv === null ? '' : idv)
      }
      this.scraperNames = names
      this.scraperIds = ids
      if (this.selectedScraper >= names.length) {
        this.selectedScraper = 0
      }
      if (names.length === 0) {
        this.statusError = true
        this.status = '服务端没有支持「按名称刮削」的演员刮削器：先去「设置 → 刮削器安装」装一个社区包（Community），再回来重试。'
      }
    } catch (e) {
      this.statusError = true
      this.status = '刮削器加载失败：' + (e as Error).message
    }
  }

  /** 把服务端/网络原文翻译成用户能照着做的中文 */
  private humanError(raw: string): string {
    const low: string = raw.toLowerCase()
    if (low.indexOf('cannot load') >= 0 || low.indexOf('not supported') >= 0 ||
      low.indexOf('operation not supported') >= 0) {
      return '这个刮削器不支持按名称搜索：把演员网页链接贴到「URL」模式再试。'
    }
    if (low.indexOf('403') >= 0 || low.indexOf('forbidden') >= 0) {
      return '源站拒绝访问（403 反爬）。换一个刮削器试试。'
    }
    if (low.indexOf('404') >= 0 || low.indexOf('not found') >= 0) {
      return '源站没找到该演员（404）。换个刮削器或改用「URL」模式。'
    }
    if (low.indexOf('timeout') >= 0 || low.indexOf('timed out') >= 0 || low.indexOf('超时') >= 0) {
      return '刮削超时：站点响应太慢，换一个刮削器或稍后重试。'
    }
    if (low.indexOf('index out of range') >= 0 || low.indexOf('cannot read property') >= 0) {
      return '刮削器返回了空结果，换一个刮削器试试。'
    }
    return '刮削失败：' + raw
  }

  /** 执行刮削 */
  private async doScrape(): Promise<void> {
    const keyword: string = this.mode === 1 ? this.urlText.trim() : this.nameText.trim()
    if (keyword.length === 0) {
      this.statusError = true
      this.status = this.mode === 1 ? '请输入演员网页 URL' : '请输入演员名称'
      return
    }
    if (this.mode === 0 && this.scraperIds.length === 0) {
      this.statusError = true
      this.status = '服务端没有可用的演员刮削器：先去「设置 → 刮削器安装」装一个社区包，或改用「URL」模式。'
      return
    }
    if (this.mode === 2) {
      if (this.boxLoadError.length > 0) {
        this.statusError = true
        this.status = '读取 BOX 源失败：' + this.boxLoadError
        return
      }
      if (this.selectedBox < 0 || this.selectedBox >= this.boxEndpoints.length) {
        this.statusError = true
        this.status = 'BOX 源未选中或已失效：请重新选择一个识别源。'
        return
      }
    }
    this.busy = true
    this.statusError = false
    this.status = '刮削中…'
    this.hasResult = false
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      let r: ScrapedPerformerDto | null
      if (this.mode === 1) {
        r = await api.scrapePerformerURL(keyword)
      } else if (this.mode === 2) {
        r = await api.scrapePerformerByStashBox(keyword, this.boxEndpoints[this.selectedBox])
      } else {
        const sid: string = this.scraperIds[this.selectedScraper]
        r = await api.scrapePerformerByName(keyword, sid)
      }
      if (r === null) {
        this.statusError = true
        this.status = this.mode === 1
          ? '这个链接没刮到内容：确认是演员详情页而不是列表页，或换个站点'
          : '没有匹配结果：换一个刮削器，或把演员网页链接贴到「URL」模式再刮'
        return
      }
      this.showScrapers = false
      this.rName = this.toStr(r.name)
      this.rGender = this.toStr(r.gender)
      this.rBirthdate = this.toStr(r.birthdate)
      this.rDeathDate = this.toStr(r.death_date)
      this.rCountry = this.toStr(r.country)
      this.rEthnicity = this.toStr(r.ethnicity)
      this.rEyeColor = this.toStr(r.eye_color)
      this.rHairColor = this.toStr(r.hair_color)
      this.rHeight = this.toStr(r.height)
      this.rWeight = this.toStr(r.weight)
      this.rMeasurements = this.toStr(r.measurements)
      this.rFakeTits = this.toStr(r.fake_tits)
      this.rTattoos = this.toStr(r.tattoos)
      this.rPiercings = this.toStr(r.piercings)
      this.rCareerStart = this.toStr(r.career_start)
      this.rCareerEnd = this.toStr(r.career_end)
      this.rDetails = this.toStr(r.details)
      // 别名：服务端给的是一串文本（逗号分隔），拆开去重
      const al: string[] = []
      const rawAliases: string = this.toStr(r.aliases)
      if (rawAliases.length > 0) {
        const parts: string[] = rawAliases.split(/[,，;；]/)
        for (let i = 0; i < parts.length; i++) {
          const one: string = parts[i].trim()
          if (one.length > 0 && al.indexOf(one) < 0) {
            al.push(one)
          }
        }
      }
      this.rAliases = al
      // 标签
      const ts: string[] = []
      if (r.tags !== undefined && r.tags !== null) {
        for (let i = 0; i < r.tags.length; i++) {
          const one: string = this.toStr(r.tags[i].name)
          if (one.length > 0 && ts.indexOf(one) < 0) {
            ts.push(one)
          }
        }
      }
      this.rTagNames = ts
      // 链接
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
      // 封面：取第一张
      let img: string = ''
      if (r.images !== undefined && r.images !== null) {
        for (let i = 0; i < r.images.length; i++) {
          const one: string = this.toStr(r.images[i])
          if (one.length > 0) {
            img = one
            break
          }
        }
      }
      this.rImage = img
      this.hasResult = true
      this.status = '刮削成功，确认后写回'
    } catch (e) {
      const raw: string = (e as Error).message
      hilog.warn(0x0000, 'StashSift-Scrape', 'performer scrape failed: %{public}s', raw)
      this.statusError = true
      this.status = this.humanError(raw)
    } finally {
      this.busy = false
    }
  }

  /** 写回：主名不改，别的只补空缺 */
  private async applyResult(): Promise<void> {
    if (this.performerId.length === 0) {
      this.statusError = true
      this.status = '缺少演员 ID，无法写回'
      return
    }
    if (this.busy) {
      return
    }
    this.busy = true
    this.statusError = false
    this.status = '写回中…'
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const dto: PerformerDto | null = await api.findPerformer(this.performerId)
      if (dto === null) {
        this.statusError = true
        this.status = '读取演员失败，无法写回'
        this.busy = false
        return
      }
      const cur: Performer = Performer.fromDto(dto)
      const u: PerformerUpdate = PerformerUpdate.from(cur)

      // 1) 名字：本地有就保留；刮到的不同名字 / 别名去重并入别名
      const curName: string = cur.name.trim()
      let aliasAdded: number = 0
      // 库里有些演员的别名是「用逗号连成一整条」存进来的（从别的工具导入的），
      // 所以先把已有别名摊平成集合用于去重判断；真正写回时已有别名原样保留，不拆不丢。
      const existSet: string[] = []
      for (let i = 0; i < cur.aliases.length; i++) {
        const parts: string[] = cur.aliases[i].split(/[,，;；]/)
        for (let k = 0; k < parts.length; k++) {
          const one: string = parts[k].trim()
          if (one.length > 0 && existSet.indexOf(one) < 0) {
            existSet.push(one)
          }
        }
      }
      if (curName.length === 0) {
        // 本地没主名才写主名，此时不重复加别名
        u.name = this.rName.trim()
        if (u.name.length > 0) {
          u.aliases = []
        }
      } else {
        u.name = curName
        u.aliases = cur.aliases.slice()
        const addAlias = (one: string): void => {
          const t: string = one.trim()
          if (t.length === 0 || t === curName) {
            return
          }
          for (let i = 0; i < existSet.length; i++) {
            if (existSet[i].toLowerCase() === t.toLowerCase()) {
              return
            }
          }
          existSet.push(t)
          u.aliases.push(t)
        }
        // 刮到的名字（和本地主名不同才算别名）
        addAlias(this.rName)
        // 刮到的其它别名
        for (let i = 0; i < this.rAliases.length; i++) {
          addAlias(this.rAliases[i])
        }
        aliasAdded = u.aliases.length - cur.aliases.length
      }

      // 2) 其余字段：只补空缺（已有就保留，只统计个数，不逐项报）
      let keptCount: number = 0
      const fillText = (curValue: string, scraped: string): string => {
        if (curValue.length > 0 && scraped.length > 0) {
          keptCount++
          return curValue
        }
        return curValue.length > 0 ? curValue : scraped
      }
      u.gender = fillText(cur.gender, this.normGender(this.rGender))
      u.birthdate = fillText(cur.birthdate, this.rBirthdate)
      u.death_date = fillText(cur.death_date, this.rDeathDate)
      u.country = fillText(cur.country, this.rCountry)
      u.ethnicity = fillText(cur.ethnicity, this.rEthnicity)
      u.eye_color = fillText(cur.eye_color, this.rEyeColor)
      u.hair_color = fillText(cur.hair_color, this.rHairColor)
      u.measurements = fillText(cur.measurements, this.rMeasurements)
      u.fake_tits = fillText(cur.fake_tits, this.rFakeTits)
      u.tattoos = fillText(cur.tattoos, this.rTattoos)
      u.piercings = fillText(cur.piercings, this.rPiercings)
      u.career_start = fillText(cur.career_start, this.rCareerStart)
      u.career_end = fillText(cur.career_end, this.rCareerEnd)
      u.details = fillText(cur.details, this.rDetails)
      // 身高体重：刮削给的是字符串，转数字；已有就不动
      if (cur.height_cm <= 0) {
        const h: number = this.toNum(this.rHeight)
        if (h > 0) {
          u.height_cm = h
        }
      }
      if (cur.weight <= 0) {
        const w: number = this.toNum(this.rWeight)
        if (w > 0) {
          u.weight = w
        }
      }
      // 3) 链接：追加去重
      const urls: string[] = cur.urls.slice()
      for (let i = 0; i < this.rUrls.length; i++) {
        const one: string = this.rUrls[i]
        if (one.length > 0 && urls.indexOf(one) < 0) {
          urls.push(one)
        }
      }
      u.urls = urls
      // 4) 封面：本地没有才写
      if (cur.image_path.length === 0 && this.rImage.length > 0) {
        u.image = this.rImage
      }
      // 5) 标签：与原有并集去重（并发分批，避免一次性打太多请求；查不到的标签会被服务端新建）
      let tagIds: string[] = []
      for (let i = 0; i < cur.tags.length; i++) {
        tagIds.push(cur.tags[i].id)
      }
      let newTagCount = 0
      if (this.rTagNames.length > 0) {
        const BATCH = 5
        const resolved: string[] = []
        for (let start = 0; start < this.rTagNames.length; start += BATCH) {
          const batch: Promise<string>[] = []
          const end = Math.min(start + BATCH, this.rTagNames.length)
          for (let i = start; i < end; i++) {
            batch.push(api.resolveId('tag', this.rTagNames[i]))
          }
          const batchResolved = await Promise.all(batch)
          for (let i = 0; i < batchResolved.length; i++) {
            resolved.push(batchResolved[i])
          }
        }
        for (let i = 0; i < resolved.length; i++) {
          const tid: string = resolved[i]
          if (tid.length > 0 && tagIds.indexOf(tid) < 0) {
            tagIds.push(tid)
            newTagCount++
          }
        }
        u.tag_ids = tagIds
      }

      const ok: boolean = await api.updatePerformer(this.performerId, u)
      if (!ok) {
        this.statusError = true
        this.status = '写回失败（服务端未返回 id）'
        this.busy = false
        return
      }
      bumpScenes()
      const nameNote: string = curName.length > 0
        ? ('名字未变' + (aliasAdded > 0 ? ('，已添加 ' + aliasAdded.toString() + ' 个别名') : ''))
        : ('已写入名字 ' + u.name)
      this.status = '写回成功　' + nameNote +
        '　标签 ' + tagIds.length.toString() +
        (newTagCount > 0 ? ('，已新建 ' + newTagCount.toString() + ' 个') : '') +
        '　链接 ' + urls.length.toString() +
        (this.rImage.length > 0 && cur.image_path.length === 0 ? '　已补封面' : '') +
        (keptCount > 0 ? ('　保留原有资料 ' + keptCount.toString() + ' 项') : '')
    } catch (e) {
      const msg: string = (e as Error).message
      hilog.error(0x0000, 'StashSift-Scrape', 'performer write back failed: %{public}s', msg)
      this.statusError = true
      this.status = '写回失败：' + msg
    }
    this.busy = false
  }

  /** 字符串转数字：兼容 "165cm" / "55 kg" 这类写法 */
  private toNum(v: string): number {
    const s: string = v.trim()
    if (s.length === 0) {
      return 0
    }
    const digits: string = s.replace(/[^0-9.]/g, '')
    if (digits.length === 0) {
      return 0
    }
    const n: number = Number(digits)
    if (isNaN(n)) {
      return 0
    }
    return n
  }

  /** 性别归一化：服务端只认 GenderEnum（枚举见上），其它写法一律不写 */
  private normGender(v: string): string {
    const s: string = v.trim().toUpperCase().replace(/[\s-]/g, '_')
    if (s === 'MALE' || s === 'FEMALE' || s === 'INTERSEX' || s === 'NON_BINARY' ||
      s === 'TRANSGENDER_MALE' || s === 'TRANSGENDER_FEMALE') {
      return s
    }
    return ''
  }

  /* ---------------- UI ---------------- */

  @Builder
  modeChip(m: number, label: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.mode === m ? Color.White : this.theme.textSecondary)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.mode === m ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(8)
      .padding({ top: 9, bottom: 9 })
      .layoutWeight(1)
      .onClick(() => {
        if (this.mode !== m) {
          this.mode = m
          this.status = ''
          this.statusError = false
          this.hasResult = false
        }
      })
  }

  /** 结果里的一行「标签 + 值」 */
  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(11).fontColor(this.theme.textSecondary).width(64)
      Text(value.length > 0 ? value : '—')
        .fontSize(11).fontColor(value.length > 0 ? this.theme.textPrimary : this.theme.textSecondary)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ top: 4 })
  }

  build() {
    Column() {
      GlassNavBar({
        title: L10n.translate('刮削演员'),
        subtitle: this.performerName.length > 0 ? this.performerName : '从演员详情页进入可写回',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Scroll() {
        Column() {
          // 模式切换
          Row({ space: 6 }) {
            this.modeChip(0, '按名称')
            this.modeChip(1, '按 URL')
            this.modeChip(2, 'BOX')
          }
          .width('100%')
          .margin({ bottom: 12 })

          // stash-box 源选择（Stash-box 模式）
          if (this.mode === 2 && this.boxNames.length > 0) {
            Column() {
              GlassCard({ style: GlassStyle.THIN, theme: this.theme }) {
                Column() {
                  Text('识别源')
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                    .width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.boxNames, (n: string, idx: number) => {
                      Text(n)
                        .fontSize(13)
                        .fontColor(this.selectedBox === idx ? Color.White : this.theme.textPrimary)
                        .backgroundColor(this.selectedBox === idx ? this.theme.brandColor : this.theme.chipBg)
                        .borderRadius(RADIUS_CHIP)
                        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                        .margin({ right: 6, bottom: 6 })
                        .onClick(() => {
                          this.selectedBox = idx
                        })
                    }, (n: string, i: number) => n + i.toString())
                  }
                  .width('100%')
                  .margin({ top: 6 })
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ bottom: 12 })
          }

          // 刮削器选择：URL 模式由服务端按链接自动选站，不用手选
          if (this.mode === 0 && this.scraperNames.length > 0) {
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

          // 输入
          Column() {
            GlassCard({ style: GlassStyle.REGULAR, theme: this.theme }) {
              Column() {
                if (this.mode === 1) {
                  TextInput({ text: this.urlText, placeholder: '输入演员网页 URL' })
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
                  Text('服务端按链接自动判断站点，不用手选刮削器。')
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .width('100%')
                    .margin({ top: 8 })
                } else {
                  TextInput({ text: this.nameText, placeholder: '输入演员名称' })
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
                  Text(this.mode === 2
                    ? '用选中的 BOX 源按名字查这个演员。'
                    : '默认填的是这个演员的名字，可以改成别名或英文名再搜。')
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .width('100%')
                    .margin({ top: 8 })
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

          if (this.hasResult) {
            Column() {
              GlassCard({ style: GlassStyle.THICK, title: '刮削结果', theme: this.theme }) {
                Column() {
                  if (this.rImage.length > 0) {
                    Image(this.rImage)
                      .width('100%')
                      .height(180)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(10)
                      .margin({ bottom: 10 })
                  }

                  Text(this.rName.length > 0 ? this.rName : '(无名字)')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                    .width('100%')
                    .maxLines(3)

                  if (this.rAliases.length > 0) {
                    Text('别名 ' + this.rAliases.join(' · '))
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width('100%')
                      .margin({ top: 4 })
                  }

                  this.infoRow('性别', this.rGender)
                  this.infoRow('生日', this.rBirthdate)
                  this.infoRow('逝世', this.rDeathDate)
                  this.infoRow('国家', this.rCountry)
                  this.infoRow('种族', this.rEthnicity)
                  this.infoRow('瞳色', this.rEyeColor)
                  this.infoRow('发色', this.rHairColor)
                  this.infoRow('身高', this.rHeight)
                  this.infoRow('体重', this.rWeight)
                  this.infoRow('三围', this.rMeasurements)
                  this.infoRow('出道', this.rCareerStart)
                  this.infoRow('引退', this.rCareerEnd)

                  if (this.rTagNames.length > 0) {
                    Row() {
                      Text('标签')
                        .fontSize(11).fontColor(this.theme.textSecondary).width(64)
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
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Top)
                    .margin({ top: 4 })
                  }

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

            Text('写回规则：名字不改，刮到的不同名字并入别名；其余只补空缺。')
              .fontSize(11)
              .fontColor(this.theme.textSecondary)
              .width('100%')
              .margin({ top: 10 })

            Button(this.busy ? '写回中…' : '写回该演员')
              .width('100%')
              .height(44)
              .backgroundColor('#FF0A59F7')
              .fontColor(Color.White)
              .borderRadius(8)
              .margin({ top: 8 })
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
      .backgroundEffect({ radius: 24, saturation: 1.35 })
    }
    .width('100%').height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
