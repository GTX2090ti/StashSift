/**
 * StashSift — 筛选 / 选择器共用的选项缓存
 *
 * 只取 id + name（精简查询），并在内存里缓存，
 * 避免每次打开筛选都拉带 details / 嵌套 tags 的重查询。
 */
import { StashApi } from '../api/StashApi'
import { StudioDto } from '../models/Models'

/** 选项条目 */
export class PickItem {
  id: string = ''
  name: string = ''

  constructor(id: string, name: string) {
    this.id = id
    this.name = name
  }
}

/** 全局缓存 */
export class PickCache {
  static studios: PickItem[] = []
  static performers: PickItem[] = []
  static tags: PickItem[] = []

  static clear(): void {
    PickCache.studios = []
    PickCache.performers = []
    PickCache.tags = []
  }

  static put(mode: string, list: PickItem[]): void {
    if (mode === 'studio') {
      PickCache.studios = list
    } else if (mode === 'performer') {
      PickCache.performers = list
    } else if (mode === 'tag') {
      PickCache.tags = list
    }
  }

  static get(mode: string): PickItem[] {
    if (mode === 'studio') {
      return PickCache.studios
    }
    if (mode === 'performer') {
      return PickCache.performers
    }
    return PickCache.tags
  }
}

/** 加载（优先缓存）某一类选项 */
export async function loadOptions(api: StashApi, mode: string): Promise<PickItem[]> {
  const cached: PickItem[] = PickCache.get(mode)
  if (cached.length > 0) {
    return cached
  }
  let raw: StudioDto[] = []
  if (mode === 'studio') {
    raw = await api.studiosLite()
  } else if (mode === 'performer') {
    raw = await api.performersLite()
  } else {
    raw = await api.tagsLite()
  }
  const out: PickItem[] = []
  for (let i = 0; i < raw.length; i++) {
    const d = raw[i]
    const nm: string = d.name === undefined ? '' : d.name
    const rid: string = d.id === undefined ? '' : d.id
    if (rid.length > 0) {
      out.push(new PickItem(rid, nm))
    }
  }
  PickCache.put(mode, out)
  return out
}
