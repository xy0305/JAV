# JAV — DB Online iOS 客户端

原生 iOS 客户端，连接自建 **DB Online** 服务器（JAVDB 私人影片订阅/影库系统）。

## 功能

- **首页**：最新（类型/排序/筛选）、推荐、排行榜（日/周/月）、Top250
- **搜索**：影片 + 演员搜索
- **影片详情**：剧照、演员、片商/发行商/系列、分类、评分、磁力链接、相似推荐
- **在线播放**：在线播放剧集 / 本地影库串流（AVPlayer）
- **演员**：演员列表 + 作品
- **订阅**：关注用户 / 订阅 / 订阅视频
- **下载**：下载记录 + qBittorrent / Aria2 / 115 / 迅雷 任务
- **设置**：服务器地址、API Key、登录、状态

## 连接服务器

首次启动填写 DB Online 服务器地址（Docker 映射端口 `39090`），例如：

```
http://192.168.1.10:39090
```

服务器需允许局域网/外网访问，图片与影片流经服务器 `/api/image` 代理自动解密。

## 构建

```bash
xcodebuild build -project JAV.xcodeproj -scheme JAV \
  -sdk iphoneos -configuration Release \
  CODE_SIGNING_ALLOWED=NO
```

CI（GitHub Actions）会自动构建并打包未签名 IPA（需自行用 Apple 开发者证书签名后安装）。

## 说明

- 平台：iOS 17+
- 语言：Swift / SwiftUI
- 未签名 IPA 需 AltStore / Sideloadly / 爱思助手 等方式签名安装。
