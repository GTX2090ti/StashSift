/**
 * StashGo — 全局错误日志采集
 *
 * 用 errorManager（@kit.AbilityKit）监听 JS 未捕获异常，写入 hilog，
 * 方便在真机上定位闪退根因。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { errorManager } from '@kit.AbilityKit'

const TAG: string = 'StashGo-Error'

/** 开启全局错误监听（进程内只需一次） */
export function installErrorLogger(): void {
  try {
    const observer: errorManager.ErrorObserver = {
      onUnhandledException: (errMsg: string) => {
        hilog.error(0x0003, TAG, '[UnhandledException] %{public}s', errMsg)
      },
      onException: (err: Error) => {
        hilog.error(0x0003, TAG, '[Exception] %{public}s', err.message)
      }
    }
    errorManager.on('error', observer)
    hilog.info(0x0003, TAG, 'error observer installed')
  } catch (e) {
    hilog.warn(0x0003, TAG, 'install failed: %{public}s', (e as Error).message)
  }
}