import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
//import 'package:path/path.dart' as path;

class MediaPickerWidget extends StatefulWidget {
  final Function(List<File> files, bool isVideo) onMediaSelected;
  final Function() onRemoveMedia;
  final List<File>? selectedMedia;
  final bool isVideo;

  const MediaPickerWidget({
    Key? key,
    required this.onMediaSelected,
    required this.onRemoveMedia,
    this.selectedMedia,
    this.isVideo = false,
  }) : super(key: key);

  @override
  State<MediaPickerWidget> createState() => _MediaPickerWidgetState();
}

class _MediaPickerWidgetState extends State<MediaPickerWidget> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
  }

  @override
  void didUpdateWidget(MediaPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMedia != oldWidget.selectedMedia) {
      _initializeVideoController();
    }
  }

  void _initializeVideoController() {
    if (widget.selectedMedia != null &&
        widget.selectedMedia!.isNotEmpty &&
        widget.isVideo) {
      _videoController = VideoPlayerController.file(widget.selectedMedia!.first)
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> imageFiles = await picker.pickMultiImage(
        imageQuality: 80,
      );

      if (imageFiles.isNotEmpty) {
        final files = imageFiles.map((xFile) => File(xFile.path)).toList();
        widget.onMediaSelected(files, false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        widget.onMediaSelected([file], true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إضافة وسائط',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.selectedMedia == null || widget.selectedMedia!.isEmpty) ...[
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.image),
                label: const Text('إضافة صور'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('إضافة فيديو'),
              ),
            ],
          ),
        ] else ...[
          if (widget.isVideo) ...[
            // عرض الفيديو
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _videoController != null &&
                          _videoController!.value.isInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (_videoController!.value.isPlaying) {
                                    _videoController!.pause();
                                  } else {
                                    _videoController!.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: widget.onRemoveMedia,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // عرض الصور
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.selectedMedia!.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        widget.selectedMedia![index],
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.red, size: 20),
                          onPressed: () {
                            final newList =
                                List<File>.from(widget.selectedMedia!);
                            newList.removeAt(index);
                            if (newList.isEmpty) {
                              widget.onRemoveMedia();
                            } else {
                              widget.onMediaSelected(newList, false);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: widget.onRemoveMedia,
              icon: const Icon(Icons.delete),
              label: const Text('إزالة جميع الوسائط'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
