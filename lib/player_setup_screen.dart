import 'package:flutter/material.dart';
import 'models/player_model.dart';
import 'game_controller.dart';
import 'game_screen.dart';

class PlayerSetupScreen extends StatefulWidget {
  const PlayerSetupScreen({super.key});

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  int playerCount = 2;
  GameMode selectedGameMode = GameMode.turnBased;
  int selectedTurnLimit = GameConfig.defaultTurnCount;
  final List<TextEditingController> nameControllers = [];
  final List<Color> selectedColors = [];
  final List<IconData> selectedIcons = [];

  final List<Color> availableColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  final List<IconData> availableIcons = [
    Icons.circle,
    Icons.square,
    Icons.star,
    Icons.diamond,
    Icons.favorite,
    Icons.bolt,
    Icons.flag,
    Icons.home,
  ];

  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }

  void _initializePlayers() {
    nameControllers.clear();
    selectedColors.clear();
    selectedIcons.clear();

    for (int i = 0; i < playerCount; i++) {
      nameControllers.add(TextEditingController(
        text: 'Oyuncu ${i + 1}',
      ));
      selectedColors.add(availableColors[i % availableColors.length]);
      selectedIcons.add(availableIcons[i % availableIcons.length]);
    }
  }

  @override
  void dispose() {
    for (var controller in nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _arePlayersValid() {
    if (nameControllers.length != playerCount) return false;

    for (int i = 0; i < playerCount; i++) {
      if (nameControllers[i].text.trim().isEmpty) return false;
    }

    final usedColors = <Color>{};
    final usedIcons = <IconData>{};

    for (int i = 0; i < playerCount; i++) {
      if (usedColors.contains(selectedColors[i])) return false;
      if (usedIcons.contains(selectedIcons[i])) return false;
      usedColors.add(selectedColors[i]);
      usedIcons.add(selectedIcons[i]);
    }

    return true;
  }

  void _showColorPicker(int playerIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${nameControllers[playerIndex].text} - Renk Seç'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableColors.map((color) {
              final isSelected = selectedColors[playerIndex] == color;
              final isUsed = selectedColors
                  .asMap()
                  .entries
                  .where((e) => e.key != playerIndex)
                  .any((e) => e.value == color);

              return GestureDetector(
                onTap: isUsed
                    ? null
                    : () {
                        setState(() {
                          selectedColors[playerIndex] = color;
                        });
                        Navigator.of(context).pop();
                      },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.grey,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isUsed
                      ? const Icon(Icons.block, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showIconPicker(int playerIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${nameControllers[playerIndex].text} - İkon Seç'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableIcons.map((icon) {
              final isSelected = selectedIcons[playerIndex] == icon;
              final isUsed = selectedIcons
                  .asMap()
                  .entries
                  .where((e) => e.key != playerIndex)
                  .any((e) => e.value == icon);

              return GestureDetector(
                onTap: isUsed
                    ? null
                    : () {
                        setState(() {
                          selectedIcons[playerIndex] = icon;
                        });
                        Navigator.of(context).pop();
                      },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? selectedColors[playerIndex].withValues(alpha: 0.3)
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? selectedColors[playerIndex]
                          : Colors.grey,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isUsed
                      ? const Icon(Icons.block, color: Colors.grey)
                      : Icon(
                          icon,
                          color: isSelected
                              ? selectedColors[playerIndex]
                              : Colors.grey,
                          size: 24,
                        ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _startGame() {
    if (!_arePlayersValid()) return;

    final players = <Player>[];
    for (int i = 0; i < playerCount; i++) {
      players.add(Player(
        id: i + 1,
        name: nameControllers[i].text.trim(),
        color: selectedColors[i],
        pawnIcon: selectedIcons[i],
        position: 0,
        stars: GameConfig.initialScore,
      ));
    }

    // Create game controller and pass to GameScreen
    final controller = GameController(
      initialPlayers: players,
      gameMode: selectedGameMode,
      maxTurns:
          selectedGameMode == GameMode.turnBased ? selectedTurnLimit : null,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameScreen(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('Oyuncu Ayarları'),
        backgroundColor: const Color(0xFF16213e),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFF16213e),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Oyuncu Sayısı',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int i = 2; i <= 4; i++)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  playerCount = i;
                                  _initializePlayers();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: playerCount == i
                                    ? Colors.orange
                                    : Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(80, 50),
                              ),
                              child: Text('$i'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Game mode & turn configuration
              Card(
                color: const Color(0xFF16213e),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Oyun Modu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  selectedGameMode = GameMode.turnBased;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedGameMode == GameMode.turnBased
                                        ? Colors.orange
                                        : Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                              ),
                              child: const Text('Tur Bazlı'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  selectedGameMode = GameMode.questionBased;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedGameMode == GameMode.questionBased
                                        ? Colors.orange
                                        : Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                              ),
                              child: const Text('Soru Bazlı'),
                            ),
                          ),
                        ],
                      ),
                      if (selectedGameMode == GameMode.turnBased) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Tur Limiti',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: selectedTurnLimit,
                          items: GameConfig.availableTurnCounts
                              .map(
                                (t) => DropdownMenuItem<int>(
                                  value: t,
                                  child: Text(
                                    '$t Tur',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                          dropdownColor: const Color(0xFF16213e),
                          decoration: InputDecoration(
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.orange),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedTurnLimit = value;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(playerCount, (index) {
                return Card(
                  color: const Color(0xFF16213e),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Oyuncu ${index + 1}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameControllers[index],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'İsim',
                            labelStyle: const TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: selectedColors[index]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showColorPicker(index),
                                icon: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: selectedColors[index],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                label: const Text('Renk Seç'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade800,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showIconPicker(index),
                                icon: Icon(
                                  selectedIcons[index],
                                  color: selectedColors[index],
                                ),
                                label: const Text('İkon Seç'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade800,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _arePlayersValid() ? _startGame : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'OYUNU BAŞLAT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_arePlayersValid())
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lütfen tüm oyuncular için benzersiz isim, renk ve ikon seçin.',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
