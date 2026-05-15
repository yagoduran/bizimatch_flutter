import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureTourService {
  FeatureTourService._();

  static final FeatureTourService instance = FeatureTourService._();

  static const String hasSeenTutorialKey = 'hasSeenTutorial';
  static const String hasSeenContractTutorialKey = 'hasSeenContractTutorial';

  final ValueNotifier<int> replayRequests = ValueNotifier<int>(0);

  final GlobalKey discoverCardKey = GlobalKey();
  final GlobalKey chatsTabKey = GlobalKey();
  final GlobalKey homeTasksExpensesKey = GlobalKey();
  final GlobalKey contractPdfButtonKey = GlobalKey();

  Future<bool> shouldAutoStartMainTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(hasSeenTutorialKey) ?? false);
  }

  Future<void> markMainTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenTutorialKey, true);
  }

  Future<bool> shouldAutoStartContractTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(hasSeenContractTutorialKey) ?? false);
  }

  Future<void> markContractTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenContractTutorialKey, true);
  }

  Future<void> resetTutorialProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenTutorialKey, false);
    await prefs.setBool(hasSeenContractTutorialKey, false);
  }

  void requestReplay() {
    replayRequests.value++;
  }
}
