// ignore_for_file: unused_element, unused_field
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Se [isProVersion] for true, o aplicativo será compilado diretamente como a versão PRO vitalícia.
/// Se for false, o aplicativo rodará no modo gratuito/normal (com faturamento real ou simulação em debug).
const bool isProVersion = false;

/// Se [useSimulatedBilling] for true, o aplicativo exibirá atalhos de simulação
/// de pagamento para facilitar os testes de desenvolvimento.
const bool useSimulatedBilling = true;

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  return PremiumNotifier();
});

class PremiumNotifier extends StateNotifier<bool> {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // ID canônico do produto cadastrado na Play Console para a versão Pro vitalícia
  static const String proProductId = 'planrace_pro_lifetime';

  PremiumNotifier() : super(isProVersion) {
    _load();
    _initializeIAP();
  }

  static const _key = 'is_premium_pro';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPremium = prefs.getBool(_key) ?? false;
      if (savedPremium && !state) {
        state = true;
      }

      // Se não é premium localmente, tenta restaurar compras da Play Store
      // para cobrir o caso onde a compra foi feita mas nunca reconhecida
      if (!state && !isProVersion) {
        _tryRestoreOnStartup();
      }
    } catch (_) {}
  }

  /// Tenta restaurar compras silenciosamente na inicialização
  Future<void> _tryRestoreOnStartup() async {
    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (available) {
        await InAppPurchase.instance.restorePurchases();
      }
    } catch (_) {
      // Falha silenciosa — o usuário pode restaurar manualmente depois
    }
  }

  void _initializeIAP() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        // Tratamento silencioso de streams de erro
      },
    );
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Compra aguardando conclusão (ex: Pix/boleto)
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Transação mal sucedida ou cancelada
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        // Compra confirmada ou recuperada
        if (purchaseDetails.productID == proProductId) {
          await setPremium(true);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Dispara a transação nativa na Google Play Store
  Future<void> buyPro() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      throw 'A Google Play Store não está disponível no momento.';
    }

    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails({proProductId});
    
    if (response.notFoundIDs.isNotEmpty) {
      throw 'O produto "$proProductId" não foi encontrado na Google Play Store. Verifique se ele está cadastrado e ativo no Console.';
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Inicia faturamento da compra vitalícia (não-consumível)
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Recupera compras anteriores do mesmo usuário da loja
  Future<void> restorePurchases() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      throw 'A Google Play Store não está disponível no momento.';
    }
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> togglePremium() async {
    if (isProVersion) return;
    state = !state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, state);
    } catch (_) {}
  }

  Future<void> setPremium(bool value) async {
    if (isProVersion) return;
    if (state == value) return;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
