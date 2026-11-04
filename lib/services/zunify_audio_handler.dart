import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Zunify v1.3 Custom MediaSession & Notification Handler
/// Guarantees Android 12/13/14 Media Notification always renders:
/// - Transparent Vinyl "Z" small icon (`@drawable/ic_stat_zunify`) at top-left
/// - `⏮ SkipToPrevious`, `⏯ Play/Pause`, and `⏭ SkipToNext` buttons (instead of the square Stop icon)
/// - Interactive squiggly seekbar (`MediaAction.seek`) & Bluetooth/TWS earphone button support
class ZunifyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  AsyncCallback? onSkipToNextCallback;
  AsyncCallback? onSkipToPreviousCallback;

  ZunifyAudioHandler() {
    player.playbackEventStream.listen(_broadcastState);
    player.playerStateStream.listen((_) {
      _broadcastState(player.playbackEvent);
    });
    player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null && duration > Duration.zero) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  void updateNowPlayingMediaItem(MediaItem item) {
    mediaItem.add(item);
    _broadcastState(player.playbackEvent);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
          MediaAction.playPause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex ?? 0,
      ),
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onSkipToNextCallback != null) {
      await onSkipToNextCallback!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPreviousCallback != null) {
      await onSkipToPreviousCallback!();
    }
  }

  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }
}
