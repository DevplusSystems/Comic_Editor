import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CharacterClipartPickerDialog extends StatefulWidget {
  @override
  State<CharacterClipartPickerDialog> createState() =>
      _CharacterClipartPickerDialogState();
}

class _CharacterClipartPickerDialogState
    extends State<CharacterClipartPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  final List<String> emojiCharacters = [
    '👨',
    '👩',
    '👧',
    '👦',
    '👮‍♂️',
    '🧑‍🎓',
    '🧑‍⚕️',
    '🧙',
    '🦸',
    '🧛',
    '🐶',
    '🐱',
    '🐵',
    '🦊',
    '🐸',
    '🦁',
    '🐦',
    '🐧',
    '🐢',
    '🧚',
    '🧞',
    '🧟',
    '👽',
    '🦄',
    '🐉',
  ];

  final List<IconData> clipArtIcons = [
    Icons.star,
    Icons.favorite,
    Icons.face,
    Icons.emoji_emotions,
    Icons.emoji_nature,
    Icons.emoji_people,
    Icons.music_note,
    Icons.cake,
    Icons.camera_alt,
    Icons.wb_sunny,
    Icons.beach_access,
    Icons.local_florist,
    Icons.pets,
    Icons.sports_esports,
  ];

  final List<Color> stickerColors = [
    Colors.pink.shade100,
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.yellow.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: const Text('Select Element'),
        content: SizedBox(
          width: 320,
          height: 420,
          child: Column(
            children: [
              const TabBar(tabs: [
                Tab(text: 'Characters'),
/*
                Tab(text: 'Clip-Art'),
*/
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildEmojiTab(context),
/*
                    _buildClipartTab(context),
*/
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiTab(BuildContext context) {
    final filtered = emojiCharacters
        .where((e) => e.toLowerCase().contains(_searchText))
        .toList();

    return _buildStickerGrid(
      context,
      filtered.map((e) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context, {
              'type': 'character',
              'value': e,
            });
          },
          child:
          _stickerContainer(Text(e, style: const TextStyle(fontSize: 28))),
        );
      }).toList(),
    );
  }

  Widget _buildClipartTab(BuildContext context) {
    final filtered = clipArtIcons
        .where((icon) => icon.toString().toLowerCase().contains(_searchText))
        .toList();

    return _buildStickerGrid(
      context,
      filtered.map((icon) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context, {
              'type': 'clipart',
              'value': icon.codePoint,
              'fontFamily': icon.fontFamily,
            });
          },
          child: _stickerContainer(Icon(icon, size: 26)),
        );
      }).toList(),
    );
  }

  Widget _buildStickerGrid(BuildContext context, List<Widget> items) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items,
      ),
    );
  }

  Widget _stickerContainer(Widget child) {
    final bgColor = (stickerColors..shuffle()).first;
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: child,
    );
  }
}