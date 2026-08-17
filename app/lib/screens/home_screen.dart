import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'giving_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'notices_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../utils/avatar_utils.dart';
import '../utils/notice_utils.dart';

import '../data/scripture_model.dart';

import 'buy_airtime_screen.dart';
import 'buy_data_screen.dart';
import 'buy_electricity_screen.dart';
import 'e_market_screen.dart';
import 'chat_screen.dart';
import '../services/scripture_service.dart';
import 'community_screen.dart';
import 'events_screen.dart';
import 'media_screen.dart';
import 'top_up_wallet.dart';
import 'transactions_screen.dart';
import 'login_screen.dart';
import '../services/user_service.dart';
import '../services/presence_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  int? _slidingHoverIndex;
  Scripture? dailyScripture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String userName = 'Guest';
  String userEmail = '';
  String userPhone = '';
  String userAvatar = '';
  String get timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  bool _isLoadingProfile = true;

  bool _wasBackgrounded = false;

  double walletBalance = 0.0;
  bool _isLoadingWallet = true;

  late final PageController _tilesPageController;
  int _currentTileIndex = 0;
  late final AnimationController _tileShineController;

  @override
  void initState() {
    super.initState();
    _tilesPageController = PageController(viewportFraction: 0.88);
    _tileShineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadUserProfile();
    _loadDailyScripture();
    _loadWalletBalance();
    WidgetsBinding.instance.addObserver(this);
    PresenceService.goOnlineForNewSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _wasBackgrounded = false;
        PresenceService.markAppForeground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Only Logout should ever make a member appear Offline, so
        // backgrounding no longer touches presence_active. Instead this
        // records when the app was backgrounded; PresenceService derives
        // Away from that timestamp at render time, since a client-side
        // timer wouldn't reliably fire once the app is suspended.
        _wasBackgrounded = true;
        PresenceService.markAppBackground();
        break;
    }
  }

  /// Retries clearing a stale backgrounded timestamp on tap, in case the
  /// write from [didChangeAppLifecycleState]'s resume handler didn't land
  /// (e.g. no network at that instant).
  void _onScreenTap() {
    if (_wasBackgrounded) {
      _wasBackgrounded = false;
      PresenceService.markAppForeground();
    }
  }

  Future<void> _loadWalletBalance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
              if (snapshot.exists && mounted) {
                final data = snapshot.data() ?? {};
                setState(() {
                  walletBalance = (data['wallet_balance'] ?? 0.0).toDouble();
                  _isLoadingWallet = false;
                });
              }
            });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingWallet = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading wallet balance: $e');
      if (mounted) {
        setState(() {
          _isLoadingWallet = false;
        });
      }
    }
  }

  Future<void> _loadDailyScripture() async {
    try {
      final scripture = await ScriptureService.getRandomScripture();
      setState(() {
        dailyScripture = scripture;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading scripture: $e');
      }
    }
  }

  bool _profileCompleted = true;

  void _loadUserProfile() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userSubscription?.cancel();
        _userSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen(
              (snapshot) {
                if (snapshot.exists && mounted) {
                  final userData = snapshot.data() ?? {};
                  setState(() {
                    userName = userData['displayname'] ?? 'Guest';
                    userAvatar = userData['avatar'] ?? '';
                    _profileCompleted = userData['profile_completed'] ?? false;
                    _isLoadingProfile = false;
                  });
                } else {
                  if (mounted) setState(() => _isLoadingProfile = false);
                }
              },
              onError: (e) {
                if (kDebugMode) print('Error loading profile stream: $e');
                if (mounted) setState(() => _isLoadingProfile = false);
              },
            );
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tilesPageController.dispose();
    _tileShineController.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB8B24)),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your profile...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _onScreenTap,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(),
        backgroundColor: const Color(0xFFFAF9F6),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTopBar(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_profileCompleted)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFB8B24,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFB8B24)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFFB8B24),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "Please complete your profile.",
                                  style: TextStyle(
                                    color: Color(0xFF3B0D11),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProfilePage(),
                                    ),
                                  ).then((_) => _loadUserProfile());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFB8B24),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Complete"),
                              ),
                            ],
                          ),
                        ),
                      _buildGreeting(),
                      const SizedBox(height: 16),
                      _buildWalletCard(),
                      const SizedBox(height: 16),
                      _buildScriptureCard(),
                      const SizedBox(height: 20),
                      _buildMarketplace(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: Transform.translate(
          offset: const Offset(0, 20),
          child: _LufunoFab(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.menu, color: Color(0xFFFB8B24)),
            ),
          ),
          const Text(
            'Tingungu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B0D11),
            ),
          ),

          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoticesScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Builder(
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    return const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFFFB8B24),
                    );
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots(),
                    builder: (context, userSnap) {
                      final userData =
                          userSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final List<dynamic> readNotices =
                          userData['read_notices'] ?? [];
                      final Set<String> readIds = readNotices
                          .map((e) => e.toString())
                          .toSet();
                      final userSociety =
                          (userData['society'] ?? userData['society_name'])
                              ?.toString();

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notices')
                            .snapshots(),
                        builder: (context, noticesSnap) {
                          int unreadCount = 0;
                          if (noticesSnap.hasData) {
                            for (var doc in noticesSnap.data!.docs) {
                              final isVisible = isNoticeVisibleToSociety(
                                doc.data() as Map<String, dynamic>,
                                userSociety,
                              );
                              if (isVisible && !readIds.contains(doc.id)) {
                                unreadCount++;
                              }
                            }
                          }
                          return Badge(
                            label: Text(unreadCount.toString()),
                            isLabelVisible: unreadCount > 0,
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Color(0xFFFB8B24),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final timeIcon = hour < 12
        ? Icons.wb_sunny_rounded
        : (hour < 17 ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFB8B24).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(timeIcon, color: const Color(0xFFFB8B24), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$timeGreeting, $userName! 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B0D11),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome to your spiritual journey',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptureCard() {
    if (dailyScripture == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFB8B24).withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB8B24)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFB8B24).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFB8B24).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB8B24).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.format_quote_rounded,
                      color: Color(0xFFFB8B24),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DAILY SCRIPTURE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFB8B24),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                dailyScripture!.translation,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"${dailyScripture!.text}"',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Color(0xFF3B0D11),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3B0D11).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dailyScripture!.reference,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B0D11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplace() {
    final utilityTiles = [
      {
        'title': 'Airtime Top-Up',
        'subtitle': 'Instant recharge for MTN, Vodacom, Cell C & Telkom',
        'icon': Icons.phone_android_rounded,
        'color': const Color(0xFFFB8B24),
        'badge': 'INSTANT',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BuyAirtimeScreen()),
        ),
      },
      {
        'title': 'Data Bundles',
        'subtitle': 'High-speed internet bundles for all SA networks',
        'icon': Icons.wifi_rounded,
        'color': const Color(0xFFE55B13),
        'badge': 'DATA',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BuyDataScreen()),
        ),
      },
      {
        'title': 'Electricity Tokens',
        'subtitle': 'Prepaid electricity tokens for Eskom & Municipal meters',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFFB8B24),
        'badge': 'PREPAID',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BuyElectricityScreen()),
        ),
      },
      {
        'title': 'E-Market',
        'subtitle': 'Shop digital goods and services in one place',
        'icon': Icons.storefront_rounded,
        'color': const Color(0xFFFB8B24),
        'badge': 'SHOPPING',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EMarketScreen()),
        ),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Digital Utilities',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3B0D11),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _tilesPageController,
            onPageChanged: (index) {
              setState(() {
                _currentTileIndex = index;
              });
            },
            itemCount: utilityTiles.length,
            itemBuilder: (context, index) {
              final tile = utilityTiles[index];
              final isSelected = _currentTileIndex == index;
              final color = tile['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: tile['onTap'] as VoidCallback,
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B0D11), Color(0xFF5A151C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3B0D11,
                              ).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                tile['icon'] as IconData,
                                color: color,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tile['title'] as String,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (tile['badge'] != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            tile['badge'] as String,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    tile['subtitle'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _tileShineController,
                              builder: (context, _) => CustomPaint(
                                painter: _ShinyBorderPainter(
                                  progress: _tileShineController.value,
                                  borderRadius: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            utilityTiles.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentTileIndex == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentTileIndex == index
                    ? const Color(0xFFFB8B24)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Drawer(
      backgroundColor: const Color(0xFFFAF9F6),
      child: Column(
        children: [
          // Sticky Profile Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF3B0D11),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    key: ValueKey(userAvatar),
                    backgroundImage:
                        AvatarUtils.getAvatarImageProviderOrDefault(userAvatar),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FirebaseAuth.instance.currentUser != null
                            ? 'Tingungu Member'
                            : 'Browsing as Guest',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Sections sliding underneath the Sticky Profile Header
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Main App Navigation Section
                _buildDrawerSectionHeader('NAVIGATION'),
                _drawerItem(
                  'Home',
                  Icons.home_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  },
                  isActive: _currentIndex == 0,
                ),
                _drawerItem(
                  'Community',
                  Icons.people_outline,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CommunityScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  'Tingungu TV & Media',
                  Icons.video_library_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MediaScreen()),
                    );
                  },
                ),
                _drawerItem(
                  'Events & Calendar',
                  Icons.event_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EventsScreen()),
                    );
                  },
                ),

                const Divider(height: 24),
                _buildDrawerSectionHeader('SERVICES & GIVING'),
                _drawerItem(
                  'Give & Pledges',
                  Icons.favorite_outline,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GivingPage()),
                    );
                  },
                ),
                _drawerItem(
                  'Buy Airtime & Utilities',
                  Icons.phone_android_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BuyAirtimeScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  'Top Up Wallet',
                  Icons.account_balance_wallet_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TopUpWalletScreen(),
                      ),
                    );
                  },
                ),

                const Divider(height: 24),
                _buildDrawerSectionHeader('ACCOUNT'),
                _drawerItem(
                  'Edit Profile',
                  Icons.person_outline,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
                _drawerItem(
                  'Transaction History',
                  Icons.history,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionsScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  'About Tingungu',
                  Icons.info_outline,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse('https://www.tingungu.co.za/index.html'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),

                const Divider(height: 24),
                ExpansionTile(
                  leading: const Icon(
                    Icons.build_circle_outlined,
                    color: Color(0xFFFB8B24),
                  ),
                  title: const Text(
                    'Developer & Seed Tools',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFFFB8B24),
                      ),
                      title: const Text(
                        'Seed Giving Options',
                        style: TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _seedGivingOptions();
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFFFB8B24),
                      ),
                      title: const Text(
                        'Seed Notices',
                        style: TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _seedNotices();
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFFFB8B24),
                      ),
                      title: const Text(
                        'Seed Media Data',
                        style: TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _seedMediaData();
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFFFB8B24),
                      ),
                      title: const Text(
                        'Seed Events Data',
                        style: TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _seedEventsData();
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFFFB8B24),
                      ),
                      title: const Text(
                        'Seed Societies Data',
                        style: TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _seedSocietiesData();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await PresenceService.goOffline();
                            await UserService.signOutUser();
                            await FirebaseAuth.instance.signOut();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('user_profile');
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB8B24),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'v1.0.0 • Developer: Jaspa Software',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _drawerItem(
    String title,
    IconData icon, {
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFFFB8B24) : const Color(0xFF3B0D11),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFFFB8B24) : const Color(0xFF3B0D11),
          ),
        ),
        selected: isActive,
        selectedTileColor: const Color(0xFFFB8B24).withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0D11), Color(0xFF5A151C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B0D11).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFFFB8B24),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tingungu Wallet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TopUpWalletScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadWalletBalance();
                  }
                },
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text(
                  'TOP UP',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFB8B24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingWallet
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'R ${walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  void _onNavTabSelect(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CommunityScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MediaScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EventsScreen()),
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  Widget _buildBottomNav() {
    final navItems = [
      {
        'label': 'Home',
        'icon': Icons.home_outlined,
        'activeIcon': Icons.home_rounded,
      },
      {
        'label': 'Community',
        'icon': Icons.groups_outlined,
        'activeIcon': Icons.groups_rounded,
      },
      {
        'label': 'Media',
        'icon': Icons.play_circle_outline_rounded,
        'activeIcon': Icons.play_circle_fill_rounded,
      },
      {
        'label': 'Events',
        'icon': Icons.calendar_month_outlined,
        'activeIcon': Icons.calendar_month_rounded,
      },
    ];

    final activeIndex = _slidingHoverIndex ?? _currentIndex;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widthPerTab = constraints.maxWidth / navItems.length;

            void updateSlidingHover(Offset globalPosition) {
              final RenderBox? box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPos = box.globalToLocal(globalPosition);
                final calculatedIndex = (localPos.dx / widthPerTab)
                    .floor()
                    .clamp(0, navItems.length - 1);
                if (_slidingHoverIndex != calculatedIndex) {
                  setState(() {
                    _slidingHoverIndex = calculatedIndex;
                  });
                }
              }
            }

            void commitTabSelection() {
              if (_slidingHoverIndex != null) {
                final targetIndex = _slidingHoverIndex!;
                setState(() {
                  _slidingHoverIndex = null;
                });
                _onNavTabSelect(targetIndex);
              }
            }

            return GestureDetector(
              onPanStart: (details) =>
                  updateSlidingHover(details.globalPosition),
              onPanUpdate: (details) =>
                  updateSlidingHover(details.globalPosition),
              onPanEnd: (_) => commitTabSelection(),
              onPanCancel: () {
                setState(() {
                  _slidingHoverIndex = null;
                });
              },
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(navItems.length, (index) {
                    final item = navItems[index];
                    final isSelected = activeIndex == index;
                    final isHovered = _slidingHoverIndex == index;

                    return GestureDetector(
                      onTap: () => _onNavTabSelect(index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 16 : 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(
                                  0xFFFB8B24,
                                ).withValues(alpha: isHovered ? 0.25 : 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFB8B24,
                                    ).withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: isSelected
                                  ? (isHovered ? 1.25 : 1.15)
                                  : 1.0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                isSelected
                                    ? (item['activeIcon'] as IconData)
                                    : (item['icon'] as IconData),
                                color: isSelected
                                    ? const Color(0xFFFB8B24)
                                    : const Color(
                                        0xFF3B0D11,
                                      ).withValues(alpha: 0.5),
                                size: 24,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isHovered
                                      ? const Color(0xFFFB8B24)
                                      : const Color(0xFF3B0D11),
                                ),
                                child: Text(item['label'] as String),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _seedMediaData() async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final batch = FirebaseFirestore.instance.batch();
    final videos = [
      {
        "title": "Sunday Morning Live Service",
        "url": "https://www.youtube.com/live/rlx4qHn9wkY",
        "thumbnail": "https://img.youtube.com/vi/rlx4qHn9wkY/0.jpg",
        "description":
            "Join our weekly Sunday service live stream for a powerful word and worship.",
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "title": "Worship & Praise Session",
        "url": "https://www.youtube.com/live/NTTN8Ie15AY",
        "thumbnail": "https://img.youtube.com/vi/NTTN8Ie15AY/0.jpg",
        "description":
            "An uplifting session of praise and worship with the Tingungu choir.",
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "title": "Midweek Fellowship Live",
        "url": "https://www.youtube.com/live/WhiwV1sp1aY",
        "thumbnail": "https://img.youtube.com/vi/WhiwV1sp1aY/0.jpg",
        "description":
            "Connecting mid-week for spiritual encouragement and community prayer.",
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "title": "Tingungu TV: Youth Ministry",
        "url": "https://www.youtube.com/live/n2BMTvSIXkU",
        "thumbnail": "https://img.youtube.com/vi/n2BMTvSIXkU/0.jpg",
        "description":
            "Engaging our youth with relevant messages and dynamic worship.",
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "title": "Evening Prayer with Pastor",
        "url": "https://www.youtube.com/live/-2jsw9JKhEQ",
        "thumbnail": "https://img.youtube.com/vi/-2jsw9JKhEQ/0.jpg",
        "description":
            "Closing the day with prayer and a short reflection from our leadership.",
        "createdAt": FieldValue.serverTimestamp(),
      },
    ];
    for (var v in videos) {
      final docRef = FirebaseFirestore.instance.collection('media').doc();
      batch.set(docRef, v);
    }
    await batch.commit();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seeded 5 videos!')));
    }
  }

  Future<void> _seedNotices() async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final batch = FirebaseFirestore.instance.batch();
    final notices = [
      {
        "title": "Sunday Service",
        "message": "Join us this Sunday at 9 AM for a special worship service.",
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "title": "Youth Meeting",
        "message": "Youth meeting will take place on Saturday at 2 PM.",
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "title": "Church Renovations",
        "message":
            "The church building project is starting next week. Thank you for your pledges!",
        "createdAt": FieldValue.serverTimestamp(),
      },
    ];
    for (var n in notices) {
      final docRef = FirebaseFirestore.instance.collection('notices').doc();
      batch.set(docRef, n);
    }
    await batch.commit();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seeded 3 notices!')));
    }
  }

  Future<void> _seedGivingOptions() async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final options = [
      {"name": "Tithes"},
      {"name": "Pledge for Church Building"},
      {"name": "Generous Donations"},
      {"name": "Pledge for Instruments"},
    ];
    final batch = FirebaseFirestore.instance.batch();
    for (var opt in options) {
      final docRef = FirebaseFirestore.instance
          .collection('giving_options')
          .doc();
      batch.set(docRef, opt);
    }
    await batch.commit();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seeded 4 giving options!')));
    }
  }

  Future<void> _seedEventsData() async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final events = [
      {
        "month": "January",
        "date_start": "1",
        "date_end": null,
        "description": "New Year's Day",
        "venue": null,
      },
      {
        "month": "January",
        "date_start": "1",
        "date_end": "28",
        "description":
            "Feb Connexional Children & Youth Back to School Campaign",
        "venue": "All Districts",
      },
      {
        "month": "January",
        "date_start": "7",
        "date_end": null,
        "description": "MCO Opens",
        "venue": null,
      },
      {
        "month": "January",
        "date_start": "11",
        "date_end": null,
        "description": "Induction of Rev David Gertze by the Vice Chair",
        "venue": "Magalies Circuit",
      },
      {
        "month": "January",
        "date_start": "11",
        "date_end": null,
        "description":
            "Induction of Rev Moeletsi Sebolai and Thuso Manamela by the Bishop",
        "venue": "Ga Rankuwa",
      },
      {
        "month": "January",
        "date_start": "12",
        "date_end": "13",
        "description": "EMMU General Committee",
        "venue": "eMseni",
      },
      {
        "month": "January",
        "date_start": "12",
        "date_end": "13",
        "description": "Bishops Orientation",
        "venue": null,
      },
      {
        "month": "January",
        "date_start": "13",
        "date_end": null,
        "description": "Limpopo District Trust Property",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "14",
        "date_end": null,
        "description": "Limpopo District EMMU Meeting",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "14",
        "date_end": "16",
        "description": "Bishops' Retreat",
        "venue": "TBC",
      },
      {
        "month": "January",
        "date_start": "15",
        "date_end": null,
        "description": "Limpopo District Finance Committee",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "16",
        "date_end": "18",
        "description": "Lay President & District Lay Leaders' Consultation",
        "venue": "Namibia District",
      },
      {
        "month": "January",
        "date_start": "17",
        "date_end": null,
        "description":
            "Connexional Women's Fellowship Spiritual opening Retreat",
        "venue": "NFSL District",
      },
      {
        "month": "January",
        "date_start": "18",
        "date_end": null,
        "description": "Induction of Rev Mosiga Seekoei by the Bishop",
        "venue": "Mbombela",
      },
      {
        "month": "January",
        "date_start": "19",
        "date_end": "23",
        "description": "Probationer Seminar",
        "venue": "eMseni",
      },
      {
        "month": "January",
        "date_start": "19",
        "date_end": "23",
        "description": "Order of Evangelism Probationer Seminar",
        "venue": "eMseni",
      },
      {
        "month": "January",
        "date_start": "20",
        "date_end": null,
        "description": "Synergizing the Orders",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "23",
        "date_end": null,
        "description": "Methodist Joint Removals (MJR) Meeting",
        "venue": "MCO",
      },
      {
        "month": "January",
        "date_start": "23",
        "date_end": "25",
        "description":
            "Connexional Women's Fellowship Executive Committee Meeting",
        "venue": "Lumko Retreat Centre",
      },
      {
        "month": "January",
        "date_start": "24",
        "date_end": null,
        "description": "Limpopo District Wesley Guild GEC",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "25",
        "date_end": null,
        "description": "Induction of Rev Elisha Moeketsi by the Bishop",
        "venue": "Mabieskraal",
      },
      {
        "month": "January",
        "date_start": "25",
        "date_end": null,
        "description": "Induction of Rev Gavin Felix by the Vice Chair",
        "venue": "Middleburg",
      },
      {
        "month": "January",
        "date_start": "25",
        "date_end": null,
        "description": "Seth Mokitimi Methodist Seminary Opening Service",
        "venue": "SMMS",
      },
      {
        "month": "January",
        "date_start": "27",
        "date_end": null,
        "description": "Limpopo District Management",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "27",
        "date_end": "29",
        "description":
            "Molopo District Boundaries Conversation: 27th Francistown, 28th Gaborone, 29th Mahikeng",
        "venue": "Molopo District",
      },
      {
        "month": "January",
        "date_start": "28",
        "date_end": null,
        "description": "Church Unity Commission Executive",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "29",
        "date_end": null,
        "description": "Connexional Men's League District Presidents Meeting",
        "venue": "Virtual",
      },
      {
        "month": "January",
        "date_start": "31",
        "date_end": null,
        "description": "Connexional Children and Youth Executive Meeting",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "3",
        "date_end": null,
        "description": "Connexional Unit Leaders' Meeting",
        "venue": "MCO",
      },
      {
        "month": "February",
        "date_start": "3",
        "date_end": "4",
        "description": "DEWCOM Meeting",
        "venue": "eMseni",
      },
      {
        "month": "February",
        "date_start": "5",
        "date_end": null,
        "description":
            "Local Preachers' Department District Secretaries Consultation",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "5",
        "date_end": null,
        "description": "MCSA Church Funds Investment & Advisory Committee",
        "venue": "TBA",
      },
      {
        "month": "February",
        "date_start": "5",
        "date_end": null,
        "description": "Communications Board Meeting",
        "venue": "MCO",
      },
      {
        "month": "February",
        "date_start": "6",
        "date_end": "8",
        "description":
            "Connexional Children and Youth Children's Ministry Indaba",
        "venue": "Lesotho",
      },
      {
        "month": "February",
        "date_start": "7",
        "date_end": null,
        "description": "Boundaries Sub-Committee: Molopo Conversations",
        "venue": "Rustenburg",
      },
      {
        "month": "February",
        "date_start": "7",
        "date_end": null,
        "description":
            "Limpopo District Women's Fellowship Extended Leaders Capacity Building Workshop",
        "venue": "Coalfields",
      },
      {
        "month": "February",
        "date_start": "8",
        "date_end": null,
        "description": "Induction of Revs Petrus Madumo and Monare",
        "venue": "Coalfields",
      },
      {
        "month": "February",
        "date_start": "8",
        "date_end": null,
        "description":
            "Induction of Revs Nomvula and Zamuxolo Botha by the Vice Chair",
        "venue": "Pretoria Central",
      },
      {
        "month": "February",
        "date_start": "9",
        "date_end": "13",
        "description": "Ordinands' Seminar",
        "venue": "Lumko Retreat Centre",
      },
      {
        "month": "February",
        "date_start": "10",
        "date_end": null,
        "description": "Connexional Audit Committee Meeting",
        "venue": null,
      },
      {
        "month": "February",
        "date_start": "10",
        "date_end": null,
        "description": "Limpopo Circuit Steward's Consultative Workshop",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "10",
        "date_end": null,
        "description": "Mission Unit Advisory Board Meeting",
        "venue": "MCO",
      },
      {
        "month": "February",
        "date_start": "10",
        "date_end": null,
        "description": "MJR Coordinators' Workshop",
        "venue": "TBA",
      },
      {
        "month": "February",
        "date_start": "10",
        "date_end": "12",
        "description": "Limpopo District Minister's retreat",
        "venue": "TBA",
      },
      {
        "month": "February",
        "date_start": "11",
        "date_end": null,
        "description": "Ecumenical Affairs Advisory Board",
        "venue": "MCO",
      },
      {
        "month": "February",
        "date_start": "12",
        "date_end": null,
        "description": "Lay Training Advisory Panel Consultation",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "12",
        "date_end": null,
        "description": "Connexional Trust Property Committee",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "12",
        "date_end": "14",
        "description":
            "Young Men's Guild Connexional General Executive Committee Meeting",
        "venue": "Natal Coastal District",
      },
      {
        "month": "February",
        "date_start": "13",
        "date_end": "16",
        "description": "Women's Manyano Connexional Extended Executive Meeting",
        "venue": "NFSL District",
      },
      {
        "month": "February",
        "date_start": "13",
        "date_end": null,
        "description": "Wesley Guild Connexional General Executive Meeting",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "15",
        "date_end": null,
        "description": "Induction of Rev Sethunya Motlhodi by the Bishop",
        "venue": "Mphahlele",
      },
      {
        "month": "February",
        "date_start": "18",
        "date_end": null,
        "description": "Ash Wednesday",
        "venue": null,
      },
      {
        "month": "February",
        "date_start": "19",
        "date_end": "20",
        "description": "Connexional Heritage Standing Committee",
        "venue": "TBC",
      },
      {
        "month": "February",
        "date_start": "19",
        "date_end": "21",
        "description": "Local Preachers Association General Committee Meeting",
        "venue": "Highveld & eSwatini District",
      },
      {
        "month": "February",
        "date_start": "20",
        "date_end": "22",
        "description":
            "Limpopo District Children Ministry Indaba & MCYU Opening Service (Sunday)",
        "venue": "Hoffenhein Lodge",
      },
      {
        "month": "February",
        "date_start": "22",
        "date_end": null,
        "description": "Induction of Rev Tshepo Nkosi by the Bishop",
        "venue": "Moreleta",
      },
      {
        "month": "February",
        "date_start": "24",
        "date_end": null,
        "description": "Medical Aid Committee",
        "venue": "MCO",
      },
      {
        "month": "February",
        "date_start": "24",
        "date_end": "25",
        "description": "Order of Evangelism Coordinators Consultation",
        "venue": "Emseni",
      },
      {
        "month": "February",
        "date_start": "26",
        "date_end": null,
        "description": "Finance Unit Investment and Advisory",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "26",
        "date_end": "March 1",
        "description":
            "Connexional Women's Fellowship General Executive Committee Meeting",
        "venue": "Central District [Maranatha]",
      },
      {
        "month": "February",
        "date_start": "27",
        "date_end": null,
        "description": "Connexional MethSSoc Executive Assembly",
        "venue": "Virtual",
      },
      {
        "month": "February",
        "date_start": "27",
        "date_end": "March 1",
        "description": "Limpopo Minister's Wives retreat",
        "venue": "TBA",
      },
      {
        "month": "February",
        "date_start": "27",
        "date_end": "March 1",
        "description": "Limpopo District Music Association Annual Convention",
        "venue": "Mabopane",
      },
      {
        "month": "February",
        "date_start": "28",
        "date_end": null,
        "description": "Limpopo District Young Women's Manyano DEC",
        "venue": "Seshego",
      },
      {
        "month": "February",
        "date_start": "28",
        "date_end": "March 1",
        "description":
            "Limpopo District YAM Strategic session & YAM Mhluzi Circuit Launch",
        "venue": "Mhluzi Circuit",
      },
    ];
    final batch = FirebaseFirestore.instance.batch();
    for (var ev in events) {
      final docRef = FirebaseFirestore.instance.collection('events').doc();
      batch.set(docRef, {...ev, "createdAt": FieldValue.serverTimestamp()});
    }
    await batch.commit();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seeded 65 events!')));
    }
  }

  Future<void> _seedSocietiesData() async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final societies = [
      {
        "name": "Zion Society",
        "circuit": "Pretoria Central",
        "location": "Pretoria",
        "leader": "Rev. Smith",
      },
      {
        "name": "Ebenezer Society",
        "circuit": "Johannesburg East",
        "location": "Bedfordview",
        "leader": "Rev. Ndlovu",
      },
      {
        "name": "Central Methodist",
        "circuit": "Cape Town Central",
        "location": "Cape Town",
        "leader": "Rev. Botha",
      },
      {
        "name": "Bethel Society",
        "circuit": "Durban Coastal",
        "location": "Durban",
        "leader": "Rev. Gwala",
      },
      {
        "name": "Wesley Society",
        "circuit": "Port Elizabeth South",
        "location": "Gqeberha",
        "leader": "Rev. Jacobs",
      },
    ];

    final existingSnapshot = await FirebaseFirestore.instance
        .collection('societies')
        .get();
    final existingNames = existingSnapshot.docs
        .map(
          (doc) => (doc.data()['name'] as String? ?? '').trim().toLowerCase(),
        )
        .toSet();

    final batch = FirebaseFirestore.instance.batch();
    var addedCount = 0;
    for (var s in societies) {
      final name = (s['name'] as String).trim().toLowerCase();
      if (existingNames.contains(name)) continue;
      final docRef = FirebaseFirestore.instance.collection('societies').doc();
      batch.set(docRef, {...s, "createdAt": FieldValue.serverTimestamp()});
      addedCount++;
    }
    if (addedCount > 0) {
      await batch.commit();
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount > 0
                ? 'Seeded $addedCount new societies!'
                : 'Societies already seeded.',
          ),
        ),
      );
    }
  }
}

