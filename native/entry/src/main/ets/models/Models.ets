/**
 * StashGo — 数据模型（ArkTS 原生，显式 DTO）
 */

export interface TagDto {
  id?: string
  name?: string
  sort_name?: string
  description?: string
  scene_count?: number
  image_count?: number
  performer_count?: number
  studio_count?: number
  group_count?: number
  favorite?: boolean
  aliases?: string[]
  parents?: TagDto[]
  children?: TagDto[]
}

/** 集合引用（短片所属集合用） */
export interface GroupRefDto {
  id?: string
  name?: string
}

/** 短片-集合关联（Stash 的 SceneGroup，真实集合在 group 字段里） */
export interface SceneGroupDto {
  group?: GroupRefDto
  scene_index?: number
}

/** 集合（Stash Group） */
export interface GroupDto {
  id?: string
  name?: string
  aliases?: string
  duration?: number
  date?: string
  rating100?: number
  director?: string
  synopsis?: string
  scene_count?: number
  front_image_path?: string
  back_image_path?: string
  urls?: string[]
  studio?: StudioRefDto
  tags?: TagDto[]
}

/** 插件任务 */
export interface PluginTaskDto {
  name?: string
  description?: string
  plugin?: PluginDto
}

export interface PerformerRefDto {
  id?: string
  name?: string
  birthdate?: string
}

export interface StudioRefDto {
  id?: string
  name?: string
}

export interface SceneFileDto {
  id?: string
  height?: number
  duration?: number
  size?: number
  path?: string
  basename?: string
  mod_time?: string
}

/** 刮削器 / 插件包（installedPackages、availablePackages 返回的形状） */
export interface PackageDto {
  package_id?: string
  name?: string
  version?: string
}

export interface PerformerDto {
  id?: string
  name?: string
  image_path?: string
  gender?: string
  birthdate?: string
  country?: string
  ethnicity?: string
  height_cm?: number
  details?: string
  rating100?: number
  favorite?: boolean
  scene_count?: number
  tags?: TagDto[]
  disambiguation?: string
  alias_list?: string[]
  urls?: string[]
  eye_color?: string
  hair_color?: string
  measurements?: string
  fake_tits?: string
  tattoos?: string
  piercings?: string
  career_start?: string
  career_end?: string
  weight?: number
  death_date?: string
  image_count?: number
  gallery_count?: number
  group_count?: number
  o_counter?: number
}

export interface StudioDto {
  id?: string
  name?: string
  image_path?: string
  rating100?: number
  scene_count?: number
  details?: string
  favorite?: boolean
  aliases?: string[]
  urls?: string[]
  organized?: boolean
  image_count?: number
  gallery_count?: number
  performer_count?: number
  group_count?: number
  o_counter?: number
  parent_studio?: StudioRefDto
  child_studios?: StudioRefDto[]
  tags?: TagDto[]
}

export interface ScenePathsDto {
  screenshot?: string
  webp?: string
}

export interface SceneCaptionDto {
  caption_type?: string
}

export interface SceneDto {
  id?: string
  title?: string
  urls?: string[]
  details?: string
  code?: string
  director?: string
  date?: string
  rating100?: number
  o_counter?: number
  play_count?: number
  organized?: boolean
  paths?: ScenePathsDto
  studio?: StudioRefDto
  performers?: PerformerRefDto[]
  tags?: TagDto[]
  groups?: SceneGroupDto[]
  files?: SceneFileDto[]
  captions?: SceneCaptionDto[]
  /** ISO 时间：最近一次被修改（收藏/打标签也会更新它） */
  updated_at?: string
  /** 自定义字段：收藏时间记在 favorite_at（Stash 没给标签打时间，只能自己存） */
  custom_fields?: Record<string, string>
}

export interface ProfileDto {
  name?: string
  lanUrl?: string
  wanUrl?: string
  apiKey?: string
}

export class Tag {
  id: string = ''
  name: string = ''
  sort_name: string = ''
  description: string = ''
  scene_count: number = 0
  favorite: boolean = false
  aliases: string[] = []

  constructor(id: string, name: string) {
    this.id = id
    this.name = name
  }

