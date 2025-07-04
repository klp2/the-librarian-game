# Changelog

All notable changes to The Librarian will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.3] - 2025-07-04

### Fixed
- **Windows Console Display Bug**: Complete Windows console compatibility implementation
  - Added Windows console detection and initialization for proper terminal handling
  - Implemented ColorMapper with LRU cache for efficient RGB to 16/256 color conversion
  - Added terminal adapter for Windows-specific optimizations (Windows Terminal, cmd.exe, PowerShell, ConEmu)
  - Integrated Windows support into graphics system with proper color mapping
  - Fixed CI environment compatibility by skipping Windows console tests in GitHub Actions
  - Comprehensive test coverage for Windows console functionality and color mapping performance

### Security
- **CRITICAL: Token Exposure Fix**: Removed accidentally committed authentication tokens
  - Removed .env.release file containing RELEASE_TOKEN
  - Removed GITHUB_TOKENS.md and GITHUB_TOKEN_USAGE.md containing sensitive tokens
  - Fixed .gitignore patterns to prevent future token commits (*~.env.release → .env.release)
  - Added comprehensive token file patterns to .gitignore for better security
  - **NOTE**: All exposed tokens have been revoked and replaced

### Technical Details
- **Windows Compatibility**: Full Windows console support with terminal detection and color mapping
- **Performance**: LRU cache implementation for color mapping reduces overhead
- **Security**: Comprehensive .gitignore patterns prevent accidental token exposure
- **CI/CD**: Enhanced test suite with CI environment detection for Windows console tests

## [0.5.2] - 2025-07-01

