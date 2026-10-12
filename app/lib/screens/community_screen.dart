import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/info_hub_model.dart';
import '../services/info_hub_service.dart';

/// Information hub for browsing the church's Districts -> Circuits ->
/// Societies -> Ministers directory, laid out the same way as the circuit
/// register spreadsheet it is sourced from.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _maroon = Color(0xFF3B0D11);
  static const _bg = Color(0xFFFAF9F6);
  static const _orange = Color(0xFFFB8B24);

  // A warm accent palette (plus maroon/orange) so circuit cards read as
  // distinct at a glance instead of one flat maroon-on-white block.
  static const _accents = [
    Color(0xFFFB8B24),
    Color(0xFF2F6F63),
    Color(0xFF6B4EA0),
    Color(0xFFC1440E),
    Color(0xFF1F6F8B),
    Color(0xFF9C6B1F),
    Color(0xFF3B0D11),
  ];

  Color _accentFor(String key) =>
      _accents[key.hashCode.abs() % _accents.length];

  List<HubDistrict> _districts = [];
  bool _isLoading = true;
  bool _hasError = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final districts = await InfoHubService.loadDirectory();
    if (!mounted) return;
    setState(() {
      _districts = districts;
      _isLoading = false;
      _hasError = districts.isEmpty;
    });
  }

  bool _circuitMatches(HubCircuit circuit) {
    if (_query.isEmpty) return true;
    if (circuit.name.toLowerCase().contains(_query)) return true;
    if (circuit.code.toLowerCase().contains(_query)) return true;
    for (final society in circuit.societies) {
      if (society.name.toLowerCase().contains(_query)) return true;
      for (final appt in society.appointments) {
        if (appt.minister.fullName.toLowerCase().contains(_query)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri.parse('$scheme:$value');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showMinisterSheet(HubSociety society, HubAppointment appt) {
    final minister = appt.minister;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: _maroon.withValues(alpha: 0.12),
                  child: Text(
                    minister.fullName.isNotEmpty
                        ? minister.fullName[0].toUpperCase()
                        : 'M',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _maroon,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  minister.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _maroon,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(child: _categoryBadge(appt.categoryName)),
              const SizedBox(height: 16),
              const Divider(),
              _detailRow(Icons.church, 'Society', society.name),
              if ((minister.cellphone ?? '').isNotEmpty)
                _detailRow(
                  Icons.phone_outlined,
                  'Contact',
                  minister.cellphone!,
                ),
              if ((minister.email ?? '').isNotEmpty)
                _detailRow(Icons.email_outlined, 'Email', minister.email!),
              const SizedBox(height: 16),
              Row(
                children: [
                  if ((minister.cellphone ?? '').isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launch('tel', minister.cellphone!),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _maroon,
                          side: const BorderSide(color: _maroon),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if ((minister.cellphone ?? '').isNotEmpty &&
                      (minister.email ?? '').isNotEmpty)
                    const SizedBox(width: 12),
                  if ((minister.email ?? '').isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launch('mailto', minister.email!),
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _maroon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _orange),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _maroon,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: _maroon,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Circuits & Societies',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_maroon),
                ),
              )
            : _hasError
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _load,
                color: _maroon,
                child: Column(
                  children: [
                    _buildStatsBanner(),
                    _buildSearchBar(),
                    Expanded(child: _buildDirectoryList()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsBanner() {
    final circuitCount = _districts.fold<int>(
      0,
      (sum, d) => sum + d.circuits.length,
    );
    final societyCount = _districts.fold<int>(
      0,
      (sum, d) => sum + d.circuits.fold(0, (s, c) => s + c.societies.length),
    );
    final ministerIds = <String>{};
    for (final d in _districts) {
      for (final c in d.circuits) {
        for (final s in c.societies) {
          for (final a in s.appointments) {
            ministerIds.add(a.minister.id);
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [_maroon, Color(0xFF5A151C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              Icons.account_tree_outlined,
              '$circuitCount',
              'Circuits',
            ),
          ),
          _statDivider(),
          Expanded(
            child: _buildStatItem(
              Icons.church_outlined,
              '$societyCount',
              'Societies',
            ),
          ),
          _statDivider(),
          Expanded(
            child: _buildStatItem(
              Icons.person_outline,
              '${ministerIds.length}',
              'Ministers',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: _orange, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Leadership roles get a solid maroon pill; other appointments get a
  /// lighter orange-outlined pill, so hierarchy reads at a glance.
  Widget _categoryBadge(String category) {
    final isLeadership =
        category.toLowerCase().contains('bishop') ||
        category.toLowerCase().contains('superintendent');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isLeadership ? _maroon : _orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: isLeadership
            ? null
            : Border.all(color: _orange.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isLeadership ? Colors.white : _maroon,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search circuit, society or minister...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'Circuit directory unavailable',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryList() {
    final children = <Widget>[];
    for (final district in _districts) {
      final visibleCircuits = district.circuits.where(_circuitMatches).toList();
      if (visibleCircuits.isEmpty) continue;

      if (_districts.length > 1) {
        children.add(_buildDistrictHeader(district));
      }
      for (final circuit in visibleCircuits) {
        children.add(_buildCircuitCard(circuit));
      }
    }

    if (children.isEmpty) {
      return Center(
        child: Text(
          'No matches for "$_query"',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: children,
    );
  }

  Widget _buildDistrictHeader(HubDistrict district) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        district.name.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildCircuitCard(HubCircuit circuit) {
    final lead = circuit.leadAppointment;
    final accent = _accentFor(circuit.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            iconColor: accent,
            collapsedIconColor: accent.withValues(alpha: 0.7),
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              circuit.code.isNotEmpty ? circuit.code : '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          title: Text(
            circuit.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _maroon,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: lead != null
                ? Row(
                    children: [
                      Flexible(
                        child: Text(
                          lead.minister.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _categoryBadge(lead.categoryName),
                    ],
                  )
                : Text(
                    'Minister not assigned',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Text(
              '${circuit.societies.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
          children: circuit.societies
              .map((s) => _buildSocietyRow(s, accent))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSocietyRow(HubSociety society, Color accent) {
    final appt = society.appointments.isNotEmpty
        ? society.appointments.first
        : null;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      leading: Icon(Icons.church_outlined, size: 18, color: accent),
      title: Text(
        society.name,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: _maroon,
        ),
      ),
      subtitle: appt != null
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      appt.minister.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _categoryBadge(appt.categoryName),
                ],
              ),
            )
          : Text(
              'No minister assigned',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[400]),
            ),
      trailing: appt != null
          ? Icon(Icons.chevron_right, size: 18, color: accent)
          : null,
      onTap: appt != null ? () => _showMinisterSheet(society, appt) : null,
    );
  }
}
