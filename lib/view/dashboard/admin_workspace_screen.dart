import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-14: Admin Console Workspace Screen
class AdminWorkspaceScreen extends StatelessWidget {
  final String userEmail;
  final VoidCallback onSignOut;

  const AdminWorkspaceScreen({
    super.key,
    required this.userEmail,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('admin_workspace_screen'),
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('admin_sign_out_button'),
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
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
                      child: const Icon(Icons.admin_panel_settings, color: AppColors.primaryGold, size: 34),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Admin Console Workspace',
                      key: Key('admin_console_title'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'System Governance & Audit Logs',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.crimsonRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Role: System Administrator ($userEmail)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.crimsonRed),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Administrative Modules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _buildAdminCard(Icons.verified_user, 'Statute Compliance Verifier', 'Manage legal groundings and Muluki code sync'),
              const SizedBox(height: 10),
              _buildAdminCard(Icons.security, 'Session & Security Management', 'Monitor active tokens and global revocation audits'),
              const SizedBox(height: 10),
              _buildAdminCard(Icons.analytics_outlined, 'Telemetry & Model Guardrails', 'System uptime and compliance auditing'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard(IconData icon, String title, String subtitle) {
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
