import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.foliomed.app",
  appName: "FolioMed",
  webDir: "out",
  server: {
    url: "https://foliomed.app",
    cleartext: false,
    appendUserAgent: "FolioMedNative",
    allowNavigation: [
      "foliomed.app",
      "www.foliomed.app",
      "accounts.google.com",
      "*.supabase.co",
    ],
  } as CapacitorConfig["server"] & { appendUserAgent?: string },
  ios: {
    scheme: "FolioMed",
    preferredContentMode: "mobile",
  },
  android: {
    allowMixedContent: false,
    // Google blocks Google Sign-In within WebViews ('wv' in user agent).
    // We override the Android user agent to spoof a standard Chrome Mobile browser,
    // bypassing the "403 disallowed_useragent" error without breaking App Links.
    overrideUserAgent: "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36 FolioMedNative",
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      launchShowDuration: 2000,
      backgroundColor: "#020617",
      showSpinner: false,
    },
    StatusBar: {
      style: "DARK",
      backgroundColor: "#020617",
    },
  },
};

export default config;
