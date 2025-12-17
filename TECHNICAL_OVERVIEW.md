# TriviaPoly - Technical Overview

## Executive Summary
TriviaPoly is a Monopoly-style educational board game built with Flutter, supporting desktop, mobile, and web platforms. The game combines traditional board game mechanics with trivia questions, featuring turn-based gameplay, tile effects, and a question system.

---

## 1. Tech Stack

### Framework & Language
- **Framework**: Flutter SDK
- **Primary Language**: Dart 3.0+ (SDK constraint: `>=3.0.0 <4.0.0`)
- **UI Framework**: Material Design 3 (`useMaterial3: true`)
- **Platform Support**: 
  - Desktop (Windows, Linux, macOS)
  - Mobile (Android, iOS)
  - Web

### State Management
- **Pattern**: StatefulWidget with `setState()` (no external state management library)
- **State Architecture**: 
  - Local state management within `_GameScreenState`
  - State variables for game flow, player data, UI visibility
  - Guard flags to prevent race conditions (`_isProcessingTileEffect`, `isPlanningNextMove`)
  - Timer-based failsafe mechanisms for state release

### Build System
- **Package Manager**: Pub (Flutter's built-in package manager)
- **Build Tools**: 
  - Gradle (Android)
  - CMake (Windows, Linux)
  - Xcode (iOS, macOS)

---

## 2. Project Structure

### Directory Mapping

```
triviapoly/
├── lib/                          # Main application code
│   ├── main.dart                 # Application entry point, MaterialApp setup
│   ├── player_setup_screen.dart  # Player configuration screen
│   └── game_screen.dart          # Main game logic and UI (3,316 lines)
│
├── android/                      # Android platform configuration
│   └── app/                      # Android app build files
│
├── ios/                          # iOS platform configuration
│   └── Runner/                   # iOS app bundle
│
├── windows/                      # Windows desktop configuration
│   └── runner/                   # Windows executable setup
│
├── linux/                        # Linux desktop configuration
│   └── runner/                   # Linux executable setup
│
├── macos/                        # macOS desktop configuration
│   └── Runner/                   # macOS app bundle
│
├── web/                          # Web platform configuration
│   ├── index.html                # Web entry point
│   └── manifest.json             # PWA manifest
│
├── test/                         # Unit and widget tests
│   └── widget_test.dart
│
├── pubspec.yaml                  # Dependencies and project metadata
├── pubspec.lock                  # Locked dependency versions
└── README.md                     # Project documentation
```

### Core Files

#### `lib/main.dart`
- **Purpose**: Application entry point
- **Key Components**:
  - `MyApp`: Root MaterialApp widget
  - Global `NavigatorKey` for navigation management
  - Route configuration (`/` → `PlayerSetupScreen`)

#### `lib/player_setup_screen.dart`
- **Purpose**: Pre-game player configuration
- **Functionality**:
  - Player count selection (2-4 players)
  - Player name input
  - Color and icon selection per player
  - Validation (unique names, colors, icons)
  - Navigation to `GameScreen` with configured players

#### `lib/game_screen.dart`
- **Purpose**: Core game logic and UI
- **Size**: 3,316 lines (monolithic game state management)
- **Key Classes**:
  - `GameScreen`: StatefulWidget entry point
  - `_GameScreenState`: Main game state and logic
  - `BoardPainter`: CustomPainter for board rendering
  - `Scoreboard`: Player statistics widget
  - `_QuestionPanel`: Question display widget
  - `_TileEffectPanel`: Tile effect feedback widget

---

## 3. Dependencies

### Production Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
```
- **Flutter SDK**: Core framework (no external packages)
- **Material Design**: Built-in Material components

### Development Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```
- **flutter_test**: Testing framework
- **flutter_lints**: Linting rules for code quality

### Third-Party Libraries
**None** - The project uses only Flutter SDK and built-in Dart libraries:
- `dart:async` - Timer, Future, async/await
- `dart:math` - Random number generation
- `package:flutter/material.dart` - UI framework

---

## 4. Core Functionality & User Flow

### Application Flow

```
1. App Launch
   └─> PlayerSetupScreen
       ├─> Select player count (2-4)
       ├─> Configure each player:
       │   ├─> Enter name
       │   ├─> Choose color
       │   └─> Choose icon
       └─> Validate & Start Game
           └─> GameScreen
```

### Game Flow

```
Game Initialization
├─> Determine Starting Order (dice rolls with tie-breaking)
├─> Initialize Board (40 tiles)
├─> Initialize Question Pool (5-10 questions)
└─> Begin Turn-Based Gameplay

Turn Cycle
├─> Current Player's Turn
│   ├─> Roll Dice (animation)
│   ├─> Move Player (step-by-step animation)
│   ├─> Land on Tile
│   │   ├─> Process Tile Effect
│   │   │   ├─> Question Tile → Show Question Panel
│   │   │   ├─> Bonus Tile → Award Stars + Panel
│   │   │   ├─> Penalty Tile → Deduct Stars + Panel
│   │   │   ├─> Bankruptcy Tile → Reset Stars to 0 + Panel
│   │   │   └─> Special Tile → Custom Effect + Panel
│   │   └─> Wait for User Acknowledgment (if panel shown)
│   └─> End Turn
│       ├─> Check Win Conditions
│       ├─> Move to Next Player
│       └─> Enable Dice for Next Turn
│
└─> Repeat Until Win Condition Met
    └─> Show Winner Panel
```

### Key Game Mechanics

#### 1. Starting Order Determination
- Each player rolls dice once
- Players sorted by dice value (highest first)
- Tie-breaking: Tied players roll again until resolved
- Visual panel shows rolls during determination

#### 2. Board System
- **40 tiles** arranged in a rectangular grid
- **Tile Types**:
  - `start`: Starting position (no effect)
  - `question`: Triggers trivia question
  - `bonus`: Awards stars (200+)
  - `penalty`: Deducts stars
  - `bankrupt`: Resets stars to 0
  - `special`: Custom effects (transfer stars, give to all, etc.)

#### 3. Question System
- **Question Model**:
  - `questionText`: The question
  - `options`: 4 answer choices (A, B, C, D)
  - `correctIndex`: Index of correct answer
  - `difficulty`: easy/medium/hard
- **Question Flow**:
  - Player lands on question tile
  - Question panel appears (blocks game input)
  - Player selects answer
  - Correct: +1 star, feedback shown
  - Wrong: No penalty, feedback shown
  - Panel closes → Turn ends

#### 4. Player Movement
- Step-by-step animation across tiles
- Visual tile highlighting during movement
- Respects all tile effects sequentially
- Supports multiple players on same tile (offset positioning)

#### 5. Win Conditions
- **Primary**: Player reaches 10 stars (`GameConfig.winStarsThreshold`)
- **Secondary**: All other players have 0 stars (bankrupt)
- Checked at end of each turn
- Winner panel displayed (non-blocking, state-driven)

#### 6. State Management Patterns

**Turn Flow Guards**:
- `_isProcessingTileEffect`: Prevents duplicate tile effect processing
- `isPlanningNextMove`: Tracks planning state with timeout failsafe
- `canRollDice`: Controls dice button availability
- `_planningStateTimer`: 500ms timeout to prevent deadlocks

**State Release Mechanism**:
- `_forceReleaseTurnLocks()`: Hard reset function called at critical points
- Prevents infinite "planning next move" deadlocks
- Called in: `_rollDice()`, `_endTurn()`, panel close handlers, `_endGame()`

**Panel System** (State-Driven, No Dialogs):
- `isQuestionPanelVisible`: Question panel visibility
- `isTileEffectPanelVisible`: Tile effect panel visibility
- Rendered as `Positioned.fill` widgets in main `Stack`
- Blocks game input while visible
- No `showDialog` or `Navigator` usage (prevents Flutter Desktop freezes)

---

## 5. Technical Architecture

### State Management Strategy
- **No External Libraries**: Pure Flutter `setState()` pattern
- **State Variables**: ~30+ boolean, int, and object state variables
- **State Guards**: Multiple boolean flags prevent race conditions
- **Timer-Based Safeguards**: Automatic state release after timeouts

### UI Rendering
- **Custom Painter**: `BoardPainter` extends `CustomPainter` for board rendering
- **Stack-Based Layout**: Main game screen uses `Stack` with `Positioned` widgets
- **Explicit Constraints**: All interactive widgets have explicit `width` and `height`
- **No Overlays**: All panels rendered in-tree (prevents Flutter Desktop MouseTracker issues)

### Game Logic Organization
- **Centralized Tile Processing**: `_processTileEffect()` handles all tile types
- **Single Switch-Case**: All tile effects resolved in one switch statement
- **Explicit Routing**: Question tiles return immediately, no fallthrough
- **Idempotent Operations**: Bankruptcy and other effects safe to call multiple times

### Developer Mode
- **Flag**: `isDeveloperMode` (default: `true` for development)
- **Features**:
  - Player selector dropdown
  - Force move input (number of tiles)
  - "Force Move" button
  - Bypasses dice roll, directly processes tile effects
  - Does not affect turn flow or `currentPlayerIndex`

---

## 6. Key Design Decisions

### 1. No External State Management
- **Rationale**: Simple game state, no need for complex state management
- **Trade-off**: Large state class (~3,316 lines), but easier to understand flow

### 2. State-Driven Panels (No Dialogs)
- **Rationale**: Flutter Desktop has known issues with `showDialog` in `Stack` with `Positioned` widgets
- **Solution**: In-tree panels using `Positioned.fill` widgets
- **Benefit**: Prevents `MouseTracker` assertion failures and freezes

### 3. Explicit Layout Constraints
- **Rationale**: Flutter Desktop requires explicit `width` and `height` for interactive widgets
- **Implementation**: All `Positioned` widgets have explicit dimensions
- **Benefit**: Prevents "RenderBox was not laid out" errors

### 4. Guard-Based Turn Flow
- **Rationale**: Prevent race conditions and duplicate processing
- **Implementation**: Multiple boolean guards with timeout failsafes
- **Benefit**: Predictable, debuggable turn flow

### 5. Monolithic Game Screen
- **Rationale**: All game logic in one file for easier state access
- **Trade-off**: Large file, but avoids prop drilling and context passing

---

## 7. Platform-Specific Considerations

### Desktop (Windows/Linux/macOS)
- **Critical**: No `showDialog` usage (causes freezes)
- **Layout**: All widgets must have explicit constraints
- **Mouse Handling**: Interactive widgets require proper hit-testing setup
- **State Release**: Timer-based failsafes prevent UI deadlocks

### Mobile (Android/iOS)
- Standard Flutter mobile patterns
- No special considerations beyond desktop fixes

### Web
- Standard Flutter web support
- No special web-specific optimizations

---

## 8. Testing & Quality

### Linting
- **Tool**: `flutter_lints ^3.0.0`
- **Configuration**: `analysis_options.yaml`
- **Enforcement**: Standard Dart/Flutter linting rules

### Test Structure
- **Location**: `test/widget_test.dart`
- **Status**: Basic test file present (minimal test coverage)

---

## 9. Known Technical Challenges & Solutions

### Challenge 1: Flutter Desktop Dialog Freezes
- **Problem**: `showDialog` in `Stack` with `Positioned` causes `MouseTracker` assertion failures
- **Solution**: State-driven in-tree panels, no `showDialog` usage

### Challenge 2: Layout Constraint Errors
- **Problem**: "RenderBox was not laid out" errors on desktop
- **Solution**: Explicit `width` and `height` for all `Positioned` widgets

### Challenge 3: Turn Flow Deadlocks
- **Problem**: Game stuck in "planning next move" state
- **Solution**: `_forceReleaseTurnLocks()` called at all critical points + 500ms timeout failsafe

### Challenge 4: Question Tile Not Triggering
- **Problem**: Question panel not appearing on question tiles
- **Solution**: Immediate return after setting panel state, no `_forceReleaseTurnLocks()` call

---

## 10. Future Extension Points

### Potential Enhancements
1. **State Management**: Consider Provider/Riverpod/Bloc for complex state
2. **Question Database**: External question storage (SQLite, Firebase)
3. **Multiplayer**: Network-based multiplayer support
4. **Save/Load**: Game state persistence
5. **Animations**: Enhanced visual feedback
6. **Sound Effects**: Audio feedback for actions
7. **Themes**: Multiple visual themes
8. **Localization**: Multi-language support

### Code Organization
- Split `game_screen.dart` into smaller modules:
  - `game_state.dart`: State management
  - `tile_processor.dart`: Tile effect logic
  - `board_painter.dart`: Board rendering
  - `question_system.dart`: Question handling
  - `ui_components.dart`: Reusable widgets

---

## 11. Code Statistics

- **Total Dart Files**: 3 (main.dart, player_setup_screen.dart, game_screen.dart)
- **Largest File**: `game_screen.dart` (3,316 lines)
- **Total Lines of Code**: ~3,700+ lines
- **Dependencies**: 0 external packages (Flutter SDK only)
- **Platform Support**: 6 platforms (Windows, Linux, macOS, Android, iOS, Web)

---

## 12. Entry Points for AI Assistants

### When Modifying Game Logic
- **File**: `lib/game_screen.dart`
- **Key Methods**:
  - `_processTileEffect()`: Tile effect handling
  - `_rollDice()`: Dice roll logic
  - `_endTurn()`: Turn completion
  - `_checkWinConditions()`: Win condition checking

### When Modifying UI
- **File**: `lib/game_screen.dart`
- **Key Widgets**:
  - `build()` method: Main UI structure
  - `BoardPainter`: Board rendering
  - `Scoreboard`: Player stats display
  - `_QuestionPanel`: Question UI
  - `_TileEffectPanel`: Tile effect UI

### When Adding Features
- **State Variables**: Add to `_GameScreenState` class
- **Tile Effects**: Add case to `_processTileEffect()` switch statement
- **UI Components**: Add to `build()` method's `Stack` children
- **Guards**: Add boolean flags for new async operations

---

## 13. Critical Code Patterns

### State Release Pattern
```dart
void _forceReleaseTurnLocks({bool preserveQuestionPanel = false}) {
  _isProcessingTileEffect = false;
  isPlanningNextMove = false;
  if (!preserveQuestionPanel) {
    isQuestionPanelVisible = false;
  }
  isTileEffectPanelVisible = false;
  _planningStateTimer?.cancel();
}
```

### Question Tile Pattern
```dart
case TileType.question:
  setState(() {
    isQuestionPanelVisible = true;
    currentQuestion = randomQuestion;
    canRollDice = false;
  });
  return; // EXIT IMMEDIATELY
```

### Panel Rendering Pattern
```dart
if (isQuestionPanelVisible && currentQuestion != null)
  Positioned.fill(
    child: SizedBox.expand(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Material(
            child: SizedBox(
              width: 450,
              height: 400,
              child: panelContent,
            ),
          ),
        ),
      ),
    ),
  ),
```

---

**Document Version**: 1.0  
**Last Updated**: Based on codebase analysis  
**Maintainer**: Development Team

