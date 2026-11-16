/**
 * StashGo — 列表页排序选项（与短片列表同一套交互：芯片 + bindMenu）
 */
import { GlassTheme } from './GlassUtils'

export class SortOption {
  label: string = ''
  sort: string = ''
  dir: string = ''

  constructor(label: string, sort: string, dir: string) {
    this.label = label
    this.sort = sort
    this.dir = dir
  }
}

/** 工作室 */
export const STUDIO_SORTS: SortOption[] = [
  new SortOption('名称', 'name', 'ASC'),
  new SortOption('添加时间', 'created_at', 'DESC'),
  new SortOption('短片数', 'scenes_count', 'DESC'),
  new SortOption('评分', 'rating', 'DESC')
]

/** 标签 */
export const TAG_SORTS: SortOption[] = [
  new SortOption('名称', 'name', 'ASC'),
  new SortOption('添加时间', 'created_at', 'DESC'),
  new SortOption('短片数', 'scenes_count', 'DESC')
]

/** 集合 */
export const GROUP_SORTS: SortOption[] = [
  new SortOption('名称', 'name', 'ASC'),
  new SortOption('日期', 'date', 'DESC'),
  new SortOption('添加时间', 'created_at', 'DESC')
]

/** 演员 */
export const PERFORMER_SORTS: SortOption[] = [
  new SortOption('名称', 'name', 'ASC'),
  new SortOption('添加时间', 'created_at', 'DESC'),
  new SortOption('短片数', 'scenes_count', 'DESC'),
  new SortOption('评分', 'rating', 'DESC')
]

/** 收藏短片 */
export const SCENE_FAV_SORTS: SortOption[] = [
  new SortOption('收藏时间', 'favorite_at', 'DESC'),
  new SortOption('最新', 'date', 'DESC'),
  new SortOption('评分', 'rating', 'DESC'),
  new SortOption('标题', 'title', 'ASC'),
  new SortOption('时长', 'duration', 'DESC')
]

/** 生成排序菜单 */
export function buildSortMenu(
  opts: SortOption[], current: number, theme: GlassTheme,
  onPick: (idx: number) => void): MenuElement[] {
  const items: MenuElement[] = []
  for (let i = 0; i < opts.length; i++) {
    const idx: number = i
    items.push({
      value: opts[i].label,
      action: () => {
        onPick(idx)
      }
    })
  }
  return items
}
