import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Devuelve el id de vídeo si [url] es un enlace de YouTube (watch, youtu.be,
/// live, shorts, embed); null en cualquier otro caso.
String? youtubeVideoId(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  return YoutubePlayerController.convertUrlToId(url.trim());
}

/// Reproductor de YouTube embebido (web y móvil) con relación 16:9.
class YoutubeEmbed extends StatefulWidget {
  const YoutubeEmbed({required this.videoId, super.key});

  final String videoId;

  @override
  State<YoutubeEmbed> createState() => _YoutubeEmbedState();
}

class _YoutubeEmbedState extends State<YoutubeEmbed> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          showControls: true,
        ),
      );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
    );
  }
}
