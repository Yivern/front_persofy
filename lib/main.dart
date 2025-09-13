import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Persofy",
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final Dio _dio = Dio();

  List<dynamic> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      final response = await _dio.get(
        "https://exhibitions-looksmart-pad-wrapped.trycloudflare.com/api/persofy/v1/search",
        queryParameters: {"query": query, "limit": 5},
      );

      setState(() {
        _results = response.data;
      });
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goToPlayer(BuildContext context, Map<String, dynamic> song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(song: song),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mi Spotify Casero")),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Buscar canción...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _search, // SOLO cuando el usuario presiona Enter
            ),
          ),
          if (_loading) LinearProgressIndicator(),
          if (_results.isNotEmpty)
            Expanded(
              child: ListView.builder(
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
                        : Icon(Icons.music_note),
                    title: Text(song["title"] ?? "Desconocido"),
                    subtitle: Text(song["uploader"] ?? ""),
                    onTap: () => _goToPlayer(context, song),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final Map<String, dynamic> song;

  PlayerPage({required this.song});

  @override
  _PlayerPageState createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _playSong();
  }

  Future<void> _playSong() async {
    try {
      await _player.setUrl(widget.song["url"]);
      _player.play();
      setState(() => _isPlaying = true);

      _player.playerStateStream.listen((state) {
        setState(() => _isPlaying = state.playing);
      });
    } catch (e) {
      print("Error reproduciendo: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.song["title"] ?? "Reproductor")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.song["thumbnail"] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.song["thumbnail"], width: 200, height: 200),
              )
            else
              Icon(Icons.music_note, size: 150),
            SizedBox(height: 20),
            Text(
              widget.song["title"] ?? "Sin título",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              widget.song["uploader"] ?? "",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                size: 80,
                color: Colors.deepPurple,
              ),
              onPressed: () {
                if (_isPlaying) {
                  _player.pause();
                } else {
                  _player.play();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
