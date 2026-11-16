/**
 * StashSift — 短片筛选状态（对齐 Stash SceneFilterType）
 *
 * 直接产出 findScenes 的 scene_filter JSON 字符串。
 */

/** 分辨率档位 */
export class ResOption {
  label: string = ''
  enumValue: string = ''

  constructor(label: string, enumValue: string) {
    this.label = label
    this.enumValue = enumValue
  }
}

export class SceneFilterState {
  static instance: SceneFilterState = new SceneFilterState()

  /** 0 = 不限；>0 表示 ≥ 该评分（0-100） */
  rating100: number = 0
  /** 时长（秒），0 = 不限 */
  durationMin: number = 0
  durationMax: number = 0
  /** 分辨率档位 enum，空 = 不限 */
  resolution: string = ''
  /** -1 不限 / 1 已整理 / 0 未整理 */
  organized: number = -1
  /** YYYY-MM-DD */
  dateAfter: string = ''
  dateBefore: string = ''

  studioIds: string[] = []
  performerIds: string[] = []
  tagIds: string[] = []

  /** 生效条件数（用于角标） */
  activeCount(): number {
    let n: number = 0
    if (this.rating100 > 0) {
      n = n + 1
    }
    if (this.durationMin > 0 || this.durationMax > 0) {
      n = n + 1
    }
    if (this.resolution.length > 0) {
      n = n + 1
    }
    if (this.organized >= 0) {
      n = n + 1
    }
    if (this.dateAfter.length > 0 || this.dateBefore.length > 0) {
      n = n + 1
    }
    if (this.studioIds.length > 0) {
      n = n + 1
    }
    if (this.performerIds.length > 0) {
      n = n + 1
    }
    if (this.tagIds.length > 0) {
      n = n + 1
    }
    return n
  }

  isEmpty(): boolean {
    return this.activeCount() === 0
  }

  reset(): void {
    this.rating100 = 0
    this.durationMin = 0
    this.durationMax = 0
    this.resolution = ''
    this.organized = -1
    this.dateAfter = ''
    this.dateBefore = ''
    this.studioIds = []
    this.performerIds = []
    this.tagIds = []
  }

  /** 复制一份（用于面板内编辑后确认再应用） */
  copyFrom(o: SceneFilterState): void {
    this.rating100 = o.rating100
    this.durationMin = o.durationMin
    this.durationMax = o.durationMax
    this.resolution = o.resolution
    this.organized = o.organized
    this.dateAfter = o.dateAfter
    this.dateBefore = o.dateBefore
    this.studioIds = o.studioIds.slice()
    this.performerIds = o.performerIds.slice()
    this.tagIds = o.tagIds.slice()
  }

  private idArray(ids: string[]): string {
    let s: string = '['
    for (let i = 0; i < ids.length; i++) {
      if (i > 0) {
        s = s + ','
      }
      s = s + JSON.stringify(ids[i])
    }
    return s + ']'
  }

  /** 生成 scene_filter JSON */
  toJson(): string {
    const parts: string[] = []

    if (this.rating100 > 0) {
      parts.push('"rating100":{"value":' + this.rating100.toString() + ',"modifier":"GREATER_THAN"}')
    }

    if (this.durationMin > 0 && this.durationMax > 0) {
      parts.push('"duration":{"value":' + this.durationMin.toString() +
        ',"value2":' + this.durationMax.toString() + ',"modifier":"BETWEEN"}')
    } else if (this.durationMin > 0) {
      parts.push('"duration":{"value":' + this.durationMin.toString() + ',"modifier":"GREATER_THAN"}')
    } else if (this.durationMax > 0) {
      parts.push('"duration":{"value":' + this.durationMax.toString() + ',"modifier":"LESS_THAN"}')
    }

    if (this.resolution.length > 0) {
      parts.push('"resolution":{"value":"' + this.resolution + '","modifier":"EQUALS"}')
    }

    if (this.organized >= 0) {
      parts.push('"organized":' + (this.organized === 1 ? 'true' : 'false'))
    }

    if (this.dateAfter.length > 0 && this.dateBefore.length > 0) {
      parts.push('"date":{"value":"' + this.dateAfter + '","value2":"' + this.dateBefore +
        '","modifier":"BETWEEN"}')
    } else if (this.dateAfter.length > 0) {
      parts.push('"date":{"value":"' + this.dateAfter + '","modifier":"GREATER_THAN"}')
    } else if (this.dateBefore.length > 0) {
      parts.push('"date":{"value":"' + this.dateBefore + '","modifier":"LESS_THAN"}')
    }

    if (this.studioIds.length > 0) {
      parts.push('"studios":{"value":' + this.idArray(this.studioIds) +
        ',"modifier":"INCLUDES_ALL","depth":0}')
    }
    if (this.performerIds.length > 0) {
      parts.push('"performers":{"value":' + this.idArray(this.performerIds) +
        ',"modifier":"INCLUDES_ALL"}')
    }
    if (this.tagIds.length > 0) {
      parts.push('"tags":{"value":' + this.idArray(this.tagIds) +
        ',"modifier":"INCLUDES_ALL","depth":0}')
    }

    return '{' + parts.join(',') + '}'
  }

  /** 供 UI 展示的摘要文字 */
  summary(): string {
    if (this.isEmpty()) {
      return '未设置筛选'
    }
    return '已启用 ' + this.activeCount().toString() + ' 项条件'
  }
}

/** 常用日期范围（返回 YYYY-MM-DD） */
export function daysAgoDate(days: number): string {
  const d: Date = new Date()
  d.setDate(d.getDate() - days)
  const y: number = d.getFullYear()
  const m: number = d.getMonth() + 1
  const day: number = d.getDate()
  const ms: string = m < 10 ? '0' + m.toString() : m.toString()
  const ds: string = day < 10 ? '0' + day.toString() : day.toString()
  return y.toString() + '-' + ms + '-' + ds
}
