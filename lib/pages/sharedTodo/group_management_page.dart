import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupManagementPage extends StatefulWidget {
  final String groupId;

  const GroupManagementPage({super.key, required this.groupId});

  @override
  _GroupManagementPageState createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> {
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late bool isAdmin = false;
  late bool isCreator = false;
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();

    final groupData = groupDoc.data()!;
    isCreator = groupData['creator'] == currentUserId;
    isAdmin = groupData['admins'].contains(currentUserId);

    _groupNameController.text =
        groupData['name'] ?? 'Group'; // Pre-fill group name
    setState(() {});
  }

  Future<void> _updateGroupName() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty.')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'name': _groupNameController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group name updated successfully.')),
    );
  }

  Future<void> _deleteGroup() async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .delete();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group deleted successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Group'),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Group Name Input Field (Visible to Admins and Creator)
              if (isAdmin || isCreator)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: _groupNameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

              // Update Group Name Button
              if (isAdmin || isCreator)
                ElevatedButton.icon(
                  onPressed: _updateGroupName,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Update Group Name'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                ),

              const SizedBox(height: 16),

              // Members List
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        !snapshot.data!.exists) {
                      return const Center(
                          child: Text('Error loading group data.'));
                    }

                    final groupData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final members =
                        (groupData['members'] ?? []) as List<dynamic>;
                    final admins = (groupData['admins'] ?? []) as List<dynamic>;
                    final creator = groupData['creator'] ?? 'Unknown Creator';

                    return ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final memberId = members[index];
                        bool isMemberAdmin = admins.contains(memberId);

                        return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(memberId)
                                .get(),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const ListTile(
                                  title: Text('Loading...'),
                                  trailing: CircularProgressIndicator(),
                                );
                              }
                              if (!userSnapshot.hasData ||
                                  !userSnapshot.data!.exists) {
                                return const ListTile(
                                    title: Text('User not found'));
                              }

                              final userData = userSnapshot.data!.data()
                                  as Map<String, dynamic>;
                              final username =
                                  userData['username'] ?? 'Unknown User';

                              return Card(
                                elevation: 6,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.teal.withOpacity(1),
                                        Colors.teal.shade200,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.teal.shade300,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    title: Text(
                                      username,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: isMemberAdmin
                                        ? const Text(
                                            'Admin',
                                            style: TextStyle(
                                              color: Color.fromARGB(
                                                  255, 242, 0, 255),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : const Text(
                                            'Member',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                    trailing: _buildActionButtons(
                                        memberId, isMemberAdmin, creator),
                                  ),
                                ),
                              );
                            });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Delete Group Button (Visible to Creator Only)
              if (isCreator)
                ElevatedButton.icon(
                  onPressed: _deleteGroup,
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Delete Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      String memberId, bool isMemberAdmin, String creator) {
    if (!isAdmin) return const SizedBox(); // Only admins can manage members.

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMemberAdmin && memberId != creator)
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            onPressed: () => _removeAdmin(memberId),
            tooltip: 'Remove Admin',
          ),
        if (!isMemberAdmin)
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.teal),
            onPressed: () => _promoteToAdmin(memberId),
            tooltip: 'Make Admin',
          ),
        if (memberId != creator) // Admins can't remove the creator.
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeMember(memberId),
            tooltip: 'Remove Member',
          ),
      ],
    );
  }

  Future<void> _promoteToAdmin(String memberId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'admins': FieldValue.arrayUnion([memberId]),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Member promoted to admin.')),
    );
  }

  Future<void> _removeAdmin(String memberId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'admins': FieldValue.arrayRemove([memberId]),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin rights revoked.')),
    );
  }

  Future<void> _removeMember(String memberId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'members': FieldValue.arrayRemove([memberId]),
      'admins': FieldValue.arrayRemove([memberId]),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Member removed from group.')),
    );
  }
}
