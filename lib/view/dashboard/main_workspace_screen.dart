import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// US-14: Citizen / Legal Advocate Main Workspace Screen (Swiss / Gemini Light Monochrome)
class MainWorkspaceScreen extends StatefulWidget {
  final String userIdentifier;
  final VoidCallback onSignOut;

  const MainWorkspaceScreen({
    super.key,
    required this.userIdentifier,
    required this.onSignOut,
  });

  @override
  State<MainWorkspaceScreen> createState() => _MainWorkspaceScreenState();
}

class _MainWorkspaceScreenState extends State<MainWorkspaceScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();

  static const List<({IconData icon, String prompt})> _suggestedTopics = [
    (
      icon: Icons.home_work_outlined,
      prompt: 'Analyze a residential tenancy agreement in Nepal',
    ),
    (
      icon: Icons.account_balance_outlined,
      prompt: 'Muluki Dewani Samhita guidelines on inheritance',
    ),
    (
      icon: Icons.domain_add_outlined,
      prompt: 'Procedure to register a private company in Kathmandu',
    ),
  ];

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  void _populatePrompt(String prompt) {
    _queryController
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    _queryFocusNode.requestFocus();
  }

  void _showWorkspaceFeedback(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: AppColors.surfacePure, fontSize: 13),
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

  void _submitOrStartConversation() {
    final draft = _queryController.text.trim();
    if (draft.isEmpty) {
      _showWorkspaceFeedback('Voice and live statutory query ready.');
      return;
    }
    _showWorkspaceFeedback('Prepared query: "$draft"');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('citizen_workspace_screen'),
      backgroundColor: AppColors.surfacePure,
      drawer: _buildWorkspaceDrawer(),
      body: Builder(
        builder: (scaffoldContext) {
          return SafeArea(
            child: Column(
              children: [
                _buildFrostedHeader(scaffoldContext),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final minBodyHeight =
                          (constraints.maxHeight - 24).clamp(0.0, double.infinity);
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 480,
                              minHeight: minBodyHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeroSection(),
                                const SizedBox(height: 28),
                                _buildSuggestedTopicsSection(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildBottomCapsuleDock(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceDrawer() {
    return Drawer(
      backgroundColor: AppColors.surfacePure,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlack,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.balance,
                      color: AppColors.surfacePure,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Wakil Legal Index',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.surfaceHighest, height: 1),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'STATUTORY COLLECTIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerTile(
                        icon: Icons.gavel_outlined,
                        title: 'Constitution of Nepal (2072)',
                        subtitle: 'Fundamental rights & state structure',
                      ),
                      const SizedBox(height: 8),
                      _buildDrawerTile(
                        icon: Icons.menu_book_outlined,
                        title: 'Muluki Dewani Samhita',
                        subtitle: 'Civil code, property & inheritance',
                      ),
                      const SizedBox(height: 8),
                      _buildDrawerTile(
                        icon: Icons.policy_outlined,
                        title: 'Muluki Apradh Samhita',
                        subtitle: 'Criminal statutes & court procedures',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onSignOut();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.surfaceHighest),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Sign Out',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedHeader(BuildContext scaffoldContext) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 56,
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
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.menu,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  tooltip: 'Workspace Menu',
                  onPressed: () {
                    Scaffold.of(scaffoldContext).openDrawer();
                  },
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlack,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.balance,
                        color: AppColors.surfacePure,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Wakil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlack,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      key: const Key('workspace_sign_out_button'),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlack.withValues(alpha: 0.05),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 24,
              color: AppColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Namaste, User',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              height: 38 / 32,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: const Text(
              'How can I assist your legal inquiry today?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textOnVariant,
                letterSpacing: -0.16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlack,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Nepal Jurisprudence • Updated 2081 B.S.',
                    textAlign: TextAlign.center,
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
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceCanvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceHighest),
            ),
            child: Column(
              children: [
                const Text(
                  'Main Legal Workspace',
                  key: Key('main_workspace_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: Citizen / Legal Advocate (${widget.userIdentifier})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedTopicsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SUGGESTED TOPICS',
                style: TextStyle(
                  fontSize: 11,
                  height: 14 / 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.55,
                ),
              ),
              Icon(
                Icons.tune,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _suggestedTopics.length; i++) ...[
          _buildPromptChip(
            icon: _suggestedTopics[i].icon,
            prompt: _suggestedTopics[i].prompt,
          ),
          if (i < _suggestedTopics.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildPromptChip({
    required IconData icon,
    required String prompt,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlack.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: () => _populatePrompt(prompt),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textOnVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 21 / 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCapsuleDock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlack.withValues(alpha: 0.10),
                      blurRadius: 6,
                      spreadRadius: -1,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.primaryBlack.withValues(alpha: 0.10),
                      blurRadius: 4,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        focusNode: _queryFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitOrStartConversation(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask Wakil...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.mic_none_outlined,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: 'Voice input',
                        onPressed: () {
                          _showWorkspaceFeedback(
                            'Voice legal dictation is available on device.',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: AppColors.primaryBlack,
                      shape: const CircleBorder(),
                      elevation: 0,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _submitOrStartConversation,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: _buildWaveformGraphic(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Wakil provides statutory legal reference under\nNepalese law, not certified legal advocacy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.44,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveformGraphic() {
    const heights = [8.0, 14.0, 16.0, 10.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < heights.length; i++) ...[
          Container(
            width: 2.5,
            height: heights[i],
            decoration: BoxDecoration(
              color: AppColors.surfacePure,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          if (i < heights.length - 1) const SizedBox(width: 2.5),
        ],
      ],
    );
  }
}