### Fixed
- **Win Condition Requirements (Issue #26)**: Fixed major gameplay bug where players could win without reaching level 10
  - Win condition now correctly requires BOTH reaching level 10 AND defeating all monsters
  - Uses one-way flag system to remember level 10 achievement throughout game session
  - Prevents premature victory for efficient players who clear monsters before sufficient character progression
  - Status messages clearly communicate both requirements to players
  - Comprehensive test coverage ensures correct behavior across all scenarios

### Added
- **Tileset System Foundation**: Secure infrastructure for future tileset support (not yet user-visible)
  - Comprehensive security validation pipeline with path traversal protection
  - Memory-safe asset loading with resource limits (10MB files, 50MB cache limit)
  - Sandboxed file operations for safe community tileset support
  - Foundation for upcoming graphical enhancements while maintaining security
  - 100% test coverage for all security-critical components

### Technical Details
- **Security**: Robust validation prevents path traversal, resource exhaustion, and malformed file attacks
- **Performance**: Zero performance impact from win condition fix; tileset foundation optimized for future use
- **Compatibility**: No migration required for existing saves; level 10 requirement applies immediately

## [0.5.1] - 2025-07-01

### Fixed
- **Win Condition Requirements (Issue #26)**: Fixed major gameplay bug where players could win without reaching level 10
  - Win condition now correctly requires BOTH reaching level 10 AND defeating all monsters
  - Uses one-way flag system to remember level 10 achievement throughout game session
  - Prevents premature victory for efficient players who clear monsters before sufficient character progression
  - Status messages clearly communicate both requirements to players
  - Comprehensive test coverage ensures correct behavior across all scenarios

### Added
- **Tileset System Foundation**: Secure infrastructure for future tileset support (not yet user-visible)
  - Comprehensive security validation pipeline with path traversal protection
  - Memory-safe asset loading with resource limits (10MB files, 50MB cache limit)
  - Sandboxed file operations for safe community tileset support
  - Foundation for upcoming graphical enhancements while maintaining security
  - 100% test coverage for all security-critical components

### Technical Details
- **Security**: Robust validation prevents path traversal, resource exhaustion, and malformed file attacks
- **Performance**: Zero performance impact from win condition fix; tileset foundation optimized for future use
- **Compatibility**: No migration required for existing saves; level 10 requirement applies immediately

## [0.5.0] - 2025-07-01

### Added
- **Graphics System Implementation**: Complete progressive enhancement graphics system
  - **Phase 0**: Rendering abstraction with clean interface architecture
  - **Stage 1**: Enhanced ASCII colors with comprehensive color management
  - ColoredRenderer wrapper for convenient color application
  - GameGraphicsManager for seamless main game integration
  - Feature flag system for runtime graphics toggle
  - FOV-aware dimming and visibility-based rendering
- **Color Configuration System**: Intelligent color management
  - Default color schemes for entities, terrain, and items
  - Context-aware color selection based on game state
  - Performance-optimized color caching system
  - Support for 16-color, 256-color, and true color terminals
- **Progressive Enhancement Architecture**: Graceful degradation support
  - Automatic fallback to basic ASCII on unsupported terminals
  - Zero performance overhead when graphics system disabled
  - Cross-platform compatibility (Linux, macOS, Windows)
  - Terminal capability detection and adaptation
- **Comprehensive Test Coverage**: 93.3% test coverage with 46 test functions
  - Foundation tests for core renderer functionality
  - Integration tests for main game compatibility
  - Security tests for malicious input validation
  - Performance benchmarks and regression baselines
  - Memory safety and boundary condition testing

### Changed
- **Rendering Architecture**: Complete abstraction of rendering system
  - Renderer interface for multiple rendering backends
  - AsciiRenderer with full tcell integration
  - Clean separation between game logic and display logic
  - Modular design for future graphics enhancements
- **Main Game Integration**: Seamless graphics system integration
  - GameGraphicsManager replaces direct tcell calls
  - Entity type-based rendering with automatic color selection
  - Visibility-aware rendering with FOV integration
  - Batch rendering for improved performance

### Migration Notes
- **For Players**: Graphics system is enabled by default with automatic fallback
  - Use 'c' key to toggle between color-enhanced and basic ASCII modes
  - No configuration required - system automatically detects terminal capabilities
  - Performance impact is minimal with intelligent caching
- **For Developers**: New rendering architecture available
  - GameGraphicsManager provides high-level rendering interface
  - Legacy tcell calls can be gradually migrated to graphics system
  - Comprehensive test suite ensures stability during migration
  - Feature flag system allows gradual rollout of graphics features

### Technical Details
- **Dependencies**: No new external dependencies added
- **Performance**: Established benchmarks for rendering operations
  - Renderer creation: 19.3ms for 1,000 renderers
  - Mass drawing: 7.1ms for 20,000 draw operations
  - Color lookups: 629μs for 100,000 lookups
- **Security**: Input validation protects against malicious inputs
  - Path traversal, XSS, SQL injection, buffer overflow protection
  - Safe defaults with graceful error handling
  - Resource limits prevent memory exhaustion

## [0.4.1] - 2025-06-28

### Fixed
- Fixed release pipeline to ensure downloadable binaries are available on GitHub Pages

## [0.4.0] - 2025-06-28

### Added
- **Temporary Win Condition**: Kill all monsters on all 10 dungeon levels to achieve victory
  - Monster tracking system displays progress in status bar
  - Victory screen with session statistics
  - Dungeon depth temporarily capped at level 10 for testing
- **Improved Startup Flow**: Enhanced loading screen with save management
  - All users see testing instructions on every startup
  - Menu options for new game vs resume save (when save exists)
  - Clear warnings prevent accidental save overwrites
  - Input validation with helpful feedback

### Changed
- Loading screen instructions now left-aligned for better readability
- Startup behavior changed to always show loading screen first

## [0.3.0] - 2025-06-28

### Added
- **Special Abilities System**: 6 powerful abilities unlocked through skill combinations
  - Berserker Fury: 3x damage boost for 3 turns (Weapon Mastery 3 + Berserker Rage 2)
  - Perfect Defense: Brief invulnerability (Armor Mastery 3 + Shield Blocking 2)
  - Shadow Strike: Guaranteed critical from stealth (Stealth 3 + Critical Strike 2)
  - Battle Meditation: Rapid HP regeneration (Survival 2 + Toughness 2)
  - Weapon Dance: Multi-hit combo attack (Dual Wielding 2 + Weapon Mastery 3)
  - Master Craftsman: Enhance equipment temporarily (Item Lore 3 + Perception 2)
- **Mana & Energy System**: Resource management for special abilities
  - Mana pool: 50 + (level-1)*10, regenerates 4 + level/2 per turn (enhanced)
  - Survival skill provides mana regeneration bonuses (+1 per 2 skill levels)
  - Combat mana recovery: 2-4 mana per enemy kill
  - Turn-based cooldown system prevents ability spam
  - UI integration with mana display in HUD
- **Enhanced Combat Effects**: Weapon-specific critical hit effects for all 9 weapon types
  - Sword: Bleeding effect (3 turns, intensity 2)
  - Dagger: Stunning effect (1 turn, intensity 1)
  - Mace: Armor break effect (5 turns, intensity 1)
  - Axe: Severe bleeding (4 turns, intensity 3)
  - Spear: Defense debuff (3 turns, intensity 2)
  - Bow: Attack debuff (3 turns, intensity 3)
  - Crossbow: Bleeding + defense debuff (combined effects)
  - Javelin: Extended bleeding (5 turns, intensity 2)
  - Shuriken: Poison effect (3 turns, intensity 1)
- **Comprehensive Balance Validation**: 8-category test suite
  - Skill point economy validation
  - Progression curve XP requirements testing
  - Mana economy balance analysis
  - Ability cooldown vs power validation
  - Dungeon scaling balance verification
  - Weapon critical effect impact testing
  - Special ability prerequisite balance
  - Endgame balance analysis
- **Enhanced UI**: Special abilities screen accessible with 'b' key
  - Learned abilities display with prerequisites
  - Cooldown and mana cost information
  - Ability activation interface

### Changed
- Enhanced StatusEffectManager with HasEffect() and GetEffectIntensity() methods
- Save system version incremented to 5 for new features compatibility
- Combat system integrates multi-hit support for Weapon Dance ability
- Improved status effect integration throughout combat calculations
- **Enhanced mana regeneration**: Increased from `2 + level/5` to `4 + level/2` per turn
- **Guaranteed attack growth**: Minimum +1 attack per level beyond 1

### Fixed
- Color constant issues (ColorCyan → ColorLightCyan, ColorMagenta → ColorPurple)
- Test compilation errors with CreateItem signature and WeaponProperties fields
- Git workflow compliance (proper feature branch usage)
- **Critical balance issues resolved**:
  - Mana regeneration speed increased by 50-58% (now 12-17 turns to fill vs 25-40)
  - Attack progression now meets minimum requirements at all levels
  - Special abilities usable frequently enough for engaging gameplay

## [0.2.0] - 2025-06-28

### Added
- **Achievement System**: Complete achievement framework with 12 achievements across 5 categories
  - Achievement viewing UI accessible with 'a' key
  - Progress tracking with visual indicators (✓/○/???)
  - Achievement rewards including XP and skill points
  - Left-aligned display with consistent formatting
  - Unlocked achievements sorted first for better visibility
- **Status Effects System**: Foundation for combat buffs/debuffs
  - 9 status effect types (poison, regeneration, strength buff, etc.)
  - Turn-based effect processing with duration tracking
  - Visual indicators and expiration messages
  - Weapon-specific critical hit effects
- **Enemy Scaling System**: Dungeon-based difficulty progression
  - Enemies scale 25% per dungeon level (HP, attack, defense)
  - Dynamic XP rewards with 15% bonus per dungeon level
  - Balanced progression curve for deeper dungeon exploration
- **Stealth Mechanics**: Fixed and enhanced stealth skill functionality
  - Detection range reduction (up to 5 tiles at max level)
  - Critical hit bonus for ambush attacks
  - Line-of-sight based enemy detection

### Changed
- Achievement display uses left-aligned text instead of centered for better readability
- Achievement category headers have consistent 18-character width
- Improved help text to include new 'a' key for achievements

### Fixed
- Stealth skill now properly reduces enemy detection range
- Stealth skill correctly provides critical hit bonuses

## [0.1.1] - 2025-06-27

### Added
- Public distribution system with automated release mirroring
- Professional GitHub Pages download site at klp2.github.io/the-librarian-game
- Cross-platform download detection and recommendations
- Comprehensive game documentation and instructions

### Changed
- Established public repository (the-librarian-game) for distribution
- Automated release workflow between private and public repositories

## [0.1.0] - 2025-06-27

### Added
- Initial version numbering and release system
- GoReleaser configuration for automated builds
- GitHub Actions CI/CD pipeline
- Version information in binary (`--version` flag)
- Command line help (`--help` flag)

### Changed
- Game name changed from "Roguelike Game" to "The Librarian"
- Updated project documentation with new game name

## [0.1.0] - 2025-06-27

### Added
- Core roguelike gameplay mechanics
- Procedural dungeon generation with rooms and corridors
- Player character movement with vi keys (hjkl) and arrow keys
- Enemy AI with line-of-sight chasing behavior
- Turn-based combat system with weapon variety
- Enhanced equipment system with 6 weapon types and armor
- Advanced combat mechanics (armor penetration, parry system, variable damage)
- Item assessment system with knowledge progression
- Persistent item lore and player inscriptions
- Equipment usage story generation
- Inventory management with equipment slots
- Level transitions between dungeon floors
- Save/load system with JSON persistence
- Comprehensive test suite (230+ tests)
- Terminal-based ASCII graphics using tcell

### Features
- **Combat**: Variable damage ranges, critical hits, tactical depth
- **Equipment**: Specialization system with mastery indicators (★/★★)
- **Story System**: Dynamic narratives based on equipment usage
- **Progression**: Item knowledge advancement through use
- **Exploration**: Multi-level dungeons with procedural generation
- **Persistence**: Game state saves between sessions

### Controls
- Arrow keys or hjkl: Movement
- g: Pick up items
- i: Open inventory
- x: Examine items
- u: Use items (potions, etc.)
- w: Wield weapons
- W: Wear armor
- r: Remove equipment
- q: Quit game

---

*This changelog follows the [Keep a Changelog](https://keepachangelog.com/) format.*