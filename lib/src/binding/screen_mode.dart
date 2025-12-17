/// Controls how the TUI renders in the terminal.
enum ScreenMode {
  /// Use alternate screen buffer (default). The TUI takes over the full
  /// terminal and restores the previous content on exit.
  alternateScreen,

  /// Render inline without alternate screen. Output stays in terminal
  /// history. Useful for CLIs, test runners, and interactive prompts.
  inline,
}

/// Controls what happens to inline content when the app exits.
enum InlineExitBehavior {
  /// Leave rendered content visible in terminal (default for inline).
  preserve,

  /// Clear all rendered content, leaving terminal as if app never ran.
  clear,
}
