@echo off
echo Kiểm tra và cập nhật phiên bản NDK trong build.gradle.kts...

set NDK_DIR=%LOCALAPPDATA%\Android\sdk\ndk
if not exist "%NDK_DIR%" (
    echo Không tìm thấy thư mục NDK.
    exit /b 1
)

:: Tìm tất cả các phiên bản NDK có sẵn
echo Phát hiện các phiên bản NDK:
dir /b "%NDK_DIR%" | findstr /V /R "^$" > temp_ndk_versions.txt

:: Hiển thị các phiên bản có sẵn
set i=1
for /f "tokens=*" %%a in (temp_ndk_versions.txt) do (
    echo !i!. %%a
    set "ndk_version_!i!=%%a"
    set /a i+=1
)

:: Chỉnh sửa app\build.gradle.kts để sử dụng phiên bản NDK mới nhất
set latestVer=
for /f "tokens=*" %%a in (temp_ndk_versions.txt) do (
    set "latestVer=%%a"
)

if "%latestVer%" == "" (
    echo Không tìm thấy phiên bản NDK nào.
    del temp_ndk_versions.txt
    exit /b 1
)

echo Sử dụng phiên bản NDK mới nhất: %latestVer%

:: Tìm và thay thế dòng NDK version
powershell -Command "(Get-Content app\build.gradle.kts) -replace 'ndkVersion = \"[^\"]*\"', 'ndkVersion = \"%latestVer%\" // auto-selected by script' | Set-Content app\build.gradle.kts"

del temp_ndk_versions.txt
echo Đã cập nhật file build.gradle.kts với phiên bản NDK: %latestVer%
