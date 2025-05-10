// import 'package:blurspace/providers/video_player_provider.dart' as video; // kasih prefix 'video'
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:chewie/chewie.dart';

// class VideoPlayerWidget extends ConsumerWidget {
//   final int index;

//   const VideoPlayerWidget({
//     super.key,
//     required this.index,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     // Watch video player state
//     final videoState = ref.watch(video.videoPlayerStateProvider);
//     final currentIdx = ref.watch(video.currentMediaIndexProvider); // pakai prefix 'video'

//     // If still loading or controller not available
//     if (videoState.isLoading ||
//         videoState.chewieController == null ||
//         videoState.controller == null ||
//         !videoState.controller!.value.isInitialized ||
//         currentIdx != index) {
//       return const Center(
//         child: CircularProgressIndicator(color: Colors.white),
//       );
//     }

//     // If there's an error
//     if (videoState.errorMessage != null) {
//       return Center(
//         child: Text(
//           videoState.errorMessage!,
//           style: const TextStyle(color: Colors.white),
//         ),
//       );
//     }

//     // Use Chewie for video player with UI style like Telegram
//     return Stack(
//       children: [
//         // Main video player with full size
//         Center(
//           child: AspectRatio(
//             aspectRatio: videoState.controller!.value.aspectRatio,
//             child: Chewie(controller: videoState.chewieController!),
//           ),
//         ),

//         // Double tap zones for rewind/forward (like Telegram)
//         Positioned.fill(
//           child: Row(
//             children: [
//               // Left zone (rewind)
//               Expanded(
//                 child: GestureDetector(
//                   onDoubleTap: () {
//                     ref.read(video.videoPlayerStateProvider.notifier).seekBackward();
//                   },
//                   behavior: HitTestBehavior.opaque,
//                   child: Container(color: Colors.transparent),
//                 ),
//               ),

//               // Middle zone (play/pause)
//               const SizedBox(width: 60),

//               // Right zone (forward)
//               Expanded(
//                 child: GestureDetector(
//                   onDoubleTap: () {
//                     ref.read(video.videoPlayerStateProvider.notifier).seekForward();
//                   },
//                   behavior: HitTestBehavior.opaque,
//                   child: Container(color: Colors.transparent),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
