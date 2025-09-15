import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/api_service.dart';

enum PlayerStatus { loading, playing, paused, completed, error }

class PlayerPage extends StatefulWidget {
  final Map<String, dynamic> songInitialInfo;

  const PlayerPage({super.key, required this.songInitialInfo});

  @override
  _PlayerPageState createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _player = AudioPlayer();

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
          setState(() =>
          _playerStatus = state.playing ? PlayerStatus.playing : PlayerStatus.paused);
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

      final streamInfo = await _apiService.getStreamInfo(youtubeUrl);

      if (mounted) {
        _fullSongInfo = streamInfo;
        await _player.setUrl(_fullSongInfo!["stream_url"]);
        setState(() => _isFetchingInitialData = false);
        _player.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingInitialData = false;
          _playerStatus = PlayerStatus.error;
          _errorMessage = e.toString();
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
          icon: const Icon(Icons.pause_circle_filled, size: 80, color: Colors.deepPurple),
          onPressed: _player.pause,
        );
      case PlayerStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_circle_fill, size: 80, color: Colors.deepPurple),
          onPressed: _player.play,
        );
      case PlayerStatus.completed:
        return IconButton(
          icon: const Icon(Icons.replay_circle_filled_outlined, size: 80, color: Colors.deepPurple),
          onPressed: () => _player.seek(Duration.zero).then((_) => _player.play()),
        );
      case PlayerStatus.error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 80);
      default:
        return const CircularProgressIndicator();
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
              const Icon(Icons.music_note, size: 150),
            const SizedBox(height: 20),
            Text(
              displayInfo["title"] ?? "Cargando...",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              displayInfo["uploader"] ?? "",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Slider(
              min: 0,
              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
              value: _position.inSeconds.clamp(0, _duration.inSeconds).toDouble(),
              onChanged: (value) {
                if (mounted) setState(() => _position = Duration(seconds: value.toInt()));
              },
              onChangeEnd: (value) {
                _player.seek(Duration(seconds: value.toInt()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(_formatTime(_position)), Text(_formatTime(_duration))],
              ),
            ),
            const SizedBox(height: 20),
            _buildControls(),
            if (_playerStatus == PlayerStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