  static fromDto(j: TagDto): Tag {
    const t = new Tag((j.id === undefined || j.id === null) ? '' : j.id, (j.name === undefined || j.name === null) ? '' : j.name)
    t.sort_name = (j.sort_name === undefined || j.sort_name === null) ? '' : j.sort_name
    t.description = (j.description === undefined || j.description === null) ? '' : j.description
    t.scene_count = (j.scene_count === undefined || j.scene_count === null) ? 0 : j.scene_count
    t.favorite = (j.favorite === undefined || j.favorite === null) ? false : j.favorite
    t.aliases = (j.aliases === undefined || j.aliases === null) ? [] : j.aliases
    return t
  }
}

export class Performer {
  id: string = ''
  name: string = ''
  image_path: string = ''
  gender: string = ''
  birthdate: string = ''
  country: string = ''
  ethnicity: string = ''
  height_cm: number = 0
  details: string = ''
  rating100: number = 0
  favorite: boolean = false
  scene_count: number = 0
  tags: Tag[] = []
  disambiguation: string = ''
  aliases: string[] = []
  urls: string[] = []
  eye_color: string = ''
  hair_color: string = ''
  measurements: string = ''
  fake_tits: string = ''
  tattoos: string = ''
  piercings: string = ''
  career_start: string = ''
  career_end: string = ''
  weight: number = 0
  death_date: string = ''
  image_count: number = 0
  gallery_count: number = 0
  group_count: number = 0
  o_counter: number = 0

  constructor(id: string, name: string) {
    this.id = id
    this.name = name
  }

  static fromDto(j: PerformerDto): Performer {
    const p = new Performer((j.id === undefined || j.id === null) ? '' : j.id, (j.name === undefined || j.name === null) ? '' : j.name)
    p.image_path = (j.image_path === undefined || j.image_path === null) ? '' : j.image_path
    p.gender = (j.gender === undefined || j.gender === null) ? '' : j.gender
    p.birthdate = (j.birthdate === undefined || j.birthdate === null) ? '' : j.birthdate
    p.country = (j.country === undefined || j.country === null) ? '' : j.country
    p.ethnicity = (j.ethnicity === undefined || j.ethnicity === null) ? '' : j.ethnicity
    p.height_cm = (j.height_cm === undefined || j.height_cm === null) ? 0 : j.height_cm
    p.details = (j.details === undefined || j.details === null) ? '' : j.details
    p.rating100 = (j.rating100 === undefined || j.rating100 === null) ? 0 : j.rating100
    p.favorite = (j.favorite === undefined || j.favorite === null) ? false : j.favorite
    p.scene_count = (j.scene_count === undefined || j.scene_count === null) ? 0 : j.scene_count
    p.disambiguation = (j.disambiguation === undefined || j.disambiguation === null) ? '' : j.disambiguation
    p.aliases = (j.alias_list === undefined || j.alias_list === null) ? [] : j.alias_list
    p.urls = (j.urls === undefined || j.urls === null) ? [] : j.urls
    p.eye_color = (j.eye_color === undefined || j.eye_color === null) ? '' : j.eye_color
    p.hair_color = (j.hair_color === undefined || j.hair_color === null) ? '' : j.hair_color
    p.measurements = (j.measurements === undefined || j.measurements === null) ? '' : j.measurements
    p.fake_tits = (j.fake_tits === undefined || j.fake_tits === null) ? '' : j.fake_tits
    p.tattoos = (j.tattoos === undefined || j.tattoos === null) ? '' : j.tattoos
    p.piercings = (j.piercings === undefined || j.piercings === null) ? '' : j.piercings
    p.career_start = (j.career_start === undefined || j.career_start === null) ? '' : j.career_start
    p.career_end = (j.career_end === undefined || j.career_end === null) ? '' : j.career_end
    p.weight = (j.weight === undefined || j.weight === null) ? 0 : j.weight
    p.death_date = (j.death_date === undefined || j.death_date === null) ? '' : j.death_date
    p.image_count = (j.image_count === undefined || j.image_count === null) ? 0 : j.image_count
    p.gallery_count = (j.gallery_count === undefined || j.gallery_count === null) ? 0 : j.gallery_count
    p.group_count = (j.group_count === undefined || j.group_count === null) ? 0 : j.group_count
    p.o_counter = (j.o_counter === undefined || j.o_counter === null) ? 0 : j.o_counter
    const tags: TagDto[] | null = j.tags === undefined ? null : j.tags
    const list: Tag[] = []
    if (tags !== null && tags !== undefined) {
      for (let i = 0; i < tags.length; i++) {
        if (tags[i] !== null) {
          list.push(Tag.fromDto(tags[i]))
        }
      }
    }
    p.tags = list
    return p
  }

