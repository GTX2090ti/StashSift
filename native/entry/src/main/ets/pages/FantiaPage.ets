/**
 * StashGo — Fantia 专用刮削页
 *
 * Fantia 的刮削器只声明了 URL 能力（fantia.jp/posts/<id>、fantia.jp/products/<id>），
 * 按名称刮会被 Stash 直接拒绝（cannot load SCENE by name），所以这里只收一个数字 ID，
 * 拼成作品链接交给 scrapeSceneURL，由服务端按链接自动选站。
 *
 * 写回规则与本项目其它刮削入口一致：
 *   标题   —— 允许用刮削结果覆盖；与现有完全相同（重复）则不写
 *   工作室 —— 一律不写，保持原样
 *   演员   —— 并集追加，已存在的同一个人不重复写
 *   标签   —— 并集追加去重；简介 / 日期 / 番号 / 导演只补空
 */
import { router } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StashApi } from '../api/StashApi'
import { bumpScenes } from '../common/DataVersion'
import { RADIUS_CHIP } from '../common/Responsive'
import { AppSettings } from '../settings/AppSettings'
import { ScrapedSceneDto, SceneDto } from '../models/Models'
import { GlassCard } from '../components/GlassCard'
import { GlassNavBar } from '../components/GlassNavBar'
import { GlassStyle, GlassTheme, GlassBackdrop, currentGlassTheme, currentBackdrop } from '../common/GlassUtils'

interface FantiaParams {
  sceneId?: string
  id?: string
}

@Entry
@Component
struct FantiaPage {
  /** 0 = 投稿 posts，1 = 商品 products */
  @State kind: number = 0
  @State idText: string = ''
  @State busy: boolean = false
  /** 下拉刷新中（Refresh 组件双向绑定） */
  @State refreshing: boolean = false
  @State status: string = ''
  @State statusError: boolean = false
  @State hasResult: boolean = false
  @State rTitle: string = ''
  @State rDate: string = ''
  @State rCode: string = ''
  @State rDetails: string = ''
  @State rImage: string = ''
  @State rStudio: string = ''
  @State rPerfText: string = ''
  @State rTagText: string = ''
  @State rPerfNames: string[] = []
  @State rTagNames: string[] = []
  @State rUrls: string[] = []
  private sceneId: string = ''
  @State theme: GlassTheme = currentGlassTheme()
  @State bd: GlassBackdrop = currentBackdrop()

  aboutToAppear(): void {
    const p = router.getParams() as FantiaParams
    if (p !== null && p !== undefined) {
      if (p.sceneId !== undefined && p.sceneId !== null) {
        this.sceneId = p.sceneId
      }
      if (p.id !== undefined && p.id !== null) {
        this.sceneId = p.id
      }
    }
  }

  /** null / undefined 一律当空串 */
  private str(v: Object | undefined | null): string {
    if (v === undefined || v === null) {
      return ''
    }
    return v.toString()
  }

  /** 从「纯数字 ID」或「整条 fantia 链接」里取出数字 ID */
  private pickedId(): string {
    const raw: string = this.idText.trim()
    if (raw.length === 0) {
      return ''
    }
    let digits: string = ''
    for (let i = raw.length - 1; i >= 0; i--) {
      const c: string = raw.charAt(i)
      if (c >= '0' && c <= '9') {
        digits = c + digits
      } else {
        break
      }
    }
    return digits
  }

  /** 拼出要交给 Stash 的作品链接 */
  private composedUrl(): string {
    const id: string = this.pickedId()
    if (id.length === 0) {
      return ''
    }
    const seg: string = this.kind === 0 ? 'posts' : 'products'
    return 'https://fantia.jp/' + seg + '/' + id
  }

  private async doScrape(): Promise<void> {
    const id: string = this.pickedId()
    if (id.length === 0) {
      this.statusError = true
      this.status = '请填 Fantia 作品 ID（纯数字），也可以直接粘贴作品链接'
      return
    }
    const url: string = this.composedUrl()
    this.busy = true
    this.statusError = false
    this.hasResult = false
    this.status = '刮削中…'
    try {
      const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
      const r: ScrapedSceneDto | null = await api.scrapeSceneURL(url)
      if (r === null) {
        this.statusError = true
        this.status = '这个 ID 没刮到内容：确认是作品页而不是列表页，或确认 ID 属于「' +
          (this.kind === 0 ? '投稿 posts' : '商品 products') + '」'
      } else {
        this.rTitle = this.str(r.title)
        this.rDate = this.str(r.date)
        this.rCode = this.str(r.code)
        this.rDetails = this.str(r.details)
        this.rImage = this.str(r.image)
        this.rStudio = (r.studio !== undefined && r.studio !== null) ? this.str(r.studio.name) : ''
        const ps: string[] = []
        if (r.performers !== undefined && r.performers !== null) {
          for (let i = 0; i < r.performers.length; i++) {
            const one: string = this.str(r.performers[i].name)
            if (one.length > 0) {
              ps.push(one)
            }
          }
        }
        this.rPerfNames = ps
        this.rPerfText = ps.join(' · ')
        const ts: string[] = []
        if (r.tags !== undefined && r.tags !== null) {
          for (let i = 0; i < r.tags.length; i++) {
            const one: string = this.str(r.tags[i].name)
            if (one.length > 0) {
              ts.push(one)
            }
          }
        }
        this.rTagNames = ts
        this.rTagText = ts.join(' · ')
        const us: string[] = []
        if (r.urls !== undefined && r.urls !== null) {
          for (let i = 0; i < r.urls.length; i++) {
            const one: string = this.str(r.urls[i])
            if (one.length > 0) {
              us.push(one)
            }
          }
        }
        this.rUrls = us
        this.hasResult = true
        this.status = '刮削成功'
      }
    } catch (e) {
      const raw: string = (e as Error).message
      hilog.warn(0x0000, 'StashGo-Fantia', 'scrape failed: %{public}s', raw)
      this.statusError = true
      this.status = this.humanError(raw)
    }
    this.busy = false
  }

