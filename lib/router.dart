import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/account/orders_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/bag/bag_controller.dart';
import 'features/bag/bag_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/shop/browse_screen.dart';
import 'features/shop/collection_screen.dart';
import 'features/shop/home_screen.dart';
import 'features/shop/product_screen.dart';
import 'features/wishlist/wishlist_screen.dart';

final _root = GlobalKey<NavigatorState>();

/// Five tabs (discover, shop, wishlist, bag, account). Everything else opens full screen above them.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _root,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Tabs(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/shop',
              builder: (_, state) => BrowseScreen(
                section: state.uri.queryParameters['section'] ?? '',
                category: state.uri.queryParameters['category'] ?? '',
                onlyNew: state.uri.queryParameters['new'] == '1',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/bag', builder: (_, _) => const BagScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (_, _) => const AccountScreen())]),
        ],
      ),
      GoRoute(path: '/products/:slug', parentNavigatorKey: _root, builder: (_, state) => ProductScreen(slug: state.pathParameters['slug']!)),
      GoRoute(path: '/collections/:slug', parentNavigatorKey: _root, builder: (_, state) => CollectionScreen(slug: state.pathParameters['slug']!)),
      GoRoute(path: '/checkout', parentNavigatorKey: _root, builder: (_, _) => const CheckoutScreen()),
      GoRoute(path: '/pay/:order', parentNavigatorKey: _root, builder: (_, state) => CheckoutScreen(orderId: int.parse(state.pathParameters['order']!))),
      GoRoute(path: '/account/orders/:id', parentNavigatorKey: _root, builder: (_, state) => OrderScreen(id: int.parse(state.pathParameters['id']!))),
      GoRoute(
        path: '/sign-in',
        parentNavigatorKey: _root,
        pageBuilder: (_, state) => MaterialPage(fullscreenDialog: true, child: SignInScreen(reason: state.extra as String?)),
      ),
    ],
  );
});

class _Tabs extends ConsumerWidget {
  const _Tabs({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(bagCountProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE0D8CB)))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Discover'),
            const NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom), label: 'Shop'),
            const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Wishlist'),
            NavigationDestination(
              icon: Badge(isLabelVisible: count > 0, label: Text('$count'), backgroundColor: const Color(0xFF1D1B18), child: const Icon(Icons.shopping_bag_outlined)),
              selectedIcon: Badge(isLabelVisible: count > 0, label: Text('$count'), backgroundColor: const Color(0xFF1D1B18), child: const Icon(Icons.shopping_bag)),
              label: 'Bag',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      ),
    );
  }
}
