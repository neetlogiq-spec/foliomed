import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/patient.dart';
import '../models/ward.dart';
import '../screens/admin/add_ward_screen.dart';
import '../screens/admin/admin_staff_screen.dart';
import '../screens/admin/ward_detail_screen.dart';
import '../screens/auth/background_setup_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/doctor/add_patient_screen.dart';
import '../screens/doctor/patient_detail_screen.dart';
import '../screens/doctor/patients_list_screen.dart';
import '../screens/nurse/nurse_patient_detail_screen.dart';
import '../screens/nurse/nurse_patients_screen.dart';
import '../screens/shared/main_scaffold.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String backgroundSetup = '/background-setup';

  static const String doctorHome = '/doctor/home';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorPatientDetail = '/doctor/patient-detail';
  static const String doctorAddPatient = '/doctor/add-patient';

  static const String nurseHome = '/nurse/home';
  static const String nursePatients = '/nurse/patients';
  static const String nursePatientDetail = '/nurse/patient-detail';

  static const String adminHome = '/admin/home';
  static const String adminWardDetail = '/admin/ward-detail';
  static const String adminAddWard = '/admin/add-ward';
  static const String adminStaff = '/admin/staff';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        onboarding: (_) => const OnboardingScreen(),
        login: (_) => const LoginScreen(),
        backgroundSetup: (_) => const BackgroundSetupScreen(),
        doctorHome: (_) => const MainScaffold(role: UserRole.doctor),
        doctorPatients: (_) => const PatientsListScreen(),
        doctorAddPatient: (_) => const AddPatientScreen(),
        nurseHome: (_) => const MainScaffold(role: UserRole.nurse),
        nursePatients: (_) => const NursePatientsScreen(),
        adminHome: (_) => const MainScaffold(role: UserRole.admin),
        adminAddWard: (_) => const AddWardScreen(),
        adminStaff: (_) => const AdminStaffScreen(),
      };

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case doctorPatientDetail:
        final patient = settings.arguments as Patient?;
        if (patient == null) return null;
        return MaterialPageRoute(
          builder: (_) => PatientDetailScreen(patientId: patient.id),
        );
      case nursePatientDetail:
        final patient = settings.arguments as Patient?;
        if (patient == null) return null;
        return MaterialPageRoute(
          builder: (_) => NursePatientDetailScreen(patientId: patient.id),
        );
      case adminWardDetail:
        final ward = settings.arguments as Ward?;
        if (ward == null) return null;
        return MaterialPageRoute(
          builder: (_) => WardDetailScreen(wardId: ward.id),
        );
      default:
        return null;
    }
  }
}
