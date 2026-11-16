/**
 * StashGo — Stash GraphQL 客户端（ArkTS 原生）
 */
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppSettings } from '../settings/AppSettings'
import { NetSwitch } from '../common/NetSwitch'
import { PackageDto, SceneGroupRow, PerformerDto, StudioDto, TagDto, GroupDto, PluginTaskDto, SceneDto, JobDto, StatsDto, ScraperDto, ScrapedSceneDto, PluginDto, FolderOption, PerformerUpdate, TagUpdate, StudioUpdate, GroupUpdate, StashBoxSource } from '../models/Models'

export class ApiException extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ApiException'
  }
}

interface VersionInner {
  version?: string
}

interface VersionData {
  version?: VersionInner
}

interface VersionEnvelope {
  data?: VersionData
}

interface ScenesPayload {
  count?: number
  scenes?: SceneDto[]
}

interface FindScenesData {
  findScenes?: ScenesPayload
}

interface ScenesEnvelope {
  data?: FindScenesData
}

interface FindSceneData {
  findScene?: SceneDto
}

interface SceneEnvelope {
  data?: FindSceneData
}

interface PerformersPayload {
  count?: number
  performers?: PerformerDto[]
}

interface FindPerformersData {
  findPerformers?: PerformersPayload
}

interface PerformersEnvelope {
  data?: FindPerformersData
}

interface FindPerformerData {
  findPerformer?: PerformerDto
}

interface PerformerEnvelope {
  data?: FindPerformerData
}

interface StudiosPayload {
  count?: number
  studios?: StudioDto[]
}

interface FindStudiosData {
  findStudios?: StudiosPayload
}

interface StudiosEnvelope {
  data?: FindStudiosData
}

interface TagsPayload {
  count?: number
  tags?: TagDto[]
}

interface FindTagsData {
  findTags?: TagsPayload
}

interface TagsEnvelope {
  data?: FindTagsData
}

interface GroupsPayload {
  count?: number
  groups?: TagDto[]
}

interface FindGroupsData {
  findGroups?: GroupsPayload
}

interface GroupsEnvelope {
  data?: FindGroupsData
}

/* ---------- 扩展 envelope ---------- */

interface SceneUpdateData {
  sceneUpdate?: TagDto
}

interface SceneUpdateEnvelope {
  data?: SceneUpdateData
}

interface SceneAddPlayData {
  sceneAddPlay?: SceneAddPlayPayload
}interface SceneAddPlayPayload {
  count?: number
}

interface SceneAddPlayEnvelope {
  data?: SceneAddPlayData
}

/* ---------- 刮削器包安装 ---------- */

interface InstalledPackagesData {
  installedPackages?: PackageDto[]
}

interface InstalledPackagesEnvelope {
  data?: InstalledPackagesData
}

interface AvailablePackagesData {
  availablePackages?: PackageDto[]
}

interface AvailablePackagesEnvelope {
  data?: AvailablePackagesData
}

/** installPackages / uninstallPackages / updatePackages 都返回一个计数字符串 */
interface PackageMutationData {
  installPackages?: string
  uninstallPackages?: string
  updatePackages?: string
}

interface PackageMutationEnvelope {
  data?: PackageMutationData
}

interface JobQueueData {
  jobQueue?: JobDto[]
}

interface JobQueueEnvelope {
  data?: JobQueueData
}

interface StatsData {
  stats?: StatsDto
}

interface StatsEnvelope {
  data?: StatsData
}

interface ScrapersData {
  listScrapers?: ScraperDto[]
}

interface ScrapersEnvelope {
  data?: ScrapersData
}

interface ScrapeSceneData {
  scrapeSceneURL?: ScrapedSceneDto
}

interface ScrapeSceneEnvelope {
  data?: ScrapeSceneData
}

interface ScrapeSingleData {
  scrapeSingleScene?: ScrapedSceneDto[]
}

interface ScrapeSingleEnvelope {
  data?: ScrapeSingleData
}

interface ScrapeSceneNameData {
  scrapeSceneByName?: ScrapedSceneDto
}

interface ScrapeSceneNameEnvelope {
  data?: ScrapeSceneNameData
}

interface PluginsData {
  plugins?: PluginDto[]
}

interface PluginsEnvelope {
  data?: PluginsData
}


/** 网络健康 */
export class NetHealth {
  static instance: NetHealth = new NetHealth()
  private failures: number = 0

  noteSuccess(): void {
    this.failures = 0
  }

  noteFailure(reason: string): void {
    this.failures++
    if (this.failures >= 3) {
      console.error('[NetHealth] 连续链路失败: ' + reason)
    }
  }
}

/** 网络日志 */
export interface NetLogEntry {
  category: string
  level: string
  title: string
  message: string
  method: string
  url: string
  status: number
  ms: number
}

export class NetLog {
  static instance: NetLog = new NetLog()
  private entries: NetLogEntry[] = []

  record(e: NetLogEntry): void {
    this.entries.unshift(e)
    if (this.entries.length > 200) {
      this.entries.pop()
    }
  }

  list(): NetLogEntry[] {
    return this.entries
  }

  clear(): void {
    this.entries = []
  }
}

/** HTTP 会话 */
export class ApiSession {
  static instance: ApiSession = new ApiSession()
  private client: http.HttpRequest | null = null

  getClient(): http.HttpRequest {
    if (this.client === null) {
      this.client = http.createHttp()
    }
    return this.client
  }

  reset(reason: string): void {
    if (this.client !== null) {
      try {
        this.client.destroy()
      } catch (e) {
        console.error('[ApiSession] destroy failed')
      }
    }
    this.client = null
    console.info('[ApiSession] 会话重建: ' + reason)
  }
}

export class StashApi {
  private baseUrl: string = ''
  private apiKey: string = ''

  constructor(baseUrl: string, apiKey: string) {
    this.baseUrl = baseUrl
    this.apiKey = apiKey
  }

