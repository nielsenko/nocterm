import 'package:nocterm/nocterm.dart';

class DebugNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    print('[NAV_OBSERVER] Pushed: ${route.settings.name} (isModal: ${route.isModal})');
    print('  Previous: ${previousRoute?.settings.name}');
  }
  
  @override
  void didPop(Route route, Route? previousRoute) {
    print('[NAV_OBSERVER] Popped: ${route.settings.name}');
    print('  Back to: ${previousRoute?.settings.name}');
  }
  
  @override
  void didRemove(Route route, Route? previousRoute) {
    print('[NAV_OBSERVER] Removed: ${route.settings.name}');
  }
  
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    print('[NAV_OBSERVER] Replaced: ${oldRoute?.settings.name} -> ${newRoute?.settings.name}');
  }
}