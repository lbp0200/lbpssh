import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';
import 'service_providers.dart';

/// 连接列表状态
class ConnectionState {
  final List<SshConnection> connections;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const ConnectionState({
    this.connections = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  List<SshConnection> get filteredConnections {
    if (searchQuery.isEmpty) return connections;
    final query = searchQuery.toLowerCase();
    return connections.where((c) =>
      c.name.toLowerCase().contains(query) ||
      c.host.toLowerCase().contains(query) ||
      c.username.toLowerCase().contains(query)
    ).toList();
  }

  ConnectionState copyWith({
    List<SshConnection>? connections,
    bool? isLoading,
    String? error,
    String? searchQuery,
    bool clearError = false,
  }) {
    return ConnectionState(
      connections: connections ?? this.connections,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionState &&
          isLoading == other.isLoading &&
          error == other.error &&
          searchQuery == other.searchQuery &&
          listEquals(connections, other.connections);

  @override
  int get hashCode => Object.hash(
        isLoading,
        error,
        searchQuery,
        Object.hashAll(connections),
      );
}

/// 连接列表通知器
class ConnectionNotifier extends Notifier<ConnectionState> {
  @override
  ConnectionState build() {
    // 延迟加载，避免在 build() 完成前访问未初始化的 state
    Future.microtask(() => _load(ref.read(connectionRepositoryProvider)));
    return const ConnectionState(isLoading: true);
  }

  ConnectionRepository get _repo => ref.read(connectionRepositoryProvider);

  Future<void> _load(ConnectionRepository repo) async {
    try {
      final connections = repo.getAllConnections();
      state = state.copyWith(connections: connections, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载连接失败: $e');
    }
  }

  Future<void> loadConnections() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final connections = _repo.getAllConnections();
      state = state.copyWith(connections: connections, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载连接失败: $e');
    }
  }

  Future<void> addConnection(SshConnection connection) async {
    try {
      await _repo.saveConnection(connection);
      await loadConnections();
    } catch (e) {
      state = state.copyWith(error: '添加连接失败: $e');
      rethrow;
    }
  }

  Future<void> updateConnection(SshConnection connection) async {
    try {
      await _repo.saveConnection(connection);
      await loadConnections();
    } catch (e) {
      state = state.copyWith(error: '更新连接失败: $e');
      rethrow;
    }
  }

  Future<void> deleteConnection(String id) async {
    try {
      await _repo.deleteConnection(id);
      await loadConnections();
    } catch (e) {
      state = state.copyWith(error: '删除连接失败: $e');
      rethrow;
    }
  }

  SshConnection? getConnectionById(String id) {
    return _repo.getConnectionById(id);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }
}

/// 连接列表 provider
final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionState>(
      ConnectionNotifier.new,
    );