class _LufunoFab extends StatefulWidget {
  final VoidCallback onTap;

  const _LufunoFab({required this.onTap});

  @override
  State<_LufunoFab> createState() => _LufunoFabState();
}

class _LufunoFabState extends State<_LufunoFab> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _textRotationController;
  late final List<_GlyphLayout> _ringGlyphs;

  static const double _buttonSize = 56;
  static const double _textRadius = 46;
  static const double _ringSize = (_textRadius + 12) * 2;

  static const TextStyle _ringTextStyle = TextStyle(
    color: Color(0xFFFB8B24),
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _textRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _ringGlyphs = _layoutRingGlyphs();
  }

  // Repeats "Hi, I'm Lufuno" with a bullet separator enough times to wrap
  // fully around the ring, then measures each glyph once so the animation
  // only has to rotate a pre-laid-out arc every frame instead of
  // re-measuring text on each tick.
  List<_GlyphLayout> _layoutRingGlyphs() {
    const unit = "Hi, I'm Lufuno   •   ";
    final unitPainter = TextPainter(
      text: const TextSpan(text: unit, style: _ringTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final unitAngle = unitPainter.width / _textRadius;
    final repeatCount = (2 * math.pi / unitAngle).floor().clamp(1, 20);
    final fullText = unit * repeatCount;

    final glyphs = <_GlyphLayout>[];
    double angle = 0;
    for (final char in fullText.split('')) {
      final tp = TextPainter(
        text: TextSpan(text: char, style: _ringTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final theta = tp.width / _textRadius;
      glyphs.add(_GlyphLayout(painter: tp, angle: angle + theta / 2));
      angle += theta;
    }
    return glyphs;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textRotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Chat with Lufuno',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: _ringSize,
          height: _ringSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _textRotationController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(_ringSize, _ringSize),
                    painter: _CircularTextPainter(
                      glyphs: _ringGlyphs,
                      radius: _textRadius,
                      rotation: _textRotationController.value * 2 * math.pi,
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final t = _pulseController.value;
                  return Container(
                    width: _buttonSize + t * 22,
                    height: _buttonSize + t * 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFFB8B24,
                      ).withValues(alpha: (1 - t) * 0.25),
                    ),
                  );
                },
              ),
              Container(
                width: _buttonSize,
                height: _buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFB8B24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFB8B24).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlyphLayout {
  final TextPainter painter;
  final double angle;

  const _GlyphLayout({required this.painter, required this.angle});
}

class _CircularTextPainter extends CustomPainter {
  final List<_GlyphLayout> glyphs;
  final double radius;
  final double rotation;

  _CircularTextPainter({
    required this.glyphs,
    required this.radius,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (final glyph in glyphs) {
      canvas.save();
      canvas.rotate(glyph.angle);
      canvas.translate(-glyph.painter.width / 2, -radius);
      glyph.painter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircularTextPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.glyphs != glyphs;
  }
}

// Draws a slow, roaming light chasing itself around the tile's border -
// a subtle base ring plus a bright glint that keeps sliding away, rather
// than a static solid outline.
class _ShinyBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  static const _accent = Color(0xFFFB8B24);
  static const _strokeWidth = 1.6;

  _ShinyBorderPainter({required this.progress, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _strokeWidth / 2,
      _strokeWidth / 2,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final gradient = SweepGradient(
      transform: GradientRotation(progress * 2 * math.pi),
      colors: [
        _accent.withValues(alpha: 0.18),
        _accent.withValues(alpha: 0.7),
        Colors.white.withValues(alpha: 0.95),
        _accent.withValues(alpha: 0.7),
        _accent.withValues(alpha: 0.18),
      ],
      stops: const [0.0, 0.12, 0.2, 0.28, 1.0],
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShinyBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
