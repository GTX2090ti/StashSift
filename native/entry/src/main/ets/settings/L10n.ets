/**
 * StashSift — L10n（ArkTS 原生）
 */
export enum AppLanguage {
  SYSTEM = 'system',
  ZH = 'zh',
  EN = 'en',
  JA = 'ja'
}

const EN: Record<string, string> = {
  '连接到 Stash 服务器': 'Connect to Stash Server',
  '档案名称': 'Profile Name',
  '内网地址': 'LAN Address',
  '外网地址': 'WAN Address',
  '请至少填写一个地址': 'Please fill in at least one address',
  '测试连接': 'Test Connection',
  '测试中…': 'Testing…',
  '保存并进入': 'Save and Enter',
  '保存档案': 'Save Profile',
  '短片': 'Scenes',
  '收藏': 'Favorites',
  '资料库': 'Library',
  '设置': 'Settings',
  '演员': 'Performers',
  '工作室': 'Studios',
  '标签': 'Tags',
  '集合': 'Groups',
  '外观': 'Appearance',
  '浅色': 'Light',
  '深色': 'Dark',
  '跟随系统': 'System',
  '安全模式': 'Safe Mode',
  '生物识别锁': 'Biometric Lock',
  '已有档案': 'Profiles',
  '加载中…': 'Loading…',
  '文件': 'Files',
  '时长': 'Duration',
  '评分': 'Rating'
}

const JA: Record<string, string> = {
  '短片': 'シーン',
  '收藏': 'お気に入り',
  '资料库': 'ライブラリ',
  '设置': '設定',
  '演员': '出演者',
  '工作室': 'スタジオ',
  '标签': 'タグ',
  '集合': 'コレクション',
  '外观': '外観',
  '浅色': 'ライト',
  '深色': 'ダーク',
  '跟随系统': 'システム',
  '安全模式': 'セーフモード',
  '生物识别锁': '生体認証ロック',
  '加载中…': '読み込み中…'
}

export class L10n {
  static preference: AppLanguage = AppLanguage.SYSTEM

  static translate(source: string): string {
    const code: string = L10n.preference === AppLanguage.SYSTEM ? 'zh' : L10n.preference
    if (code === 'en') {
      const v: string | undefined = EN[source]
      return v === undefined ? source : v
    }
    if (code === 'ja') {
      const v: string | undefined = JA[source]
      return v === undefined ? source : v
    }
    return source
  }
}
