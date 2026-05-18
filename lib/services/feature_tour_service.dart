import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FeatureTourService: aplikazioaren tutorial eta onboarding egoerak kudeatzen ditu.
///
/// Zer egiten duen:
/// - Erabiltzaileak tutorial-a ikusi duen gordetzen du `SharedPreferences`-en.
/// - Tutorial errepikatzeko eskaerak `ValueNotifier` bidez adierazten ditu.
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
    /// Egiaztatzen du aplikazioaren tutorial nagusia automatikoki hasi behar den.
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(hasSeenTutorialKey) ?? false);
  }

  Future<void> markMainTutorialSeen() async {
    /// Markatu tutorial nagusia ikusia dagoela SharedPreferences-en.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenTutorialKey, true);
  }

  Future<bool> shouldAutoStartContractTutorial() async {
    /// Kontratu tutorial-a automatikoki hasi behar den egiaztatzen du.
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(hasSeenContractTutorialKey) ?? false);
  }

  Future<void> markContractTutorialSeen() async {
    /// Kontratu-tutorial ikusia markatzen du SharedPreferences-en.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenContractTutorialKey, true);
  }

  Future<void> resetTutorialProgress() async {
    /// Bi tutorialen egoera berrezarri (ikusi/ez ikusi) SharedPreferences-en.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenTutorialKey, false);
    await prefs.setBool(hasSeenContractTutorialKey, false);
  }

  void requestReplay() {
    replayRequests.value++;
  }
}
