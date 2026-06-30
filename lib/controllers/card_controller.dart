import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../services/card_service.dart';

/// Holds the signed-in user's HayaatID card (null until they request one).
class CardController extends ChangeNotifier {
  final CardService _service = CardService();

  CardModel? _card;
  bool _loading = false;
  bool _loaded = false;

  CardModel? get card => _card;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get hasCard => _card != null;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _card = await _service.getMyCard();
    } catch (_) {
      _card = null;
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  void setCard(CardModel card) {
    _card = card;
    _loaded = true;
    notifyListeners();
  }

  void clear() {
    _card = null;
    _loaded = false;
    notifyListeners();
  }
}
