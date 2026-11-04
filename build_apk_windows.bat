@echo off
title Zunify v1.0 APK Builder - Crafted by Fannz
echo ========================================================
echo   ZUNIFY v1.0 - STANDALONE ANDROID APK BUILDER
echo   Crafted with love by Fannz (com.fannz.zunify)
echo ========================================================
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] Flutter SDK belum terdeteksi di PATH Windows kamu.
    echo [TIP] Kamu bisa langsung upload folder ini ke GitHub,
    echo       dan GitHub Actions (.github/workflows/build-apk.yml)
    echo       akan otomatis meng-compile file Zunify-v1.0-by-Fannz.apk
    echo       secara gratis di cloud tanpa perlu install Android Studio!
    echo.
    pause
    exit /b 1
)

echo [1/4] Menyiapkan platform Android & dependencies...
call flutter create --org com.fannz --project-name zunify --platforms=android .
call flutter pub get

echo [2/4] Memasang icon launcher Zunify Gaya 2 (Vinyl Minimalis)...
call dart run flutter_launcher_icons

echo [3/4] Meng-compile Release APK Zunify...
call flutter build apk --release --no-tree-shake-icons

echo [4/4] Menyalin file APK hasil build...
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "Zunify-v1.0-by-Fannz.apk"

echo.
echo ========================================================
echo   SELESAI! File APK siap di-install ke HP lu & temen-temen:
echo   Lokasi: %cd%\Zunify-v1.0-by-Fannz.apk
echo ========================================================
pause
