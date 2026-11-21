import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Ultra-stable MediaSession & Notification Handler for ZunifyG.
/// Renders SkipToPrevious, Play/Pause, SkipToNext, and Seekbar in Android
/// notification shade & lockscreen reliably without force close.
class LiteAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  AsyncCallback? onNextCallback;
  AsyncCallback? onPreviousCallback;

  LiteAudioHandler() {
    player.playbackEventStream.listen(_broadcast);
    player.playerStateStream.listen((_) => _broadcast(player.playbackEvent));
    player.durationStream.listen((dur) {
      final cur = mediaItem.value;
      if (cur != null && dur != null && dur > Duration.zero) {
        mediaItem.add(cur.copyWith(duration: dur));
      }
    });
  }

  void updateTrack(MediaItem item) {
    mediaItem.add(item);
    _broadcast(player.playbackEvent);
  }

  void _broadcast(PlaybackEvent event) {
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
    if (onNextCallback != null) await onNextCallback!();
  }

  @override
  Future<void> skipToPrevious() async {
    if (onPreviousCallback != null) await onPreviousCallback!();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }
}
