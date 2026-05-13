import 'dart:async';

import 'terminal_service.dart';

/// 搜索方向
enum SearchDirection {
  forward,   // 向前搜索
  backward,  // 向后搜索
}

/// 搜索选项
class SearchOptions {
  final bool caseSensitive;
  final bool wholeWord;
  final bool regex;
  final bool wrap;

  const SearchOptions({
    this.caseSensitive = false,
    this.wholeWord = false,
    this.regex = false,
    this.wrap = true,
  });
}

/// 搜索结果
class SearchResult {
  final String text;
  final int? startColumn;
  final int? startLine;
  final int? endColumn;
  final int? endLine;
  final bool found;

  const SearchResult({
    required this.text,
    this.startColumn,
    this.startLine,
    this.endColumn,
    this.endLine,
    this.found = true,
  });
}

/// 搜索回调
typedef SearchResultCallback = void Function(SearchResult result);

/// 扩展搜索服务
///
/// 实现终端扩展搜索功能
class KittySearchService {
  final TerminalSession? _session;

  // 回调
  SearchResultCallback? onSearchResult;

  // 当前搜索选项
  SearchOptions _currentOptions = const SearchOptions();
  String _lastSearchText = '';

  KittySearchService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取当前搜索选项
  SearchOptions get currentOptions => _currentOptions;

  /// 搜索文本
  ///
  /// [text] - 要搜索的文本
  /// [direction] - 搜索方向
  /// [options] - 搜索选项
  Future<void> search(
    String text, {
    SearchDirection direction = SearchDirection.forward,
    SearchOptions? options,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _lastSearchText = text;
    if (options != null) {
      _currentOptions = options;
    }

    // 构建搜索序列
    // OSC 6n 可以用于搜索，但实际实现取决于终端
    String searchSeq = '';

    // 添加选项前缀
    if (_currentOptions.caseSensitive) searchSeq += '1';
    if (_currentOptions.wholeWord) searchSeq += '2';
    if (_currentOptions.regex) searchSeq += '3';
    if (!_currentOptions.wrap) searchSeq += '4';

    if (searchSeq.isNotEmpty) searchSeq = ';$searchSeq';

    // 发送搜索
    final dirChar = direction == SearchDirection.forward ? '/' : '?';
    _session.writeRaw('$dirChar$text$searchSeq\r');
  }

  /// 查找下一个
  Future<void> findNext() async {
    if (_lastSearchText.isEmpty) return;

    await search(_lastSearchText, direction: SearchDirection.forward);
  }

  /// 查找上一个
  Future<void> findPrevious() async {
    if (_lastSearchText.isEmpty) return;

    await search(_lastSearchText, direction: SearchDirection.backward);
  }

  /// 设置搜索选项
  ///
  /// [options] - 搜索选项
  Future<void> setOptions(SearchOptions options) async {
    _currentOptions = options;
  }

  /// 启用区分大小写
  Future<void> enableCaseSensitive() async {
    _currentOptions = SearchOptions(
      caseSensitive: true,
      wholeWord: _currentOptions.wholeWord,
      regex: _currentOptions.regex,
      wrap: _currentOptions.wrap,
    );
  }

  /// 禁用区分大小写
  Future<void> disableCaseSensitive() async {
    _currentOptions = SearchOptions(
      caseSensitive: false,
      wholeWord: _currentOptions.wholeWord,
      regex: _currentOptions.regex,
      wrap: _currentOptions.wrap,
    );
  }

  /// 启用整词匹配
  Future<void> enableWholeWord() async {
    _currentOptions = SearchOptions(
      caseSensitive: _currentOptions.caseSensitive,
      wholeWord: true,
      regex: _currentOptions.regex,
      wrap: _currentOptions.wrap,
    );
  }

  /// 禁用整词匹配
  Future<void> disableWholeWord() async {
    _currentOptions = SearchOptions(
      caseSensitive: _currentOptions.caseSensitive,
      wholeWord: false,
      regex: _currentOptions.regex,
      wrap: _currentOptions.wrap,
    );
  }

  /// 启用正则表达式
  Future<void> enableRegex() async {
    _currentOptions = SearchOptions(
      caseSensitive: _currentOptions.caseSensitive,
      wholeWord: _currentOptions.wholeWord,
      regex: true,
      wrap: _currentOptions.wrap,
    );
  }

  /// 禁用正则表达式
  Future<void> disableRegex() async {
    _currentOptions = SearchOptions(
      caseSensitive: _currentOptions.caseSensitive,
      wholeWord: _currentOptions.wholeWord,
      regex: false,
      wrap: _currentOptions.wrap,
    );
  }

  /// 启用环绕搜索
  Future<void> enableWrap() async {
    _currentOptions = SearchOptions(
      caseSensitive: _currentOptions.caseSensitive,
      wholeWord: _currentOptions.wholeWord,
      regex: _currentOptions.regex,
      wrap: true,
    );
  }

  /// 禁用环绕搜索
  Future<void> disableWrap() async {
    _currentOptions = SearchOptions(
      caseSensitive: _currentOptions.caseSensitive,
      wholeWord: _currentOptions.wholeWord,
      regex: _currentOptions.regex,
      wrap: false,
    );
  }

  /// 清除搜索
  Future<void> clearSearch() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 发送 Escape 清除搜索
    _session.writeRaw('\x1b');
    _lastSearchText = '';
  }

  /// 高亮搜索结果
  ///
  /// [enable] - 是否高亮
  Future<void> setHighlight(bool enable) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 某些终端支持通过 OSC 控制高亮
    final cmd = '\x1b]搜索结果;highlight=${enable ? "on" : "off"}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 获取搜索历史
  Future<List<String>> getSearchHistory() async {
    // 搜索历史通常存储在本地
    // 这里返回空列表，实际实现可能需要存储
    return [];
  }

  /// 添加到搜索历史
  Future<void> addToHistory(String text) async {
    // 可以存储到本地
  }

  /// 处理搜索响应
  ///
  /// 由外部调用，解析终端返回的搜索结果
  void handleSearchResponse(String response) {
    try {
      // 解析搜索结果响应
      // 格式取决于终端实现
      // 先检查否定响应，避免 "not found" 被 "found" 匹配
      if (response.contains('not found') || response.contains('no match')) {
        onSearchResult?.call(SearchResult(
          text: _lastSearchText,
          found: false,
        ));
      } else if (response.contains('found')) {
        onSearchResult?.call(SearchResult(
          text: _lastSearchText,
          found: true,
        ));
      }
    } catch (e) {
      // 忽略解析错误
    }
  }
}
