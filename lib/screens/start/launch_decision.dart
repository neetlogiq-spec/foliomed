/// Where a cold start should land.
enum LaunchStep { welcome, signIn, chooseRole, alertSetup, home }

/// Pure routing rule for app start, kept apart from the UI so it can be
/// tested:
/// - not signed in → Welcome the first time, Sign in afterwards;
/// - signed in but the profile is missing → Sign in;
/// - role not chosen yet → Choose role;
/// - alert setup still needed on this phone → Alert setup;
/// - otherwise → Home.
LaunchStep decideLaunch({
  required bool signedIn,
  required bool hasProfile,
  required bool welcomeSeen,
  required bool roleConfirmed,
  required bool alertSetupNeeded,
}) {
  if (!signedIn) return welcomeSeen ? LaunchStep.signIn : LaunchStep.welcome;
  if (!hasProfile) return LaunchStep.signIn;
  if (!roleConfirmed) return LaunchStep.chooseRole;
  if (alertSetupNeeded) return LaunchStep.alertSetup;
  return LaunchStep.home;
}
