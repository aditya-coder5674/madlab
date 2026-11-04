class RunEvent {
  final String type;
  final Map<String, dynamic> data;

  const RunEvent(this.type, this.data);
}

class InteractiveRunSession {
  final String id;
  final Stream<RunEvent> events;

  const InteractiveRunSession({required this.id, required this.events});
}
