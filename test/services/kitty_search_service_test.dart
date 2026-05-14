import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_search_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittySearchService', () {
    late _MockTerminalSession mockSession;
    late KittySearchService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittySearchService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittySearchService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('SearchOptions', () {
      test('uses default values', () {
        const options = SearchOptions();
        expect(options.caseSensitive, isFalse);
        expect(options.wholeWord, isFalse);
        expect(options.regex, isFalse);
        expect(options.wrap, isTrue);
      });

      test('sets all fields correctly', () {
        const options = SearchOptions(
          caseSensitive: true,
          wholeWord: true,
          regex: true,
          wrap: false,
        );
        expect(options.caseSensitive, isTrue);
        expect(options.wholeWord, isTrue);
        expect(options.regex, isTrue);
        expect(options.wrap, isFalse);
      });
    });

    group('SearchResult', () {
      test('defaults found to true', () {
        const result = SearchResult(text: 'hello');
        expect(result.text, 'hello');
        expect(result.found, isTrue);
      });

      test('stores all fields', () {
        const result = SearchResult(
          text: 'hello',
          startColumn: 1,
          startLine: 2,
          endColumn: 5,
          endLine: 2,
          found: false,
        );
        expect(result.startColumn, 1);
        expect(result.startLine, 2);
        expect(result.endColumn, 5);
        expect(result.endLine, 2);
        expect(result.found, isFalse);
      });
    });

    group('search', () {
      test('sends forward search sequence', () async {
        await service.search('hello');
        verify(() => mockSession.writeRaw('/hello\r')).called(1);
      });

      test('sends backward search sequence', () async {
        await service.search('hello', direction: SearchDirection.backward);
        verify(() => mockSession.writeRaw('?hello\r')).called(1);
      });

      test('includes option flags for case sensitive', () async {
        await service.search(
          'hello',
          options: const SearchOptions(caseSensitive: true),
        );
        verify(() => mockSession.writeRaw('/hello;1\r')).called(1);
      });

      test('includes option flags for whole word', () async {
        await service.search(
          'hello',
          options: const SearchOptions(wholeWord: true),
        );
        verify(() => mockSession.writeRaw('/hello;2\r')).called(1);
      });

      test('includes option flags for regex', () async {
        await service.search(
          'hello',
          options: const SearchOptions(regex: true),
        );
        verify(() => mockSession.writeRaw('/hello;3\r')).called(1);
      });

      test('includes option flags for no wrap', () async {
        await service.search(
          'hello',
          options: const SearchOptions(wrap: false),
        );
        verify(() => mockSession.writeRaw('/hello;4\r')).called(1);
      });

      test('combines multiple option flags', () async {
        await service.search(
          'text',
          options: const SearchOptions(
            caseSensitive: true,
            regex: true,
            wrap: false,
          ),
        );
        // Flags are concatenated: 1 (case) + 3 (regex) + 4 (no wrap)
        verify(() => mockSession.writeRaw('/text;134\r')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittySearchService();
        expect(() => nullService.search('hello'), throwsA(isA<Exception>()));
      });

      test('updates current options when provided', () async {
        expect(service.currentOptions.wrap, isTrue);
        await service.search(
          'hello',
          options: const SearchOptions(wrap: false),
        );
        expect(service.currentOptions.wrap, isFalse);
      });
    });

    group('findNext', () {
      test('sends forward search with last text', () async {
        await service.search('hello');
        await service.findNext();
        verify(() => mockSession.writeRaw('/hello\r')).called(2);
      });

      test('does nothing when no previous search', () async {
        await service.findNext();
        verifyNever(() => mockSession.writeRaw(any()));
      });
    });

    group('findPrevious', () {
      test('sends backward search with last text', () async {
        await service.search('hello');
        await service.findPrevious();
        verify(() => mockSession.writeRaw('?hello\r')).called(1);
      });

      test('does nothing when no previous search', () async {
        await service.findPrevious();
        verifyNever(() => mockSession.writeRaw(any()));
      });
    });

    group('setOptions', () {
      test('updates current options', () async {
        const options = SearchOptions(
          caseSensitive: true,
          wholeWord: true,
          regex: true,
          wrap: false,
        );
        await service.setOptions(options);
        expect(service.currentOptions.caseSensitive, isTrue);
        expect(service.currentOptions.wholeWord, isTrue);
        expect(service.currentOptions.regex, isTrue);
        expect(service.currentOptions.wrap, isFalse);
      });
    });

    group('enable/disable options', () {
      test('enableCaseSensitive sets caseSensitive to true', () async {
        await service.enableCaseSensitive();
        expect(service.currentOptions.caseSensitive, isTrue);
      });

      test('disableCaseSensitive sets caseSensitive to false', () async {
        await service.enableCaseSensitive();
        await service.disableCaseSensitive();
        expect(service.currentOptions.caseSensitive, isFalse);
      });

      test('enableWholeWord sets wholeWord to true', () async {
        await service.enableWholeWord();
        expect(service.currentOptions.wholeWord, isTrue);
      });

      test('disableWholeWord sets wholeWord to false', () async {
        await service.enableWholeWord();
        await service.disableWholeWord();
        expect(service.currentOptions.wholeWord, isFalse);
      });

      test('enableRegex sets regex to true', () async {
        await service.enableRegex();
        expect(service.currentOptions.regex, isTrue);
      });

      test('disableRegex sets regex to false', () async {
        await service.enableRegex();
        await service.disableRegex();
        expect(service.currentOptions.regex, isFalse);
      });

      test('enableWrap sets wrap to true', () async {
        await service.enableWrap();
        expect(service.currentOptions.wrap, isTrue);
      });

      test('disableWrap sets wrap to false', () async {
        await service.disableWrap();
        expect(service.currentOptions.wrap, isFalse);
      });

      test('toggle options preserve other settings', () async {
        await service.enableCaseSensitive();
        await service.enableRegex();
        await service.disableWholeWord();
        expect(service.currentOptions.caseSensitive, isTrue);
        expect(service.currentOptions.regex, isTrue);
        expect(service.currentOptions.wholeWord, isFalse);
        expect(service.currentOptions.wrap, isTrue);
      });
    });

    group('clearSearch', () {
      test('sends escape character', () async {
        await service.clearSearch();
        verify(() => mockSession.writeRaw('\x1b')).called(1);
      });

      test('resets last search text', () async {
        await service.search('hello');
        await service.clearSearch();
        // findNext should not send anything since last text was cleared
        await service.findNext();
        // Only the search and clearSearch calls should exist
        verify(() => mockSession.writeRaw(any())).called(2);
      });

      test('throws when session is null', () async {
        final nullService = KittySearchService();
        expect(() => nullService.clearSearch(), throwsA(isA<Exception>()));
      });
    });

    group('setHighlight', () {
      test('sends highlight on sequence', () async {
        await service.setHighlight(true);
        verify(
          () => mockSession.writeRaw('\x1b]搜索结果;highlight=on\x1b\\\\'),
        ).called(1);
      });

      test('sends highlight off sequence', () async {
        await service.setHighlight(false);
        verify(
          () => mockSession.writeRaw('\x1b]搜索结果;highlight=off\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittySearchService();
        expect(() => nullService.setHighlight(true), throwsA(isA<Exception>()));
      });
    });

    group('getSearchHistory', () {
      test('returns empty list', () async {
        final history = await service.getSearchHistory();
        expect(history, isEmpty);
      });
    });

    group('addToHistory', () {
      test('does not throw', () async {
        await service.addToHistory('test');
      });
    });

    group('handleSearchResponse', () {
      test('calls onSearchResult with found for "found" response', () {
        SearchResult? result;
        service.onSearchResult = (r) => result = r;
        service.handleSearchResponse('found at line 5');
        expect(result, isNotNull);
        expect(result!.found, isTrue);
        expect(result!.text, '');
      });

      test('calls onSearchResult with not found for "not found" response', () {
        SearchResult? result;
        service.onSearchResult = (r) => result = r;
        service.handleSearchResponse('not found');
        expect(result, isNotNull);
        expect(result!.found, isFalse);
      });

      test('calls onSearchResult with not found for "no match" response', () {
        SearchResult? result;
        service.onSearchResult = (r) => result = r;
        service.handleSearchResponse('no match');
        expect(result, isNotNull);
        expect(result!.found, isFalse);
      });

      test('uses last searched text', () async {
        await service.search('hello world');
        SearchResult? result;
        service.onSearchResult = (r) => result = r;
        service.handleSearchResponse('found');
        expect(result!.text, 'hello world');
      });

      test('does nothing when no callback is set', () {
        expect(() => service.handleSearchResponse('found'), returnsNormally);
      });

      test('does not call callback for unrelated response', () {
        var called = false;
        service.onSearchResult = (_) => called = true;
        service.handleSearchResponse('some other output');
        expect(called, isFalse);
      });

      test('does not throw for empty response', () {
        expect(() => service.handleSearchResponse(''), returnsNormally);
      });
    });
  });
}
