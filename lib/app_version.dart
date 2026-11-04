/// Single source of truth for the app version shown in-app and used by the
/// in-app updater. MUST match `versionName` in android/app/build.gradle
/// (the CI workflow fails the build if they differ).
const String kAppVersion = '1.6.1';

/// GitHub repository that hosts the release APKs + changelog (free, no server).
const String kUpdateRepo = 'Irfans128/zunify-apk';
