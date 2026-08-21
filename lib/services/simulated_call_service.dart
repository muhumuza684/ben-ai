import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../screens/incoming_screen.dart';

class SimulatedCallService {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final Map<int, Timer> _timers = {};
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final reminders = await DatabaseService.getPendingReminders();
    for (final reminder in reminders) {
      final contactId = reminder.contactId;
      if (contactId == null) continue;
      final contact = await DatabaseService.getContact(contactId);
      if (contact != null) schedule(reminder, contact);
    }
  }

  static void schedule(Reminder reminder, Contact contact) {
    final id = reminder.id ?? reminder.scheduledAt.millisecondsSinceEpoch;
    _timers[id]?.cancel();
    final delay = reminder.scheduledAt.difference(DateTime.now());
    if (delay.isNegative) return;
    _timers[id] = Timer(delay, () async {
      await DatabaseService.markReminderFired(id);
      _timers.remove(id);
      _showIncomingCall(contact, reminder.task);
    });
  }

  static Future<void> handleReminderTap(int reminderId) async {
    final reminder = await DatabaseService.getReminder(reminderId);
    if (reminder == null || reminder.contactId == null) return;
    final contact = await DatabaseService.getContact(reminder.contactId!);
    if (contact == null) return;
    _showIncomingCall(contact, reminder.task);
  }

  static void cancel(int reminderId) {
    _timers.remove(reminderId)?.cancel();
  }

  static void _showIncomingCall(Contact contact, String reason) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(MaterialPageRoute(
      builder: (_) => IncomingScreen(contact: contact, callReason: reason),
      fullscreenDialog: true,
    ));
  }

  static void dispose() {
    for (final timer in _timers.values) timer.cancel();
    _timers.clear();
  }
}