  static listFromDto(arr: PerformerDto[]): Performer[] {
    const out: Performer[] = []
    for (let i = 0; i < arr.length; i++) {
      out.push(Performer.fromDto(arr[i]))
    }
    return out
  }
}

export class Studio {
  id: string = ''
  name: string = ''
  image_path: string = ''
  rating100: number = 0
  scene_count: number = 0
  details: string = ''
  favorite: boolean = false
  aliases: string[] = []
  urls: string[] = []
  organized: boolean = false
  image_count: number = 0
  gallery_count: number = 0
  performer_count: number = 0
  group_count: number = 0
  o_counter: number = 0
  tags: Tag[] = []
  parentName: string = ''
  childNames: string[] = []

  constructor(id: string, name: string) {
    this.id = id
    this.name = name
  }

  static fromDto(j: StudioDto): Studio {
    const s = new Studio((j.id === undefined || j.id === null) ? '' : j.id, (j.name === undefined || j.name === null) ? '' : j.name)
    s.image_path = (j.image_path === undefined || j.image_path === null) ? '' : j.image_path
    s.rating100 = (j.rating100 === undefined || j.rating100 === null) ? 0 : j.rating100
    s.scene_count = (j.scene_count === undefined || j.scene_count === null) ? 0 : j.scene_count
    s.aliases = (j.aliases === undefined || j.aliases === null) ? [] : j.aliases
    s.urls = (j.urls === undefined || j.urls === null) ? [] : j.urls
    s.organized = (j.organized === undefined || j.organized === null) ? false : j.organized
    s.image_count = (j.image_count === undefined || j.image_count === null) ? 0 : j.image_count
    s.gallery_count = (j.gallery_count === undefined || j.gallery_count === null) ? 0 : j.gallery_count
    s.performer_count = (j.performer_count === undefined || j.performer_count === null) ? 0 : j.performer_count
    s.group_count = (j.group_count === undefined || j.group_count === null) ? 0 : j.group_count
    s.o_counter = (j.o_counter === undefined || j.o_counter === null) ? 0 : j.o_counter
    const stags: TagDto[] | null = j.tags === undefined ? null : j.tags
    const stl: Tag[] = []
    if (stags !== null && stags !== undefined) {
      for (let i = 0; i < stags.length; i++) {
        if (stags[i] !== null) {
          stl.push(Tag.fromDto(stags[i]))
        }
      }
    }
    s.tags = stl
    const pst: StudioRefDto | null = j.parent_studio === undefined ? null : j.parent_studio
    if (pst !== null && pst !== undefined && pst.name !== undefined && pst.name !== null) {
      s.parentName = pst.name
    }
    const ch: StudioRefDto[] | null = j.child_studios === undefined ? null : j.child_studios
    const chn: string[] = []
    if (ch !== null && ch !== undefined) {
      for (let i = 0; i < ch.length; i++) {
        const c0: StudioRefDto = ch[i]
        if (c0 !== null && c0.name !== undefined) {
          const nm: string = c0.name
          chn.push(nm)
        }
      }
    }
    s.childNames = chn
    s.details = (j.details === undefined || j.details === null) ? '' : j.details
    return s
  }

  static listFromDto(arr: StudioDto[]): Studio[] {
    const out: Studio[] = []
    for (let i = 0; i < arr.length; i++) {
      out.push(Studio.fromDto(arr[i]))
    }
    return out
  }
}

export class SceneFile {
  id: string = ''
  height: number = 0
  duration: number = 0
  size: number = 0
  path: string = ''
  basename: string = ''
  mod_time: string = ''

  static fromDto(j: SceneFileDto): SceneFile {
    const f = new SceneFile()
    f.id = (j.id === undefined || j.id === null) ? '' : j.id
    f.height = (j.height === undefined || j.height === null) ? 0 : j.height
    f.duration = (j.duration === undefined || j.duration === null) ? 0 : j.duration
    f.size = (j.size === undefined || j.size === null) ? 0 : j.size
    f.path = (j.path === undefined || j.path === null) ? '' : j.path
    f.basename = (j.basename === undefined || j.basename === null) ? '' : j.basename
    f.mod_time = (j.mod_time === undefined || j.mod_time === null) ? '' : j.mod_time
    return f
  }
}

