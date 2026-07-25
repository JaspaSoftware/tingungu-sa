import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/avatar_utils.dart';
import 'society_selection_screen.dart';
import 'login_screen.dart';

class ProfilePage extends StatefulWidget {
  static const String id = "profileScreen";

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  String? _optimisticAvatar;

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  Future<void> _updateField(String field, String currentValue, String title) async {
    TextEditingController controller = TextEditingController(text: currentValue);
    String? newValue = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $title', style: const TextStyle(color: Color(0xFF3B0D11))),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter $title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B0D11)),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newValue != null && newValue.trim().isNotEmpty && newValue != currentValue) {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        field: newValue.trim(),
      });
      _checkProfileCompletion();
    }
  }

  Future<void> _showDobPicker(String currentDob) async {
    int selectedDay = 1;
    String selectedMonth = 'January';
    int activeMode = 0; // 0 = Visual Dropdown/Calendar, 1 = Type Digits

    final TextEditingController digitController = TextEditingController(text: currentDob);

    // Try parsing existing DOB
    if (currentDob.isNotEmpty) {
      final parts = currentDob.split(' ');
      if (parts.length >= 2) {
        final parsedDay = int.tryParse(parts[0]);
        if (parsedDay != null && parsedDay >= 1 && parsedDay <= 31) {
          selectedDay = parsedDay;
        }
        final matchedMonth = _months.firstWhere(
          (m) => m.toLowerCase().startsWith(parts[1].toLowerCase()),
          orElse: () => 'January',
        );
        selectedMonth = matchedMonth;
      }
    }

    String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomSafeArea = MediaQuery.of(context).padding.bottom;
            final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: keyboardPadding + bottomSafeArea + 24,
                  ),
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
                        'Set Birthday (Day & Month)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B0D11),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select your birth day and month below:',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 20),

                      // Mode Switch Segmented Control
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => activeMode = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: activeMode == 0 ? const Color(0xFF3B0D11) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_month,
                                        size: 18,
                                        color: activeMode == 0 ? Colors.white : Colors.grey[700],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Choose Date',
                                        style: TextStyle(
                                          color: activeMode == 0 ? Colors.white : Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => activeMode = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: activeMode == 1 ? const Color(0xFF3B0D11) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: activeMode == 1 ? Colors.white : Colors.grey[700],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Type Digits',
                                        style: TextStyle(
                                          color: activeMode == 1 ? Colors.white : Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Mode 0: Visual Selectors (Day & Month Dropdowns + Full Calendar)
                      if (activeMode == 0) ...[
                        Row(
                          children: [
                            // Day Dropdown
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: selectedDay,
                                        isExpanded: true,
                                        items: List.generate(31, (i) => i + 1)
                                            .map((day) => DropdownMenuItem<int>(
                                                  value: day,
                                                  child: Text('$day', style: const TextStyle(fontSize: 15)),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setModalState(() => selectedDay = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Month Dropdown
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedMonth,
                                        isExpanded: true,
                                        items: _months
                                            .map((month) => DropdownMenuItem<String>(
                                                  value: month,
                                                  child: Text(month, style: const TextStyle(fontSize: 15)),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setModalState(() => selectedMonth = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Calendar Picker Button
                        OutlinedButton.icon(
                          onPressed: () {
                            _showCustomCalendarDialog(
                              context,
                              selectedDay,
                              selectedMonth,
                              (day, month) {
                                setModalState(() {
                                  selectedDay = day;
                                  selectedMonth = month;
                                });
                              },
                            );
                          },
                          icon: const Icon(Icons.calendar_today, color: Color(0xFFFB8B24), size: 18),
                          label: const Text('Open Full Calendar Picker', style: TextStyle(color: Color(0xFFFB8B24))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFB8B24)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size.fromHeight(45),
                          ),
                        ),
                      ]
                      // Mode 1: Manual Digit Input (DD/MM or Day Month)
                      else ...[
                        TextFormField(
                          controller: digitController,
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(
                            labelText: 'Enter Birthday (e.g. 14 June or 14/06)',
                            hintText: '14 June',
                            prefixIcon: const Icon(Icons.edit_calendar, color: Color(0xFFFB8B24)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tip: Type your day and month (e.g. "14 June" or "14/06")',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (activeMode == 0) {
                              Navigator.pop(context, '$selectedDay $selectedMonth');
                            } else {
                              final text = digitController.text.trim();
                              if (text.isNotEmpty) {
                                Navigator.pop(context, text);
                              } else {
                                Navigator.pop(context);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B0D11),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Save Birthday', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && result.trim().isNotEmpty && result != currentDob) {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        'dob': result.trim(),
      });
      _checkProfileCompletion();
    }
  }

  Future<void> _showCustomCalendarDialog(
    BuildContext context,
    int initialDay,
    String initialMonth,
    Function(int day, String month) onSelected,
  ) async {
    int tempMonthIndex = _months.indexOf(initialMonth);
    if (tempMonthIndex < 0) tempMonthIndex = 0;
    int tempDay = initialDay;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final monthName = _months[tempMonthIndex];
            final daysInMonth = DateTime(2000, tempMonthIndex + 2, 0).day;
            final firstWeekday = DateTime(2000, tempMonthIndex + 1, 1).weekday % 7;

            if (tempDay > daysInMonth) tempDay = daysInMonth;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Birthday',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month Switcher Row (< Month >)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFF3B0D11)),
                          onPressed: () {
                            setDialogState(() {
                              tempMonthIndex = (tempMonthIndex - 1 + 12) % 12;
                            });
                          },
                        ),
                        Text(
                          monthName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFF3B0D11)),
                          onPressed: () {
                            setDialogState(() {
                              tempMonthIndex = (tempMonthIndex + 1) % 12;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Weekday Headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map((day) => SizedBox(
                                width: 36,
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),

                    // Calendar Grid (1..31)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: firstWeekday + daysInMonth,
                      itemBuilder: (context, index) {
                        if (index < firstWeekday) {
                          return const SizedBox.shrink();
                        }
                        final dayNum = index - firstWeekday + 1;
                        final isSelected = dayNum == tempDay;

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              tempDay = dayNum;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFB8B24) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSelected(tempDay, _months[tempMonthIndex]);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B0D11),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkProfileCompletion() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      final displayname = data['displayname'] ?? '';
      final society = data['society'] ?? '';
      final dob = data['dob'] ?? '';
      if (displayname.isNotEmpty && society.isNotEmpty && dob.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
          'profile_completed': true,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 16)),
          backgroundColor: const Color(0xFF3B0D11),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle_outlined, size: 80, color: Color(0xFF3B0D11)),
                const SizedBox(height: 16),
                const Text(
                  'Guest User',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Log in to edit your profile, select your society, and view transactions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Log In / Register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFB8B24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF3B0D11),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF3B0D11)));
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

            String avatarUrl = _optimisticAvatar ?? userData['avatar'] ?? '';
            String displayName = userData['displayname'] ?? '';
            String society = userData['society'] ?? '';
            String dob = userData['dob'] ?? '';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => AvatarUtils.showAvatarUploadOptions(
                      context,
                      currentAvatar: avatarUrl,
                      onAvatarUpdated: (newAvatar) {
                        setState(() {
                          _optimisticAvatar = newAvatar;
                        });
                      },
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          key: ValueKey(avatarUrl),
                          radius: 50,
                          backgroundColor: const Color(0xFF3B0D11).withValues(alpha: 0.1),
                          backgroundImage: AvatarUtils.getAvatarImageProviderOrDefault(avatarUrl),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFB8B24),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _buildProfileTile('Display Name', displayName, 'displayname'),
                _buildProfileTile('Society', society, 'society'),
                _buildProfileTile('Date of Birth (Day & Month)', dob, 'dob'),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileTile(String title, String subtitle, String field) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        subtitle: Text(
          subtitle.isNotEmpty ? subtitle : 'Not provided',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.edit, color: Color(0xFFFB8B24)),
        onTap: () async {
          if (field == 'society') {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SocietySelectionPage(currentSociety: subtitle)),
            );
            _checkProfileCompletion();
          } else if (field == 'dob') {
            _showDobPicker(subtitle);
          } else {
            _updateField(field, subtitle, title);
          }
        },
      ),
    );
  }
}

