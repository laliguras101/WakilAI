import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-14: Citizen / Legal Advocate Main Workspace Screen
class MainWorkspaceScreen extends StatelessWidget {
  final String userIdentifier;
  final VoidCallback onSignOut;

  const MainWorkspaceScreen({
    super.key,
    required this.userIdentifier,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('citizen_workspace_screen'),
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        title: const Text('Wakil Legal Workspace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('workspace_sign_out_button'),
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryNavy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.balance, color: AppColors.primaryGold, size: 34),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Main Legal Workspace',
                      key: Key('main_workspace_title'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI Legal Analysis & Statutory Research',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Role: Citizen / Legal Advocate ($userIdentifier)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emeraldGreen),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Active Legal Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _buildFeatureCard(Icons.article_outlined, 'Muluki Ain & Penal Code Query', 'Ask natural language queries in Nepali or English'),
              const SizedBox(height: 10),
              _buildFeatureCard(Icons.folder_shared_outlined, 'Case Document Review', 'Verify petition formats against Supreme Court guidelines'),
              const SizedBox(height: 10),
              _buildFeatureCard(Icons.support_agent, 'Verified Advocate Connect', 'Connect with certified Nepal Bar Council advocates'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryNavy, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
