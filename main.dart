import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ------------------------------
// MODEL CLASSES
// ------------------------------
class Task {
  int? id;
  String title;
  String description;
  DateTime dueDate;
  bool isCompleted;
  String repeatType; // "none", "daily", "weekly"
  List<int> repeatDays; // For weekly: 1=Monday, 7=Sunday
  List<Subtask> subtasks;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.isCompleted = false,
    this.repeatType = "none",
    this.repeatDays = const <int>[],
    this.subtasks = const <Subtask>[],
  });

  double get progress {
    if (subtasks.isEmpty) {
      return isCompleted ? 1.0 : 0.0;
    }
    final int completed = subtasks.where((Subtask sub) => sub.isCompleted).length;
    return completed / subtasks.length;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
      'repeatType': repeatType,
      'repeatDays': repeatDays.join(','),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, List<Subtask> subs) {
    final String repeatDaysRaw = (map['repeatDays'] ?? '').toString();
    final List<int> days = repeatDaysRaw.isNotEmpty
        ? repeatDaysRaw.split(',').where((String value) => value.isNotEmpty).map(int.parse).toList()
        : <int>[];

    return Task(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int),
      isCompleted: map['isCompleted'] == 1,
      repeatType: map['repeatType'] as String? ?? 'none',
      repeatDays: days,
      subtasks: subs,
    );
  }
}

class Subtask {
  int? id;
  int taskId;
  String title;
  bool isCompleted;

  Subtask({
    this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'taskId': taskId,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as int?,
      taskId: map['taskId'] as int,
      title: map['title'] as String? ?? '',
      isCompleted: map['isCompleted'] == 1,
    );
  }
}

// ------------------------------
// DATABASE HELPER
// ------------------------------
class DBHelper {
  static Database? _db;
  static int _webNextTaskId = 1;
  static final List<Task> _webTasks = <Task>[];

  static final DBHelper instance = DBHelper._privateConstructor();
  DBHelper._privateConstructor();

  Future<Database> get db async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final String path = '${dir.path}/tasks.db';

    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            description TEXT,
            dueDate INTEGER,
            isCompleted INTEGER,
            repeatType TEXT,
            repeatDays TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE subtasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            taskId INTEGER,
            title TEXT,
            isCompleted INTEGER,
            FOREIGN KEY (taskId) REFERENCES tasks(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Task _cloneTask(Task task, {int? idOverride}) {
    final int? taskId = idOverride ?? task.id;
    return Task(
      id: taskId,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      isCompleted: task.isCompleted,
      repeatType: task.repeatType,
      repeatDays: List<int>.from(task.repeatDays),
      subtasks: task.subtasks
          .asMap()
          .entries
          .map(
            (MapEntry<int, Subtask> entry) => Subtask(
              id: entry.value.id ?? (entry.key + 1),
              taskId: taskId ?? entry.value.taskId,
              title: entry.value.title,
              isCompleted: entry.value.isCompleted,
            ),
          )
          .toList(),
    );
  }

  Future<int> insertTask(Task task) async {
    if (kIsWeb) {
      final int id = task.id ?? _webNextTaskId++;
      final Task cloned = _cloneTask(task, idOverride: id);
      _webTasks.removeWhere((Task current) => current.id == id);
      _webTasks.add(cloned);
      return id;
    }

    final Database database = await instance.db;
    final int id = await database.insert('tasks', task.toMap());
    for (final Subtask sub in task.subtasks) {
      sub.taskId = id;
      await database.insert('subtasks', sub.toMap());
    }
    return id;
  }

  Future<List<Task>> getTasks() async {
    if (kIsWeb) {
      final List<Task> copy = _webTasks.map((Task task) => _cloneTask(task)).toList();
      copy.sort((Task a, Task b) => a.dueDate.compareTo(b.dueDate));
      return copy;
    }

    final Database database = await instance.db;
    final List<Map<String, Object?>> taskMaps = await database.query('tasks');
    final List<Task> tasks = <Task>[];

    for (final Map<String, Object?> map in taskMaps) {
      final List<Map<String, Object?>> subMaps = await database.query(
        'subtasks',
        where: 'taskId = ?',
        whereArgs: <Object?>[map['id']],
      );
      final List<Subtask> subs = subMaps
          .map((Map<String, Object?> subMap) => Subtask.fromMap(subMap))
          .toList();
      tasks.add(Task.fromMap(map, subs));
    }
    tasks.sort((Task a, Task b) => a.dueDate.compareTo(b.dueDate));
    return tasks;
  }

  Future<void> updateTask(Task task) async {
    if (kIsWeb) {
      final int index = _webTasks.indexWhere((Task current) => current.id == task.id);
      if (index == -1) {
        return;
      }
      _webTasks[index] = _cloneTask(task);
      return;
    }

    final Database database = await instance.db;
    await database.update('tasks', task.toMap(), where: 'id = ?', whereArgs: <Object?>[task.id]);
    await database.delete('subtasks', where: 'taskId = ?', whereArgs: <Object?>[task.id]);
    for (final Subtask sub in task.subtasks) {
      sub.taskId = task.id!;
      await database.insert('subtasks', sub.toMap());
    }
  }

  Future<void> deleteTask(int id) async {
    if (kIsWeb) {
      _webTasks.removeWhere((Task task) => task.id == id);
      return;
    }

    final Database database = await instance.db;
    await database.delete('tasks', where: 'id = ?', whereArgs: <Object?>[id]);
    await database.delete('subtasks', where: 'taskId = ?', whereArgs: <Object?>[id]);
  }
}

// ------------------------------
// MAIN APP
// ------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    tz_data.initializeTimeZones();
    final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();
    await notif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void toggleThemeOf(BuildContext context) {
    context.findAncestorStateOfType<_MyAppState>()?.toggleTheme();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D8A72),
      brightness: brightness,
    );

    final TextTheme textTheme = GoogleFonts.spaceGroteskTextTheme(
      ThemeData(brightness: brightness, useMaterial3: true).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: const TaskHomeScreen(),
    );
  }
}

