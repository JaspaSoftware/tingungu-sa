import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/society_model.dart';
import '../services/society_service.dart';


class SocietySelectionPage extends StatefulWidget {
  final String currentSociety;
  static const String id = "societySelectionScreen";

  const SocietySelectionPage({super.key, required this.currentSociety});

  @override
  State<SocietySelectionPage> createState() => _SocietySelectionPageState();
}

class _SocietySelectionPageState extends State<SocietySelectionPage> {
  List<Society> societies = [];
  List<Society> filteredSocieties = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSocieties();
  }

  Future<void> fetchSocieties() async {
    try {
      final data = await SocietyService.getAllSocieties();
      setState(() {
        societies = data;
        filteredSocieties = societies;
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching societies: $e');
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  void filterSocieties(String query) {
    setState(() {
      filteredSocieties = societies
          .where((society) =>
          society.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> updateSociety(String selectedSociety) async {
    setState(() {
      isLoading = true;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await SocietyService.joinSociety(userId, selectedSociety);
    }

    if (mounted) {
      Navigator.pop(context); // close screen after saving
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF3B0D11),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Select Society',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B0D11)))
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search society...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF3B0D11)),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: filterSocieties,
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        8,
                        0,
                        MediaQuery.of(context).padding.bottom + 16,
                      ),
                      itemCount: filteredSocieties.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final society = filteredSocieties[index];
                        final isSelected = society.name == widget.currentSociety;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text(
                            society.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF3B0D11) : Colors.black87,
                            ),
                          ),
                          subtitle: society.circuit != null ? Text(society.circuit!, style: const TextStyle(fontSize: 12)) : null,
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFFFB8B24))
                              : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () => updateSociety(society.name),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