  static normalizeBase(base: string): string {
    let s: string = base === null || base === undefined ? '' : base.trim()
    if (s.length === 0) {
      return ''
    }
    if (s.indexOf('://') < 0) {
      s = 'http://' + s
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1)
    }
    return s
  }

  private endpoint(): string {
    return StashApi.normalizeBase(this.baseUrl) + '/graphql'
  }

  private headerMap(): Record<string, string> {
    const h: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
    if (this.apiKey.length > 0) {
      h['ApiKey'] = this.apiKey
    }
    return h
  }

  private async post(q: string, vars: string, timeoutMs: number): Promise<string> {
    const url: string = this.endpoint()
    const body: string = '{"query":' + JSON.stringify(q) + ',"variables":' + vars + '}'
    const request = ApiSession.instance.getClient()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: this.headerMap(),
      extraData: body,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    }
    let resp: http.HttpResponse
    try {
      resp = await request.request(url, options)
    } catch (e) {
      throw new ApiException('网络错误: ' + (e as BusinessError).message)
    }
    const text: string = resp.result === undefined || resp.result === null ? '' : resp.result as string
    if (resp.responseCode !== 200) {
      throw new ApiException('HTTP ' + resp.responseCode + '：' + text.substring(0, 160))
    }
    return text
  }

  private async query(q: string, vars: string, timeoutMs: number): Promise<string> {
    const isMutation: boolean = q.trim().toLowerCase().startsWith('mutation')
    try {
      const text: string = await this.post(q, vars, timeoutMs)
      NetHealth.instance.noteSuccess()
      return text
    } catch (e) {
      const msg: string = (e as Error).message
      if (!isMutation) {
        ApiSession.instance.reset(msg)
        // 内网不可用：自动切到外网，再用新地址重试一次
        try {
          await NetSwitch.autoPick(true)
          const nb: string = AppSettings.instance.baseUrl
          if (nb.length > 0) {
            this.baseUrl = nb
          }
        } catch (e3) {
          // 切换失败就用原地址重试
        }
        try {
          const text: string = await this.post(q, vars, timeoutMs)
          NetHealth.instance.noteSuccess()
          return text
        } catch (e2) {
          NetHealth.instance.noteFailure(msg)
          throw new ApiException((e2 as Error).message)
        }
      }
      throw new ApiException(msg)
    }
  }

  /** 查询版本 */
  async version(): Promise<string> {
    const gq: string = 'query { version { version } }'
    const text: string = await this.query(gq, '{}', 10000)
    const env = JSON.parse(text) as VersionEnvelope
    const data: VersionData | undefined = env.data
    if (data === undefined) {
      return ''
    }
    const v: VersionInner | undefined = data.version
    if (v === undefined || v.version === undefined) {
      return ''
    }
    return v.version
  }

  /** 短片列表 */
  async findScenes(page: number, perPage: number): Promise<SceneDto[]> {
    const gq: string =
      'query FindScenes($filter: FindFilterType!) { findScenes(filter: $filter) { count scenes {' +
      ' id title date rating100 o_counter play_count organized paths { screenshot webp }' +
      ' studio { id name } performers { id name } tags { id name }' +
      ' files { height duration } captions { caption_type } } } }'
    const vars: string =
      '{"filter":{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":"date","direction":"DESC"}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as ScenesEnvelope
    const data: FindScenesData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: ScenesPayload | undefined = data.findScenes
    if (payload === undefined || payload.scenes === undefined) {
      return []
    }
    return payload.scenes
  }

  /** 单个短片 */
  async findScene(id: string): Promise<SceneDto | null> {
    const gq: string =
      'query FindScene($id: ID!) { findScene(id: $id) {' +
      ' id title date rating100 o_counter play_count organized details code director' +
      ' urls paths { screenshot webp }' +
      ' studio { id name } performers { id name birthdate } tags { id name } groups { group { id name } }' +
      ' files { id height duration size path mod_time basename } } }'
    const vars: string = '{"id":' + JSON.stringify(id) + '}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as SceneEnvelope
    const data: FindSceneData | undefined = env.data
    if (data === undefined) {
      return null
    }
    const s: SceneDto | undefined = data.findScene
    return s === undefined ? null : s
  }

  /** 演员列表 */
  async findPerformers(page: number, perPage: number): Promise<PerformerDto[]> {
    const gq: string =
      'query FindPerformers($filter: FindFilterType!) { findPerformers(filter: $filter) { count performers {' +
      ' id name image_path gender birthdate rating100 favorite scene_count country ethnicity' +
      ' height_cm details disambiguation alias_list urls eye_color hair_color measurements' +
      ' fake_tits tattoos piercings career_start career_end weight death_date' +
      ' image_count gallery_count group_count o_counter tags { id name } } } }'
    const vars: string =
      '{"filter":{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":"name","direction":"ASC"}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as PerformersEnvelope
    const data: FindPerformersData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: PerformersPayload | undefined = data.findPerformers
    if (payload === undefined || payload.performers === undefined) {
      return []
    }
    return payload.performers
  }

  /** 单个演员 */
  async findPerformer(id: string): Promise<PerformerDto | null> {
    const gq: string =
      'query FindPerformer($id: ID!) { findPerformer(id: $id) {' +
      ' id name image_path gender birthdate country ethnicity height_cm details' +
      ' rating100 favorite scene_count disambiguation alias_list urls eye_color hair_color' +
      ' measurements fake_tits tattoos piercings career_start career_end weight death_date' +
      ' image_count gallery_count group_count o_counter tags { id name } } }'
    const vars: string = '{"id":' + JSON.stringify(id) + '}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as PerformerEnvelope
    const data: FindPerformerData | undefined = env.data
    if (data === undefined) {
      return null
    }
    const p: PerformerDto | undefined = data.findPerformer
    return p === undefined ? null : p
  }

  /** 演员列表（搜索 / 排序） */
  async findPerformersEx(
    page: number, perPage: number, q: string, sort: string, direction: string
  ): Promise<PerformerDto[]> {
    const gq: string =
      'query FindPerformers($filter: FindFilterType!) { findPerformers(filter: $filter) { count performers {' +
      ' id name image_path gender birthdate rating100 favorite scene_count country ethnicity' +
      ' height_cm details disambiguation alias_list urls eye_color hair_color measurements' +
      ' fake_tits tattoos piercings career_start career_end weight death_date' +
      ' image_count gallery_count group_count o_counter tags { id name } } } }'
    let filter: string = '{"page":' + page.toString() + ',"per_page":' + perPage.toString()
    filter = filter + ',"sort":"' + sort + '","direction":"' + direction + '"'
    if (q.length > 0) {
      filter = filter + ',"q":' + JSON.stringify(q)
    }
    filter = filter + '}'
    const vars: string = '{"filter":' + filter + '}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as PerformersEnvelope
    const data: FindPerformersData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: PerformersPayload | undefined = data.findPerformers
    if (payload === undefined || payload.performers === undefined) {
      return []
    }
    return payload.performers
  }

  /** 某演员参演的短片 */
  /** 按标签筛选短片（收藏用） */
  async findScenesByTag(tagId: string, page: number, perPage: number,
    sort: string = 'date', direction: string = 'DESC'): Promise<SceneDto[]> {
    const gq: string =
      'query($filter: FindFilterType!, $sf: SceneFilterType) {' +
      ' findScenes(filter: $filter, scene_filter: $sf) { scenes {' +
      ' id title date rating100 o_counter play_count organized paths { screenshot webp }' +
      ' studio { id name } performers { id name } tags { id name }' +
      ' files { height duration } captions { caption_type } } } }'
    const vars: string = '{"filter":{"page":' + page.toString() +
      ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction) + '}' +
      ',"sf":{"tags":{"value":[' + JSON.stringify(tagId) + '],"modifier":"INCLUDES_ALL"}}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const payload = (data as Record<string, Object>)['findScenes']
    if (payload === undefined || payload === null) {
      return []
    }
    const list = (payload as Record<string, Object>)['scenes']
    if (list === undefined || list === null) {
      return []
    }
    return list as SceneDto[]
  }

  /** 只改标签，不动其他字段 */
  /** 清空短片的关联与链接（工作室/演员/标签/URL） */
  async clearSceneMeta(id: string): Promise<boolean> {
    const m: string =
      'mutation UpdateScene($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    const input: string = '{"id":' + JSON.stringify(id) +
      ',"studio_id":null,"performer_ids":[],"tag_ids":[],"urls":[]}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    return data !== undefined && data !== null
  }
  /** 设置短片的演员（覆盖） */
  async setScenePerformers(sceneId: string, performerIds: string[]): Promise<boolean> {
    const m: string =
      'mutation UpdateScene($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    const input: string = '{"id":' + JSON.stringify(sceneId) +
      ',"performer_ids":' + JSON.stringify(performerIds) + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    return data !== undefined && data !== null
  }

  /** 设置短片的工作室 */
  async setSceneStudio(sceneId: string, studioId: string): Promise<boolean> {
    const m: string =
      'mutation UpdateScene($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    const input: string = '{"id":' + JSON.stringify(sceneId) +
      ',"studio_id":' + JSON.stringify(studioId) + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    return data !== undefined && data !== null
  }

  /** 设置短片所属集合（覆盖） */
  async setSceneGroups(sceneId: string, groupIds: string[]): Promise<boolean> {
    const arr: string = '[' + groupIds.map((g: string, i: number): string => {
      return '{"group_id":' + JSON.stringify(g) + ',"scene_index":' + i.toString() + '}'
    }).join(',') + ']'
    const m: string =
      'mutation UpdateScene($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    const input: string = '{"id":' + JSON.stringify(sceneId) + ',"groups":' + arr + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    return data !== undefined && data !== null
  }

  /** 批量查询若干短片已属的集合 id */
  async sceneGroupIds(ids: string[]): Promise<SceneGroupRow[]> {
    const gq: string = 'query($ids: [ID!], $filter: FindFilterType!) {' +
      ' findScenes(scene_filter: {id: {value: $ids, modifier: INCLUDES_ALL}}, filter: $filter) {' +
      ' scenes { id groups { group { id } } } } }'
    const vars: string = '{"ids":' + JSON.stringify(ids) + ',"filter":{"page":1,"per_page":-1}}'
    const text: string = await this.query(gq, vars, 20000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    const out: SceneGroupRow[] = []
    if (data === undefined || data === null) {
      return out
    }
    const payload = (data as Record<string, Object>)['findScenes']
    if (payload === undefined || payload === null) {
      return out
    }
    const list = (payload as Record<string, Object>)['scenes']
    if (list === undefined || list === null) {
      return out
    }
    const arr = list as Object[]
    for (let i = 0; i < arr.length; i++) {
      const row = arr[i] as Record<string, Object>
      const rowId = row['id']
      const gids: string[] = []
      const gs = row['groups']
      if (gs !== undefined && gs !== null) {
        const ga = gs as Object[]
        for (let k = 0; k < ga.length; k++) {
          const g = (ga[k] as Record<string, Object>)['group']
          if (g !== undefined && g !== null) {
            const gid = (g as Record<string, Object>)['id']
            if (gid !== undefined && gid !== null) {
              gids.push(gid as string)
            }
          }
        }
      }
      out.push(new SceneGroupRow(rowId === undefined || rowId === null ? '' : rowId as string, gids))
    }
    return out
  }
  async setSceneTags(sceneId: string, tagIds: string[]): Promise<boolean> {
    const m: string =
      'mutation UpdateScene($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    const input: string = '{"id":' + JSON.stringify(sceneId) +
      ',"tag_ids":' + JSON.stringify(tagIds) + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    return data !== undefined && data !== null
  }
  async findScenesByPerformer(
    performerId: string, page: number, perPage: number
  ): Promise<SceneDto[]> {
    let gq: string =
      'query FindScenes($filter: FindFilterType!, $sf: SceneFilterType) {' +
      ' findScenes(filter: $filter, scene_filter: $sf) { count scenes {'
    gq = gq + ' id title date rating100 o_counter play_count organized paths { screenshot webp }'
    gq = gq + ' studio { id name } performers { id name } tags { id name }'
    gq = gq + ' files { height duration } captions { caption_type } } } }'
    const filter: string = '{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":"date","direction":"DESC"}'
    const sf: string = '{"performers":{"value":[' + JSON.stringify(performerId) +
      '],"modifier":"INCLUDES"}}'
    const vars: string = '{"filter":' + filter + ',"sf":' + sf + '}'
    const text: string = await this.query(gq, vars, 20000)
    const env = JSON.parse(text) as ScenesEnvelope
    const data: FindScenesData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: ScenesPayload | undefined = data.findScenes
    if (payload === undefined || payload.scenes === undefined) {
      return []
    }
    return payload.scenes
  }

  /** 演员收藏开关 */


  /** 收藏的工作室（studio_filter.favorite）；排序由调用方按 SortOption 传入 */
  async findFavoriteStudios(page: number, perPage: number,
    sort: string = 'name', direction: string = 'ASC'): Promise<StudioDto[]> {
    const gq: string =
      'query FindStudios($filter: FindFilterType!, $sf: StudioFilterType) {' +
      ' findStudios(filter: $filter, studio_filter: $sf) { count studios {' +
      ' id name image_path scene_count rating100 favorite details } } }'
    const vars: string = '{"filter":{"page":' + page.toString() +
      ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction) + '}' +
      ',"sf":{"favorite":true}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const payload = (data as Record<string, Object>)['findStudios']
    if (payload === undefined || payload === null) {
      return []
    }
    const list = (payload as Record<string, Object>)['studios']
    if (list === undefined || list === null) {
      return []
    }
    return list as StudioDto[]
  }
  async studiosForBrowse(): Promise<StudioDto[]> {
    const gq: string =
      'query($filter: FindFilterType!) { findStudios(filter: $filter) { count studios {' +
      ' id name image_path scene_count rating100 favorite } } }'
    const vars: string = '{"filter":{"page":1,"per_page":300,"sort":"name","direction":"ASC"}}'
    const text: string = await this.query(gq, vars, 20000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const payload = (data as Record<string, Object>)['findStudios']
    if (payload === undefined || payload === null) {
      return []
    }
    const list = (payload as Record<string, Object>)['studios']
    if (list === undefined || list === null) {
      return []
    }
    const arr = list as StudioDto[]
    arr.sort((a: StudioDto, b: StudioDto) => {
      const ca: number = a.scene_count === undefined ? 0 : a.scene_count
      const cb: number = b.scene_count === undefined ? 0 : b.scene_count
      return cb - ca
    })
    return arr
  }
  /** 收藏的演员（performer_filter.filter_favorites） */
  async findFavoritePerformers(page: number, perPage: number,
    sort: string = 'name', direction: string = 'ASC'): Promise<PerformerDto[]> {
    const gq: string =
      'query($filter: FindFilterType!, $pfilter: PerformerFilterType) {' +
      ' findPerformers(filter: $filter, performer_filter: $pfilter) { count performers {' +
      ' id name image_path gender birthdate rating100 favorite scene_count' +
      ' country ethnicity height_cm details disambiguation alias_list urls' +
      ' tags { id name } } } }'
    const vars: string = '{"filter":{"page":' + page.toString() +
      ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction) + '}' +
      ',"pfilter":{"filter_favorites":true}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const payload = (data as Record<string, Object>)['findPerformers']
    if (payload === undefined || payload === null) {
      return []
    }
    const list = (payload as Record<string, Object>)['performers']
    if (list === undefined || list === null) {
      return []
    }
    return list as PerformerDto[]
  }
  /* ---------- 短片收藏（对齐 SJP：收藏 = 打上 FAVORITE 标签） ---------- */

  /** SJP（8097）配置里的 FAVORITE_TAG，两边必须一致 */
  private static readonly FAVORITE_TAG_NAME: string = 'FAVORITE'
  private static favTagId: string = ''

  /** 收藏标签的 id；标签不存在时返回空串（不新建） */
  async favoriteTagId(): Promise<string> {
    if (StashApi.favTagId.length > 0) {
      return StashApi.favTagId
    }
    const gq: string =
      'query($filter: FindFilterType!) { findTags(filter: $filter) { tags { id name } } }'
    const vars: string = '{"filter":{"page":1,"per_page":20,"q":' +
      JSON.stringify(StashApi.FAVORITE_TAG_NAME) + '}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return ''
    }
    const payload = (data as Record<string, Object>)['findTags']
    if (payload === undefined || payload === null) {
      return ''
    }
    const list = (payload as Record<string, Object>)['tags']
    if (list === undefined || list === null) {
      return ''
    }
    const arr = list as Record<string, Object>[]
    const want: string = StashApi.FAVORITE_TAG_NAME.toLowerCase()
    for (let i = 0; i < arr.length; i++) {
      const nv = arr[i]['name']
      if (nv === undefined || nv === null) {
        continue
      }
      if ((nv as string).toLowerCase() === want) {
        const iv = arr[i]['id']
        const found: string = iv === undefined || iv === null ? '' : iv as string
        if (found.length > 0) {
          StashApi.favTagId = found
        }
        return found
      }
    }
    return ''
  }

  /** 收藏的短片：带 FAVORITE 标签的那些 */
  async findFavoriteScenes(page: number, perPage: number,
    sort: string, direction: string): Promise<SceneDto[]> {
    const tagId: string = await this.favoriteTagId()
    if (tagId.length === 0) {
      return []
    }
    let gq: string = 'query($filter: FindFilterType!, $sf: SceneFilterType) {' +
      ' findScenes(filter: $filter, scene_filter: $sf) { count scenes {'
    gq = gq + ' id title date rating100 o_counter play_count organized paths { screenshot webp }'
    gq = gq + ' studio { id name } performers { id name } tags { id name }'
    gq = gq + ' files { height duration } captions { caption_type } updated_at custom_fields } } }'
    const filter: string = '{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction) + '}'
    const sf: string = '{"tags":{"value":[' + JSON.stringify(tagId) + '],"modifier":"INCLUDES_ALL"}}'
    const vars: string = '{"filter":' + filter + ',"sf":' + sf + '}'
    const text: string = await this.query(gq, vars, 20000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as ScenesEnvelope
    const data: FindScenesData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: ScenesPayload | undefined = data.findScenes
    if (payload === undefined || payload.scenes === undefined) {
      return []
    }
    return payload.scenes
  }

  /**
   * 一次性取回全部收藏短片（按收藏时间排序时用）。
   * 服务端不能按 custom_fields 排序，只能本地排，所以必须拿全量。
   */
  async findAllFavoriteScenes(): Promise<SceneDto[]> {
    const out: SceneDto[] = []
    const perPage: number = 500
    let page: number = 1
    while (page <= 10) {
      const chunk: SceneDto[] = await this.findFavoriteScenes(page, perPage, 'updated_at', 'DESC')
      for (let i = 0; i < chunk.length; i++) {
        out.push(chunk[i])
      }
      if (chunk.length < perPage) {
        break
      }
      page = page + 1
    }
    return out
  }

  /** 收藏时间的 ISO 串（local 带时区，和 Stash 自己的 updated_at 同格式） */
  private static nowIso(): string {
    const d = new Date()
    const off: number = -d.getTimezoneOffset()
    const sign: string = off >= 0 ? '+' : '-'
    const abs: number = Math.abs(off)
    const p = (n: number): string => n < 10 ? '0' + n.toString() : n.toString()
    return d.getFullYear().toString() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) +
      'T' + p(d.getHours()) + ':' + p(d.getMinutes()) + ':' + p(d.getSeconds()) +
      sign + p(Math.floor(abs / 60)) + ':' + p(abs % 60)
  }

  /** 收藏 / 取消收藏：给这条短片加 / 删 FAVORITE 标签，同时记下/清掉收藏时间 */
  async setSceneFavorite(sceneId: string, favorite: boolean): Promise<boolean> {
    const tagId: string = await this.favoriteTagId()
    if (tagId.length === 0) {
      throw new ApiException('找不到收藏标签「' + StashApi.FAVORITE_TAG_NAME +
        '」：先在 Stash 里建一个同名标签（或改 SJP 的 FAVORITE_TAG）')
    }
    const m: string = 'mutation BulkSceneUpdate($input: BulkSceneUpdateInput!)' +
      ' { bulkSceneUpdate(input: $input) { id } }'
    const cf: string = favorite ?
      '"custom_fields":{"partial":{"favorite_at":' + JSON.stringify(StashApi.nowIso()) + '}}' :
      '"custom_fields":{"remove":["favorite_at"]}'
    const input: string = '{"ids":[' + JSON.stringify(sceneId) + '],"tag_ids":{"ids":[' +
      JSON.stringify(tagId) + '],"mode":"' + (favorite ? 'ADD' : 'REMOVE') + '"},' + cf + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 30000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return false
    }
    const payload = (data as Record<string, Object>)['bulkSceneUpdate']
    return payload !== undefined && payload !== null
  }

  /** 批量收藏 / 取消收藏（多选时用） */
  async setScenesFavorite(sceneIds: string[], favorite: boolean): Promise<boolean> {
    if (sceneIds.length === 0) {
      return true
    }
    const tagId: string = await this.favoriteTagId()
    if (tagId.length === 0) {
      throw new ApiException('找不到收藏标签「' + StashApi.FAVORITE_TAG_NAME + '」')
    }
    let idArr: string = '['
    for (let i = 0; i < sceneIds.length; i++) {
      if (i > 0) {
        idArr = idArr + ','
      }
      idArr = idArr + JSON.stringify(sceneIds[i])
    }
    idArr = idArr + ']'
    const m: string = 'mutation BulkSceneUpdate($input: BulkSceneUpdateInput!)' +
      ' { bulkSceneUpdate(input: $input) { id } }'
    const cf: string = favorite ?
      '"custom_fields":{"partial":{"favorite_at":' + JSON.stringify(StashApi.nowIso()) + '}}' :
      '"custom_fields":{"remove":["favorite_at"]}'
    const input: string = '{"ids":' + idArr + ',"tag_ids":{"ids":[' +
      JSON.stringify(tagId) + '],"mode":"' + (favorite ? 'ADD' : 'REMOVE') + '"},' + cf + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 60000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    return data !== undefined && data !== null
  }

  async updatePerformerFavorite(id: string, favorite: boolean): Promise<boolean> {    const gq: string =
      'mutation PUpd($input: PerformerUpdateInput!) { performerUpdate(input: $input) { id favorite } }'
    const vars: string = '{"input":{"id":' + JSON.stringify(id) +
      ',"favorite":' + (favorite ? 'true' : 'false') + '}}'
    const text: string = await this.query(gq, vars, 15000)
    return text.length > 0
  }

  /** 演员评分 */
  async updatePerformerRating(id: string, rating100: number): Promise<boolean> {
    const gq: string =
      'mutation PUpd($input: PerformerUpdateInput!) { performerUpdate(input: $input) { id rating100 } }'
    const vars: string = '{"input":{"id":' + JSON.stringify(id) +
      ',"rating100":' + rating100.toString() + '}}'
    const text: string = await this.query(gq, vars, 15000)
    return text.length > 0
  }

  /** 工作室列表 */
  /**
   * 工作室列表（轻量版）：只取卡片要用的字段。
   * 带 tags / aliases / urls / 各种 count 的重查询在 60 条时要 2.5 秒，精简后 20 毫秒级。
   */
  async findStudiosLite(page: number, perPage: number,
    sort: string = 'name', direction: string = 'ASC', q: string = ''): Promise<StudioDto[]> {
    const gq: string =
      'query FindStudios($filter: FindFilterType!) { findStudios(filter: $filter) { studios {' +
      ' id name image_path scene_count rating100 favorite details } } }'
    let vars: string =
      '{"filter":{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction)
    if (q.length > 0) {
      vars = vars + ',"q":' + JSON.stringify(q)
    }
    vars = vars + '}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const payload = (data as Record<string, Object>)['findStudios']
    if (payload === undefined || payload === null) {
      return []
    }
    const list = (payload as Record<string, Object>)['studios']
    if (list === undefined || list === null) {
      return []
    }
    return list as StudioDto[]
  }

  async findStudios(page: number, perPage: number,
    sort: string = 'name', direction: string = 'ASC', q: string = ''): Promise<StudioDto[]> {
    const gq: string =
      'query FindStudios($filter: FindFilterType!) { findStudios(filter: $filter) { count studios {' +
      ' id name image_path rating100 scene_count details favorite aliases urls organized' +
      ' image_count gallery_count performer_count group_count o_counter tags { id name } } } }'
    let vars: string =
      '{"filter":{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction)
    if (q.length > 0) {
      vars = vars + ',"q":' + JSON.stringify(q)
    }
    vars = vars + '}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as StudiosEnvelope
    const data: FindStudiosData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: StudiosPayload | undefined = data.findStudios
    if (payload === undefined || payload.studios === undefined) {
      return []
    }
    return payload.studios
  }

  /** 标签列表 */
  async findTags(page: number, perPage: number,
    sort: string = 'name', direction: string = 'ASC', q: string = ''): Promise<TagDto[]> {
    const gq: string =
      'query FindTags($filter: FindFilterType!) { findTags(filter: $filter) { count tags {' +
      ' id name sort_name scene_count favorite aliases } } }'
    let vars: string =
      '{"filter":{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction)
    if (q.length > 0) {
      vars = vars + ',"q":' + JSON.stringify(q)
    }
    vars = vars + '}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as TagsEnvelope
    const data: FindTagsData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: TagsPayload | undefined = data.findTags
    if (payload === undefined || payload.tags === undefined) {
      return []
    }
    return payload.tags
  }

  /** 集合列表 */
  async findGroups(page: number, perPage: number,
    sort: string = 'name', direction: string = 'ASC', q: string = ''): Promise<TagDto[]> {
    const gq: string =
      'query FindGroups($filter: FindFilterType!) { findGroups(filter: $filter) { count groups { id name } } }'
    let vars: string =
      '{"filter":{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction)
    if (q.length > 0) {
      vars = vars + ',"q":' + JSON.stringify(q)
    }
    vars = vars + '}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as GroupsEnvelope
    const data: FindGroupsData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: GroupsPayload | undefined = data.findGroups
    if (payload === undefined || payload.groups === undefined) {
      return []
    }
    return payload.groups
  }

  /** 集合列表（带封面 / 数量 / 日期 / 工作室，供列表页展示） */
  async findGroupsRich(page: number, perPage: number,
    sort: string = 'name', direction: string = 'ASC', q: string = ''): Promise<GroupDto[]> {
    const gq: string =
      'query FindGroups($filter: FindFilterType!) { findGroups(filter: $filter) { count groups {' +
      ' id name scene_count date front_image_path back_image_path rating100' +
      ' studio { id name } tags { id name } } } }'
    let vars: string =
      '{"filter":{"page":' + page.toString() + ',"per_page":' + perPage.toString() +
      ',"sort":' + JSON.stringify(sort) + ',"direction":' + JSON.stringify(direction)
    if (q.length > 0) {
      vars = vars + ',"q":' + JSON.stringify(q)
    }
    vars = vars + '}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    const out: GroupDto[] = []
    if (data === undefined || data === null) {
      return out
    }
    const payload = (data as Record<string, Object>)['findGroups']
    if (payload === undefined || payload === null) {
      return out
    }
    const list = (payload as Record<string, Object>)['groups']
    if (list === undefined || list === null) {
      return out
    }
    return list as GroupDto[]
  }

  /* ==================== 扩展：搜索 / 筛选 / 变更 / 任务 / 统计 / 刮削 ==================== */
  /** 短片列表（支持关键词搜索、排序、仅已整理） */
  async findScenesAdvanced(
    page: number, perPage: number, q: string, sort: string, direction: string, organizedOnly: boolean
  ): Promise<SceneDto[]> {
    let gq: string = 'query FindScenes($filter: FindFilterType!, $sf: SceneFilterType) { findScenes(filter: $filter, scene_filter: $sf) { count scenes {'
    gq = gq + ' id title date rating100 o_counter play_count organized paths { screenshot webp }'
    gq = gq + ' studio { id name } performers { id name } tags { id name }'
    gq = gq + ' files { height duration } captions { caption_type } } } }'

    let filter: string = '{"page":' + page.toString() + ',"per_page":' + perPage.toString()
    filter = filter + ',"sort":"' + sort + '","direction":"' + direction + '"'
    if (q.length > 0) {
      filter = filter + ',"q":' + JSON.stringify(q)
    }
    filter = filter + '}'

    let sf: string = '{}'
    if (organizedOnly) {
      sf = '{"organized":true}'
    }
    const vars: string = '{"filter":' + filter + ',"sf":' + sf + '}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as ScenesEnvelope
    const data: FindScenesData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: ScenesPayload | undefined = data.findScenes
    if (payload === undefined || payload.scenes === undefined) {
      return []
    }
    return payload.scenes
  }

  /** 短片列表（带自定义 scene_filter JSON） */
  async findScenesFiltered(
    page: number, perPage: number, q: string, sort: string, direction: string, sceneFilterJson: string
  ): Promise<SceneDto[]> {
    let gq: string = 'query FindScenes($filter: FindFilterType!, $sf: SceneFilterType) { findScenes(filter: $filter, scene_filter: $sf) { count scenes {'
    gq = gq + ' id title date rating100 o_counter play_count organized paths { screenshot webp }'
    gq = gq + ' studio { id name } performers { id name } tags { id name }'
    gq = gq + ' files { height duration } captions { caption_type } } } }'

    let filter: string = '{"page":' + page.toString() + ',"per_page":' + perPage.toString()
    filter = filter + ',"sort":"' + sort + '","direction":"' + direction + '"'
    if (q.length > 0) {
      filter = filter + ',"q":' + JSON.stringify(q)
    }
    filter = filter + '}'

    const sf: string = sceneFilterJson.length === 0 ? '{}' : sceneFilterJson
    const vars: string = '{"filter":' + filter + ',"sf":' + sf + '}'
    const text: string = await this.query(gq, vars, 20000)
    const env = JSON.parse(text) as ScenesEnvelope
    const data: FindScenesData | undefined = env.data
    if (data === undefined) {
      return []
    }
    const payload: ScenesPayload | undefined = data.findScenes
    if (payload === undefined || payload.scenes === undefined) {
      return []
    }
    return payload.scenes
  }

  /** 更新短片（评分 / 标题 / 简介 / 已整理） */
  /** 名字→ID 的会话级缓存，避免重复查询 */
  private static idCache: Map<string, string> = new Map<string, string>()

  /** 把可能为 null / undefined 的字段安全转成字符串（Stash 大量字段可空） */
  private static safeText(v: Object | undefined): string {
    if (v === undefined || v === null) {
      return ''
    }
    return v.toString()
  }
  async updateScene(
    id: string, rating100: number, organized: boolean, title: string, details: string,
    date: string = '', code: string = '', director: string = '', coverImage: string = ''
  ): Promise<boolean> {
    const m: string =
      'mutation UpdateScene($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    // 先归一化：Stash 的标量字段可能返回 null
    const t: string = StashApi.safeText(title)
    const d: string = StashApi.safeText(details)
    const dt: string = StashApi.safeText(date)
    const cd: string = StashApi.safeText(code)
    const dr: string = StashApi.safeText(director)
    const cv: string = StashApi.safeText(coverImage)
    const rt: number = (rating100 === undefined || rating100 === null) ? 0 : rating100
    let input: string = '{"id":' + JSON.stringify(id) + ',"rating100":' + rt.toString()
    input = input + ',"organized":' + (organized ? 'true' : 'false')
    input = input + ',"title":' + JSON.stringify(t)
    input = input + ',"details":' + JSON.stringify(d)
    if (dt.length > 0) {
      input = input + ',"date":' + JSON.stringify(dt)
    }
    if (cd.length > 0) {
      input = input + ',"code":' + JSON.stringify(cd)
    }
    if (dr.length > 0) {
      input = input + ',"director":' + JSON.stringify(dr)
    }
    if (cv.length > 0) {
      input = input + ',"cover_image":' + JSON.stringify(cv)
    }
    input = input + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as SceneUpdateEnvelope
    const data: SceneUpdateData | undefined = env.data
    if (data === undefined) {
      return false
    }
    return data.sceneUpdate !== undefined
  }




  /* ---------------- 选择器专用精简查询（只取 id + name） ---------------- */

  private async litePick(gq: string, key: string): Promise<StudioDto[]> {
    const vars: string = '{"filter":{"page":1,"per_page":500,"sort":"name","direction":"ASC"}}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const payload = (data as Record<string, Object>)[key]
    if (payload === undefined || payload === null) {
      return []
    }
    const arr = (payload as Record<string, Object>)['studios']
    if (arr === undefined || arr === null) {
      return []
    }
    return arr as StudioDto[]
  }

  async studiosLite(): Promise<StudioDto[]> {
    return this.litePick(
      'query($filter: FindFilterType!) { findStudios(filter: $filter) { studios { id name } } }',
      'findStudios')
  }

  async performersLite(): Promise<StudioDto[]> {
    return this.litePick(
      'query($filter: FindFilterType!) { findPerformers(filter: $filter) { studios: performers { id name } } }',
      'findPerformers')
  }

  async tagsLite(): Promise<StudioDto[]> {
    return this.litePick(
      'query($filter: FindFilterType!) { findTags(filter: $filter) { studios: tags { id name } } }',
      'findTags')
  }


  /** 从短片文件路径统计出含视频的文件夹（按数量降序） */
  async folderOptions(): Promise<FolderOption[]> {
    const gq: string =
      'query { findScenes(filter: {per_page: 600, sort: "created_at", direction: DESC}) {' +
      ' scenes { files { path } } } }'
    const text: string = await this.query(gq, '{}', 20000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const payload = (data as Record<string, Object>)['findScenes']
    if (payload === undefined || payload === null) {
      return []
    }
    const scenes = (payload as Record<string, Object>)['scenes']
    if (scenes === undefined || scenes === null) {
      return []
    }
    const arr = scenes as Record<string, Object>[]
    const map: Map<string, number> = new Map<string, number>()
    for (let i = 0; i < arr.length; i++) {
      const sc = arr[i]
      const files = sc['files']
      if (files === undefined || files === null) {
        continue
      }
      const fl = files as Record<string, Object>[]
      for (let k = 0; k < fl.length; k++) {
        const pv = fl[k]['path']
        if (pv === undefined || pv === null) {
          continue
        }
        const p: string = pv as string
        const idx: number = p.lastIndexOf('/')
        if (idx <= 0) {
          continue
        }
        const dir: string = p.substring(0, idx)
        const old: number | undefined = map.get(dir)
        map.set(dir, old === undefined ? 1 : old + 1)
      }
    }
    const out: FolderOption[] = []
    const keys: string[] = []
    map.forEach((v: number, k: string) => {
      keys.push(k)
    })
    for (let i = 0; i < keys.length; i++) {
      const cnt: number | undefined = map.get(keys[i])
      out.push(new FolderOption(keys[i], cnt === undefined ? 0 : cnt))
    }
    out.sort((a: FolderOption, b: FolderOption) => b.count - a.count)
    return out
  }


  /** 读取 Stash 已配置的媒体库路径（选择性扫描的候选目录） */
  async libraryPaths(): Promise<FolderOption[]> {
    const gq: string = 'query { configuration { general { stashes { path excludeVideo } } } }'
    const text: string = await this.query(gq, '{}', 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return []
    }
    const cfg = (data as Record<string, Object>)['configuration']
    if (cfg === undefined || cfg === null) {
      return []
    }
    const gen = (cfg as Record<string, Object>)['general']
    if (gen === undefined || gen === null) {
      return []
    }
    const stashes = (gen as Record<string, Object>)['stashes']
    if (stashes === undefined || stashes === null) {
      return []
    }
    const arr = stashes as Record<string, Object>[]
    const out: FolderOption[] = []
    for (let i = 0; i < arr.length; i++) {
      const pv = arr[i]['path']
      if (pv === undefined || pv === null) {
        continue
      }
      out.push(new FolderOption(pv as string, 0))
    }
    out.sort((a: FolderOption, b: FolderOption) => a.path < b.path ? -1 : 1)
    return out
  }

  /**
   * 把名字解析成 ID：先按名字精确查，查不到就新建。
   * kind: 'studio' | 'performer' | 'tag'
   */
  async resolveId(kind: string, name: string): Promise<string> {
    const n: string = name.trim()
    if (n.length === 0) {
      return ''
    }
    const cacheKey: string = kind + '|' + n.toLowerCase()
    const hit: string | undefined = StashApi.idCache.get(cacheKey)
    if (hit !== undefined) {
      return hit
    }
    let gq: string = ''
    let rootKey: string = ''
    let listKey: string = ''
    if (kind === 'studio') {
      gq = 'query($filter: FindFilterType!) { findStudios(filter: $filter) { studios { id name } } }'
      rootKey = 'findStudios'
      listKey = 'studios'
    } else if (kind === 'performer') {
      gq = 'query($filter: FindFilterType!) { findPerformers(filter: $filter) { performers { id name } } }'
      rootKey = 'findPerformers'
      listKey = 'performers'
    } else {
      gq = 'query($filter: FindFilterType!) { findTags(filter: $filter) { tags { id name } } }'
      rootKey = 'findTags'
      listKey = 'tags'
    }
    const vars: string = '{"filter":{"page":1,"per_page":20,"q":' + JSON.stringify(n) + '}}'
    try {
      const text: string = await this.query(gq, vars, 15000)
      const env = JSON.parse(text) as Record<string, Object>
      const data = env['data']
      if (data !== undefined && data !== null) {
        const root = (data as Record<string, Object>)[rootKey]
        if (root !== undefined && root !== null) {
          const list = (root as Record<string, Object>)[listKey]
          if (list !== undefined && list !== null) {
            const arr = list as Record<string, Object>[]
            const lower: string = n.toLowerCase()
            for (let i = 0; i < arr.length; i++) {
              const nv = arr[i]['name']
              if (nv === undefined || nv === null) {
                continue
              }
              if ((nv as string).toLowerCase() === lower) {
                const iv = arr[i]['id']
                const found: string = iv === undefined || iv === null ? '' : (iv as string)
                if (found.length > 0) {
                  StashApi.idCache.set(cacheKey, found)
                }
                return found
              }
            }
          }
        }
      }
    } catch (e) {
      // 查询失败就走新建
    }
    try {
      if (kind === 'studio') {
        return await this.createStudio(n)
      }
      if (kind === 'performer') {
        return await this.createPerformer(n)
      }
      return await this.createTag(n)
    } catch (e) {
      return ''
    }
  }
  /** 清理缺失文件（metadataClean），dryRun=true 只预演不删除 */
  async cleanLibrary(paths: string[] = [], dryRun: boolean = false): Promise<boolean> {
    const m: string = 'mutation($input: CleanMetadataInput!) { metadataClean(input: $input) }'
    let input: string = '{"dryRun":' + (dryRun ? 'true' : 'false')
    input = input + ',"ignoreZipFileContents":false'
    if (paths.length > 0) {
      input = input + ',"paths":' + JSON.stringify(paths)
    }
    input = input + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 30000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return false
    }
    const v = (data as Record<string, Object>)['metadataClean']
    return v !== undefined && v !== null
  }
  /** 扫描媒体库（Stash metadataScan），返回是否提交成功 */
  async scanLibrary(rescan: boolean = false, paths: string[] = []): Promise<boolean> {
    const m: string =
      'mutation($input: ScanMetadataInput!) { metadataScan(input: $input) }'
    let input: string = '{"rescan":' + (rescan ? 'true' : 'false')
    input = input + ',"scanGenerateCovers":true,"scanGeneratePreviews":false'
    input = input + ',"scanGenerateImagePreviews":false,"scanGenerateSprites":true'
    input = input + ',"scanGeneratePhashes":true,"scanGenerateThumbnails":true'
    input = input + ',"scanGenerateClipPreviews":false'
    if (paths.length > 0) {
      input = input + ',"paths":' + JSON.stringify(paths)
    }
    input = input + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 20000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return false
    }
    const v = (data as Record<string, Object>)['metadataScan']
    return v !== undefined && v !== null
  }
  /** 新建工作室，返回 id（失败返回空串） */
  async createStudio(name: string): Promise<string> {
    const m: string = 'mutation($i: StudioCreateInput!) { studioCreate(input: $i) { id } }'
    const v: string = '{"i":{"name":' + JSON.stringify(name) + '}}'
    const text: string = await this.query(m, v, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return ''
    }
    const created = (data as Record<string, Object>)['studioCreate']
    if (created === undefined || created === null) {
      return ''
    }
    const idv = (created as Record<string, Object>)['id']
    return idv === undefined || idv === null ? '' : idv as string
  }

  /** 新建演员，返回 id */
  async createPerformer(name: string): Promise<string> {
    const m: string = 'mutation($i: PerformerCreateInput!) { performerCreate(input: $i) { id } }'
    const v: string = '{"i":{"name":' + JSON.stringify(name) + '}}'
    const text: string = await this.query(m, v, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return ''
    }
    const created = (data as Record<string, Object>)['performerCreate']
    if (created === undefined || created === null) {
      return ''
    }
    const idv = (created as Record<string, Object>)['id']
    return idv === undefined || idv === null ? '' : idv as string
  }

  /** 新建标签，返回 id */
  async createTag(name: string): Promise<string> {
    const m: string = 'mutation($i: TagCreateInput!) { tagCreate(input: $i) { id } }'
    const v: string = '{"i":{"name":' + JSON.stringify(name) + '}}'
    const text: string = await this.query(m, v, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data']
    if (data === undefined || data === null) {
      return ''
    }
    const created = (data as Record<string, Object>)['tagCreate']
    if (created === undefined || created === null) {
      return ''
    }
    const idv = (created as Record<string, Object>)['id']
    return idv === undefined || idv === null ? '' : idv as string
  }
  /* ==================== 元数据编辑（演员 / 标签 / 工作室 / 集合） ==================== */

  /** 解析写操作返回：GraphQL errors 抛 ApiException（带服务端原因），其余按布尔判断 */
  private mutationOk(text: string, key: string): boolean {
    const env = JSON.parse(text) as Record<string, Object>
    const errs = env['errors']
    if (errs !== undefined && errs !== null) {
      const arr = errs as Record<string, Object>[]
      if (arr.length > 0) {
        const mv = arr[0]['message']
        const msg: string = mv === undefined || mv === null ? '写入失败' : mv as string
        throw new ApiException(msg)
      }
    }
    const data = env['data']
    if (data === undefined || data === null) {
      return false
    }
    const v = (data as Record<string, Object>)[key]
    return v !== undefined && v !== null
  }

  /** 解析新建类返回的 id；失败抛 ApiException */
  private mutationId(text: string, key: string): string {
    const env = JSON.parse(text) as Record<string, Object>
    const errs = env['errors']
    if (errs !== undefined && errs !== null) {
      const arr = errs as Record<string, Object>[]
      if (arr.length > 0) {
        const mv = arr[0]['message']
        const msg: string = mv === undefined || mv === null ? '写入失败' : mv as string
        throw new ApiException(msg)
      }
    }
    const data = env['data']
    if (data === undefined || data === null) {
      return ''
    }
    const created = (data as Record<string, Object>)[key]
    if (created === undefined || created === null) {
      return ''
    }
    const idv = (created as Record<string, Object>)['id']
    return idv === undefined || idv === null ? '' : idv as string
  }

  /** 更新演员（整表写回，空串清空字段；别名 / URL 传空数组即清空） */
  async updatePerformer(id: string, u: PerformerUpdate): Promise<boolean> {
    const m: string =
      'mutation($i: PerformerUpdateInput!) { performerUpdate(input: $i) { id } }'
    let i: string = '{"id":' + JSON.stringify(id)
    i = i + ',"name":' + JSON.stringify(u.name)
    i = i + ',"disambiguation":' + JSON.stringify(u.disambiguation)
    i = i + ',"alias_list":' + JSON.stringify(u.aliases)
    i = i + ',"urls":' + JSON.stringify(u.urls)
    if (u.gender.length > 0) {
      i = i + ',"gender":' + JSON.stringify(u.gender)
    }
    i = i + ',"birthdate":' + JSON.stringify(u.birthdate)
    i = i + ',"death_date":' + JSON.stringify(u.death_date)
    i = i + ',"country":' + JSON.stringify(u.country)
    i = i + ',"ethnicity":' + JSON.stringify(u.ethnicity)
    i = i + ',"hair_color":' + JSON.stringify(u.hair_color)
    i = i + ',"eye_color":' + JSON.stringify(u.eye_color)
    i = i + ',"height_cm":' + Math.round(u.height_cm).toString()
    i = i + ',"weight":' + Math.round(u.weight).toString()
    i = i + ',"measurements":' + JSON.stringify(u.measurements)
    i = i + ',"fake_tits":' + JSON.stringify(u.fake_tits)
    i = i + ',"tattoos":' + JSON.stringify(u.tattoos)
    i = i + ',"piercings":' + JSON.stringify(u.piercings)
    i = i + ',"career_start":' + JSON.stringify(u.career_start)
    i = i + ',"career_end":' + JSON.stringify(u.career_end)
    i = i + ',"details":' + JSON.stringify(u.details)
    i = i + '}'
    return this.mutationOk(await this.query(m, '{"i":' + i + '}', 20000), 'performerUpdate')
  }

  /** 合并演员：sourceIds 全部并入 destinationId，返回是否成功 */
  async mergePerformers(sourceIds: string[], destinationId: string): Promise<boolean> {
    if (sourceIds.length === 0 || destinationId.length === 0) {
      return false
    }
    const m: string =
      'mutation($i: PerformerMergeInput!) { performerMerge(input: $i) { id } }'
    const i: string = '{"source":' + JSON.stringify(sourceIds) +
      ',"destination":' + JSON.stringify(destinationId) + '}'
    return this.mutationOk(await this.query(m, '{"i":' + i + '}', 30000), 'performerMerge')
  }

  /** 更新标签（整表写回）；setParents=true 时才覆盖父标签 */
  async updateTag(id: string, u: TagUpdate): Promise<boolean> {
    const m: string = 'mutation($i: TagUpdateInput!) { tagUpdate(input: $i) { id } }'
    let i: string = '{"id":' + JSON.stringify(id)
    i = i + ',"name":' + JSON.stringify(u.name)
    i = i + ',"sort_name":' + JSON.stringify(u.sort_name)
    i = i + ',"description":' + JSON.stringify(u.description)
    i = i + ',"aliases":' + JSON.stringify(u.aliases)
    i = i + ',"favorite":' + (u.favorite ? 'true' : 'false')
    if (u.setParents) {
      i = i + ',"parent_ids":' + JSON.stringify(u.parentIds)
    }
    i = i + '}'
    return this.mutationOk(await this.query(m, '{"i":' + i + '}', 20000), 'tagUpdate')
  }

  /** 合并标签：sourceIds 并入 destinationId */
  async mergeTags(sourceIds: string[], destinationId: string): Promise<boolean> {
    if (sourceIds.length === 0 || destinationId.length === 0) {
      return false
    }
    const m: string = 'mutation($i: TagsMergeInput!) { tagsMerge(input: $i) { id } }'
    const i: string = '{"source":' + JSON.stringify(sourceIds) +
      ',"destination":' + JSON.stringify(destinationId) + '}'
    return this.mutationOk(await this.query(m, '{"i":' + i + '}', 30000), 'tagsMerge')
  }

  /** 更新工作室（整表写回）；setParent=true 时才覆盖父工作室 */
  async updateStudio(id: string, u: StudioUpdate): Promise<boolean> {
    const m: string = 'mutation($i: StudioUpdateInput!) { studioUpdate(input: $i) { id } }'
    let i: string = '{"id":' + JSON.stringify(id)
    i = i + ',"name":' + JSON.stringify(u.name)
    i = i + ',"aliases":' + JSON.stringify(u.aliases)
    i = i + ',"urls":' + JSON.stringify(u.urls)
    i = i + ',"details":' + JSON.stringify(u.details)
    i = i + ',"favorite":' + (u.favorite ? 'true' : 'false')
    i = i + ',"rating100":' + Math.round(u.rating100).toString()
    i = i + ',"organized":' + (u.organized ? 'true' : 'false')
    if (u.setParent) {
      i = i + ',"parent_id":' +
        (u.parentId.length > 0 ? JSON.stringify(u.parentId) : 'null')
    }
    i = i + '}'
    return this.mutationOk(await this.query(m, '{"i":' + i + '}', 20000), 'studioUpdate')
  }

  /** 新建集合（Group），返回 id */
  async createGroup(name: string): Promise<string> {
    const m: string = 'mutation($i: GroupCreateInput!) { groupCreate(input: $i) { id } }'
    const i: string = '{"name":' + JSON.stringify(name) + '}'
    return this.mutationId(await this.query(m, '{"i":' + i + '}', 20000), 'groupCreate')
  }

  /** 更新集合（整表写回）；setStudio / setTags=true 时才覆盖关联 */
  async updateGroup(id: string, u: GroupUpdate): Promise<boolean> {
    const m: string = 'mutation($i: GroupUpdateInput!) { groupUpdate(input: $i) { id } }'
    let i: string = '{"id":' + JSON.stringify(id)
    i = i + ',"name":' + JSON.stringify(u.name)
    i = i + ',"aliases":' + JSON.stringify(u.aliases)
    i = i + ',"date":' + JSON.stringify(u.date)
    i = i + ',"duration":' + Math.round(u.duration).toString()
    i = i + ',"rating100":' + Math.round(u.rating100).toString()
    i = i + ',"director":' + JSON.stringify(u.director)
    i = i + ',"synopsis":' + JSON.stringify(u.synopsis)
    i = i + ',"urls":' + JSON.stringify(u.urls)
    if (u.setStudio) {
      i = i + ',"studio_id":' +
        (u.studioId.length > 0 ? JSON.stringify(u.studioId) : 'null')
    }
    if (u.setTags) {
      i = i + ',"tag_ids":' + JSON.stringify(u.tagIds)
    }
    i = i + '}'
    return this.mutationOk(await this.query(m, '{"i":' + i + '}', 20000), 'groupUpdate')
  }

  /** 删除集合 */
  async destroyGroup(id: string): Promise<boolean> {
    const m: string = 'mutation($i: GroupDestroyInput!) { groupDestroy(input: $i) }'
    const i: string = '{"id":' + JSON.stringify(id) + '}'
    return this.mutationOk(await this.query(m, '{"i":' + i + '}', 20000), 'groupDestroy')
  }

  /** 更新短片的关联（工作室 / 演员 / 标签），空字符串或空数组表示不改 */
  async updateSceneMeta(
    id: string, studioId: string, performerIds: string[], tagIds: string[],
    clearStudio: boolean = false, urls: string[] = []
  ): Promise<boolean> {
    const m: string =
      'mutation UpdateScene($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    const sid: string = StashApi.safeText(studioId)
    let input: string = '{"id":' + JSON.stringify(id)
    if (sid.length > 0) {
      input = input + ',"studio_id":' + JSON.stringify(sid)
    } else if (clearStudio) {
      input = input + ',"studio_id":null'
    }
    if (urls.length > 0) {
      input = input + ',"urls":' + JSON.stringify(urls)
    }
    if (performerIds.length > 0) {
      input = input + ',"performer_ids":' + JSON.stringify(performerIds)
    }
    if (tagIds.length > 0) {
      input = input + ',"tag_ids":' + JSON.stringify(tagIds)
    }
    input = input + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as SceneUpdateEnvelope
    const data: SceneUpdateData | undefined = env.data
    if (data === undefined) {
      return false
    }
    return data.sceneUpdate !== undefined
  }
  /** 设置短片的主文件：primary_file_id 生效后 files[0] 变成该文件 */
  async setPrimaryFile(sceneId: string, fileId: string): Promise<boolean> {
    const m: string =
      'mutation SetPrimaryFile($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id } }'
    const input: string = '{"id":' + JSON.stringify(sceneId) +
      ',"primary_file_id":' + JSON.stringify(fileId) + '}'
    const text: string = await this.query(m, '{"input":' + input + '}', 15000)
    const env = JSON.parse(text) as SceneUpdateEnvelope
    const data: SceneUpdateData | undefined = env.data
    if (data === undefined) {
      return false
    }
    return data.sceneUpdate !== undefined
  }
  /** 已安装的刮削器包 */
  async installedScraperPackages(): Promise<PackageDto[]> {
    const gq: string = 'query { installedPackages(type: Scraper) { package_id name version } }'
    const text: string = await this.query(gq, '{}', 20000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as InstalledPackagesEnvelope
    const data: InstalledPackagesData | undefined = env.data
    if (data === undefined || data.installedPackages === undefined) {
      return []
    }
    return data.installedPackages
  }

  /** 索引里可安装的刮削器包；source 是索引 index.yml 的地址 */
  async availableScraperPackages(source: string): Promise<PackageDto[]> {
    const gq: string = 'query { availablePackages(type: Scraper, source: ' +
      JSON.stringify(source) + ') { package_id name version } }'
    const text: string = await this.query(gq, '{}', 90000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as AvailablePackagesEnvelope
    const data: AvailablePackagesData | undefined = env.data
    if (data === undefined || data.availablePackages === undefined) {
      return []
    }
    return data.availablePackages
  }

  /** 拼 install/uninstall/update 的 packages 参数 */
  private static packageSpecs(ids: string[], source: string): string {
    let out: string = '['
    for (let i = 0; i < ids.length; i++) {
      if (i > 0) {
        out = out + ','
      }
      out = out + '{"id":' + JSON.stringify(ids[i]) +
        ',"sourceURL":' + JSON.stringify(source) + '}'
    }
    return out + ']'
  }

  private async packageMutation(op: string, ids: string[], source: string): Promise<string> {
    if (ids.length === 0) {
      return ''
    }
    const gq: string = 'mutation { ' + op + '(type: Scraper, packages: ' +
      StashApi.packageSpecs(ids, source) + ') }'
    const text: string = await this.query(gq, '{}', 180000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as PackageMutationEnvelope
    const data: PackageMutationData | undefined = env.data
    if (data === undefined) {
      return ''
    }
    let r: string | undefined = undefined
    if (op === 'installPackages') {
      r = data.installPackages
    } else if (op === 'uninstallPackages') {
      r = data.uninstallPackages
    } else if (op === 'updatePackages') {
      r = data.updatePackages
    }
    return (r === undefined || r === null) ? '' : r
  }

  /** 安装刮削器包，返回受影响的刮削器数量（空串＝失败） */
  async installScraperPackages(ids: string[], source: string): Promise<string> {
    return await this.packageMutation('installPackages', ids, source)
  }

  /** 卸载刮削器包 */
  async uninstallScraperPackages(ids: string[], source: string): Promise<string> {
    return await this.packageMutation('uninstallPackages', ids, source)
  }

  /** 更新刮削器包 */
  async updateScraperPackages(ids: string[], source: string): Promise<string> {
    return await this.packageMutation('updatePackages', ids, source)
  }

  /** 标记已看一次，返回最新次数 */
  async markScenePlayed(id: string): Promise<number> {
    const m: string = 'mutation SceneAddPlay($id: ID!) { sceneAddPlay(id: $id) { count } }'
    const text: string = await this.query(m, '{"id":' + JSON.stringify(id) + '}', 15000)
    const env = JSON.parse(text) as SceneAddPlayEnvelope
    const data: SceneAddPlayData | undefined = env.data
    if (data === undefined || data.sceneAddPlay === undefined) {
      return 0
    }
    const c: number | undefined = data.sceneAddPlay.count
    return c === undefined ? 0 : c
  }

  /** 清零已看次数 */
  async resetScenePlayCount(id: string): Promise<boolean> {
    const m: string = 'mutation SceneResetPlayCount($id: ID!) { sceneResetPlayCount(id: $id) }'
    const text: string = await this.query(m, '{"id":' + JSON.stringify(id) + '}', 15000)
    return text.length > 0
  }

  /** 任务队列 */
  async jobQueue(): Promise<JobDto[]> {
    const gq: string = 'query { jobQueue { id status description subTasks } }'
    const text: string = await this.query(gq, '{}', 15000)
    const env = JSON.parse(text) as JobQueueEnvelope
    const data: JobQueueData | undefined = env.data
    if (data === undefined || data.jobQueue === undefined) {
      return []
    }
    return data.jobQueue
  }

  /** 媒体库统计 */
  async stats(): Promise<StatsDto | null> {
    const gq: string =
      'query { stats { scene_count scenes_size scenes_duration image_count images_size' +
      ' gallery_count performer_count studio_count group_count tag_count' +
      ' total_o_count total_play_duration total_play_count scenes_played } }'
    const text: string = await this.query(gq, '{}', 20000)
    const env = JSON.parse(text) as StatsEnvelope
    const data: StatsData | undefined = env.data
    if (data === undefined || data.stats === undefined) {
      return null
    }
    return data.stats
  }

  /** 已安装插件 */
  async plugins(): Promise<PluginDto[]> {
    const gq: string =
      'query { plugins { id name description version enabled } }'
    const text: string = await this.query(gq, '{}', 15000)
    const env = JSON.parse(text) as PluginsEnvelope
    const data: PluginsData | undefined = env.data
    if (data === undefined || data.plugins === undefined) {
      return []
    }
    return data.plugins
  }

  /** 刮削器列表（0.31.1 为 listScrapers(types: [SCENE])，带每个刮削器支持的刮削方式） */
  async scrapers(): Promise<ScraperDto[]> {
    const gq: string =
      'query { listScrapers(types: [SCENE]) { id name scene { supported_scrapes urls } } }'
    const text: string = await this.query(gq, '{}', 15000)
    const env = JSON.parse(text) as ScrapersEnvelope
    const data: ScrapersData | undefined = env.data
    if (data === undefined || data === null || data.listScrapers === undefined || data.listScrapers === null) {
      return []
    }
    return data.listScrapers
  }

  /** 按名称刮削短片（scrapeSingleScene）；站点只支持 URL 时抛 ApiException（带服务端原文） */
  async scrapeSceneByName(name: string, scraperId: string): Promise<ScrapedSceneDto | null> {
    const gq: string =
      'query ScrapeSingle($source: ScraperSourceInput!, $input: ScrapeSingleSceneInput!) {' +
      ' scrapeSingleScene(source: $source, input: $input) {' +
      ' title code director date details urls image studio { name } performers { name } tags { name } } }'
    const source: string = '{"scraper_id":' + JSON.stringify(scraperId) + '}'
    const input: string = '{"query":' + JSON.stringify(name) + '}'
    const vars: string = '{"source":' + source + ',"input":' + input + '}'
    const text: string = await this.query(gq, vars, 60000)
    // 服务端把「这个刮削器不支持按名称刮」这类错误放在 errors 里、data 为 null，
    // 不抛出来就会变成一句看不懂的空值异常 —— 直接透出服务端原文，由页面翻译成人话。
    this.throwIfErrors(text)
    const env = JSON.parse(text) as ScrapeSingleEnvelope
    const data: ScrapeSingleData | null | undefined = env.data
    if (data === undefined || data === null) {
      return null
    }
    const arr: ScrapedSceneDto[] | undefined = data.scrapeSingleScene
    if (arr === undefined || arr === null || arr.length === 0) {
      return null
    }
    return arr[0]
  }

  /**
   * 按 fragment 刮削指定短片（scrapeSingleScene + scene_id）。
   * 与按名称的区别：fragment 不需要刮削器声明 NAME，CosplayDoga 这类只有 FRAGMENT 的站也能用；
   * 而且 Stash 会把这条短片的 title / code / url / 文件名一起交给刮削器，命中率更高。
   */
  async scrapeSceneByFragment(sceneId: string, scraperId: string,
    hint: string = ''): Promise<ScrapedSceneDto | null> {
    const gq: string =
      'query ScrapeSingle($source: ScraperSourceInput!, $input: ScrapeSingleSceneInput!) {' +
      ' scrapeSingleScene(source: $source, input: $input) {' +
      ' title code director date details urls image studio { name } performers { name } tags { name } } }'
    const source: string = '{"scraper_id":' + JSON.stringify(scraperId) + '}'
    let input: string = '{"scene_id":' + JSON.stringify(sceneId)
    const h: string = hint.trim()
    if (h.length > 0) {
      // 用户手填的标题也一并给过去，刮削器可优先用它
      input = input + ',"scene_input":{"title":' + JSON.stringify(h) + '}'
    }
    input = input + '}'
    const vars: string = '{"source":' + source + ',"input":' + input + '}'
    const text: string = await this.query(gq, vars, 60000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as ScrapeSingleEnvelope
    const data: ScrapeSingleData | null | undefined = env.data
    if (data === undefined || data === null) {
      return null
    }
    const arr: ScrapedSceneDto[] | undefined = data.scrapeSingleScene
    if (arr === undefined || arr === null || arr.length === 0) {
      return null
    }
    return arr[0]
  }

  /** 按 URL 刮削短片（scrapeSceneURL，返回单个） */
  async scrapeSceneURL(url: string): Promise<ScrapedSceneDto | null> {
    const gq: string =
      'query ScrapeUrl($url: String!) { scrapeSceneURL(url: $url) {' +
      ' title code director date details urls image studio { name } performers { name } tags { name } } }'
    const vars: string = '{"url":' + JSON.stringify(url) + '}'
    const text: string = await this.query(gq, vars, 60000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as ScrapeSceneEnvelope
    const data: ScrapeSceneData | null | undefined = env.data
    if (data === undefined || data === null) {
      return null
    }
    const one: ScrapedSceneDto | undefined = data.scrapeSceneURL
    if (one === undefined || one === null) {
      return null
    }
    return one
  }

  /** 响应里若有 GraphQL errors，抛 ApiException（带第一条服务端原因） */
  private throwIfErrors(text: string): void {
    const env = JSON.parse(text) as Record<string, Object>
    const errs = env['errors']
    if (errs === undefined || errs === null) {
      return
    }
    const arr = errs as Record<string, Object>[]
    if (arr.length === 0) {
      return
    }
    const mv = arr[0]['message']
    const msg: string = mv === undefined || mv === null ? '刮削失败（服务端未返回原因）' : mv as string
    throw new ApiException(msg)
  }

  /** 批量更新短片（评分 / 已整理）；rating<0 表示不改，organized 传 null 表示不改 */
  async bulkUpdateScenes(ids: string[], organized: boolean | null, rating100: number): Promise<boolean> {
    if (ids.length === 0) {
      return false
    }
    let idArr: string = '['
    for (let i = 0; i < ids.length; i++) {
      if (i > 0) {
        idArr = idArr + ','
      }
      idArr = idArr + JSON.stringify(ids[i])
    }
    idArr = idArr + ']'
    let input: string = '{"ids":' + idArr
    if (organized !== null) {
      input = input + ',"organized":' + (organized ? 'true' : 'false')
    }
    if (rating100 >= 0) {
      input = input + ',"rating100":' + rating100.toString()
    }
    input = input + '}'
    const m: string =
      'mutation BulkSceneUpdate($input: BulkSceneUpdateInput!) { bulkSceneUpdate(input: $input) { id } }'
    const text: string = await this.query(m, '{"input":' + input + '}', 60000)
    return text.length > 0
  }

  /** 批量改标签（mode: ADD / REMOVE / SET） */
  async bulkUpdateSceneTags(ids: string[], tagIds: string[], mode: string): Promise<boolean> {
    if (ids.length === 0 || tagIds.length === 0) {
      return false
    }
    let idArr: string = '['
    for (let i = 0; i < ids.length; i++) {
      if (i > 0) {
        idArr = idArr + ','
      }
      idArr = idArr + JSON.stringify(ids[i])
    }
    idArr = idArr + ']'
    let tagArr: string = '['
    for (let i = 0; i < tagIds.length; i++) {
      if (i > 0) {
        tagArr = tagArr + ','
      }
      tagArr = tagArr + JSON.stringify(tagIds[i])
    }
    tagArr = tagArr + ']'
    const input: string = '{"ids":' + idArr + ',"tag_ids":{"ids":' + tagArr + ',"mode":"' + mode + '"}}'
    const m: string =
      'mutation BulkSceneUpdate($input: BulkSceneUpdateInput!) { bulkSceneUpdate(input: $input) { id } }'
    const text: string = await this.query(m, '{"input":' + input + '}', 60000)
    return text.length > 0
  }

  /** 触发扫描 */
  async metadataScan(paths: string[], rescan: boolean): Promise<boolean> {
    const gq: string = 'mutation { metadataScan(input: {}) }'
    const text: string = await this.query(gq, '{}', 20000)
    return text.length > 0
  }

  /** 生成封面（按短片 ID） */
  async generateCovers(sceneIDs: string[]): Promise<boolean> {
    let ids: string = '['
    for (let i = 0; i < sceneIDs.length; i++) {
      if (i > 0) {
        ids = ids + ','
      }
      ids = ids + JSON.stringify(sceneIDs[i])
    }
    ids = ids + ']'
    const gq: string =
      'mutation($sceneIDs: [ID!]!) { metadataGenerate(input: { covers: true, sceneIDs: $sceneIDs }) }'
    const text: string = await this.query(gq, '{"sceneIDs":' + ids + '}', 30000)
    return text.length > 0
  }

  /* ============ 去重 / 合并 / 识别 / 插件 / 标签集合详情 ============ */

  /** 重复短片分组（distance 越小越严格，0 表示完全相同的指纹） */
  async findDuplicateScenes(distance: number): Promise<SceneDto[][]> {
    let gq: string = 'query Dup($d: Int) { findDuplicateScenes(distance: $d) {'
    gq = gq + ' id title date rating100 play_count o_counter organized paths { screenshot webp }'
    gq = gq + ' studio { id name } performers { id name } tags { id name }'
    gq = gq + ' files { height duration } captions { caption_type } } }'
    const env = JSON.parse(await this.query(gq, '{"d":' + distance.toString() + '}', 60000)) as DupEnvelope
    const data: DupData | undefined = env.data
    if (data === undefined || data.findDuplicateScenes === undefined) {
      return []
    }
    return data.findDuplicateScenes
  }

  /** 删除单个短片 */
  async destroyScene(id: string, deleteFile: boolean): Promise<boolean> {
    const gq: string = 'mutation Del($input: SceneDestroyInput!) { sceneDestroy(input: $input) }'
    const vars: string = '{"input":{"id":' + JSON.stringify(id) +
      ',"delete_file":' + (deleteFile ? 'true' : 'false') + ',"delete_generated":false}}'
    const text: string = await this.query(gq, vars, 20000)
    return text.length > 0
  }

  /** 批量删除短片 */
  async destroyScenes(ids: string[], deleteFile: boolean): Promise<boolean> {
    let arr: string = '['
    for (let i = 0; i < ids.length; i++) {
      if (i > 0) {
        arr = arr + ','
      }
      arr = arr + JSON.stringify(ids[i])
    }
    arr = arr + ']'
    const gq: string = 'mutation Del($input: ScenesDestroyInput!) { scenesDestroy(input: $input) }'
    const vars: string = '{"input":{"ids":' + arr +
      ',"delete_file":' + (deleteFile ? 'true' : 'false') + ',"delete_generated":false}}'
    const text: string = await this.query(gq, vars, 60000)
    return text.length > 0
  }

  /** 合并短片：把 source 并入 destination */
  async mergeScenes(sourceIds: string[], destinationId: string,
    playHistory: boolean, oHistory: boolean, valuesJson: string = ''): Promise<boolean> {
    let arr: string = '['
    for (let i = 0; i < sourceIds.length; i++) {
      if (i > 0) {
        arr = arr + ','
      }
      arr = arr + JSON.stringify(sourceIds[i])
    }
    arr = arr + ']'
    const gq: string =
      'mutation Mg($input: SceneMergeInput!) { sceneMerge(input: $input) { id } }'
    let vars: string = '{"input":{"source":' + arr +
      ',"destination":' + JSON.stringify(destinationId) +
      ',"play_history":' + (playHistory ? 'true' : 'false') +
      ',"o_history":' + (oHistory ? 'true' : 'false')
    if (valuesJson.length > 0) {
      vars = vars + ',"values":' + valuesJson
    }
    vars = vars + '}}'
    const text: string = await this.query(gq, vars, 60000)
    return text.length > 0
  }

  /* ---------- stash-box 识别 ---------- */

  /** 服务端配置的 stash-box 源（StashDB / PMV Stash / ThePornDB…） */
  async stashBoxSources(): Promise<StashBoxSource[]> {
    const out: StashBoxSource[] = []
    const gq: string = 'query { configuration { general { stashBoxes { name endpoint } } } }'
    const text: string = await this.query(gq, '{}', 15000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data'] as Record<string, Object> | undefined
    if (data === undefined || data === null) {
      return out
    }
    const cfg = data['configuration'] as Record<string, Object> | undefined
    if (cfg === undefined || cfg === null) {
      return out
    }
    const general = cfg['general'] as Record<string, Object> | undefined
    if (general === undefined || general === null) {
      return out
    }
    const boxes = general['stashBoxes'] as Object[] | undefined
    if (boxes === undefined || boxes === null) {
      return out
    }
    for (let i = 0; i < boxes.length; i++) {
      const b = boxes[i] as Record<string, Object>
      const nm = b['name']
      const ep = b['endpoint']
      if (ep === undefined || ep === null) {
        continue
      }
      out.push(new StashBoxSource(
        nm === undefined || nm === null ? (ep as string) : nm as string, ep as string))
    }
    return out
  }

  /**
   * 用 stash-box 识别一条短片，返回任务 id（失败返回空串）。
   * 写回策略对齐本地刮削规则：只补空缺，已有内容不覆盖；缺的工作室/演员/标签按需新建。
   */
  async identifyScene(sceneId: string, endpoint: string): Promise<string> {
    const fo: string = '[{"field":"title","strategy":"MERGE"},{"field":"details","strategy":"MERGE"},' +
      '{"field":"date","strategy":"MERGE"},{"field":"url","strategy":"MERGE"},' +
      '{"field":"studio","strategy":"MERGE","createMissing":true},' +
      '{"field":"performers","strategy":"MERGE","createMissing":true},' +
      '{"field":"tags","strategy":"MERGE","createMissing":true}]'
    const gq: string = 'mutation Id($input: IdentifyMetadataInput!) { metadataIdentify(input: $input) }'
    const vars: string = '{"input":{"sources":[{"source":{"stash_box_endpoint":' +
      JSON.stringify(endpoint) + '}}],"options":{"setCoverImage":false,"setOrganized":false,' +
      '"fieldOptions":' + fo + '},"sceneIDs":[' + JSON.stringify(sceneId) + ']}}'
    const text: string = await this.query(gq, vars, 60000)
    this.throwIfErrors(text)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data'] as Record<string, Object> | undefined
    if (data === undefined || data === null) {
      return ''
    }
    const jid = data['metadataIdentify']
    return jid === undefined || jid === null ? '' : jid as string
  }

  /** 任务状态：READY / RUNNING / FINISHED / CANCELLED / FAILED */
  async jobStatus(jobId: string): Promise<string> {
    const gq: string = 'query($id: ID!) { findJob(input: {id: $id}) { id status error } }'
    const vars: string = '{"id":' + JSON.stringify(jobId) + '}'
    const text: string = await this.query(gq, vars, 15000)
    const env = JSON.parse(text) as Record<string, Object>
    const data = env['data'] as Record<string, Object> | undefined
    if (data === undefined || data === null) {
      return ''
    }
    const job = data['findJob'] as Record<string, Object> | undefined
    if (job === undefined || job === null) {
      return ''
    }
    const st = job['status']
    return st === undefined || st === null ? '' : st as string
  }

  /** 单个标签 */
  async findTag(id: string): Promise<TagDto | null> {
    const gq: string =
      'query FindTag($id: ID!) { findTag(id: $id) {' +
      ' id name sort_name description scene_count image_count performer_count studio_count group_count' +
      ' favorite aliases parents { id name } children { id name } } }'
    const env = JSON.parse(await this.query(gq, '{"id":' + JSON.stringify(id) + '}', 15000)) as TagEnvelope
    const data: FindTagData | undefined = env.data
    if (data === undefined || data.findTag === undefined) {
      return null
    }
    return data.findTag
  }

  /** 单个集合 */
  async findGroup(id: string): Promise<GroupDto | null> {
    const gq: string =
      'query FindGroup($id: ID!) { findGroup(id: $id) {' +
      ' id name aliases duration date rating100 director synopsis scene_count urls' +
      ' front_image_path back_image_path studio { id name } tags { id name } } }'
    const env = JSON.parse(await this.query(gq, '{"id":' + JSON.stringify(id) + '}', 15000)) as GroupEnvelope
    const data: FindGroupData | undefined = env.data
    if (data === undefined || data.findGroup === undefined) {
      return null
    }
    return data.findGroup
  }

  /** 单个工作室 */
  async findStudio(id: string): Promise<StudioDto | null> {
    const gq: string =
      'query FindStudio($id: ID!) { findStudio(id: $id) {' +
      ' id name image_path rating100 scene_count details favorite aliases urls organized' +
      ' image_count gallery_count performer_count group_count o_counter tags { id name }' +
      ' parent_studio { id name } child_studios { id name } } }'
    const env = JSON.parse(await this.query(gq, '{"id":' + JSON.stringify(id) + '}', 15000)) as StudioEnvelope
    const data: FindStudioData | undefined = env.data
    if (data === undefined || data.findStudio === undefined) {
      return null
    }
    return data.findStudio
  }
  /** 插件列表 */
  async listPlugins(): Promise<PluginDto[]> {
    const env = JSON.parse(await this.query(
      'query { plugins { id name description version enabled url } }', '{}', 15000)) as PluginsEnvelope
    const data: PluginsData | undefined = env.data
    if (data === undefined || data.plugins === undefined) {
      return []
    }
    return data.plugins
  }

  /** 插件任务列表 */
  async listPluginTasks(): Promise<PluginTaskDto[]> {
    const env = JSON.parse(await this.query(
      'query { pluginTasks { name description plugin { id name } } }', '{}', 15000)) as PluginTaskEnvelope
    const data: PluginTasksData | undefined = env.data
    if (data === undefined || data.pluginTasks === undefined) {
      return []
    }
    return data.pluginTasks
  }

  /** 启用 / 禁用插件 */
  async setPluginEnabled(id: string, enabled: boolean): Promise<boolean> {
    const gq: string = 'mutation En($m: BoolMap!) { setPluginsEnabled(enabledMap: $m) }'
    const vars: string = '{"m":{' + JSON.stringify(id) + ':' + (enabled ? 'true' : 'false') + '}}'
    const text: string = await this.query(gq, vars, 20000)
    return text.length > 0
  }

  /** 运行插件任务 */
  async runPluginTask(pluginId: string, taskName: string): Promise<string> {
    const gq: string =
      'mutation Run($pid: ID!, $t: String!) { runPluginTask(plugin_id: $pid, task_name: $t) }'
    const vars: string = '{"pid":' + JSON.stringify(pluginId) + ',"t":' + JSON.stringify(taskName) + '}'
    return await this.query(gq, vars, 300000)
  }
}

/* ==================== 去重 / 合并 / 详情 / 插件 的响应外壳 ==================== */

interface DupData {
  findDuplicateScenes?: SceneDto[][]
}

interface DupEnvelope {
  data?: DupData
}

interface TagEnvelope {
  data?: FindTagData
}

interface FindTagData {
  findTag?: TagDto | null
}

interface GroupEnvelope {
  data?: FindGroupData
}

interface FindGroupData {
  findGroup?: GroupDto | null
}

interface PluginEnvelope {
  data?: PluginsData
}

interface PluginsWrapData {
  plugins?: PluginDto[]
}

interface PluginTaskEnvelope {
  data?: PluginTasksData
}

interface PluginTasksData {
  pluginTasks?: PluginTaskDto[]
}
interface StudioEnvelope {
  data?: FindStudioData
}

interface FindStudioData {
  findStudio?: StudioDto | null
}
