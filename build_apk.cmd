@echo off
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.16.8-hotspot
echo Using JAVA_HOME=%JAVA_HOME%
cd /d d:\dialer\umar_dailer
flutter build apk
echo EXIT_CODE=%ERRORLEVEL%
