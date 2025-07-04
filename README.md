# The Librarian

A roguelike game written in Go, inspired by the Complete Roguelike Tutorial. Journey through the depths of a mystical library where stories become reality and knowledge is power.

## Features

- **Procedural dungeon generation** with rooms and corridors
- **Character progression system** with leveling, skills, and specialization
- **Special abilities system** with 6 powerful abilities unlocked through skill combinations
- **Enhanced combat system** with 9 weapon types and unique critical hit effects
- **Advanced status effects** - bleeding, stunning, armor breaks, poison, buffs
- **Mana and energy management** - resource-based ability system with cooldowns
- **Achievement system** - track progress with 12+ achievements and rewards
- **Weapon specialization** - each weapon type has unique properties and critical effects
- **Skill system** - 12 skills across combat, defense, and utility categories
- **Item assessment system** - examine items to discover lore and properties
- **Knowledge progression** - items become more familiar through use (★/★★ indicators)
- **Dynamic storytelling** - equipment usage generates discoverable narratives
- **Player inscriptions** - add personal notes to equipment that persist
- **Stealth mechanics** - reduce enemy detection range and gain ambush bonuses
- **Intelligent enemy AI** with line-of-sight and tactical behavior
- **Level transitions** with stairs between dungeon floors and enemy scaling
- **Save/load system** - persistent progress across sessions
- **Enhanced ASCII graphics** with progressive color system using tcell
- **Graphics system** with runtime color toggle and feature flags

## Controls

### Game Controls
- **Arrow Keys** or **hjkl**: Move player (4 directions)
- **Numpad 1-9**: Move player (8 directions including diagonals)
  - 7 8 9
  - 4 . 6  (5 = no movement)
  - 1 2 3
- **g**: Pick up item
- **i**: Open inventory
- **s**: View skills and spend skill points
- **a**: View achievements and progress
- **b**: View special abilities and activate them
- **x**: Examine items (on ground or in inventory)
- **c**: Toggle color graphics system (enhanced colors vs basic ASCII)
- **q** or **Escape**: Quit game

### Inventory Mode Controls
- **Arrow Keys**: Navigate through equipment and items
- **u**: Use selected item (potions, etc.)
- **d**: Drop selected item
- **w**: Wield selected weapon
- **W**: Wear selected armor
- **x**: Examine selected item
- **r**: Remove equipped weapon or armor
- **i** or **Escape**: Close inventory

### Death Screen Controls
- **N**: New Game (generate fresh dungeon)
- **R**: Restart (play same map again)
- **Q** or **Escape**: Quit

## Installation

### Option 1: Download Release (Recommended)
1. Go to the [Releases page](https://github.com/klp2/rogue-lite-1/releases)
2. Download the appropriate archive for your operating system
3. Extract and run the `the-librarian` executable

### Option 2: Build from Source
1. Make sure you have Go installed (version 1.21 or later)
2. Clone this repository
3. Install dependencies:
   ```bash
   go mod tidy
   ```
4. Run the game:
   ```bash
   go run .
   ```

## Graphics Features

The game includes a progressive enhancement graphics system that provides rich visual experience while maintaining full terminal compatibility.

### Color System
- **Enhanced ASCII rendering** with context-aware coloring for all game elements
- **Runtime toggle** between color-enhanced and basic ASCII modes (press 'c')
- **Automatic color configuration** with intelligent defaults for entities, terrain, and items
- **Performance optimized** with color caching and batch rendering

### Visual Elements
- **Entities**: Colored representation of player, monsters, and NPCs
  - Player: Bright colors for high visibility
  - Enemies: Type-specific colors (orcs, goblins, skeletons)
  - Combat feedback with status effect indicators
- **Terrain**: Enhanced dungeon visualization
  - Walls, floors, doors with distinct colors
  - Stairs and special locations highlighted
  - Field-of-view dimming for explored areas
- **Items**: Equipment and treasure with category-based colors
  - Weapons, armor, potions, scrolls each have unique colors
  - Rarity and quality indicators through color intensity

### Terminal Compatibility
- **Fallback support**: Graceful degradation to monochrome ASCII on unsupported terminals
- **Color depth detection**: Automatic adaptation to terminal capabilities
- **Cross-platform**: Full support for Linux, macOS, and Windows terminals
- **Performance**: Zero overhead when graphics system is disabled

### Terminal Requirements
For optimal color experience:
- **Minimum**: ANSI color support (16 colors)
- **Recommended**: 256-color terminal or true color support
- **Terminals tested**: xterm, gnome-terminal, Windows Terminal, iTerm2, Terminal.app

## Game Mechanics

- **Player**: 30 HP, starts in the first generated room
- **Enemies**: 10 HP orcs that spawn randomly throughout the dungeon
- **Combat System**: 
  - Variable damage ranges based on weapon type
  - Armor penetration mechanics for heavy weapons
  - Parry system with shields and armor
  - Hit bonuses for accurate weapons
  - Automatic combat when moving into opponents
- **Equipment**: 
  - **Weapons**: Iron Sword, Steel Sword, Dagger, War Mace, Spear, Battle Axe
  - **Armor**: Leather Armor, Chain Mail, Plate Armor, Shield
  - Each item has unique tactical properties and special abilities
- **AI Behavior**: 
  - Enemies move randomly when player is not visible
  - Enemies chase player when they have line of sight
  - Line of sight blocked by walls and obstacles
- **Death**: Random insulting message with options to restart or generate new dungeon

## Release Information

**Current Version**: v0.5.3 (Windows Console Compatibility & Security Fixes)
**License**: Proprietary - All Rights Reserved
**Platforms**: Linux, macOS, Windows (x86_64 and ARM64)

See [CHANGELOG.md](CHANGELOG.md) for version history and [RELEASE_GUIDE.md](RELEASE_GUIDE.md) for release process.

## Dependencies

- `github.com/gdamore/tcell/v2` - Terminal cell library for rendering and input handling

## Development

### Running Tests
```bash
go test ./...
```

### Building Locally
```bash
go build -o the-librarian .
./the-librarian --version
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Create a pull request

See [RELEASE_GUIDE.md](RELEASE_GUIDE.md) for release and versioning information.

## License

Copyright © 2025 Kevin Phair. All rights reserved.

This software is proprietary and confidential. See [LICENSE](LICENSE) for details.