import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'player_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();

  List<dynamic> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      final results = await _apiService.searchSongs(query);
      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _goToPlayer(BuildContext context, Map<String, dynamic> songInitialInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(songInitialInfo: songInitialInfo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Personify")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Buscar canción...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_results.isNotEmpty)
                  ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final song = _results[index];
                      return ListTile(
                        leading: song["thumbnail"] != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            song["thumbnail"],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                            : const Icon(Icons.music_note),
                        title: Text(song["title"] ?? "Desconocido"),
                        subtitle: Text(song["uploader"] ?? ""),
                        onTap: () => _goToPlayer(context, song),
                      );
                    },
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (!_loading && _results.isEmpty)
                  Center(
                    child: Text(
                      "Busca tu música favorita",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