export class Scene {
  id: string = ''
  title: string = ''
  date: string = ''
  poster: string = ''
  duration: number = 0
  rating100: number = 0
  o_counter: number = 0
  play_count: number = 0
  organized: boolean = false
  favorite: boolean = false
  /** 收藏时间（custom_fields.favorite_at）；老收藏没有这个值，用 updatedAt 兜底 */
  favoriteAt: string = ''
  /** 服务端 updated_at（打标签也会刷新它） */
  updatedAt: string = ''
  performerNames: string[] = []
  urls: string[] = []
  details: string = ''
  code: string = ''
  director: string = ''
  performerRefs: ScenePerformer[] = []
  filePath: string = ''
  fileSize: number = 0
  fileModTime: string = ''
  studioNames: string[] = []
  studioId: string = ''
  tagNames: string[] = []
  tagIds: string[] = []
  groupNames: string[] = []
  groupIds: string[] = []
  hasCaption: boolean = false
  files: SceneFile[] = []

  constructor(id: string, title: string) {
    this.id = id
    this.title = title
  }

  static fromDto(j: SceneDto): Scene {
    const s = new Scene((j.id === undefined || j.id === null) ? '' : j.id, (j.title === undefined || j.title === null) ? '' : j.title)
    s.date = (j.date === undefined || j.date === null) ? '' : j.date
    const pth: ScenePathsDto | undefined = j.paths
    s.poster = (pth === undefined || pth === null || pth.screenshot === undefined || pth.screenshot === null) ? '' : pth.screenshot
    s.duration = 0
    s.rating100 = (j.rating100 === undefined || j.rating100 === null) ? 0 : j.rating100
    s.o_counter = (j.o_counter === undefined || j.o_counter === null) ? 0 : j.o_counter
    s.play_count = (j.play_count === undefined || j.play_count === null) ? 0 : j.play_count
    s.organized = (j.organized === undefined || j.organized === null) ? false : j.organized
    s.updatedAt = (j.updated_at === undefined || j.updated_at === null) ? '' : j.updated_at
    const cf: Record<string, string> | undefined = j.custom_fields
    if (cf !== undefined && cf !== null) {
      const fa = cf['favorite_at']
      if (fa !== undefined && fa !== null) {
        s.favoriteAt = fa
      }
    }

    const ps: PerformerRefDto[] | null = j.performers === undefined ? null : j.performers
    const pn: string[] = []
    if (ps !== null && ps !== undefined) {
      for (let i = 0; i < ps.length; i++) {
        const pr: PerformerRefDto = ps[i]
        if (pr !== null && pr.name !== undefined) {
          pn.push(pr.name)
        }
      }
    }
    s.performerNames = pn
    const prefs: ScenePerformer[] = []
    if (ps !== null && ps !== undefined) {
      for (let i = 0; i < ps.length; i++) {
        const pr2: PerformerRefDto = ps[i]
        if (pr2 !== null && pr2.name !== undefined) {
          prefs.push(new ScenePerformer(
            (pr2.id === undefined || pr2.id === null) ? '' : pr2.id,
            pr2.name,
            (pr2.birthdate === undefined || pr2.birthdate === null) ? '' : pr2.birthdate))
        }
      }
    }
    s.performerRefs = prefs
    s.urls = (j.urls === undefined || j.urls === null) ? [] : j.urls
    s.details = (j.details === undefined || j.details === null) ? '' : j.details
    s.code = (j.code === undefined || j.code === null) ? '' : j.code
    s.director = (j.director === undefined || j.director === null) ? '' : j.director

    const st: StudioRefDto | null = j.studio === undefined ? null : j.studio
    if (st !== null && st !== undefined && st.name !== undefined) {
      s.studioNames = [st.name]
      if (st.id !== undefined && st.id !== null) {
        s.studioId = st.id
      }
    }

    const ts: TagDto[] | null = j.tags === undefined ? null : j.tags
    const tn: string[] = []
    const ti: string[] = []
    if (ts !== null && ts !== undefined) {
      for (let i = 0; i < ts.length; i++) {
        const tr: TagDto = ts[i]
        if (tr !== null && tr.name !== undefined) {
          tn.push(tr.name)
          ti.push((tr.id === undefined || tr.id === null) ? '' : tr.id)
        }
      }
    }
    s.tagNames = tn
    s.tagIds = ti
    const gs: SceneGroupDto[] | null = j.groups === undefined ? null : j.groups
    const gn: string[] = []
    const gi: string[] = []
    if (gs !== null && gs !== undefined) {
      for (let i = 0; i < gs.length; i++) {
        const sg: SceneGroupDto = gs[i]
        if (sg !== null && sg.group !== undefined && sg.group !== null) {
          const g0: GroupRefDto = sg.group
          if (g0.name !== undefined && g0.name !== null) {
            gn.push(g0.name)
            gi.push((g0.id === undefined || g0.id === null) ? '' : g0.id)
          }
        }
      }
    }
    s.groupNames = gn
    s.groupIds = gi
    const cps: SceneCaptionDto[] | null = j.captions === undefined ? null : j.captions
    if (cps !== null && cps !== undefined) {
      s.hasCaption = cps.length > 0
    }

    const fs: SceneFileDto[] | null = j.files === undefined ? null : j.files
    const fl: SceneFile[] = []
    if (fs !== null && fs !== undefined) {
      for (let i = 0; i < fs.length; i++) {
        if (fs[i] !== null) {
          fl.push(SceneFile.fromDto(fs[i]))
        }
      }
    }
    s.files = fl
    if (fl.length > 0) {
      s.duration = fl[0].duration
      s.filePath = fl[0].path
      s.fileSize = fl[0].size
      s.fileModTime = fl[0].mod_time
    }
    return s
  }

