import sys
path = '/Users/lbp/Projects/lbpSSH/test/providers/terminal_notifier_reconnect_session_test.dart'
with open(path, 'r') as f:
    content = f.read()
old_marker = "@override\n  Widget build(BuildContext context)"
new_section = """  Widget _buildSection(String label, Future<void> Function() test) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ElevatedButton(onPressed: test, child: Text('Run')),
      ],),
    );
  }

  @override
  Widget build(BuildContext context)"""
if new_section in content:
    content = content.replace(old_marker, new_section)
    with open(path, 'w') as f:
        f.write(content)
    print('done')
else:
    idx = content.find(old_marker)
    if idx >= 0:
        start = max(0, idx-100)
        end = min(len(content), idx+200)
        print(repr(content[start:end]))
    else:
        print('marker not found')
