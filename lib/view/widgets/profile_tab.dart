import 'package:flutter/material.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({required this.profileData, required this.onRefresh});

  final Map<String, dynamic>? profileData;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = profileData?['data'] as Map<String, dynamic>?;
    final name = profile?['name']?.toString().trim().isNotEmpty == true
        ? profile!['name'] as String
        : 'Pengguna';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          Text(
            'Profil Pengguna',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF21242C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF2E7BEF),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile?['email'] ?? '-',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Dibuat pada',
                    value: profile?['created_at'] ?? '-',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Terakhir diperbarui',
                    value: profile?['updated_at'] ?? '-',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF8A92A6),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF21242C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
