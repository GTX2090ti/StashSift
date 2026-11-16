/**
 * StashGo — 生物识别（人脸 / 指纹）解锁
 *
 * 用 userIAM 的 UserAuthInstance：ATL3（生物识别）+ 人脸/指纹任一通过即解锁。
 */
import { userAuth } from '@kit.UserAuthenticationKit'

export class BiometricResult {
  ok: boolean = false
  message: string = ''

  constructor(ok: boolean, message: string) {
    this.ok = ok
    this.message = message
  }
}

/** 发起一次生物识别认证，返回是否通过 */
export function authenticateBiometric(reason: string,
  onDone: (r: BiometricResult) => void): void {
  try {
    const authParam: userAuth.AuthParam = {
      challenge: new Uint8Array([0, 1, 2, 3]),
      authType: [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
      authTrustLevel: userAuth.AuthTrustLevel.ATL3
    }
    const widgetParam: userAuth.WidgetParam = {
      title: reason,
      navigationButtonText: '取消'
    }
    const instance: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)
    instance.on('result', {
      onResult: (result: userAuth.UserAuthResult) => {
        if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
          onDone(new BiometricResult(true, ''))
        } else {
          onDone(new BiometricResult(false, '认证未通过（' + result.result.toString() + '）'))
        }
      }
    })
    instance.start()
  } catch (e) {
    onDone(new BiometricResult(false, '无法启动生物识别：' + (e as Error).message))
  }
}

/** 设备是否具备人脸/指纹能力 */
export function biometricAvailable(): boolean {
  try {
    const face: userAuth.EnrolledState =
      userAuth.getEnrolledState(userAuth.UserAuthType.FACE)
    if (face.credentialDigest > 0) {
      return true
    }
  } catch (e) {
    // 忽略，继续尝试指纹
  }
  try {
    const finger: userAuth.EnrolledState =
      userAuth.getEnrolledState(userAuth.UserAuthType.FINGERPRINT)
    return finger.credentialDigest > 0
  } catch (e) {
    return false
  }
}
