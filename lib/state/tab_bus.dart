import 'package:flutter/material.dart';

class TabBus extends ChangeNotifier {
  int index = 0;

  void go(int i) {
    if (i == index) return;
    index = i;
    notifyListeners();
  }
}