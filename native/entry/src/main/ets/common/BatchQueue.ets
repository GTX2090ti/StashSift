/**
 * StashGo — 本地后台任务队列
 *
 * 用于批量写入（标签 / 演员 / 工作室 / 集合 / 收藏 / 评分 / 识别）：
 * 逐条串行提交，不阻塞页面，进度通过 AppStorage 广播给顶栏与任务页。
 */
import { StashApi } from '../api/StashApi'
import { AppSettings } from '../settings/AppSettings'

export class BatchJob {
  id: string = ''
  title: string = ''
  total: number = 0
  done: number = 0
  failed: number = 0
  running: boolean = false
  message: string = ''
  startedAt: number = 0

  constructor(id: string, title: string, total: number) {
    this.id = id
    this.title = title
    this.total = total
    this.startedAt = Date.now()
    this.running = true
  }

  percent(): number {
    if (this.total <= 0) {
      return 0
    }
    return Math.round((this.done + this.failed) * 100 / this.total)
  }
}

export class BatchQueue {
  static instance: BatchQueue = new BatchQueue()

  private jobs: BatchJob[] = []
  private seq: number = 0

  /** 当前进行中的任务数 */
  activeCount(): number {
    let n: number = 0
    for (let i = 0; i < this.jobs.length; i++) {
      if (this.jobs[i].running) {
        n = n + 1
      }
    }
    return n
  }

  list(): BatchJob[] {
    return this.jobs
  }

  private publish(): void {
    AppStorage.setOrCreate('batchActive', this.activeCount())
    AppStorage.setOrCreate('batchVersion', Date.now())
  }

  private api(): StashApi {
    return new StashApi(AppSettings.instance.baseUrl, AppSettings.instance.apiKey)
  }

  /**
   * 启动一个批量任务。
   * apply 对单条执行，返回 true 表示成功。
   */
  start(title: string, ids: string[], apply: (id: string) => Promise<boolean>): BatchJob {
    this.seq = this.seq + 1
    const job = new BatchJob('b' + this.seq.toString() + '-' + Date.now().toString(), title, ids.length)
    this.jobs.unshift(job)
    this.publish()
    this.run(job, ids, apply)
    return job
  }

  private async run(job: BatchJob, ids: string[],
    apply: (id: string) => Promise<boolean>): Promise<void> {
    for (let i = 0; i < ids.length; i++) {
      if (!job.running) {
        break
      }
      try {
        const ok: boolean = await apply(ids[i])
        if (ok) {
          job.done = job.done + 1
        } else {
          job.failed = job.failed + 1
        }
      } catch (e) {
        job.failed = job.failed + 1
        if (job.message.length === 0) {
          job.message = (e as Error).message
        }
      }
      this.publish()
    }
    job.running = false
    if (job.failed === 0) {
      job.message = '全部完成'
    }
    this.publish()
  }

  /** 取消（剩下的不再执行） */
  cancel(id: string): void {
    for (let i = 0; i < this.jobs.length; i++) {
      if (this.jobs[i].id === id) {
        this.jobs[i].running = false
        this.jobs[i].message = '已取消'
      }
    }
    this.publish()
  }

  clearFinished(): void {
    const keep: BatchJob[] = []
    for (let i = 0; i < this.jobs.length; i++) {
      if (this.jobs[i].running) {
        keep.push(this.jobs[i])
      }
    }
    this.jobs = keep
    this.publish()
  }
}
