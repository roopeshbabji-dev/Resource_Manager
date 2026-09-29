import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app/app_state.dart';
import 'core/theme/app_theme.dart';
import 'database/database_helper.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/profile/more_screen.dart';
import 'features/reminders/reminders_screen.dart';
import 'features/resources/resources_screen.dart';
import 'features/search/search_screen.dart';

export 'app/app_state.dart' show AppState;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseHelper.ensurePlatformInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: const HouseholdManagerApp(),
    ),
  );
}

class HouseholdManagerApp extends StatelessWidget {
  const HouseholdManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Household Resource Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: state.themeMode,
      home: state.isLoading
          ? const _SplashScreen()
          : state.currentUser == null
          ? const AuthScreen()
          : const AppShell(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.home_work_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Household Resource Manager',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ),
    ),
  );
}

/// Feature showcase carousel items for the auth screen
class _FeatureSlide {
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const _FeatureSlide({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

const _kFeatureSlides = [
  _FeatureSlide(
    badge: 'UTILITY INTELLIGENCE',
    title: 'Smart Meter & Resource Tracking',
    description: 'Monitor Electricity, Water, Gas & Internet consumption in real time with automatic cost projections.',
    icon: Icons.bolt_rounded,
    gradient: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
  ),
  _FeatureSlide(
    badge: 'BUDGET MANAGEMENT',
    title: 'Expense & Financial Clarity',
    description: 'Track household bills, categorize recurring expenses, and forecast monthly family spending trends.',
    icon: Icons.account_balance_wallet_rounded,
    gradient: [Color(0xFF312E81), Color(0xFF6366F1)],
  ),
  _FeatureSlide(
    badge: 'PANTRY & STOCK',
    title: 'Smart Inventory & Expiry Alerts',
    description: 'Keep essentials stocked with minimum threshold warnings, restock lists, and expiry date notifications.',
    icon: Icons.kitchen_rounded,
    gradient: [Color(0xFF064E3B), Color(0xFF10B981)],
  ),
  _FeatureSlide(
    badge: 'AUTOMATED SCHEDULES',
    title: 'Timely Tasks & Bill Reminders',
    description: 'Never miss utility due dates, filter cleanings, or recurring household maintenance schedules.',
    icon: Icons.notifications_active_rounded,
    gradient: [Color(0xFF78350F), Color(0xFFF59E0B)],
  ),
];

class _FeatureCarousel extends StatefulWidget {
  const _FeatureCarousel();

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % _kFeatureSlides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _kFeatureSlides.length,
            itemBuilder: (context, index) {
              final slide = _kFeatureSlides[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: slide.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: slide.gradient.last.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              slide.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slide.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slide.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(slide.icon, color: Colors.white, size: 36),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _kFeatureSlides.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final state = context.read<AppState>();
      if (_registering) {
        final result = await state.register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        if (result == RegistrationResult.created) {
          final registeredEmail = _email.text.trim();
          setState(() {
            _registering = false;
            _email.text = registeredEmail;
            _password.clear();
            _confirmPassword.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Account created successfully! Please sign in with your password.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (result == RegistrationResult.duplicateEmail) {
          setState(() {
            _registering = false;
            _password.clear();
            _confirmPassword.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'An account with this email already exists. Please sign in.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text('Please check your input details and try again.'),
            ),
          );
        }
      } else {
        final success = await state.login(
          email: _email.text,
          password: _password.text,
        );
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Incorrect email or password. Please try again.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Authentication exception: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Authentication error: ${error.toString().replaceAll('Exception:', '').trim()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Branding Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.home_work_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Household Resource Manager',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Smart Home Utilities & Inventory',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Featured Showcase Carousel
                  const _FeatureCarousel(),
                  const SizedBox(height: 24),

                  // Auth Card
                  Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SegmentedButton<bool>(
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor: theme.colorScheme.primary,
                                selectedForegroundColor: Colors.white,
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  icon: Icon(Icons.login_rounded),
                                  label: Text('Sign In'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.person_add_rounded),
                                  label: Text('Create Account'),
                                ),
                              ],
                              selected: {_registering},
                              onSelectionChanged: (value) => setState(() {
                                _registering = value.first;
                                _form.currentState?.reset();
                              }),
                            ),
                            const SizedBox(height: 20),

                            if (_registering) ...[
                              TextFormField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                  hintText: 'e.g., Alex Johnson',
                                ),
                                validator: (value) => (value?.trim().length ?? 0) < 2
                                    ? 'Enter your name (at least 2 characters).'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],

                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                                hintText: 'alex@example.com',
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                return RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(email)
                                    ? null
                                    : 'Enter a valid email address.';
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _password,
                              obscureText: _obscurePassword,
                              autofillHints: _registering
                                  ? const [AutofillHints.newPassword]
                                  : const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                helperText: _registering ? 'Must be at least 8 characters' : null,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password.';
                                }
                                if (_registering && value.length < 8) {
                                  return 'Password must be at least 8 characters.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) {
                                if (!_loading) _submit();
                              },
                            ),

                            if (_registering) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmPassword,
                                obscureText: _obscureConfirmPassword,
                                autofillHints: const [AutofillHints.newPassword],
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.shield_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value != _password.text) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) {
                                  if (!_loading) _submit();
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: _loading
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _registering
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.arrow_forward_rounded,
                                      ),
                                label: Text(
                                  _registering ? 'Create Account' : 'Sign In',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Insight tips carousel for the Home screen
const _kHomeInsightTips = [
  _FeatureSlide(
    badge: 'ENERGY EFFICIENCY',
    title: 'Smart Power Saving',
    description: 'Switch off appliances on standby mode to reduce household electricity waste by 5–10%.',
    icon: Icons.electric_bolt_rounded,
    gradient: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
  ),
  _FeatureSlide(
    badge: 'WATER AUDIT',
    title: 'Regular Meter Checks',
    description: 'Log weekly water meter readings to detect subtle leaks and keep utility bills optimized.',
    icon: Icons.water_drop_rounded,
    gradient: [Color(0xFF0F766E), Color(0xFF06B6D4)],
  ),
  _FeatureSlide(
    badge: 'PANTRY CONTROL',
    title: 'Pantry Expiry Tracking',
    description: 'Track expiry dates on groceries and essential supplies to minimize food waste.',
    icon: Icons.inventory_2_rounded,
    gradient: [Color(0xFF065F46), Color(0xFF10B981)],
  ),
  _FeatureSlide(
    badge: 'BUDGET GOAL',
    title: 'Categorized Expenses',
    description: 'Tag recurring utility bills to easily forecast and manage next month’s budget.',
    icon: Icons.savings_rounded,
    gradient: [Color(0xFF581C87), Color(0xFF8B5CF6)],
  ),
];

class _HomeTipsCarousel extends StatefulWidget {
  const _HomeTipsCarousel();

  @override
  State<_HomeTipsCarousel> createState() => _HomeTipsCarouselState();
}

class _HomeTipsCarouselState extends State<_HomeTipsCarousel> {
  final PageController _controller = PageController();
  int _active = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _active = i),
            itemCount: _kHomeInsightTips.length,
            itemBuilder: (context, index) {
              final tip = _kHomeInsightTips[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: tip.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: tip.gradient.last.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tip.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tip.badge,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tip.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tip.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _kHomeInsightTips.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _active == index ? 16 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: _active == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final greeting = switch (DateTime.now().hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.home_rounded, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search household data',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: state.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: state.loadDashboard(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Dashboard could not be loaded.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => (context as Element).markNeedsBuild(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final money = NumberFormat.currency(
            locale: 'en_IN',
            symbol: state.currency,
            decimalDigits: 0,
          );
          final change = data.expenseChangePercent;
          final comparison =
              data.previousMonthExpenses == 0 && data.monthlyExpenses == 0
              ? 'No prior comparison available'
              : '${change >= 0 ? '↑' : '↓'} ${change.abs().toStringAsFixed(1)}% vs last month';

          final nowFormatted = DateFormat('EEEE, d MMMM').format(DateTime.now());

          return RefreshIndicator(
            onRefresh: () async => (context as Element).markNeedsBuild(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                // Header Greeting
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        (state.currentUser?.name.isNotEmpty ?? false)
                            ? state.currentUser!.name[0].toUpperCase()
                            : 'H',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, ${state.currentUser?.name ?? "Family"} 👋',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            nowFormatted,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Household Tips Carousel
                const _HomeTipsCarousel(),
                const SizedBox(height: 16),

                // Monthly Expenses Banner
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Monthly Spending',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: change <= 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              comparison,
                              style: TextStyle(
                                color: change <= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        money.format(data.monthlyExpenses),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metrics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 620 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: columns == 2 ? 1.55 : 1.25,
                      children: [
                        _MetricCard(
                          title: 'Water Usage',
                          value: data.waterUsage.toStringAsFixed(0),
                          detail: '${data.waterUnit} recorded',
                          icon: Icons.water_drop_rounded,
                          accentColor: const Color(0xFF0284C7),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const ResourcesScreen(),
                            ),
                          ),
                        ),
                        _MetricCard(
                          title: 'Utility Bills',
                          value: money.format(data.utilityCost),
                          detail: 'monthly total',
                          icon: Icons.electric_bolt_rounded,
                          accentColor: const Color(0xFFEAB308),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const ExpensesScreen(),
                            ),
                          ),
                        ),
                        _MetricCard(
                          title: 'Low Stock',
                          value: '${data.lowStockCount}',
                          detail: data.lowStockCount > 0 ? 'needs restock' : 'all stocked',
                          icon: Icons.inventory_2_rounded,
                          accentColor: data.lowStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const InventoryScreen(),
                            ),
                          ),
                        ),
                        _MetricCard(
                          title: 'Family Members',
                          value: '${data.householdMemberCount}',
                          detail: 'in household',
                          icon: Icons.people_alt_rounded,
                          accentColor: const Color(0xFF8B5CF6),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileSettingsScreen(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickAction(
                        icon: Icons.add_card_rounded,
                        label: 'Add Bill',
                        color: const Color(0xFF2563EB),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const ExpenseEditorScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.add_chart_rounded,
                        label: 'Log Meter',
                        color: const Color(0xFF0D9488),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const AddResourceUsageScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'Add Item',
                        color: const Color(0xFF16A34A),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const InventoryEditorScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.add_alert_rounded,
                        label: 'Set Task',
                        color: const Color(0xFFD97706),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const ReminderEditorScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Low Stock Alert Section
                if (data.lowStockItems.isNotEmpty) ...[
                  _Section(
                    title: 'Restock Needed (${data.lowStockItems.length})',
                    child: Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.lowStockItems.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = data.lowStockItems[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Current: ${item.quantity} ${item.unit} (Min: ${item.minimumStock})'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.quantity <= 0 ? 'Out of stock' : 'Low Stock',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(builder: (_) => const InventoryScreen()),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Upcoming Reminders Section
                _Section(
                  title: 'Upcoming Reminders',
                  child: data.upcomingReminders.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('No pending tasks or bill reminders!'),
                              ],
                            ),
                          ),
                        )
                      : Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: data.upcomingReminders.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = data.upcomingReminders[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 20),
                                ),
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'Due: ${DateFormat('d MMM yyyy').format(item.dueDate)}${item.time.isNotEmpty ? " at ${item.time}" : ""}',
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Recent Expenses
                _Section(
                  title: 'Recent Expenses',
                  child: data.recentExpenses.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('No expenses recorded yet.'),
                              ],
                            ),
                          ),
                        )
                      : Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: data.recentExpenses.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = data.recentExpenses[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.receipt_rounded, color: theme.colorScheme.primary, size: 20),
                                ),
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${item.category} · ${DateFormat('d MMM').format(item.date)}',
                                ),
                                trailing: Text(
                                  money.format(item.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(builder: (_) => const ExpensesScreen()),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _screens = [
    HomeScreen(),
    ResourcesScreen(),
    InventoryScreen(),
    ExpensesScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _selectedIndex, children: _screens),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.bolt_rounded),
          label: 'Utilities',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_rounded),
          label: 'Inventory',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Expenses',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'More',
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  Icon(Icons.arrow_outward_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      onPressed: onTap,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}
