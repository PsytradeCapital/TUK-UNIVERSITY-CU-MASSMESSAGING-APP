import 'package:flutter/material.dart';
import '../models/attendee_model.dart';
import '../repositories/offline_first_attendee_repository.dart';

class FilteredMembersScreen extends StatelessWidget {
  final String title;
  final String filterType;
  final DateTime? startDate;
  final DateTime? endDate;

  const FilteredMembersScreen({
    Key? key,
    required this.title,
    required this.filterType,
    this.startDate,
    this.endDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: FutureBuilder<List<AttendeeModel>>(
        future: OfflineFirstAttendeeRepository().getAllAttendees(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data ?? [];
          final filteredMembers = _filterMembers(members);

          if (filteredMembers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No members found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredMembers.length,
            itemBuilder: (context, index) {
              final member = filteredMembers[index];
              return _buildMemberCard(context, member);
            },
          );
        },
      ),
    );
  }

  List<AttendeeModel> _filterMembers(List<AttendeeModel> members) {
    switch (filterType) {
      case 'active':
        return members.where((m) => m.attendanceCount > 0).toList();
      case 'inactive':
        return members.where((m) => m.attendanceCount == 0).toList();
      case 'recent':
        if (startDate == null || endDate == null) return [];
        return members.where((m) {
          // Filter logic for recent attendees
          return true; // Simplified for now
        }).toList();
      case 'absent':
        if (startDate == null || endDate == null) return [];
        return members.where((m) {
          // Filter logic for absent members
          return true; // Simplified for now
        }).toList();
      default:
        return members;
    }
  }

  Widget _buildMemberCard(BuildContext context, AttendeeModel member) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.attendanceCount > 0 ? Colors.green : Colors.grey,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(member.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.phoneNumber),
            Text(
              '${member.location} • ${member.yearOfStudy ?? "N/A"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${member.attendanceCount}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'visits',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
