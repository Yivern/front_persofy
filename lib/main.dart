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
      title: "Personify",
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

  final String _apiBaseUrl =
      "https://exhibitions-looksmart-pad-wrapped.trycloudflare.com"; // Direccion dinamica

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      final response = await _dio.get(
        "$_apiBaseUrl/api/persofy/v1/search",
        queryParameters: {"query": query, "limit": 10},
      );
      if (mounted) {
        setState(() {
          _results = response.data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al buscar: ${e.toString()}")),
        );
      }
      print("Error en búsqueda: $e");
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
      appBar: AppBar(title: Text("Personify")),
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
                            : Icon(Icons.music_note),
                        title: Text(song["title"] ?? "Desconocido"),
                        subtitle: Text(song["uploader"] ?? ""),
                        onTap: () => _goToPlayer(context, song),
                      );
                    },
                  ),
                if (_loading) Center(child: CircularProgressIndicator()),
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

enum PlayerStatus { loading, playing, paused, completed, error }

class PlayerPage extends StatefulWidget {
  final Map<String, dynamic> songInitialInfo;

  PlayerPage({required this.songInitialInfo});

  @override
  _PlayerPageState createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final Dio _dio = Dio();
  final AudioPlayer _player = AudioPlayer();
  final String _apiBaseUrl =
      "https://exhibitions-looksmart-pad-wrapped.trycloudflare.com"; // Direccion dinamica

  bool _isFetchingInitialData = true;

  Map<String, dynamic>? _fullSongInfo;
  PlayerStatus _playerStatus = PlayerStatus.loading;
  String _errorMessage = "";

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchStreamAndPlay();

    _player.playerStateStream.listen((state) {
      if (!mounted) return;

      switch (state.processingState) {
        case ProcessingState.idle:
        case ProcessingState.loading:
        case ProcessingState.buffering:
          if (_isFetchingInitialData) {
            setState(() => _playerStatus = PlayerStatus.loading);
          }
          break;
        case ProcessingState.ready:
          setState(() => _playerStatus =
              state.playing ? PlayerStatus.playing : PlayerStatus.paused);
          break;
        case ProcessingState.completed:
          setState(() => _playerStatus = PlayerStatus.completed);
          break;
      }
    });

    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    });

    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _fetchStreamAndPlay() async {
    try {
      final youtubeUrl = widget.songInitialInfo["url"];
      if (youtubeUrl == null) throw Exception("URL de YouTube no encontrada.");

      final response = await _dio.get(
        "$_apiBaseUrl/api/persofy/v1/stream",
        queryParameters: {"query": youtubeUrl},
      );

      if (mounted) {
        _fullSongInfo = response.data;
        await _player.setUrl(_fullSongInfo!["stream_url"]);
        setState(() => _isFetchingInitialData = false);
        _player.play();
      }
    } catch (e) {
      print("Error obteniendo y reproduciendo: $e");
      if (mounted) {
        setState(() {
          _isFetchingInitialData = false;
          _playerStatus = PlayerStatus.error;
          _errorMessage = "No se pudo cargar el audio.";
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildControls() {
    switch (_playerStatus) {
      case PlayerStatus.playing:
        return IconButton(
          icon: Icon(Icons.pause_circle_filled,
              size: 80, color: Colors.deepPurple),
          onPressed: _player.pause,
        );
      case PlayerStatus.paused:
        return IconButton(
          icon:
              Icon(Icons.play_circle_fill, size: 80, color: Colors.deepPurple),
          onPressed: _player.play,
        );
      case PlayerStatus.completed:
        return IconButton(
          icon: Icon(Icons.replay_circle_filled_outlined,
              size: 80, color: Colors.deepPurple),
          onPressed: () =>
              _player.seek(Duration.zero).then((_) => _player.play()),
        );
      case PlayerStatus.error:
        return Icon(Icons.error_outline, color: Colors.red, size: 80);
      default:
        return CircularProgressIndicator();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayInfo = widget.songInitialInfo;

    return Scaffold(
      appBar: AppBar(title: Text(displayInfo["title"] ?? "Cargando...")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (displayInfo["thumbnail"] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  displayInfo["thumbnail"],
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(Icons.music_note, size: 150),
            SizedBox(height: 20),
            Text(
              displayInfo["title"] ?? "Cargando...",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              displayInfo["uploader"] ?? "",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),

            Slider(
              min: 0,
              max: _duration.inSeconds > 0
                  ? _duration.inSeconds.toDouble()
                  : 1.0,
              value:
                  _position.inSeconds.clamp(0, _duration.inSeconds).toDouble(),
              onChanged: (value) {
                if (mounted)
                  setState(() => _position = Duration(seconds: value.toInt()));
              },
              onChangeEnd: (value) {
                _player.seek(Duration(seconds: value.toInt()));
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatTime(_position)),
                  Text(_formatTime(_duration)),
                ],
              ),
            ),
            SizedBox(height: 20),

            _buildControls(),

            if (_playerStatus == PlayerStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
