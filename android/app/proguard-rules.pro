# R8 keep rules for FolioMed release builds.

# google_mlkit_text_recognition references the optional Chinese, Devanagari,
# Japanese and Korean recognizers. FolioMed only reads Latin script (monitor
# vitals), so those libraries are intentionally not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
