import 'package:flutter/material.dart';

import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

class TasksPanel extends StatefulWidget {
  const TasksPanel({super.key, required this.auth});
  final AuthController auth;

  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  List<WorkspaceTask> _tasks = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _filter = 'all';
  final Set<String> _mutating = {};

  List<WorkspaceTask> get _visibleTasks => _tasks.where((task) {
    if (_filter == 'open') return !task.completed;
    if (_filter == 'done') return task.completed;
    return true;
  }).toList(growable: false);

  int get _completed => _tasks.where((task) => task.completed).length;
  int get _open => _tasks.length - _completed;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.auth.listTasks();
      if (!mounted) return;
      setState(() { _tasks = result; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _notify(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _edit([WorkspaceTask? task]) async {
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (_) => _TaskEditorDialog(task: task),
    );
    if (draft == null || !mounted || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      final saved = task == null
          ? await widget.auth.createTask(
              title: draft.title,
              description: draft.description,
              dueAt: draft.dueAt,
            )
          : await widget.auth.updateTask(
              id: task.id,
              title: draft.title,
              description: draft.description,
              dueAt: draft.dueAt,
            );
      if (!mounted) return;
      setState(() {
        if (task == null) {
          _tasks = [saved, ..._tasks];
        } else {
          _tasks = _tasks.map((item) => item.id == saved.id ? saved : item).toList();
        }
      });
      _notify(task == null ? 'Задача добавлена' : 'Изменения сохранены');
    } catch (error) {
      _notify(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(WorkspaceTask task, bool completed) async {
    if (_mutating.contains(task.id)) return;
    setState(() => _mutating.add(task.id));
    try {
      final saved = await widget.auth.setTaskCompleted(task.id, completed);
      if (!mounted) return;
      setState(() {
        _tasks = _tasks.map((item) => item.id == saved.id ? saved : item).toList();
      });
    } catch (error) {
      _notify(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _mutating.remove(task.id));
    }
  }

  Future<void> _delete(WorkspaceTask task) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('«\${task.title}» будет удалена из твоего списка.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || _mutating.contains(task.id)) return;
    setState(() => _mutating.add(task.id));
    try {
      await widget.auth.deleteTask(task.id);
      if (!mounted) return;
      setState(() => _tasks.removeWhere((item) => item.id == task.id));
      _notify('Задача удалена');
    } catch (error) {
      _notify(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _mutating.remove(task.id));
    }
  }

  String _date(DateTime value) {
    final date = value.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.\${date.year}';
  }

  bool _isOverdue(WorkspaceTask task) {
    if (task.completed || task.dueAt == null) return false;
    final now = DateTime.now();
    final due = task.dueAt!.toLocal();
    return DateTime(due.year, due.month, due.day)
        .isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTasks;
    return Column(
      key: const ValueKey('workspace-tasks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WORKSPACE / TASKS',
                style: TextStyle(color: ENetColors.cyan, fontSize: 10.5,
                  letterSpacing: 1.8, fontWeight: FontWeight.w800)),
              SizedBox(height: 9),
              Text('Задачи',
                style: TextStyle(color: ENetColors.text, fontSize: 34,
                  height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1)),
              SizedBox(height: 8),
              Text('Планируй дела и отмечай выполненное.',
                style: TextStyle(color: ENetColors.muted, fontSize: 14)),
            ],
          )),
          IconButton(
            tooltip: 'Обновить задачи',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan),
          ),
        ]),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 3 : 2;
          final gap = 10.0;
          final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            _TaskMetric(width: itemWidth, label: 'Всего', value: _tasks.length,
              icon: Icons.checklist_rounded, color: ENetColors.cyan),
            _TaskMetric(width: itemWidth, label: 'В работе', value: _open,
              icon: Icons.timelapse_rounded, color: ENetColors.blue),
            _TaskMetric(width: itemWidth, label: 'Выполнено', value: _completed,
              icon: Icons.task_alt_rounded, color: ENetColors.mint),
          ]);
        }),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(child: Text('МОЙ СПИСОК',
            style: TextStyle(color: ENetColors.muted, fontSize: 10.5,
              letterSpacing: 1.7, fontWeight: FontWeight.w800))),
          FilledButton.icon(
            onPressed: (_saving || widget.auth.busy) ? null : () => _edit(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Новая задача'),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _TaskFilter(label: 'Все', value: 'all', selected: _filter,
            onSelected: (value) => setState(() => _filter = value)),
          _TaskFilter(label: 'В работе', value: 'open', selected: _filter,
            onSelected: (value) => setState(() => _filter = value)),
          _TaskFilter(label: 'Выполненные', value: 'done', selected: _filter,
            onSelected: (value) => setState(() => _filter = value)),
        ]),
        const SizedBox(height: 14),
        if (_loading && _tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _tasks.isEmpty)
          Glass(
            radius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Icon(Icons.cloud_off_rounded, color: ENetColors.danger, size: 30),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: ENetColors.muted, fontSize: 13)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ]),
          )
        else if (visible.isEmpty)
          Glass(
            radius: 22,
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              Icon(_filter == 'done' ? Icons.task_alt_rounded : Icons.add_task_rounded,
                color: ENetColors.mint, size: 36),
              const SizedBox(height: 13),
              Text(
                _filter == 'done' ? 'Завершённых задач пока нет' :
                _filter == 'open' ? 'Все задачи выполнены' :
                'Список пока пуст',
                style: const TextStyle(color: ENetColors.text,
                  fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              const Text('Добавь первое дело, чтобы начать планирование.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ENetColors.muted, fontSize: 12.5, height: 1.5)),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _saving ? null : () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Создать задачу'),
              ),
            ]),
          )
        else
          for (final task in visible) ...[
            _TaskCard(
              task: task,
              overdue: _isOverdue(task),
              busy: _mutating.contains(task.id),
              dateLabel: task.dueAt == null ? null : _date(task.dueAt!),
              onToggle: (value) => _toggle(task, value),
              onEdit: () => _edit(task),
              onDelete: () => _delete(task),
            ),
            const SizedBox(height: 10),
          ],
        if (_error != null && _tasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Не удалось обновить список: $_error',
              style: const TextStyle(color: ENetColors.danger, fontSize: 12)),
          ),
        if (_loading && _tasks.isNotEmpty) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        const Text('Задачи хранятся в аккаунте eNet ID и доступны после входа на другом устройстве.',
          style: TextStyle(color: ENetColors.faint, fontSize: 11.5, height: 1.45)),
      ],
    );
  }
}