  /** 下拉刷新：按当前 ID 重新刮一次（不写回） */
  private async pullRefresh(): Promise<void> {
    if (this.busy) {
      this.refreshing = false
      return
    }
    if (this.pickedId().length === 0) {
      this.statusError = true
      this.status = '先填作品 ID，再下拉刷新'
      this.refreshing = false
      return
    }
    await this.doScrape()
    this.refreshing = false
  }

  /** 服务端 / 网络原文 → 能照着做的一句话 */
  private humanError(raw: string): string {
    const low: string = raw.toLowerCase()
    if (low.indexOf('404') >= 0 || low.indexOf('not found') >= 0) {
      return '作品不存在（404）：ID 或类型选错了，检查后再试。'
    }
    if (low.indexOf('403') >= 0 || low.indexOf('forbidden') >= 0) {
      return 'Fantia 拒绝了请求（403 反爬）：检查 Stash 侧的 Cookie / CookieCloud 是否还有效。'
    }
    if (low.indexOf('400') >= 0) {
      return '请求被网关 / 代理拒绝（400）：先确认 Stash 容器能正常访问 fantia.jp。'
    }
    if (low.indexOf('timeout') >= 0 || low.indexOf('超时') >= 0) {
      return '刮削超时：Fantia 响应慢，稍后重试。'
    }
    return '刮削失败：' + raw
  }

  /** 写回当前短片（无 sceneId 时不允许） */
  private async applyResult(): Promise<void> {
    if (this.sceneId.length === 0) {
      this.statusError = true
      this.status = '没有关联短片：从短片详情页进入才能写回'
      return
    }
    this.busy = true
    this.status = '写回中…'
    const api = new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)

    // 1) 读当前值
    let curTitle: string = ''
    let curDetails: string = ''
    let curDate: string = ''
    let curCode: string = ''
    let curDirector: string = ''
    let curImage: string = ''
    let curPerfIds: string[] = []
    let curTagIds: string[] = []
    let curUrls: string[] = []
    let hasStudio: boolean = false
    try {
      const cur: SceneDto | null = await api.findScene(this.sceneId)
      if (cur !== null && cur !== undefined) {
        curTitle = this.str(cur.title)
        curDetails = this.str(cur.details)
        curDate = this.str(cur.date)
        curCode = this.str(cur.code)
        curDirector = this.str(cur.director)
        const st = cur.studio
        if (st !== undefined && st !== null) {
          hasStudio = this.str(st.id).length > 0
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
      hilog.warn(0x0000, 'StashGo-Fantia', 'read scene failed: %{public}s', (e as Error).message)
    }

    // 2) 基础字段：标题可覆盖（相同＝重复不写），其它只补空
    const scrapedTitle: string = this.rTitle.trim()
    const titleDup: boolean = scrapedTitle.length === 0 || scrapedTitle === curTitle
    const fTitle: string = titleDup ? curTitle : scrapedTitle
    const fDetails: string = curDetails.length > 0 ? curDetails : this.rDetails
    const fDate: string = curDate.length > 0 ? curDate : this.rDate
    const fCode: string = curCode.length > 0 ? curCode : this.rCode
    const fDirector: string = curDirector.length > 0 ? curDirector : ''
    const fImage: string = curImage.length > 0 ? curImage : this.rImage
    try {
      const ok: boolean = await api.updateScene(this.sceneId, 0, false,
        fTitle, fDetails, fDate, fCode, fDirector, fImage)
      if (!ok) {
        this.statusError = true
        this.status = '基础字段写回失败（服务端未返回 id）'
        this.busy = false
        return
      }
    } catch (e) {
      this.statusError = true
      this.status = '基础字段写回失败：' + (e as Error).message
      this.busy = false
      return
    }

    // 3) 演员 / 标签并集去重；工作室「有则保留、无则写入」
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
      const all: string[][] = await Promise.all([Promise.all(perfJobs), Promise.all(tagJobs)])
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
      this.statusError = true
      this.status = '名字转 ID 失败：' + (e as Error).message
      this.busy = false
      return
    }

    // 4) 关联字段写回（工作室为空＝不改；占位时表示「当前无工作室，补写刮削结果」）
    try {
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
      const head: string = ok2 ? '写回成功' : '关联字段写回失败（服务端未返回 id）'
      const titleText: string = titleDup ? '标题未变' : '标题已更新'
      let studioText: string = ''
      if (studioToWrite.length > 0) {
        studioText = '　写入工作室'
      } else if (hasStudio) {
        studioText = '　保留原有工作室'
      }
      this.statusError = !ok2
      this.status = head + '　' + titleText + '　演员 ' + perfIds.length.toString() +
        ' · 标签 ' + tagIds.length.toString() + studioText
    } catch (e) {
      this.statusError = true
      this.status = '关联字段写回失败：' + (e as Error).message
    }
    this.busy = false
  }

