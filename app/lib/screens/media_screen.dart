import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  void _playVideo(String videoUrl) async {
    final Uri url = Uri.parse(videoUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch video'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('Tingungu Media', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF3B0D11),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('media').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFB8B24)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B0D11).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.video_library_outlined, color: Color(0xFF3B0D11), size: 60),
                  ),
                  const SizedBox(height: 24),
                  const Text('No Videos Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11))),
                  const SizedBox(height: 8),
                  const Text('Check back soon for inspiring videos.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final videos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index].data() as Map<String, dynamic>;
              final title = video['title'] ?? 'Video';
              final youtubeUrl = video['url'] ?? '';
              final thumbnail = video['thumbnail'] ?? '';
              final description = video['description'] ?? '';

              return GestureDetector(
                onTap: () => _playVideo(youtubeUrl),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              thumbnail,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.video_library, size: 50, color: Colors.grey)),
                            ),
                          ),
                          const Icon(Icons.play_circle_fill, color: Colors.white, size: 60),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B0D11))),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text("Recently added", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                const Spacer(),
                                const Text("Watch Now", style: TextStyle(color: Color(0xFFFB8B24), fontWeight: FontWeight.bold, fontSize: 13)),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFFFB8B24)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
  }
}
