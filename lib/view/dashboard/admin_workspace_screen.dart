import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// US-14: Admin Console Workspace Screen (Swiss / Gemini Light Monochrome)
class AdminWorkspaceScreen extends StatefulWidget {
  final String userEmail;
  final VoidCallback onSignOut;

  const AdminWorkspaceScreen({
    super.key,
    required this.userEmail,
    required this.onSignOut,
  });

  @override
  State<AdminWorkspaceScreen> createState() => _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends State<AdminWorkspaceScreen> {
  int _selectedNavIndex = 0;
  int _selectedDayIndex = 4; // Friday peak
  bool _isQdrantSynced = false;

  static const List<({String shortDay, String fullDay, String value, double ratio})>
      _weeklyVolume = [
    (shortDay: 'M', fullDay: 'Monday', value: '6.2k', ratio: 0.59),
    (shortDay: 'T', fullDay: 'Tuesday', value: '7.1k', ratio: 0.68),
    (shortDay: 'W', fullDay: 'Wednesday', value: '8.0k', ratio: 0.77),
    (shortDay: 'T', fullDay: 'Thursday', value: '7.8k', ratio: 0.75),
    (shortDay: 'F', fullDay: 'Friday', value: '10.4k', ratio: 1.00),
    (shortDay: 'S', fullDay: 'Saturday', value: '8.4k', ratio: 0.81),
    (shortDay: 'S', fullDay: 'Sunday', value: '6.3k', ratio: 0.61),
  ];

  static const List<({IconData icon, String label})> _navItems = [
    (icon: Icons.bar_chart_rounded, label: 'Overview'),
    (icon: Icons.menu_book_outlined, label: 'Corpus'),
    (icon: Icons.people_outline, label: 'Users'),
    (icon: Icons.tune, label: 'Audit & Config'),
  ];

  void _triggerIndexSync() {
    setState(() {
      _isQdrantSynced = true;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Qdrant Vector DB index synchronized with 128k legal embeddings.',
            style: TextStyle(color: AppColors.surfacePure, fontSize: 13),
          ),
          backgroundColor: AppColors.primaryBlack,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showIngestionLogsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfacePure,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        final maxSheetHeight = MediaQuery.of(sheetContext).size.height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ingestion & Error Logs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Recent statutory pipeline & vector sync events',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLogEntry(
                    code: 'SYNC',
                    title: 'BM25 Hybrid Corpus refreshed (48 Nepal Acts)',
                    timestamp: '12m ago',
                    isAlert: false,
                  ),
                  const SizedBox(height: 8),
                  _buildLogEntry(
                    code: _isQdrantSynced ? 'SYNC' : 'WARN',
                    title: _isQdrantSynced
                        ? 'Qdrant Vector DB delta embeddings verified'
                        : 'Qdrant Vector DB awaiting scheduled delta re-index',
                    timestamp: _isQdrantSynced ? 'Just now' : '18m ago',
                    isAlert: !_isQdrantSynced,
                  ),
                  const SizedBox(height: 8),
                  _buildLogEntry(
                    code: 'OK',
                    title: 'Gemini 1.5 Pro health probe passed (280ms)',
                    timestamp: '25m ago',
                    isAlert: false,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogEntry({
    required String code,
    required String title,
    required String timestamp,
    required bool isAlert,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? AppColors.errorContainer : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isAlert
                  ? AppColors.crimsonError
                  : AppColors.primaryBlack,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.surfacePure,
                letterSpacing: 0.44,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isAlert
                        ? AppColors.onErrorContainer
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAlert
                        ? AppColors.onErrorContainer
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('admin_workspace_screen'),
      backgroundColor: AppColors.surfacePure,
      body: SafeArea(
        child: Column(
          children: [
            _buildFrostedHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildConsoleIdentityCard(),
                        const SizedBox(height: 16),
                        if (_selectedNavIndex == 0) ...[
                          _buildSystemHealthBanner(),
                          const SizedBox(height: 16),
                          _buildKpiGrid(),
                          const SizedBox(height: 16),
                          _buildQueryVolumeCard(),
                          const SizedBox(height: 16),
                          _buildRagServicesSection(),
                          const SizedBox(height: 16),
                          _buildQuickActions(),
                        ] else ...[
                          _buildSecondaryTabView(_selectedNavIndex),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildFrostedBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surfacePure.withValues(alpha: 0.80),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlack.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlack,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.balance,
                        size: 15,
                        color: AppColors.surfacePure,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Wakil Admin',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 11,
                          height: 14 / 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnVariant,
                          letterSpacing: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlack,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  key: const Key('admin_sign_out_button'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(
                    Icons.logout,
                    size: 15,
                    color: AppColors.surfacePure,
                  ),
                  onPressed: widget.onSignOut,
                  tooltip: 'Sign Out',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsoleIdentityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceHighest),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              size: 18,
              color: AppColors.primaryBlack,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Console Workspace',
                  key: Key('admin_console_title'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'Role: System Administrator (${widget.userEmail})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealthBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlack.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlack,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'All Systems Operational',
                style: TextStyle(
                  fontSize: 11,
                  height: 14 / 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.44,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Text(
              'ap-south-1 (KTM Edge)',
              style: TextStyle(
                fontSize: 11,
                height: 14 / 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnVariant,
                letterSpacing: 0.44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Total Users',
                  icon: Icons.group_outlined,
                  value: '14,820',
                  footerIcon: Icons.arrow_upward,
                  footerText: '+12% this week',
                  footerColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  title: 'Daily Queries',
                  icon: Icons.bolt,
                  value: '8,430',
                  footerIcon: Icons.trending_up,
                  footerText: '+18% vs yday',
                  footerColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Avg RAG Latency',
                  icon: Icons.speed,
                  value: '412',
                  unit: 'ms',
                  footerText: 'P95: 680ms • Fast',
                  footerColor: AppColors.textOnVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  title: 'Flagged Query',
                  icon: Icons.flag_outlined,
                  value: '14',
                  footerText: '0.16% flag rate • Low',
                  footerColor: AppColors.textOnVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required IconData icon,
    required String value,
    String? unit,
    IconData? footerIcon,
    required String footerText,
    required Color footerColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlack.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnVariant,
                    letterSpacing: 0.44,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 15, color: AppColors.textOnVariant),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: unit == null
                ? Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 30 / 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 16 / 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textOnVariant,
                          letterSpacing: 0.13,
                        ),
                      ),
                    ],
                  ),
          ),
          Row(
            children: [
              if (footerIcon != null) ...[
                Icon(footerIcon, size: 11, color: footerColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  footerText,
                  style: TextStyle(
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w600,
                    color: footerColor,
                    letterSpacing: 0.44,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueryVolumeCard() {
    final selectedDay = _weeklyVolume[_selectedDayIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlack.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QUERY VOLUME',
                      style: TextStyle(
                        fontSize: 11,
                        height: 14 / 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnVariant,
                        letterSpacing: 0.55,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text(
                          '54,210',
                          style: TextStyle(
                            fontSize: 18,
                            height: 24 / 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.18,
                          ),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'past 7 days',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textOnVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  _selectedDayIndex == 4
                      ? 'Peak: Friday'
                      : '${selectedDay.fullDay}: ${selectedDay.value}',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.44,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < _weeklyVolume.length; i++) ...[
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = i;
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Opacity(
                              opacity: _selectedDayIndex == i ? 1.0 : 0.0,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _weeklyVolume[i].value,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 14 / 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.44,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 68 * _weeklyVolume[i].ratio,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _selectedDayIndex == i
                                    ? AppColors.primaryBlack
                                    : AppColors.surfaceHighest,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _weeklyVolume[i].shortDay,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 14 / 11,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedDayIndex == i
                                      ? AppColors.textPrimary
                                      : AppColors.textOnVariant,
                                  letterSpacing: 0.44,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < _weeklyVolume.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRagServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'RAG Pipeline & Services',
                  style: TextStyle(
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.18,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '3 Active',
                style: TextStyle(
                  fontSize: 11,
                  height: 14 / 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnVariant,
                  letterSpacing: 0.44,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildServiceCard(
          icon: Icons.psychology_outlined,
          title: 'Gemini 1.5 Pro',
          statusLabel: 'Operational',
          leftMetric: 'Latency: 280ms',
          rightMetric: 'Quota: 62% remaining',
          progress: 0.62,
          isWarningStatus: false,
        ),
        const SizedBox(height: 8),
        _buildServiceCard(
          icon: Icons.dns_outlined,
          title: 'Qdrant Vector DB',
          statusLabel: _isQdrantSynced ? 'Synced' : 'Sync Pending',
          leftMetric: '128k embeddings',
          rightMetric: 'Mem: 2.1 GB / 8 GB',
          progress: _isQdrantSynced ? 0.85 : 0.26,
          isWarningStatus: !_isQdrantSynced,
        ),
        const SizedBox(height: 8),
        _buildServiceCard(
          icon: Icons.manage_search,
          title: 'BM25 Hybrid Corpus',
          statusLabel: 'Synced',
          leftMetric: '48 Nepal Acts & Codes',
          rightMetric: 'Synced 12m ago',
          progress: 1.0,
          isWarningStatus: false,
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String statusLabel,
    required String leftMetric,
    required String rightMetric,
    required double progress,
    required bool isWarningStatus,
  }) {
    final badgeBg =
        isWarningStatus ? AppColors.errorContainer : AppColors.surfaceHighest;
    final dotColor =
        isWarningStatus ? AppColors.crimsonError : AppColors.primaryBlack;
    final textColor =
        isWarningStatus ? AppColors.onErrorContainer : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlack.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 16 / 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        height: 14 / 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 0.44,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  leftMetric,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textOnVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rightMetric,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textOnVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.surfaceHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _triggerIndexSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlack,
            foregroundColor: AppColors.surfacePure,
            elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: const StadiumBorder(),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync, size: 16),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Trigger Index Sync',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _showIngestionLogsSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceHighest,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: const StadiumBorder(),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 16),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'View Ingestion & Error Logs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryTabView(int tabIndex) {
    final (String title, String subtitle, List<({String name, String meta})> rows) =
        switch (tabIndex) {
      1 => (
          'Statutory Corpus Registry',
          '48 verified Nepali legal documents indexed for RAG retrieval',
          [
            (name: 'Constitution of Nepal (2072 B.S.)', meta: '308 Articles • Synced'),
            (name: 'Muluki Dewani Samhita (2074 B.S.)', meta: '721 Sections • Synced'),
            (name: 'Muluki Apradh Samhita (2074 B.S.)', meta: '308 Sections • Synced'),
          ],
        ),
      2 => (
          'Role & Access Governance',
          'Active citizen, advocate, and @wakil.gov.np administrator accounts',
          [
            (name: 'Verified Citizen & Advocate Tier', meta: '14,792 active'),
            (name: 'System Administrators (@wakil.gov.np)', meta: '28 active'),
            (name: 'Revoked / Expired Sessions', meta: '12 logged today'),
          ],
        ),
      _ => (
          'Audit & Guardrail Config',
          'Statute compliance verifier, telemetry & token revocation policies',
          [
            (name: 'Disclaimer Enforcement Gate', meta: 'Enabled • Mandatory'),
            (name: 'Global Session Revocation Epoch', meta: 'Active • Strict'),
            (name: 'KTM Edge Telemetry Retention', meta: '30 days • Encrypted'),
          ],
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            letterSpacing: -0.18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < rows.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    rows[i].name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    rows[i].meta,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildFrostedBottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfacePure.withValues(alpha: 0.80),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlack.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    for (int i = 0; i < _navItems.length; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _selectedNavIndex = i;
                            });
                          },
                          child: SizedBox(
                            height: 52,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _navItems[i].icon,
                                  size: 18,
                                  color: _selectedNavIndex == i
                                      ? AppColors.primaryBlack
                                      : AppColors.textOnVariant,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _navItems[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 14 / 11,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedNavIndex == i
                                        ? AppColors.primaryBlack
                                        : AppColors.textOnVariant,
                                    letterSpacing: 0.44,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
