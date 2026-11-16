/**
 * StashGo — 内外网自动切换
 *
 * 规则：优先用内网地址；内网探测失败时自动切到外网；网络变化时重新判断。
 * 探测方式：向 <url>/graphql 发一个极轻的 version 查询。
 */
import { http } from '@kit.NetworkKit'
import { connection } from '@kit.NetworkKit'
import { AppSettings, AddrSlot } from '../settings/AppSettings'

export class NetSwitch {
  private static watching: boolean = false
  private static lastPick: number = 0

  /** 探测某个地址是否可用 */
  static async probe(base: string, apiKey: string, timeoutMs: number = 3000): Promise<boolean> {
    const url: string = base.length > 0 ? base : ''
    if (url.length === 0) {
      return false
    }
    const client = http.createHttp()
    try {
      const body: string = '{"query":"query { version { version } }"}'
      const resp = await client.request(url + '/graphql', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'ApiKey': apiKey
        },
        extraData: body,
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs,
        expectDataType: http.HttpDataType.STRING
      })
      const code: number = resp.responseCode
      return code >= 200 && code < 500
    } catch (e) {
      return false
    } finally {
      client.destroy()
    }
  }

  /** 依据可达性选择内外网 */
  static async autoPick(force: boolean = false): Promise<AddrSlot> {
    const s: AppSettings = AppSettings.instance
    const now: number = Date.now()
    // 10 秒内不重复探测，避免频繁抖动
    if (!force && now - NetSwitch.lastPick < 10000) {
      return s.activeSlot
    }
    NetSwitch.lastPick = now

    const lan: string = s.lanUrl
    const wan: string = s.wanUrl
    if (lan.length === 0 && wan.length === 0) {
      return s.activeSlot
    }
    if (lan.length === 0) {
      s.setSlot(AddrSlot.WAN)
      return s.activeSlot
    }
    if (wan.length === 0) {
      s.setSlot(AddrSlot.LAN)
      return s.activeSlot
    }

    // 内网优先
    const lanOk: boolean = await NetSwitch.probe(lan, s.apiKey, 3000)
    if (lanOk) {
      s.setSlot(AddrSlot.LAN)
      return AddrSlot.LAN
    }
    s.setSlot(AddrSlot.WAN)
    return AddrSlot.WAN
  }

}
