@echo off
setlocal
set "SRC=%~dp0"
set "DST=%LOCALAPPDATA%\CodexZh"

echo.
echo   正在安装 Codex 汉化...
echo.

if not exist "%DST%" mkdir "%DST%"
copy /y "%SRC%hanhua.ps1" "%DST%\hanhua.ps1" >nul
copy /y "%SRC%start-hanhua.bat" "%DST%\start-hanhua.bat" >nul

powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%DST%' -File | Unblock-File -ErrorAction SilentlyContinue"
powershell -NoProfile -Command "$d=[Environment]::GetFolderPath('Desktop'); $s=(New-Object -ComObject WScript.Shell).CreateShortcut($d+'\Codex 中文版.lnk'); $s.TargetPath='%DST%\start-hanhua.bat'; $s.WorkingDirectory='%DST%'; $s.WindowStyle=7; $s.Save()"

echo   安装完成！
echo.
echo   桌面上已生成「Codex 中文版」快捷方式，
echo   以后双击它打开 Codex 即可。
echo.
pause