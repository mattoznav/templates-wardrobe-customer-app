import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

/// The signed-in customer, or null. Tokens come from [TokenStore].
final authProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // A refresh token that expired somewhere in the app signs the user out here
    ref.listen(sessionExpiredProvider, (_, _) => state = const AsyncData(null));
    if (ref.read(tokenStoreProvider).read() == null) return null;
    try {
      return await ref.read(apiProvider).me();
    } catch (_) {
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    final tokens = await ref.read(apiProvider).signIn(email, password);
    await ref.read(tokenStoreProvider).write(tokens);
    state = AsyncData(await ref.read(apiProvider).me());
  }

  Future<void> register({required String email, required String password, required String firstName, required String lastName}) async {
    final tokens = await ref.read(apiProvider).register(email: email, password: password, firstName: firstName, lastName: lastName);
    await ref.read(tokenStoreProvider).write(tokens);
    state = AsyncData(await ref.read(apiProvider).me());
  }

  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).write(null);
    state = const AsyncData(null);
  }
}
