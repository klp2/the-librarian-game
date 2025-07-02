# Release v0.5.1 - The Librarian

## 🐛 Bug Fixes

### Fixed Win Condition Requirements (Issue #26)
- **FIXED**: Win condition now correctly requires reaching **level 10 AND defeating all monsters** (previously only required defeating monsters)
- Players can no longer achieve victory by clearing all monsters before reaching level 10
- Uses a one-way flag system to remember when level 10 is reached, ensuring the requirement persists throughout the game
- Comprehensive test coverage ensures the fix works correctly across all scenarios
- Status messages clearly communicate both requirements to players

This addresses the major gameplay issue where skilled players could win too early by efficiently clearing monsters without sufficient character progression.

## 🔧 Under the Hood Improvements

### Tileset System Foundation
- **ADDED**: Secure infrastructure for future tileset support (not yet user-visible)
- Implemented comprehensive security validation pipeline with path traversal protection
- Added memory-safe asset loading with resource limits (10MB files, 50MB cache)
- Built foundation for community tileset support with sandboxed file operations
- 100% test coverage for security-critical components

This foundational work prepares for upcoming graphical enhancements while maintaining the game's security and stability.

## 📦 Downloads

Download the latest release for your platform:

- **Windows**: `the-librarian_0.5.1_windows_amd64.zip`
- **macOS**: `the-librarian_0.5.1_darwin_amd64.tar.gz` (Intel) / `the-librarian_0.5.1_darwin_arm64.tar.gz` (Apple Silicon)
- **Linux**: `the-librarian_0.5.1_linux_amd64.tar.gz`

## 🎮 How to Play

Extract the download and run the executable. Use arrow keys or vi keys (hjkl) to move, 'g' to pick up items, 'i' for inventory, and '?' for help.

**Win Condition**: Reach level 10 and defeat all monsters across all 10 dungeon levels!

## 🔄 Migration Notes

- **Existing saves**: No migration required - the level 10 requirement will apply immediately
- **Gameplay impact**: Players already at level 10+ will notice no change; players below level 10 will need to reach it before victory
- **Performance**: No performance impact from this fix

---

**Full Changelog**: https://github.com/YOUR_USERNAME/the-librarian-game/compare/v0.5.0...v0.5.1