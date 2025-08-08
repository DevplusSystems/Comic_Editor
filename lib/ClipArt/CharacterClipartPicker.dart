import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

class CharacterClipartPickerDialog extends StatefulWidget {
  @override
  State<CharacterClipartPickerDialog> createState() =>
      _CharacterClipartPickerDialogState();
}

class _CharacterClipartPickerDialogState
    extends State<CharacterClipartPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // Folders to scan
  static const _characterDir = 'assets/characters/';
  static const _clipartDir = 'assets/clipart/';

  List<String> _characterAssets = [];
  List<String> _clipartAssets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.webp');
  }

  bool _isSvg(String path) {
    return path.toLowerCase().endsWith('.svg');
  }

  Future<void> _loadAssets() async {
    try {
      // AssetManifest.json lists all bundled assets
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);

      final allAssets = manifest.keys.cast<String>().toList();

      _characterAssets = allAssets
          .where((p) =>
      p.startsWith(_characterDir) && (_isImage(p) || _isSvg(p)))
          .toList()
        ..sort();

      _clipartAssets = allAssets
          .where((p) => p.startsWith(_clipartDir) && (_isImage(p) || _isSvg(p)))
          .toList()
        ..sort();

      setState(() => _loading = false);
    } catch (e) {
      // Fallback: if manifest structure differs (very old Flutter), try alternative
      setState(() {
        _characterAssets = [];
        _clipartAssets = [];
        _loading = false;
      });
      debugPrint('Error loading AssetManifest: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Element'),
            const SizedBox(height: 10),
            _buildSearchField(),
            const SizedBox(height: 10),
            const TabBar(tabs: [
              Tab(text: 'Characters'),
              Tab(text: 'Clip-Art'),
            ]),
          ],
        ),
        content: SizedBox(
          width: 340,
          height: 440,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
            children: [
              _buildAssetsGrid(
                context,
                _characterAssets.where(_filterBySearch).toList(),
                type: 'character',
              ),
              _buildAssetsGrid(
                context,
                _clipartAssets.where(_filterBySearch).toList(),
                type: 'clipart',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search…',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _filterBySearch(String path) {
    if (_searchText.isEmpty) return true;
    final fileName = path.split('/').last.toLowerCase();
    return fileName.contains(_searchText);
  }

  Widget _buildAssetsGrid(BuildContext context, List<String> assets,
      {required String type}) {
    if (assets.isEmpty) {
      return Center(
        child: Text(
          'No assets found',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: assets.length,
      itemBuilder: (_, i) {
        final assetPath = assets[i];
        return GestureDetector(
          onTap: () => Navigator.pop(context, {'type': type, 'value': assetPath}),
          child: _stickerContainer(_assetThumb(assetPath)),
        );
      },
    );
  }

  Widget _assetThumb(String assetPath) {
    if (_isSvg(assetPath)) {
      return SvgPicture.asset(assetPath, width: 36, height: 36);
    }
    return Image.asset(assetPath, width: 36, height: 36, fit: BoxFit.contain);
  }

  Widget _stickerContainer(Widget child) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: child,
    );
  }
}
