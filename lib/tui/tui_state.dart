import '../data/models/ssh_connection.dart';

class TuiState {
  List<SshConnection> connections;
  String screen;
  int sel;
  SshConnection? editConn;
  String searchQuery;
  bool isSearching;
  int formFieldIndex;
  Map<String, String> formValues;
  AuthType formAuthType;

  TuiState({
    this.connections = const [],
    this.screen = 'list',
    this.sel = 0,
    this.editConn,
    this.searchQuery = '',
    this.isSearching = false,
    this.formFieldIndex = 0,
    Map<String, String>? formValues,
    this.formAuthType = AuthType.password,
  }) : formValues = formValues ?? <String, String>{};

  List<SshConnection> get filteredConnections {
    if (searchQuery.isEmpty) return connections;
    final q = searchQuery.toLowerCase();
    return connections
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.host.toLowerCase().contains(q) ||
              c.username.toLowerCase().contains(q),
        )
        .toList();
  }

  String formValue(String key, {String fallback = ''}) =>
      formValues[key] ?? fallback;

  void setFormValue(String key, String value) => formValues[key] = value;

  SshConnection? buildConnection() {
    final name = formValue('name');
    final host = formValue('host');
    final username = formValue('username');
    if (name.isEmpty || host.isEmpty || username.isEmpty) return null;
    final port = int.tryParse(formValue('port', fallback: '22')) ?? 22;
    return SshConnection(
      id: editConn?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      host: host,
      port: port,
      username: username,
      authType: formAuthType,
      password: formValue('password'),
      privateKeyPath: formValue('privateKeyPath'),
      keyPassphrase: formValue('keyPassphrase'),
    );
  }
}
