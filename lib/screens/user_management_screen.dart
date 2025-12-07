import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/accessibility_utils.dart';

/// Screen for managing users (admin only)
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserRepository _userRepository = UserRepository();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'all'; // all, approved, pending
  UserRole? _filterRole;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _userRepository.getAllUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
      _filterUsers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            user.name.toLowerCase().contains(searchQuery) ||
            user.email.toLowerCase().contains(searchQuery);

        // Status filter
        final matchesStatus = _filterStatus == 'all' ||
            (_filterStatus == 'approved' && user.isApproved) ||
            (_filterStatus == 'pending' && !user.isApproved);

        // Role filter
        final matchesRole = _filterRole == null || user.role == _filterRole;

        return matchesSearch && matchesStatus && matchesRole;
      }).toList();
    });
  }

  Future<void> _approveUser(UserModel user) async {
    try {
      await _userRepository.approveUser(user.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} has been approved'),
            backgroundColor: AppTheme.secondaryGreen,
          ),
        );
      }
      
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve user: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _revokeUser(UserModel user) async {
    try {
      await _userRepository.revokeUserAccess(user.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name}\'s access has been revoked'),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
      
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke user access: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _updateUserRole(UserModel user, UserRole newRole) async {
    try {
      await _userRepository.updateUserRole(user.uid, newRole);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name}\'s role updated to ${_getRoleDisplayName(newRole)}'),
            backgroundColor: AppTheme.secondaryGreen,
          ),
        );
      }
      
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user role: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.leader:
        return 'CU Leader';
      case UserRole.member:
        return 'Member';
    }
  }

  void _showUserDetailsDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user.email),
              const SizedBox(height: AppTheme.spacingS),
              _buildDetailRow('Role', user.getRoleDisplayName()),
              const SizedBox(height: AppTheme.spacingS),
              _buildDetailRow('Status', user.isApproved ? 'Approved' : 'Pending'),
              const SizedBox(height: AppTheme.spacingS),
              _buildDetailRow('Created', _formatDate(user.createdAt)),
              if (user.lastLoginAt != null) ...[
                const SizedBox(height: AppTheme.spacingS),
                _buildDetailRow('Last Login', _formatDate(user.lastLoginAt!)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh user list',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            color: AppTheme.surfaceGrey,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        isSelected: _filterStatus == 'all',
                        onSelected: () {
                          setState(() {
                            _filterStatus = 'all';
                          });
                          _filterUsers();
                        },
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      _buildFilterChip(
                        label: 'Approved',
                        isSelected: _filterStatus == 'approved',
                        onSelected: () {
                          setState(() {
                            _filterStatus = 'approved';
                          });
                          _filterUsers();
                        },
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      _buildFilterChip(
                        label: 'Pending',
                        isSelected: _filterStatus == 'pending',
                        onSelected: () {
                          setState(() {
                            _filterStatus = 'pending';
                          });
                          _filterUsers();
                        },
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      _buildFilterChip(
                        label: 'Admin',
                        isSelected: _filterRole == UserRole.admin,
                        onSelected: () {
                          setState(() {
                            _filterRole = _filterRole == UserRole.admin ? null : UserRole.admin;
                          });
                          _filterUsers();
                        },
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      _buildFilterChip(
                        label: 'Leader',
                        isSelected: _filterRole == UserRole.leader,
                        onSelected: () {
                          setState(() {
                            _filterRole = _filterRole == UserRole.leader ? null : UserRole.leader;
                          });
                          _filterUsers();
                        },
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      _buildFilterChip(
                        label: 'Member',
                        isSelected: _filterRole == UserRole.member,
                        onSelected: () {
                          setState(() {
                            _filterRole = _filterRole == UserRole.member ? null : UserRole.member;
                          });
                          _filterUsers();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // User list
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryBlueLight.withOpacity(0.3),
      checkmarkColor: AppTheme.primaryBlue,
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No users found matching your search'
                  : 'No users found',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      padding: const EdgeInsets.all(AppTheme.spacingS),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    final currentUser = _authService.getCurrentUser();
    final isCurrentUser = currentUser?.uid == user.uid;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingS,
      ),
      child: InkWell(
        onTap: () => _showUserDetailsDialog(user),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // User avatar
                  CircleAvatar(
                    backgroundColor: user.isApproved
                        ? AppTheme.secondaryGreen
                        : AppTheme.warningOrange,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.textOnPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (isCurrentUser)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlueLight.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              // Status and role chips
              Row(
                children: [
                  _buildStatusChip(user.isApproved),
                  const SizedBox(width: AppTheme.spacingS),
                  _buildRoleChip(user.role),
                ],
              ),
              if (!isCurrentUser) ...[
                const SizedBox(height: AppTheme.spacingM),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!user.isApproved)
                      TextButton.icon(
                        onPressed: () => _approveUser(user),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.secondaryGreen,
                        ),
                      ),
                    if (user.isApproved)
                      TextButton.icon(
                        onPressed: () => _showRevokeConfirmation(user),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Revoke'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                        ),
                      ),
                    const SizedBox(width: AppTheme.spacingS),
                    TextButton.icon(
                      onPressed: () => _showRoleChangeDialog(user),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Change Role'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isApproved
            ? AppTheme.secondaryGreen.withOpacity(0.1)
            : AppTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.check_circle : Icons.pending,
            size: 14,
            color: isApproved ? AppTheme.secondaryGreen : AppTheme.warningOrange,
          ),
          const SizedBox(width: 4),
          Text(
            isApproved ? 'Approved' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isApproved ? AppTheme.secondaryGreen : AppTheme.warningOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(UserRole role) {
    Color color;
    IconData icon;
    
    switch (role) {
      case UserRole.admin:
        color = AppTheme.primaryBlue;
        icon = Icons.admin_panel_settings;
        break;
      case UserRole.leader:
        color = AppTheme.secondaryGreen;
        icon = Icons.person;
        break;
      case UserRole.member:
        color = AppTheme.textSecondary;
        icon = Icons.person_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _getRoleDisplayName(role),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showRevokeConfirmation(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text(
          'Are you sure you want to revoke access for ${user.name}? They will no longer be able to use the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _revokeUser(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  void _showRoleChangeDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${user.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Administrator'),
              subtitle: const Text('Full access, can approve users'),
              onTap: () {
                Navigator.of(context).pop();
                _updateUserRole(user, UserRole.admin);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('CU Leader'),
              subtitle: const Text('Can register attendees and send messages'),
              onTap: () {
                Navigator.of(context).pop();
                _updateUserRole(user, UserRole.leader);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Member'),
              subtitle: const Text('Read-only access to view data'),
              onTap: () {
                Navigator.of(context).pop();
                _updateUserRole(user, UserRole.member);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
