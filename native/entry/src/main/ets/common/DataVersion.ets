/**
 * StashGo — 数据版本号
 *
 * 任意页面修改了短片/演员等数据后调用 bumpScenes()，
 * 其他列表页监听到版本变化就重新拉取，避免显示旧标题。
 */
export function bumpScenes(): void {
  AppStorage.setOrCreate('sceneVersion', Date.now())
}

/** 列表页用的初始值（读不到时为 0） */
export function scenesVersion(): number {
  const v: number | undefined = AppStorage.get<number>('sceneVersion')
  return v === undefined ? 0 : v
}

/** 装了 / 卸了刮削器包后调用：刮削页监听到变化就重拉刮削器列表 */
export function bumpScrapers(): void {
  AppStorage.setOrCreate('scraperVersion', Date.now())
}

export function scrapersVersion(): number {
  const v: number | undefined = AppStorage.get<number>('scraperVersion')
  return v === undefined ? 0 : v
}
