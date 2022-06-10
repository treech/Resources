CHCP 65001
@echo off
:again
cls
echo.
echo.
echo ######################输入编号######################
echo 1.开启git代理
echo 2.关闭git代理
set /p num=
if "%num%"=="1" (
git config --global https.proxy socks5://127.0.0.1:1080
git config --global http.proxy socks5://127.0.0.1:1080
echo 代理已开启
)

if "%num%"=="2" (
git config --global --unset http.proxy
git config --global --unset https.proxy
echo 代理已关闭
)
git config --global --get http.proxy
git config --global --get https.proxy
pause