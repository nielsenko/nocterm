import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:hotreloader/hotreloader.dart';

import '../framework/framework.dart';

/// Mixin that adds hot reload support to TUI bindings
mixin HotReloadBinding on NoctermBinding {
  HotReloader? _reloader;
  StreamSubscription? _reloadSubscription;
  bool _isReloading = false;

  /// Initialize hot reload support
  ///
  /// This should only be called in development mode
  Future<void> initializeHotReload() async {
    if (_reloader != null) return;
    print('executableArguments: ${Platform.executableArguments}');

    // Only enable hot reload if we're running with --enable-vm-service
    // This is automatically set when running with `dart run --enable-vm-service`
    final bool vmServiceEnabled = Platform.executableArguments.any(
        (arg) => arg.contains('--enable-vm-service') || arg.contains('--observe') || arg.contains('--enable-asserts'));

    if (!vmServiceEnabled) {
      print('[HotReload] VM service not enabled. Run with --enable-vm-service to enable hot reload.');
      return;
    }

    try {
      print('[HotReload] Initializing hot reload support...');
      
      // Get and print VM service info
      try {
        final info = await Service.getInfo();
        if (info.serverUri != null) {
          print('[HotReload] VM Service URL: ${info.serverUri}');
          if (info.serverWebSocketUri != null) {
            print('[HotReload] DevTools URL: ${info.serverUri}devtools/?uri=${info.serverWebSocketUri}');
          }
        }
      } catch (e) {
        // Service.getInfo might not be available in all environments
        print('[HotReload] Could not retrieve VM service URL: $e');
      }

      _reloader = await HotReloader.create(
        debounceInterval: const Duration(seconds: 1),
        onBeforeReload: (ctx) {
          if (_isReloading) {
            return false; // Prevent concurrent reloads
          }
          _isReloading = true;

          // Log the file that triggered the reload
          if (ctx.event != null) {
            print('[HotReload] Change detected: ${ctx.event!.path}');
          }
          return true;
        },
        onAfterReload: (ctx) {
          _isReloading = false;

          if (ctx.result == HotReloadResult.Succeeded) {
            print('[HotReload] Hot reload successful');
            // Trigger reassemble after successful reload
            _performReassembleAfterReload();
          } else if (ctx.result == HotReloadResult.Failed) {
            print('[HotReload] Compilation error during hot reload');
          } else {
            print('[HotReload] Hot reload failed: ${ctx.result}');
          }
        },
      );

      print('[HotReload] Hot reload initialized successfully');
      print('[HotReload] Watching for changes in lib/, bin/, and test/ directories...');
    } catch (e, stack) {
      print('[HotReload] Failed to initialize hot reload: $e');
      print('[HotReload] Stack trace: $stack');
    }
  }

  /// Perform reassemble after a successful hot reload
  void _performReassembleAfterReload() {
    // Use a microtask to ensure the VM has finished updating
    scheduleMicrotask(() async {
      try {
        print('[HotReload] Reassembling application...');
        await performReassemble();
        print('[HotReload] Application reassembled successfully');
      } catch (e, stack) {
        print('[HotReload] Error during reassemble: $e');
        print('[HotReload] Stack trace: $stack');
      }
    });
  }

  /// Stop hot reload support
  void stopHotReload() {
    _reloadSubscription?.cancel();
    _reloader?.stop();
    _reloader = null;
    print('[HotReload] Hot reload stopped');
  }

  /// Override shutdown to cleanup hot reload
  void shutdownWithHotReload() {
    stopHotReload();
  }
}
