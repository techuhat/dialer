import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/call_log_entry.dart' as call_log;
import '../core/services/call_log_service.dart';
import '../core/utils/format_utils.dart';
import '../core/call_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  static const LinearGradient _backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1929), Color(0xFF1C3A5E)],
  );

  late TabController _tabController;
  List<call_log.CallLogEntry> _allCalls = [];
  List<call_log.CallLogEntry> _recentCalls = [];
  List<call_log.CallLogEntry> _missedCalls = [];
  bool _isLoading = true;
  String _selectedSort = 'Recent';
  StreamSubscription<void>? _callLogSubscription;
  
  final List<String> _sortOptions = ['Recent', 'Oldest', 'Duration', 'Name', 'Type'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _callLogSubscription = CallLogService.changes.listen((_) {
      if (mounted) {
        _loadCallHistory(showLoader: false);
      }
    });
    _loadCallHistory();
  }

  @override
  void dispose() {
    _callLogSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCallHistory({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Load call logs from database - now enriched with real contact names
      final allCalls = await CallLogService.getAllCallLogs();
      final recentCalls = await CallLogService.getRecentCalls();
      final missedCalls = await CallLogService.getMissedCalls();

      if (!mounted) return;

      setState(() {
        _allCalls = allCalls;
        _recentCalls = recentCalls;
        _missedCalls = missedCalls;
        _isLoading = false;
      });

      debugPrint('Loaded ${allCalls.length} calls, ${recentCalls.length} recent, ${missedCalls.length} missed');
    } catch (e) {
      if (!mounted) return;
      if (showLoader) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading call history: $e');
    }
  }

  List<call_log.CallLogEntry> _getSortedCalls(List<call_log.CallLogEntry> calls) {
    final sortedCalls = List<call_log.CallLogEntry>.from(calls);
    
    switch (_selectedSort) {
      case 'Recent':
        sortedCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Oldest':
        sortedCalls.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'Duration':
        sortedCalls.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case 'Name':
        sortedCalls.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        break;
      case 'Type':
        sortedCalls.sort((a, b) => a.type.index.compareTo(b.type.index));
        break;
    }
    
    return sortedCalls;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header with sort options
              _buildHeader(context),
              // Tab bar
              _buildTabBar(),
              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call History',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review and manage your call logs',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF90B0CB),
                      ),
                    ),
                  ],
                ),
              ),
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: DropdownButton<String>(
                  value: _selectedSort,
                  dropdownColor: const Color(0xFF1C3A5E),
                  underline: Container(),
                  icon: const Icon(Icons.sort, color: Colors.white70, size: 20),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  items: _sortOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSort = newValue;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF42A5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        isScrollable: false,
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'All ${_allCalls.length}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Recent ${_recentCalls.length}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.call_missed, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Missed ${_missedCalls.length}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCallList(_getSortedCalls(_allCalls)),
        _buildCallList(_getSortedCalls(_recentCalls)),
        _buildCallList(_getSortedCalls(_missedCalls)),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
      ),
    );
  }

  Widget _buildCallList(List<call_log.CallLogEntry> calls) {
    if (calls.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadCallHistory(showLoader: false),
      backgroundColor: const Color(0xFF1C3A5E),
      color: const Color(0xFF42A5F5),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        itemCount: calls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildCallLogItem(calls[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_outlined,
              size: 48,
              color: Color(0xFF90B0CB),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No calls found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF90B0CB),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCallLogItem(call_log.CallLogEntry callLog) {
    final visuals = _CallTypeVisuals.fromType(callLog.type);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(callLog.isRead ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: callLog.isRead 
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFF42A5F5).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCallDetails(callLog),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                // Call type icon
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: visuals.badgeColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(visuals.icon, color: visuals.badgeColor, size: 24),
                ),
                const SizedBox(width: 16),
                // Call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              callLog.displayName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!callLog.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF42A5F5),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PhoneUtils.formatPhoneNumber(callLog.number),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFB0BEC5),
                        ),
                      ),
                      if (callLog.duration > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          TimeUtils.formatDuration(callLog.duration),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF90B0CB),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Time and action
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      TimeUtils.formatCallTimestamp(callLog.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF90B0CB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF42A5F5),
                            Color(0xFF1E88E5),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _makeCall(callLog.number),
                          borderRadius: BorderRadius.circular(20),
                          splashColor: Colors.white.withOpacity(0.2),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Call',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCallDetails(call_log.CallLogEntry callLog) {
    // Mark as read if it's unread
    if (!callLog.isRead) {
      CallLogService.markAsRead(callLog.id);
      _loadCallHistory();
    }
    
    // Show call details bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CallDetailsBottomSheet(callLog: callLog),
    );
  }

  Future<void> _makeCall(String number) async {
    HapticFeedback.selectionClick();
    try {
      final success = await CallService.makeCall(number);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to make call'),
              backgroundColor: Color(0xFFE53935),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }
}

// Helper classes
class _CallTypeVisuals {
  final IconData icon;
  final Color badgeColor;
  final String displayText;

  const _CallTypeVisuals({
    required this.icon,
    required this.badgeColor,
    required this.displayText,
  });

  static _CallTypeVisuals fromType(call_log.CallType type) {
    switch (type) {
      case call_log.CallType.outgoing:
        return const _CallTypeVisuals(
          icon: Icons.call_made,
          badgeColor: Color(0xFF66BB6A),
          displayText: 'Outgoing',
        );
      case call_log.CallType.incoming:
        return const _CallTypeVisuals(
          icon: Icons.call_received,
          badgeColor: Color(0xFF42A5F5),
          displayText: 'Incoming',
        );
      case call_log.CallType.missed:
        return const _CallTypeVisuals(
          icon: Icons.call_missed,
          badgeColor: Color(0xFFE53935),
          displayText: 'Missed',
        );
    }
  }
}

// Call Details Bottom Sheet
class _CallDetailsBottomSheet extends StatelessWidget {
  final call_log.CallLogEntry callLog;

  const _CallDetailsBottomSheet({required this.callLog});

  @override
  Widget build(BuildContext context) {
    final visuals = _CallTypeVisuals.fromType(callLog.type);
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C3A5E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Call info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: visuals.badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(visuals.icon, color: visuals.badgeColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      callLog.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      PhoneUtils.formatPhoneNumber(callLog.number),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFB0BEC5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Call details
          _buildDetailRow(context, 'Type', visuals.displayText, visuals.badgeColor),
          _buildDetailRow(context, 'Time', TimeUtils.formatCallTimestamp(callLog.timestamp), Colors.white70),
          if (callLog.duration > 0)
            _buildDetailRow(context, 'Duration', TimeUtils.formatDuration(callLog.duration), Colors.white70),
          
          const SizedBox(height: 32),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _makeCallFromDetails(callLog.number, context);
                  },
                  icon: const Icon(Icons.call, size: 20),
                  label: const Text('Call Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendMessage(callLog.number, context);
                  },
                  icon: const Icon(Icons.message, size: 20),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF42A5F5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF90B0CB),
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCallFromDetails(String number, BuildContext context) async {
    HapticFeedback.selectionClick();
    try {
      final success = await CallService.makeCall(number);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to make call'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  Future<void> _sendMessage(String number, BuildContext context) async {
    // Implementation for SMS functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message functionality will be implemented')),
    );
  }
}
