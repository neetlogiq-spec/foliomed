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
