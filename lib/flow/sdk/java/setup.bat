@echo off
REM Quick setup script for Maria Java SDK (Windows)
REM Run this after installing Java and Maven

echo 🚀 Maria Java SDK - Quick Setup
echo ================================
echo.

REM Check Java
echo Checking Java installation...
java -version >nul 2>&1
if errorlevel 1 (
    echo ❌ Java not found! Please install Java 17 or higher
    echo    Download from: https://adoptium.net/
    exit /b 1
)
echo ✓ Java found

REM Check Maven  
echo Checking Maven installation...
mvn -version >nul 2>&1
if errorlevel 1 (
    echo ❌ Maven not found! Please install Maven
    echo    Download from: https://maven.apache.org/download.cgi
    exit /b 1
)
echo ✓ Maven found

REM Build the SDK
echo.
echo Building Maria Java SDK...
cd /d "%~dp0"
call mvn clean package -q
if errorlevel 1 (
    echo ❌ Build failed
    exit /b 1
)
echo ✓ SDK built successfully

REM Try to run the example
echo.
echo Running example...
cd examples
call mvn compile exec:java -q
if errorlevel 1 (
    echo ❌ Example failed to run
    exit /b 1
)

echo.
echo ✓ Setup complete! You're ready to use Maria in Java!
echo.
echo Next steps:
echo   1. Check out examples\Main.java
echo   2. Read README.md for more examples
echo   3. Create your own Java programs with Maria!

pause
