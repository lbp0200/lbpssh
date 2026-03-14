# Provider → Riverpod 迁移分析

## 当前状态
- Provider 文件数: 6
- 总依赖点: 24 (使用 grep 统计)
  - ChangeNotifierProvider: 6 处
  - Provider.of: 6 处
  - context.read: 12 处
  - context.watch: 0 处

## Provider 依赖分析

### 1. ConnectionProvider
- 位置: `lib/presentation/providers/connection_provider.dart`
- 依赖数: 9 处
- 复杂度: 中
- 依赖服务: ConnectionRepository
- 说明: 管理连接列表，包含增删改查和搜索过滤功能

### 2. TerminalProvider
- 位置: `lib/presentation/providers/terminal_provider.dart`
- 依赖数: 12 处 (最高)
- 复杂度: 高
- 依赖服务: TerminalService, AppConfigService, SshService, LocalTerminalService, TerminalInputService
- 说明: 管理终端会话生命周期，支持本地终端和 SSH 终端，是核心 Provider
- 注意: 被 SftpProvider 依赖

### 3. SyncProvider
- 位置: `lib/presentation/providers/sync_provider.dart`
- 依赖数: 3 处
- 复杂度: 低
- 依赖服务: SyncService
- 说明: 管理配置同步状态

### 4. AppConfigProvider
- 位置: `lib/presentation/providers/app_config_provider.dart`
- 依赖数: 3 处
- 复杂度: 低
- 依赖服务: AppConfigService
- 说明: 管理应用配置（终端配置、主题等）

### 5. ImportExportProvider
- 位置: `lib/presentation/providers/import_export_provider.dart`
- 依赖数: 1 处
- 复杂度: 低
- 依赖服务: ImportExportService
- 说明: 管理导入导出功能

### 6. SftpProvider
- 位置: `lib/presentation/providers/sftp_provider.dart`
- 依赖数: 1 处
- 复杂度: 中
- 依赖服务: TerminalProvider (依赖另一个 Provider)
- 说明: 管理 SFTP 标签页

## 使用分布

| 文件 | Provider.of | Consumer | context.read | 其他 |
|------|-------------|----------|--------------|------|
| main.dart | 1 | 2 | 6 | 0 |
| terminal_view.dart | 3 | 2 | 1 | 0 |
| main_screen.dart | 2 | 0 | 1 | 0 |
| connection_form.dart | 1 | 0 | 0 | 0 |
| sync_settings.dart | 0 | 3 | 0 | 0 |
| app_settings_screen.dart | 2 | 1 | 0 | 0 |
| import_export_settings.dart | 0 | 1 | 0 | 0 |
| collapsible_sidebar.dart | 0 | 0 | 2 | 0 |
| connection_list.dart | 0 | 2 | 0 | 0 |
| compact_connection_list.dart | 0 | 2 | 0 | 0 |

## 迁移策略

### 推荐策略: 渐进式迁移

#### Phase 1: 新功能使用 Riverpod
- 新功能直接使用 Riverpod，不使用 Provider
- 不修改现有 Provider 代码

#### Phase 2: 迁移低复杂度 Provider
- **AppConfigProvider**: 简单配置管理，无外部依赖
- **SyncProvider**: 同步状态管理，依赖清晰
- **ImportExportProvider**: 导入导出功能，独立性强

#### Phase 3: 迁移中等复杂度 Provider
- **ConnectionProvider**: 连接管理，依赖 Repository
- **SftpProvider**: SFTP 标签页，依赖 TerminalProvider

#### Phase 4: 迁移高复杂度 Provider
- **TerminalProvider**: 核心终端管理，多服务依赖
- 最后迁移，因为它被其他 Provider 依赖

### 迁移注意事项

1. **保持 Provider 兼容层**
   - 使用 `ProviderScope` 包装应用
   - 可以同时运行 Provider 和 Riverpod

2. **代码修改模式**
   ```dart
   // Provider 模式
   final provider = context.read<ConnectionProvider>();
   provider.loadConnections();

   // Riverpod 模式
   ref.read(connectionProvider.notifier).loadConnections();
   ```

3. **Consumer 替换**
   ```dart
   // Provider 模式
   Consumer<ConnectionProvider>(
     builder: (context, provider, _) => Widget(),
   )

   // Riverpod 模式
   Consumer(
     builder: (context, ref, _) {
       final connections = ref.watch(connectionProvider);
       return Widget();
     },
   )
   ```

4. **避免破坏性变更**
   - 保持 API 兼容性
   - 使用扩展方法或别名
   - 分阶段发布迁移

### 依赖注入变化

| Provider | 现有 DI 方式 | Riverpod 方式 |
|----------|-------------|---------------|
| ConnectionProvider | 构造函数注入 Repository | NotifierProvider |
| TerminalProvider | 构造函数注入 Services | NotifierProvider + Service Providers |
| SyncProvider | 构造函数注入 SyncService | NotifierProvider |
| AppConfigProvider | 构造函数注入 AppConfigService | NotifierProvider |
| ImportExportProvider | 构造函数注入 Service | NotifierProvider |
| SftpProvider | 构造函数注入 TerminalProvider | NotifierProvider (需要 ref) |

## 成本估算

- 总文件数: 6 个 Provider 文件
- 需要修改的文件:
  - Provider 文件: 6 个 (转换为 Notifier)
  - 使用 Provider 的文件: 10+ 个 (修改调用方式)
  - main.dart: 1 个 (ProviderScope 配置)

## 风险评估

1. **TerminalProvider 依赖风险**: 高
   - 多个服务依赖
   - 被 SftpProvider 依赖
   - 建议最后迁移

2. **SftpProvider 依赖风险**: 中
   - 依赖 TerminalProvider
   - 需要处理 Provider 间的依赖

3. **测试覆盖**: 需要更新测试用例

## 下一步行动

1. 添加 `flutter_riverpod` 依赖
2. 创建示例 Provider 验证迁移方案
3. 按照上述 Phase 顺序逐步迁移
4. 运行测试确保功能正常