class _TaskMetric extends StatelessWidget {
  const _TaskMetric({
    required this.width, required this.label, required this.value,
    required this.icon, required this.color,
  });
  final double width;
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Glass(
      radius: 18, blur: 10, shadow: false,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: const TextStyle(color: ENetColors.text,
            fontSize: 21, fontWeight: FontWeight.w800)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ENetColors.muted, fontSize: 11)),
        ])),
      ]),
    ),
  );
}

class _TaskFilter extends StatelessWidget {
  const _TaskFilter({
    required this.label, required this.value, required this.selected,
    required this.onSelected,
  });
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    onSelected: (_) => onSelected(value),
    selectedColor: ENetColors.mint.withValues(alpha: .17),
    side: BorderSide(color: selected == value
      ? ENetColors.mint.withValues(alpha: .35) : ENetColors.border),
    labelStyle: TextStyle(
      color: selected == value ? ENetColors.text : ENetColors.muted,
      fontSize: 12, fontWeight: FontWeight.w600,
    ),
    backgroundColor: ENetColors.surface,
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task, required this.overdue, required this.busy,
    required this.dateLabel, required this.onToggle, required this.onEdit,
    required this.onDelete,
  });
  final WorkspaceTask task;
  final bool overdue;
  final bool busy;
  final String? dateLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Glass(
    radius: 19, blur: 10, shadow: false,
    padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Checkbox.adaptive(
        value: task.completed,
        onChanged: busy ? null : (value) => onToggle(value ?? false),
        activeColor: ENetColors.mint,
        checkColor: ENetColors.onAccent,
      ),
      Expanded(child: InkWell(
        onTap: busy ? null : onEdit,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: task.completed ? ENetColors.muted : ENetColors.text,
                fontSize: 14, fontWeight: FontWeight.w700,
                decoration: task.completed ? TextDecoration.lineThrough : null,
              )),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ENetColors.muted, fontSize: 11.5, height: 1.4)),
            ],
            if (dateLabel != null) ...[
              const SizedBox(height: 7),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 12,
                  color: overdue ? ENetColors.danger : ENetColors.faint),
                const SizedBox(width: 5),
                Text(
                  overdue ? 'Просрочено · $dateLabel' : 'Срок · $dateLabel',
                  style: TextStyle(color: overdue ? ENetColors.danger : ENetColors.faint,
                    fontSize: 10.5, fontWeight: overdue ? FontWeight.w700 : FontWeight.w500),
                ),
              ]),
            ],
          ]),
        ),
      )),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(10),
          child: SizedBox(width: 17, height: 17,
            child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else
        PopupMenuButton<String>(
          tooltip: 'Действия с задачей',
          icon: const Icon(Icons.more_horiz_rounded, color: ENetColors.muted),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Изменить')),
            PopupMenuItem(value: 'delete', child: Text('Удалить')),
          ],
        ),
    ]),
  );
}

class _TaskDraft {
  const _TaskDraft({
    required this.title, required this.description, required this.dueAt,
  });
  final String title;
  final String description;
  final DateTime? dueAt;
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.task});
  final WorkspaceTask? task;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.task?.description ?? '');
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _dueAt = widget.task?.dueAt?.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.\${date.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
      helpText: 'Срок выполнения',
    );
    if (picked != null && mounted) {
      setState(() => _dueAt = DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  void _submit() {
    if (_form.currentState?.validate() != true) return;
    Navigator.pop(context, _TaskDraft(
      title: _title.text.trim(),
      description: _description.text.trim(),
      dueAt: _dueAt,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? 'Новая задача' : 'Изменить задачу'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Название задачи',
                hintText: 'Например, подготовить релиз eNet',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Введите название задачи' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              maxLength: 1000,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Описание',
                hintText: 'Дополнительные детали',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(_dueAt == null ? 'Добавить срок' : _date(_dueAt!)),
              )),
              if (_dueAt != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Убрать срок',
                  onPressed: () => setState(() => _dueAt = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ]),
          ],
        )),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
      FilledButton(onPressed: _submit, child: const Text('Сохранить')),
    ],
  );
}
