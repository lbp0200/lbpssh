import 'package:utopia_tui/utopia_tui.dart';
import 'tui_state.dart';
import 'screens/connection_list_screen.dart';
import 'screens/connection_form_screen.dart';

void paintCurrentScreen(TuiState state, TuiContext ctx) {
  if (state.screen == 'list') {
    paintConnectionList(state, ctx);
  } else if (state.screen == 'form') {
    paintConnectionForm(state, ctx);
  }
}
