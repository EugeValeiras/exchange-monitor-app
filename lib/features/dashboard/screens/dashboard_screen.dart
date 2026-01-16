import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/services/price_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/balance_chart.dart';
import '../widgets/price_cards.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hideSmallBalances = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final balanceService = context.read<BalanceService>();
    final chartService = context.read<ChartService>();
    final priceService = context.read<PriceService>();
    final authService = context.read<AuthService>();

    // Set auth token for price service
    final token = await authService.getStoredToken();
    priceService.setAuthToken(token);
    priceService.connect();

    // Load data
    await Future.wait([
      balanceService.loadBalance(),
      chartService.loadChartData(),
    ]);
  }

  Future<void> _handleRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // User avatar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showUserMenu(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brandPrimary,
                child: Text(
                  authService.currentUser?.initials ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.brandAccent,
        backgroundColor: AppColors.bgCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance Card
              BalanceCard(
                hideSmallBalances: _hideSmallBalances,
                onToggleSmallBalances: () => setState(() => _hideSmallBalances = !_hideSmallBalances),
              ),
              const SizedBox(height: 24),

              // Chart
              const BalanceChartWidget(),
              const SizedBox(height: 24),

              // Price Cards
              const PriceCardsWidget(),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final authService = context.read<AuthService>();
        final user = authService.currentUser;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.brandPrimary,
                      child: Text(
                        user?.initials ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Usuario',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            user?.email ?? '',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),

                // Logout button
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Cerrar Sesion',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    authService.logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
