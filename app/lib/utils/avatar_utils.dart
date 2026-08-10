import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/user_service.dart';

class AvatarUtils {
  /// Opens a full-screen, pinch-to-zoom view of an avatar. Purely for
  /// viewing - separate from [showAvatarUploadOptions], which changes it.
  static void showFullAvatarView(
    BuildContext context, {
    String? avatarUrl,
    String? name,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: _FullAvatarViewer(avatarUrl: avatarUrl, name: name),
        ),
      ),
    );
  }

  /// Returns an [ImageProvider] for an avatar string.
  /// Handles HTTP/HTTPS URLs, asset paths, base64 data URIs, and raw base64 strings.
  static ImageProvider? getAvatarImageProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
    final trimmed = avatarUrl.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    if (trimmed.startsWith('asset:') ||
        trimmed.startsWith('assets/') ||
        trimmed.startsWith('lib/assets/')) {
      String path = trimmed;
      if (path.startsWith('asset:')) {
        path = path.substring(6);
      }
      return AssetImage(path);
    }

    try {
      final String base64Data = trimmed.contains(',')
          ? trimmed.split(',').last
          : trimmed;
      final bytes = base64Decode(base64Data);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Returns an [ImageProvider] for an avatar, falling back to a default Methodist Church avatar if empty
  static ImageProvider getAvatarImageProviderOrDefault(
    String? avatarUrl, {
    String defaultAsset = 'lib/assets/images/mcsa_logo.png',
  }) {
    return getAvatarImageProvider(avatarUrl) ?? AssetImage(defaultAsset);
  }

  /// Preset avatars relating to the Methodist Church (Disabled for current version)
  static const List<Map<String, String>> presetAvatars = [];

  /// Saves the updated avatar URL or base64 string to Firestore & backend
  static Future<bool> saveAvatar(
    BuildContext context,
    String avatarValue, {
    void Function(String)? onAvatarUpdated,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Instantly notify listener/callback for immediate local UI update
    onAvatarUpdated?.call(avatarValue);

    try {
      // 1. Update Firestore (updates local cache immediately)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'avatar': avatarValue,
      }, SetOptions(merge: true));

      // 2. Sync with MySQL backend in background asynchronously without blocking UI
      UserService.updateUserProfile(
        userId: user.uid,
        avatar: avatarValue,
      ).catchError((_) => <String, dynamic>{});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully!'),
            backgroundColor: Color(0xFF3B0D11),
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Opens the Avatar Selection & Upload Modal Bottom Sheet
  static Future<void> showAvatarUploadOptions(
    BuildContext context, {
    String currentAvatar = '',
    void Function(String)? onAvatarUpdated,
  }) async {
    final ImagePicker picker = ImagePicker();

    Future<void> pickAndUploadImage(ImageSource source) async {
      try {
        final XFile? image = await picker.pickImage(
          source: source,
          // Large enough to still look sharp in the full-screen avatar
          // viewer, not just as a small circle thumbnail, while staying
          // comfortably under Firestore's 1MiB document size limit once
          // base64-encoded.
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 88,
        );

        if (image != null) {
          final bytes = await image.readAsBytes();
          final String base64String =
              'data:image/jpeg;base64,${base64Encode(bytes)}';
          if (context.mounted) {
            onAvatarUpdated?.call(base64String);
            Navigator.pop(context);
            await saveAvatar(
              context,
              base64String,
              onAvatarUpdated: onAvatarUpdated,
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
        }
      }
    }

    Future<void> showUrlInputDialog() async {
      final controller = TextEditingController(
        text: currentAvatar.startsWith('http') ? currentAvatar : '',
      );
      final String? url = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Enter Image URL',
            style: TextStyle(color: Color(0xFF3B0D11)),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/my-photo.jpg',
              labelText: 'Image Web Link',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B0D11),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (url != null && url.isNotEmpty && context.mounted) {
        onAvatarUpdated?.call(url);
        Navigator.pop(context);
        await saveAvatar(context, url, onAvatarUpdated: onAvatarUpdated);
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Change Profile Picture',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B0D11),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a method to update your profile avatar:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Gallery Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB8B24).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xFFFB8B24),
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Pick an image stored on your device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pickAndUploadImage(ImageSource.gallery),
                ),
                const Divider(),

                // Camera Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B0D11).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Use camera to capture a new avatar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pickAndUploadImage(ImageSource.camera),
                ),
                const Divider(),

                // URL Link Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link, color: Colors.blue),
                  ),
                  title: const Text(
                    'Image Web Link',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Paste a URL to an online picture'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: showUrlInputDialog,
                ),
                const Divider(),

                if (currentAvatar.isNotEmpty) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                    title: const Text(
                      'Remove Current Avatar',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      onAvatarUpdated?.call('');
                      Navigator.pop(ctx);
                      await saveAvatar(
                        context,
                        '',
                        onAvatarUpdated: onAvatarUpdated,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FullAvatarViewer extends StatelessWidget {
  final String? avatarUrl;
  final String? name;

  const _FullAvatarViewer({this.avatarUrl, this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image(
                    image: AvatarUtils.getAvatarImageProviderOrDefault(
                      avatarUrl,
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (name != null && name!.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: Text(
                      name!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