  static listFromDto(arr: SceneDto[]): Scene[] {
    const out: Scene[] = []
    for (let i = 0; i < arr.length; i++) {
      out.push(Scene.fromDto(arr[i]))
    }
    return out
  }
}

export class Profile {
  name: string = ''
  lanUrl: string = ''
  wanUrl: string = ''
  apiKey: string = ''

  constructor(name: string, lanUrl: string, wanUrl: string, apiKey: string) {
    this.name = name
    this.lanUrl = lanUrl
    this.wanUrl = wanUrl
    this.apiKey = apiKey
  }

  static fromDto(j: ProfileDto): Profile {
    return new Profile(
      (j.name === undefined || j.name === null) ? '' : j.name,
      (j.lanUrl === undefined || j.lanUrl === null) ? '' : j.lanUrl,
      (j.wanUrl === undefined || j.wanUrl === null) ? '' : j.wanUrl,
      (j.apiKey === undefined || j.apiKey === null) ? '' : j.apiKey
    )
  }
}

/** 服务端配置的 stash-box 源（StashDB / PMV Stash / ThePornDB…） */
export class StashBoxSource {
  name: string = ''
  endpoint: string = ''

  constructor(name: string, endpoint: string) {
    this.name = name
    this.endpoint = endpoint
  }
}

/** 任务队列项 */
export interface JobDto {
  id?: string
  status?: string
  description?: string
  subTasks?: string[]
}

/** 统计结果 */
export interface StatsDto {
  scene_count?: number
  scenes_size?: number
  scenes_duration?: number
  image_count?: number
  images_size?: number
  gallery_count?: number
  performer_count?: number
  studio_count?: number
  group_count?: number
  tag_count?: number
  total_o_count?: number
  total_play_duration?: number
  total_play_count?: number
  scenes_played?: number
}

/** 刮削器对某一实体（短片）的支持能力（对应 Stash 的 ScraperSpec） */
export interface ScraperSpecDto {
  /** NAME / URL / FRAGMENT —— 该刮削器支持的刮削方式 */
  supported_scrapes?: string[]
  /** 该刮削器认得的 URL 前缀，仅部分站点有 */
  urls?: string[]
}

/** 刮削器 */
export interface ScraperDto {
  id?: string
  name?: string
  scene?: ScraperSpecDto
}

/** 刮削结果（短片） */
export interface ScrapedStudioRef {
  name?: string
}

