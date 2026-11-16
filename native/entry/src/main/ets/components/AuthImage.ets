/**
 * StashGo — 鉴权图片组件（对齐原版 AuthImage）
 *
 * Stash 的封面接口需要 ApiKey 请求头，ArkUI 的 Image 组件不能带自定义头，
 * 所以这里用 http 取字节流 → 解码成 PixelMap → 内存缓存。
 */
import { http } from '@kit.NetworkKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppSettings } from '../settings/AppSettings'

/** 全局像素图缓存（按 URL，最多 120 张） */
class PixelCache {
  private static instance: PixelCache = new PixelCache()
  private map: Map<string, image.PixelMap> = new Map<string, image.PixelMap>()
  private max: number = 120

  static get(): PixelCache {
    return PixelCache.instance
  }

  get(url: string): image.PixelMap | undefined {
    return this.map.get(url)
  }

  put(url: string, pm: image.PixelMap): void {
    if (this.map.size >= this.max) {
      const first: string | undefined = this.map.keys().next().value
      if (first !== undefined) {
        const old: image.PixelMap | undefined = this.map.get(first)
        if (old !== undefined) {
          old.release()
        }
        this.map.delete(first)
      }
    }
    this.map.set(url, pm)
  }

  clear(): void {
    this.map.forEach((pm: image.PixelMap) => {
      pm.release()
    })
    this.map.clear()
  }
}

/** 图片地址重写（对齐原版 rewriteImage） */
export function rewriteImage(raw: string, base: string): string {
  if (raw.length === 0) {
    return raw
  }
  const bs: string = AppSettings.normalizeBase(base)
  let out: string = raw
  const isAbs: boolean = out.startsWith('http://') || out.startsWith('https://')
  if (!isAbs) {
    if (bs.length === 0) {
      return out
    }
    out = bs + (out.startsWith('/') ? out : '/' + out)
    return out
  }
  if (bs.length === 0) {
    return out
  }
  const schemeEnd: number = out.indexOf('://')
  if (schemeEnd < 0) {
    return out
  }
  const afterScheme: string = out.substring(schemeEnd + 3)
  const hostEnd: number = afterScheme.indexOf('/')
  const rawHost: string = hostEnd < 0 ? afterScheme : afterScheme.substring(0, hostEnd)
  const bsSchemeEnd: number = bs.indexOf('://')
  if (bsSchemeEnd < 0) {
    return out
  }
  const bsAfter: string = bs.substring(bsSchemeEnd + 3)
  const bsHostEnd: number = bsAfter.indexOf('/')
  const bsHost: string = bsHostEnd < 0 ? bsAfter : bsAfter.substring(0, bsHostEnd)
  if (rawHost !== bsHost) {
    const rawPath: string = hostEnd < 0 ? '/' : afterScheme.substring(hostEnd)
    out = bs + rawPath
  }
  return out
}

/** 取图片像素图（带缓存） */
export async function loadPixel(url: string, apiKey: string): Promise<image.PixelMap | null> {
  if (url.length === 0) {
    return null
  }
  const cached: image.PixelMap | undefined = PixelCache.get().get(url)
  if (cached !== undefined) {
    return cached
  }
  const req = http.createHttp()
  try {
    const resp: http.HttpResponse = await req.request(url, {
      method: http.RequestMethod.GET,
      header: { 'ApiKey': apiKey },
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 15000,
      readTimeout: 20000
    })
    if (resp.responseCode !== 200) {
      return null
    }
    const buf: ArrayBuffer = resp.result as ArrayBuffer
    const src: image.ImageSource = image.createImageSource(buf)
    const pm: image.PixelMap = await src.createPixelMap()
    PixelCache.get().put(url, pm)
    return pm
  } catch (e) {
    console.error('[AuthImage] load failed: ' + (e as BusinessError).message)
    return null
  } finally {
    req.destroy()
  }
}

/**
 * 鉴权图片组件。
 * 用法：AuthImage({ rawPath: scene.poster, coverHeight: 0 })
 */
@Component
export struct AuthImage {
  /** 地址变化（刮削后封面 URL 会带新的 ?t=）时重新拉图 */
  @Prop @Watch('onPathChanged') rawPath: string = ''
  @State pm: image.PixelMap | undefined = undefined
  @State loaded: boolean = false

  aboutToAppear(): void {
    this.fetch()
  }

  onPathChanged(): void {
    this.pm = undefined
    this.loaded = false
    this.fetch()
  }

  /** 外部数据变化时需要重新拉图 */
  onDidBuild(): void {
  }

  private async fetch(): Promise<void> {
    if (this.rawPath.length === 0) {
      this.loaded = true
      return
    }
    const url: string = rewriteImage(this.rawPath, AppSettings.instance.baseUrl)
    const out: image.PixelMap | null = await loadPixel(url, AppSettings.instance.apiKey)
    if (out !== null) {
      this.pm = out
    }
    this.loaded = true
  }

  /** 安全模式：全局模糊成人图像 */
  @StorageProp('safeMode') safeMode: boolean = false

  build() {
    Stack() {
      if (this.pm !== undefined) {
        Image(this.pm)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(this.safeMode ? 24 : 0)
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.film'))
            .fontSize(24)
            .fontColor(['#33000000'])
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#FFF0F0F2')
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}