class TaskHomeScreen extends StatefulWidget {
  const TaskHomeScreen({super.key});

  @override
  State<TaskHomeScreen> createState() => _TaskHomeScreenState();
}

class _TaskHomeScreenState extends State<TaskHomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  List<Task> _allTasks = <Task>[];

  final DBHelper _db = DBHelper.instance;
  final FlutterLocalNotificationsPlugin _notifPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _requestNotifPermission();
  }

  Future<void> _requestNotifPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _notifPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _loadTasks() async {
    try {
      final List<Task> tasks = await _db.getTasks();
      if (!mounted) {
        return;
      }
      setState(() {
        _allTasks = tasks;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showMessage('Unable to load tasks for this platform.');
    }
  }

  List<Task> get _todayTasks {
    final DateTime now = DateTime.now();
    return _allTasks.where((Task task) {
      return !task.isCompleted &&
          task.dueDate.year == now.year &&
          task.dueDate.month == now.month &&
          task.dueDate.day == now.day;
    }).toList();
  }

  List<Task> get _completedTasks => _allTasks.where((Task task) => task.isCompleted).toList();
  List<Task> get _repeatingTasks => _allTasks.where((Task task) => task.repeatType != 'none').toList();

  List<Task> get _currentList {
    switch (_selectedIndex) {
      case 0:
        return _todayTasks;
      case 1:
        return _completedTasks;
      default:
        return _repeatingTasks;
    }
  }

  String get _activeSectionLabel {
    switch (_selectedIndex) {
      case 0:
        return 'Today';
      case 1:
        return 'Completed';
      default:
        return 'Repeating';
    }
  }

  Future<void> _showTaskForm([Task? existingTask]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return TaskFormDialog(existingTask: existingTask, onSave: _loadTasks);
      },
    );
  }

  Future<void> _markComplete(Task task) async {
    task.isCompleted = !task.isCompleted;

    if (task.isCompleted && task.repeatType != 'none') {
      if (task.repeatType == 'daily') {
        task.dueDate = task.dueDate.add(const Duration(days: 1));
        task.isCompleted = false;
      } else if (task.repeatType == 'weekly' && task.repeatDays.isNotEmpty) {
        final int currentDay = task.dueDate.weekday;
        final int nextDay = task.repeatDays.firstWhere(
          (int day) => day > currentDay,
          orElse: () => task.repeatDays.first,
        );
        final int diff = nextDay > currentDay ? nextDay - currentDay : (7 - currentDay) + nextDay;
        task.dueDate = task.dueDate.add(Duration(days: diff));
        task.isCompleted = false;
      }

      for (final Subtask sub in task.subtasks) {
        sub.isCompleted = false;
      }
    }

    await _db.updateTask(task);
    if (!task.isCompleted) {
      await _scheduleNotification(task);
    }
    await _loadTasks();
  }

  Future<void> _scheduleNotification(Task task) async {
    if (kIsWeb || task.id == null) {
      return;
    }

    await _notifPlugin.zonedSchedule(
      task.id!,
      'Upcoming Task: ${task.title}',
      task.description,
      tz.TZDateTime.from(task.dueDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('task_reminder', 'Task Reminders'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> _exportToCSV() async {
    final List<List<dynamic>> rows = <List<dynamic>>[
      <String>['ID', 'Title', 'Description', 'Due Date', 'Status', 'Repeat Type'],
    ];

    for (final Task task in _allTasks) {
      rows.add(<dynamic>[
        task.id,
        task.title,
        task.description,
        DateFormat.yMd().add_jm().format(task.dueDate),
        task.isCompleted ? 'Completed' : 'Pending',
        task.repeatType,
      ]);
    }

    final String csv = const ListToCsvConverter().convert(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    _showMessage('CSV copied to clipboard.');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildStatPill({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context) {
    final int total = _allTasks.length;
    final int completed = _completedTasks.length;
    final int pending = total - completed;
    final double progress = total == 0 ? 0 : completed / total;
    final String todayLabel = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pulse Board',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: 2),
          Text(todayLabel),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _buildStatPill(context: context, icon: Icons.list_alt_rounded, value: '$total', label: 'Total'),
              _buildStatPill(context: context, icon: Icons.check_circle_outline, value: '$completed', label: 'Done'),
              _buildStatPill(context: context, icon: Icons.hourglass_bottom, value: '$pending', label: 'Open'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).round()}% complete this cycle'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    String label = 'Nothing to show yet.';
    if (_selectedIndex == 0) {
      label = 'No tasks due today. Add one and start strong.';
    } else if (_selectedIndex == 1) {
      label = 'No completed tasks yet. Finish one to see momentum.';
    } else {
      label = 'No repeating tasks yet. Create one to automate routines.';
    }

    return Center(
      key: ValueKey<String>(label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.calendar_view_week_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = task.isCompleted
        ? scheme.tertiary
        : task.repeatType != 'none'
            ? scheme.secondary
            : scheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.18),
            scheme.surface.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 12),
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) {
            _markComplete(task);
          },
        ),
        title: Text(
          task.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(DateFormat.yMMMd().add_jm().format(task.dueDate)),
            if (task.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (task.subtasks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text('${(task.progress * 100).round()}% subtasks complete'),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _showTaskForm(task);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                if (task.id == null) {
                  return;
                }
                await _db.deleteTask(task.id!);
                await _loadTasks();
              },
            ),
          ],
        ),
        children: <Widget>[
          if (task.subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'No subtasks',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...task.subtasks.map((Subtask sub) {
              return CheckboxListTile(
                value: sub.isCompleted,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  sub.title,
                  style: TextStyle(
                    decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                onChanged: (_) async {
                  sub.isCompleted = !sub.isCompleted;
                  await _db.updateTask(task);
                  await _loadTasks();
                },
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Task> currentList = _currentList;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Task App - $_activeSectionLabel'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              MyApp.toggleThemeOf(context);
            },
            tooltip: 'Toggle Light and Dark Theme',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportToCSV,
            tooltip: 'Copy Tasks CSV',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primaryContainer.withValues(alpha: 0.7),
              scheme.surface,
              scheme.secondaryContainer.withValues(alpha: 0.65),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: <Widget>[
                _buildHeroPanel(context),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(
                      value: 0,
                      icon: Icon(Icons.today_outlined),
                      label: Text('Today'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: Icon(Icons.check_circle_outline),
                      label: Text('Completed'),
                    ),
                    ButtonSegment<int>(
                      value: 2,
                      icon: Icon(Icons.repeat_rounded),
                      label: Text('Repeating'),
                    ),
                  ],
                  selected: <int>{_selectedIndex},
                  onSelectionChanged: (Set<int> selection) {
                    setState(() {
                      _selectedIndex = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : currentList.isEmpty
                            ? _buildEmptyState(context)
                            : ListView.builder(
                                key: ValueKey<int>(_selectedIndex),
                                padding: EdgeInsets.zero,
                                itemCount: currentList.length,
                                itemBuilder: (BuildContext context, int index) {
                                  return _buildTaskCard(context, currentList[index]);
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTaskForm,
        icon: const Icon(Icons.add_task),
        label: const Text('Add Task'),
      ),
    );
  }
}

// ------------------------------
// ADD / EDIT TASK FORM DIALOG
// ------------------------------
class TaskFormDialog extends StatefulWidget {
  final Task? existingTask;
  final Future<void> Function() onSave;

  const TaskFormDialog({
    super.key,
    this.existingTask,
    required this.onSave,
  });

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  String _repeatType = 'none';
  List<int> _repeatDays = <int>[];
  List<TextEditingController> _subtaskCtrls = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingTask?.title);
    _descCtrl = TextEditingController(text: widget.existingTask?.description);

    if (widget.existingTask != null) {
      _selectedDate = widget.existingTask!.dueDate;
      _repeatType = widget.existingTask!.repeatType;
      _repeatDays = List<int>.from(widget.existingTask!.repeatDays);
      _subtaskCtrls = widget.existingTask!.subtasks
          .map((Subtask task) => TextEditingController(text: task.title))
          .toList();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final TextEditingController controller in _subtaskCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  height: 5,
                  width: 52,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                Text(
                  widget.existingTask == null ? 'Create Task' : 'Update Task',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  title: Text('Due: ${DateFormat.yMd().add_jm().format(_selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final DateTime now = DateTime.now();
                    final DateTime? date = await showDatePicker(
                      context: context,
                      firstDate: now,
                      lastDate: DateTime(2030),
                      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
                    );
                    if (date == null) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDate),
                    );
                    if (time == null || !mounted) {
                      return;
                    }
                    setState(() {
                      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _repeatType,
                  decoration: const InputDecoration(
                    labelText: 'Repeat Task',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'none', child: Text('No Repeat')),
                    DropdownMenuItem<String>(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem<String>(value: 'weekly', child: Text('Weekly')),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _repeatType = value ?? 'none';
                    });
                  },
                ),
                if (_repeatType == 'weekly') ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List<Widget>.generate(7, (int i) {
                      final int day = i + 1;
                      final List<String> labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      return FilterChip(
                        label: Text(labels[i]),
                        selected: _repeatDays.contains(day),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              if (!_repeatDays.contains(day)) {
                                _repeatDays.add(day);
                              }
                            } else {
                              _repeatDays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Subtasks',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                ..._subtaskCtrls.asMap().entries.map((MapEntry<int, TextEditingController> entry) {
                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: entry.value,
                          decoration: const InputDecoration(hintText: 'Subtask title'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            final TextEditingController removed = _subtaskCtrls.removeAt(entry.key);
                            removed.dispose();
                          });
                        },
                      ),
                    ],
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Subtask'),
                    onPressed: () {
                      setState(() {
                        _subtaskCtrls.add(TextEditingController());
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    final List<Subtask> subs = _subtaskCtrls
                        .where((TextEditingController controller) => controller.text.trim().isNotEmpty)
                        .map(
                          (TextEditingController controller) => Subtask(taskId: 0, title: controller.text.trim()),
                        )
                        .toList();

                    final Task task = Task(
                      id: widget.existingTask?.id,
                      title: _titleCtrl.text.trim(),
                      description: _descCtrl.text.trim(),
                      dueDate: _selectedDate,
                      repeatType: _repeatType,
                      repeatDays: _repeatDays,
                      subtasks: subs,
                    );

                    if (widget.existingTask == null) {
                      await DBHelper.instance.insertTask(task);
                    } else {
                      await DBHelper.instance.updateTask(task);
                    }

                    await widget.onSave();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pop(context);
                  },
                  child: Text(widget.existingTask == null ? 'Save Task' : 'Update Task'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
