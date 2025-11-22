import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../theme_provider.dart'; // Import ThemeNotifier
import '../realtime_db_service.dart';
import '../due_date_provider.dart';
import 'profile.dart';

import 'custom_header.dart';

class EnergySchedulingScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService; // New: Add RealtimeDbService
  const EnergySchedulingScreen({super.key, required this.realtimeDbService});

  @override
  State<EnergySchedulingScreen> createState() => _EnergySchedulingScreenState();
}

class _EnergySchedulingScreenState extends State<EnergySchedulingScreen>
    with TickerProviderStateMixin {
  // Removed _isDarkMode internal state
  int _currentIndex = 3;
  late RealtimeDbService _realtimeDbService;

  late AnimationController _profileController;
  late Animation<Offset> _profileSlideAnimation;
  late Animation<double> _profileScaleAnimation;

  @override
  void initState() {
    super.initState();
    _realtimeDbService = widget.realtimeDbService;

    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _profileSlideAnimation =
        Tween<Offset>(begin: const Offset(0.2, -0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _profileController,
            curve: Curves.easeOutBack,
          ),
        );

    _profileScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _profileController.dispose();
    super.dispose();
  }

  // Scheduled tasks
  final List<Map<String, dynamic>> _scheduledTasks = [
    {
      "device": "Air Conditioner",
      "time": "2:00 PM - 4:00 PM",
      "energy": "2.4 kWh",
      "cost": "₱18.50",
      "icon": Icons.ac_unit,
    },
    {
      "device": "Washing Machine",
      "time": "6:00 PM - 7:30 PM",
      "energy": "1.8 kWh",
      "cost": "₱14.20",
      "icon": Icons.local_laundry_service,
    },
    {
      "device": "Lights",
      "time": "7:00 PM - 10:00 PM",
      "energy": "0.9 kWh",
      "cost": "₱6.70",
      "icon": Icons.lightbulb,
    },
  ];

  String? selectedHour;
  String? selectedMinute;
  String? selectedDevice;

  final List<String> hours = List.generate(
    24,
    (index) => index.toString().padLeft(2, '0'),
  );
  final List<String> minutes = List.generate(
    60,
    (index) => index.toString().padLeft(2, '0'),
  );
  final List<String> devices = [
    "Air Conditioner",
    "Washing Machine",
    "Lights",
    "Fan",
  ];

  // Add task
  void _addTask() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Schedule New Task",
            style: TextStyle(fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                hint: const Text(
                  "Select Device",
                  style: TextStyle(fontSize: 13),
                ),
                value: selectedDevice,
                items: devices
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedDevice = val),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<String>(
                    hint: const Text("Hour", style: TextStyle(fontSize: 13)),
                    value: selectedHour,
                    items: hours
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text(
                              h,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => selectedHour = val),
                  ),
                  DropdownButton<String>(
                    hint: const Text("Minute", style: TextStyle(fontSize: 13)),
                    value: selectedMinute,
                    items: minutes
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => selectedMinute = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDevice != null &&
                    selectedHour != null &&
                    selectedMinute != null) {
                  setState(() {
                    _scheduledTasks.add({
                      "device": selectedDevice!,
                      "time": "$selectedHour:$selectedMinute",
                      "energy": "0.5 kWh",
                      "cost": "₱5.00",
                      "icon": Icons.devices_other,
                    });
                  });
                  Navigator.pop(context);
                  selectedDevice = null;
                  selectedHour = null;
                  selectedMinute = null;
                }
              },
              child: const Text("Save", style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  void _editTask(int index) {
    final task = _scheduledTasks[index];

    String editedDevice = task["device"];
    String editedTime = task["time"];
    String editedEnergy = task["energy"];
    String editedCost = task["cost"];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Task", style: TextStyle(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Device"),
                style: const TextStyle(fontSize: 13),
                controller: TextEditingController(text: editedDevice),
                onChanged: (value) => editedDevice = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Time"),
                style: const TextStyle(fontSize: 13),
                controller: TextEditingController(text: editedTime),
                onChanged: (value) => editedTime = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Energy"),
                style: const TextStyle(fontSize: 13),
                controller: TextEditingController(text: editedEnergy),
                onChanged: (value) => editedEnergy = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Cost"),
                style: const TextStyle(fontSize: 13),
                controller: TextEditingController(text: editedCost),
                onChanged: (value) => editedCost = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _scheduledTasks[index] = {
                    "device": editedDevice,
                    "time": editedTime,
                    "energy": editedEnergy,
                    "cost": editedCost,
                    "icon": task["icon"],
                  };
                });
                Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  void _removeTask(int index) {
    setState(() {
      _scheduledTasks.removeAt(index);
    });
  }

  // Task card builder... (remains the same)
  Widget _buildTaskCard(Map<String, dynamic> task, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(64),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withAlpha(25),
            child: Icon(task["icon"], size: 18, color: Colors.tealAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task["device"],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  task["time"],
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    "Energy: ${task["energy"]}",
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                task["cost"],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.orange,
                      size: 18,
                    ),
                    onPressed: () => _editTask(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () => _removeTask(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(
      context,
    ); // Access ThemeNotifier
    // Content of the main screen area
    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface, // Use theme colors
                Theme.of(context).primaryColor, // Use theme colors
              ],
            ),
          ),
        ),

        // Main content area
        Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ), // Adjust padding for mobile
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Due Date Display
                  Consumer<DueDateProvider>(
                    builder: (context, dueDateProvider, _) {
                      if (dueDateProvider.dueDate == null) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: dueDateProvider.isOverdue
                              ? Colors.red.withOpacity(0.1)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: dueDateProvider.isOverdue
                                ? Colors.red
                                : Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: dueDateProvider.isOverdue
                                    ? Colors.red.withOpacity(0.2)
                                    : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: dueDateProvider.isOverdue
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.secondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment Due Date',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dueDateProvider.getFormattedDueDate() ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: dueDateProvider.isOverdue
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.secondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dueDateProvider.isOverdue
                                    ? 'Overdue ${dueDateProvider.getDaysRemaining()!.abs()}d'
                                    : '${dueDateProvider.getDaysRemaining()}d left',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Tip Section (moved up for mobile)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          color: Colors.teal,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Tip: Running the Washing Machine at 10 PM could save ₱5 (off-peak rate).",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_scheduledTasks.isNotEmpty) ...[
                    Text(
                      "Next Scheduled Task",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color,
                      ),
                    ), // Use theme color
                    const SizedBox(height: 8),
                    _buildTaskCard(_scheduledTasks[0], 0),
                  ],

                  const SizedBox(height: 18),
                  Text(
                    "Upcoming Tasks",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ), // Use theme color
                  const SizedBox(height: 6),

                  Column(
                    children: _scheduledTasks.length > 1
                        ? _scheduledTasks
                        .sublist(1)
                        .asMap()
                        .entries
                        .map(
                          (entry) => _buildTaskCard(
                        entry.value,
                        entry.key + 1,
                      ),
                    )
                        .toList()
                        : [
                      Text(
                        "No upcoming tasks.",
                        style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color, // Use theme color
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _addTask,
                      child: const Text(
                        "Add Task",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Add some padding at the bottom for the mobile nav bar
                ],
              ),
            ),
          ),

        // Profile Popover - Always present
        Positioned(
          top: 70,
          right: 10,
          child: FadeTransition(
            opacity: _profileController,
            child: SlideTransition(
              position: _profileSlideAnimation,
              child: ScaleTransition(
                scale: _profileScaleAnimation,
                alignment: Alignment.topRight,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).cardColor, // Use theme colors
                        Theme.of(
                          context,
                        ).primaryColor, // Use theme colors
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(150),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.color,
                        ),
                      ), // Use theme color
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondary,
                        ), // Use theme color
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Marie Fe Tapales',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.color, // Use theme color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'marie@example.com',
                        style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color, // Use theme color
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          _profileController.reverse();
                          Future.delayed(
                            const Duration(milliseconds: 300),
                                () {
                              if (!mounted) return;
                              // Assuming EnergyProfileScreen is imported from profile.dart
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EnergyProfileScreen(
                                    realtimeDbService: _realtimeDbService,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Text(
                          'View Profile',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.color, // Use theme color
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _profileController.reverse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size.fromHeight(34),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
