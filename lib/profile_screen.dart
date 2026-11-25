import 'package:ai39a/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Softwarica • WakilAI",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        actions: const [
          Icon(Icons.more_horiz, color: AppColors.primary, size: 25),
          SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: AppColors.primaryContainer,
                      child: const Center(
                        child: Icon(Icons.person, size: 48, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const Column(
                    children: [
                      Text("24", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Cases", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const Column(
                    children: [
                      Text("18", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Drafts", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const Column(
                    children: [
                      Text("1.2k", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Statutes", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.security, color: AppColors.primary),
                title: const Text("Security & Sessions"),
                subtitle: const Text("2FA OTP & Active Devices"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.gavel, color: AppColors.primary),
                title: const Text("Jurisdiction Settings"),
                subtitle: const Text("Nepal Supreme Court & High Courts"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
