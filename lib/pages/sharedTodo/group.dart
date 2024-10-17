class Group {
  final String id;
  final String name;
  final List<String> members;

  Group({required this.id, required this.name, required this.members});

  factory Group.fromFirestore(Map<String, dynamic> data, String id) {
    return Group(
      id: id,
      name: data['name'] ?? '',
      members: List<String>.from(data['members'] ?? []),
    );
  }
}
