## 1.9.0

- Fix: 粘贴文本全选高亮的问题（macOS 上 IME 和快捷键双路径冲突导致）
- Chore: 升级 file_picker 到 ^11.0.2（适配 API 变更，FilePicker.platform.xxx → FilePicker.xxx）
- Chore: 升级 flutter_local_notifications 到 ^22.0.1
- Chore: 升级 dartssh2 到 ^2.14.0
- Chore: 修复 kterm 版本号与本地路径依赖一致（^1.2.0 → ^1.4.0）

## 1.8.0

- UI: 表单新增卡片分区组件 `_FormSection`，连接编辑页分 5 个区域（基本信息/认证/跳板机/SOCKS5/备注）
- UI: 设置页导航选中/悬停色使用设计 token 替代原始 hex
- UI: 空状态页面增加圆形图标容器和引导说明文字
- UI: 跳板机/SOCKS5 配置支持折叠