  @StorageProp('themeVersion') @Watch('onThemeChanged') themeVersion: number = 0

  onThemeChanged(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  onPageShow(): void {
    this.theme = currentGlassTheme()
    this.bd = currentBackdrop()
  }

  @Builder
  kindChip(k: number, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.kind === k ? Color.White : this.theme.textSecondary)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.kind === k ? this.theme.brandColor : this.theme.chipBg)
      .borderRadius(8)
      .padding({ top: 9, bottom: 9 })
      .layoutWeight(1)
      .margin({ left: 3, right: 3 })
      .onClick(() => {
        this.kind = k
        this.status = ''
      })
  }

  build() {
    Column() {
      GlassNavBar({
        title: 'Fantia 刮削',
        subtitle: this.sceneId.length > 0 ? '写回目标已就绪' : '从短片详情进入可写回',
        theme: this.theme,
        style: GlassStyle.REGULAR
      })

      Refresh({ refreshing: $$this.refreshing, promptText: '下拉刷新刮削结果' }) {
        Scroll() {
        Column() {
          Row() {
            this.kindChip(0, '投稿 posts')
            this.kindChip(1, '商品 products')
          }
          .width('100%')
          .margin({ bottom: 12 })

          Column() {
            GlassCard({ style: GlassStyle.REGULAR, theme: this.theme }) {
              Column() {
                Text('作品 ID')
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
                  .width('100%')
                TextInput({ text: this.idText, placeholder: '只要数字，例如 123456' })
                  .fontSize(14)
                  .fontColor(this.theme.textPrimary)
                  .placeholderColor(this.theme.textSecondary)
                  .backgroundColor(this.theme.chipBg)
                  .borderRadius(RADIUS_CHIP)
                  .height(44)
                  .width('100%')
                  .type(InputType.Number)
                  .padding({ left: 12, right: 12 })
                  .margin({ top: 6 })
                  .onChange((v: string) => {
                    this.idText = v
                  })
                Text(this.composedUrl().length > 0
                  ? ('将按 ' + this.composedUrl() + ' 刮削')
                  : '也可以直接粘贴作品链接，会自动取末尾的数字 ID')
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .width('100%')
                  .margin({ top: 8 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
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
              .margin({ top: 4 })
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
                  Text(this.rTitle.length > 0 ? this.rTitle : '(无标题)')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                    .width('100%')
                    .maxLines(3)
                  Text('日期 ' + (this.rDate.length > 0 ? this.rDate : '—') +
                    (this.rCode.length > 0 ? '   番号 ' + this.rCode : ''))
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .width('100%')
                    .margin({ top: 6 })

                  Row() {
                    Text('工作室')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width(52)
                    Text((this.rStudio.length > 0 ? this.rStudio : '—') + '（有则保留 · 无则写入）')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .margin({ top: 8 })

                  Row() {
                    Text('演员')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width(52)
                    Text(this.rPerfText.length > 0 ? this.rPerfText : '—')
                      .fontSize(11)
                      .fontColor(this.theme.textPrimary)
                      .layoutWeight(1)
                      .maxLines(3)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                  .margin({ top: 4 })

                  Row() {
                    Text('标签')
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .width(52)
                    Text(this.rTagText.length > 0 ? this.rTagText : '—')
                      .fontSize(11)
                      .fontColor(this.theme.textPrimary)
                      .layoutWeight(1)
                      .maxLines(4)
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

              Button(this.busy ? '写回中…' : '写回该短片')
                .width('100%')
                .height(44)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor(this.sceneId.length > 0 ? this.theme.brandColor : this.theme.textSecondary)
                .borderRadius(10)
                .margin({ top: 10 })
                .enabled(!this.busy && this.sceneId.length > 0)
                .onClick(() => {
                  this.applyResult()
                })
            }
            .width('100%')
            .margin({ top: 12 })
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
      .layoutWeight(1)
      .width('100%')
      .onRefreshing(() => {
        this.pullRefresh()
      })

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
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[this.bd.top, 0.0], [this.bd.mid, 0.5], [this.bd.bottom, 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
