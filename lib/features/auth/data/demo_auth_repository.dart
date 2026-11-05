import '../domain/auth_repository.dart';

/// UI-only: accepts any validated email/password. No account is created,
/// no password is stored, and no email is sent.
class DemoAuthRepository implements AuthRepository {
  final List<WorkspaceTask> _tasks = [];
  @override
  Future<AuthUser> signIn({required String email, required String password}) async {
    return AuthUser(id: 'demo-user', email: email.trim(), name: email.trim().split('@').first);
  }

  @override
  Future<AuthUser> signUp({required String name, required String email, required String password}) async {
    return AuthUser(id: 'demo-user', email: email.trim(), name: name.trim());
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<bool> checkServer() async => false;

  @override
  Future<List<EcosystemService>> listServices() async => const [];

  @override
  Future<void> changePassword(String currentPassword, String nextPassword) async {
    throw UnsupportedError('Демо-аккаунт');
  }

  @override
  Future<int> revokeOtherSessions() async => 0;

  @override
  Future<AuthUser> updateName(String name) async =>
      AuthUser(id: 'demo-user', email: 'demo@example.org', name: name);

  @override
  Future<List<AccountSession>> listSessions() async => const [];

  @override
  Future<void> revokeSession(String sessionId) async {}

  @override
  Future<String> getApiEndpoint() async => 'http://127.0.0.1:8787';

  @override
  Future<void> setApiEndpoint(String value) async {}

  @override
  Future<List<String>> favoriteServices() async => const [];

  @override
  Future<List<String>> saveFavoriteServices(List<String> serviceIds) async =>
      List.unmodifiable(serviceIds);

  @override
  Future<NotificationFeed> listNotifications() async =>
      const NotificationFeed(notifications: [], unreadCount: 0);

  @override
  Future<void> readNotification(String id) async {}

  @override
  Future<int> readAllNotifications() async => 0;

  @override
  Future<List<WorkspaceTask>> listTasks() async =>
      List.unmodifiable(_tasks);

  @override
  Future<WorkspaceTask> createTask({
    required String title,
    required String description,
    DateTime? dueAt,
  }) async {
    final now = DateTime.now().toUtc();
    final task = WorkspaceTask(
      id: 'demo-task-${now.microsecondsSinceEpoch}',
      title: title.trim(),
      description: description.trim(),
      completed: false,
      createdAt: now,
      updatedAt: now,
      dueAt: dueAt?.toUtc(),
    );
    _tasks.insert(0, task);
    return task;
  }

  @override
  Future<WorkspaceTask> updateTask({
    required String id,
    required String title,
    required String description,
    DateTime? dueAt,
  }) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw Exception('Задача не найдена.');
    final previous = _tasks[index];
    final updated = WorkspaceTask(
      id: id, title: title.trim(), description: description.trim(),
      completed: previous.completed, createdAt: previous.createdAt,
      updatedAt: DateTime.now().toUtc(), dueAt: dueAt?.toUtc(),
    );
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<WorkspaceTask> setTaskCompleted(String id, bool completed) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw Exception('Задача не найдена.');
    final previous = _tasks[index];
    final updated = WorkspaceTask(
      id: id, title: previous.title, description: previous.description,
      completed: completed, createdAt: previous.createdAt,
      updatedAt: DateTime.now().toUtc(), dueAt: previous.dueAt,
    );
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
  }

  @override
  Future<void> signOut() async {}
}
