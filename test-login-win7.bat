@echo off
chcp 65001 >nul
title Tailscale Win7 兼容版 - 登录测试
echo ============================================================
echo  Tailscale Win7 兼容版 (go-legacy-win7 工具链编译)
echo  实际运行 + 登录测试脚本
echo ============================================================
ver
echo.

echo [1/4] 检查文件...
if not exist "%~dp0tailscaled-win7-legacy.exe" (
  echo   [错误] 找不到 tailscaled-win7-legacy.exe
  goto :end
)
if not exist "%~dp0tailscale-win7-legacy.exe" (
  echo   [错误] 找不到 tailscale-win7-legacy.exe
  goto :end
)
echo   OK - 文件齐全

echo [2/4] 以当前用户启动 tailscaled (无管理员时用用户态 state)...
start "tailscaled" /min "%~dp0tailscaled-win7-legacy.exe" --state="%~dp0ts-state.json" --socket="%~dp0ts.sock"
timeout /t 3 /nobreak >nul

echo [3/4] 发起登录 (tailscale up)...
"%~dp0tailscale-win7-legacy.exe" --socket="%~dp0ts.sock" up
echo.
echo   如果上面输出 https://login.tailscale.com/ 开头的链接：
echo   请用浏览器打开它，登录你的 Tailscale 账号并授权这台设备。
echo   登录完成后回到本窗口按任意键继续。
pause >nul

echo [4/4] 检查登录状态...
"%~dp0tailscale-win7-legacy.exe" --socket="%~dp0ts.sock" status
echo.
echo   判定标准:
echo     - 显示 "Logged out"            = 尚未登录 / 登录失败
echo     - 显示机器名 + 100.x.x.x 地址  = 登录成功, 组网正常!
echo     - 窗口闪退 / "不是有效的Win32" = PE 版本仍被系统拒绝
echo.
echo   测试完关闭 tailscaled:
echo     taskkill /f /im tailscaled-win7-legacy.exe
:end
pause
