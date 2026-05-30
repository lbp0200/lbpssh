import '../data/models/ssh_connection.dart';

class TuiState {
  List<SshConnection> connections;
  String screen;
  int sel;
  SshConnection? editConn;

  TuiState({
    this.connections = const [],
    this.screen = 'list',
    this.sel = 0,
    this.editConn,
  });
}