export interface ScrapedPerformerRef {
  name?: string
}

export interface ScrapedTagRef {
  name?: string
}

export interface ScrapedSceneDto {
  title?: string
  code?: string
  director?: string
  date?: string
  details?: string
  urls?: string[]
  image?: string
  studio?: ScrapedStudioRef
  performers?: ScrapedPerformerRef[]
  tags?: ScrapedTagRef[]
}

/** 插件 */
export interface PluginDto {
  id?: string
  name?: string
  description?: string
  version?: string
  enabled?: boolean
}

/** 短片里的演员引用（带生日，用于算年龄） */
export class ScenePerformer {
  id: string = ''
  name: string = ''
  birthdate: string = ''

  constructor(id: string, name: string, birthdate: string) {
    this.id = id
    this.name = name
    this.birthdate = birthdate
  }
}
/** 可扫描的文件夹（由短片路径统计得出） */
export class FolderOption {
  path: string = ''
  count: number = 0

  constructor(path: string, count: number) {
    this.path = path
    this.count = count
  }
}
/** 短片所属集合（批量用） */
export class SceneGroupRow {
  sceneId: string = ''
  groupIds: string[] = []

  constructor(sceneId: string, groupIds: string[]) {
    this.sceneId = sceneId
    this.groupIds = groupIds
  }
}

/* ==================== 编辑表单载荷（整表写回） ==================== */

/** 演员编辑载荷：空字符串会清空该字段；gender 空串表示不改 */
export class PerformerUpdate {
  name: string = ''
  disambiguation: string = ''
  aliases: string[] = []
  urls: string[] = []
  gender: string = ''
  birthdate: string = ''
  death_date: string = ''
  country: string = ''
  ethnicity: string = ''
  hair_color: string = ''
  eye_color: string = ''
  height_cm: number = 0
  weight: number = 0
  measurements: string = ''
  fake_tits: string = ''
  tattoos: string = ''
  piercings: string = ''
  career_start: string = ''
  career_end: string = ''
  details: string = ''

  static from(p: Performer): PerformerUpdate {
    const u = new PerformerUpdate()
    u.name = p.name
    u.disambiguation = p.disambiguation
    u.aliases = p.aliases.slice()
    u.urls = p.urls.slice()
    u.gender = p.gender
    u.birthdate = p.birthdate
    u.death_date = p.death_date
    u.country = p.country
    u.ethnicity = p.ethnicity
    u.hair_color = p.hair_color
    u.eye_color = p.eye_color
    u.height_cm = p.height_cm
    u.weight = p.weight
    u.measurements = p.measurements
    u.fake_tits = p.fake_tits
    u.tattoos = p.tattoos
    u.piercings = p.piercings
    u.career_start = p.career_start
    u.career_end = p.career_end
    u.details = p.details
    return u
  }
}

/** 标签编辑载荷：setParents=true 时才写父标签 */
export class TagUpdate {
  name: string = ''
  sort_name: string = ''
  description: string = ''
  aliases: string[] = []
  favorite: boolean = false
  parentIds: string[] = []
  setParents: boolean = false

  static from(t: Tag): TagUpdate {
    const u = new TagUpdate()
    u.name = t.name
    return u
  }
}

/** 工作室编辑载荷：setParent=true 时才写父工作室（parentId 空串=清空父级） */
export class StudioUpdate {
  name: string = ''
  aliases: string[] = []
  urls: string[] = []
  details: string = ''
  favorite: boolean = false
  rating100: number = 0
  organized: boolean = false
  parentId: string = ''
  setParent: boolean = false

  static from(s: Studio): StudioUpdate {
    const u = new StudioUpdate()
    u.name = s.name
    u.aliases = s.aliases.slice()
    u.urls = s.urls.slice()
    u.details = s.details
    u.favorite = s.favorite
    u.rating100 = s.rating100
    u.organized = s.organized
    return u
  }
}

/** 集合编辑载荷：setStudio / setTags=true 时才写关联 */
export class GroupUpdate {
  name: string = ''
  aliases: string = ''
  date: string = ''
  duration: number = 0
  rating100: number = 0
  director: string = ''
  synopsis: string = ''
  urls: string[] = []
  studioId: string = ''
  setStudio: boolean = false
  tagIds: string[] = []
  setTags: boolean = false
}