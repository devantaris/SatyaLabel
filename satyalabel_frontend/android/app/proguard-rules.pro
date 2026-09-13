# google_mlkit_text_recognition references recognizers for other scripts
# (chinese/devanagari/japanese/korean) that are only bundled when their
# separate artifacts are added. We use only the latin recognizer, so the
# references are safe to ignore during R8 minification.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
