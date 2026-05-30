import 'dart:convert';

List<String> parseKeys(List<int> bytes) {
  final keys = <String>[];
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b == 27) {
      if (i + 1 < bytes.length && bytes[i + 1] == 91) {
        i += 2;
        if (i < bytes.length) {
          final seq = bytes[i];
          i++;
          switch (seq) {
            case 65: keys.add('up'); break;
            case 66: keys.add('down'); break;
            case 67: keys.add('right'); break;
            case 68: keys.add('left'); break;
            case 72: keys.add('home'); break;
            case 70: keys.add('end'); break;
          }
        }
      } else {
        keys.add('esc');
        i++;
      }
    } else if (b == 13 || b == 10) {
      keys.add('enter');
      i++;
    } else if (b == 9) {
      keys.add('tab');
      i++;
    } else if (b == 127 || b == 8) {
      keys.add('backspace');
      i++;
    } else if (b == 3) {
      keys.add('ctrl_c');
      i++;
    } else if (b >= 32 && b < 127) {
      keys.add(String.fromCharCode(b));
      i++;
    } else if (b >= 128) {
      final len = b < 0xC0 ? 1 : b < 0xE0 ? 2 : b < 0xF0 ? 3 : 4;
      if (i + len <= bytes.length) {
        try {
          keys.add(utf8.decode(bytes.sublist(i, i + len)));
        } catch (_) {}
        i += len;
      } else {
        i++;
      }
    } else {
      i++;
    }
  }
  return keys;
}
