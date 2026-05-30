import '../data/models/ssh_connection.dart';

class TuiState {
  List<SshConnection> connections;
  String screen;
  int sel;
  SshConnection? editConn;
  String searchQuery;
  bool isSearching;

  TuiState({
    this.connections = const [],
    this.screen = 'list',
    this.sel = 0,
    this.editConn,
    this.searchQuery = '',
    this.isSearching = false,
  });

  List<SshConnection> get filteredConnections {
    if (searchQuery.isEmpty) return connections;
    final q = searchQuery.toLowerCase();
    return connections.where((c) =>
      c.name.toLowerCase().contains(q) ||
      c.host.toLowerCase().contains(q) ||
      c.username.toLowerCase().contains(q),
    ).toList();
  }
}
