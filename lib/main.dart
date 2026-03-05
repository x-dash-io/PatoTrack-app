import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'helpers/notification_service.dart';
import 'providers/currency_provider.dart';
import 'theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/all_transactions_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/analytics_screen.dart';
import 'styles/app_colors.dart';
import 'styles/app_shadows.dart';
import 'styles/app_theme.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

final NotificationService notificationService = NotificationService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env").catchError((_) {});
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  tz.initializeTimeZones();
  await notificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => CurrencyProvider()),
      ],
      child: const PatoTrack(),
    ),
  );
}

class PatoTrack extends StatelessWidget {
  const PatoTrack({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: true,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PatoTrack',
        themeMode: themeProvider.themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const AuthGate(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    AllTransactionsScreen(),
    ReportsScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [AppShadows.nav],
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(AppIcons.home_outlined),
              selectedIcon: Icon(AppIcons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.receipt_long_outlined),
              selectedIcon: Icon(AppIcons.receipt_long_rounded),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.bar_chart_outlined),
              selectedIcon: Icon(AppIcons.bar_chart_rounded),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.trending_up_rounded),
              selectedIcon: Icon(AppIcons.trending_up_rounded),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.person_outline_rounded),
              selectedIcon: Icon(AppIcons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
