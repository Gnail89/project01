@echo off
rem //setting variables
set NAME="Wireless Network Connection"
rem //setting ip,dns,gateway
set ADDR=192.168.99.253
set MASK=255.255.255.0
set GATEWAY=192.168.99.254
set DNS1=192.168.99.254
set DNS2=8.8.8.8
rem //setting completed

echo Please choose an option (enter the number):
echo 1 setup Static IP, VPN performance option.
echo 2 setup Dynamic IP, VPN does not performance.
echo 3 Exit.
echo Please choose:
set /p operate=
if %operate%==1 goto 1
if %operate%==2 goto 2
if %operate%==3 goto 3

:1
echo setup Static IP, please wait.
echo IP Address = %ADDR%
echo Netmask = %MASK%
echo Gateway = %GATEWAY%
netsh interface ipv4 set address name=%NAME% source=static addr=%ADDR% mask=%MASK% gateway=%GATEWAY% gwmetric=0 >nul
echo Primary DNS = %DNS1%
netsh interface ipv4 set dns name=%NAME% source=static addr=%DNS1% register=PRIMARY >nul
echo Second DNS = %DNS2%
netsh interface ipv4 add dns name=%NAME% addr=%DNS2% index=2 >nul
echo Completed.
pause
goto 3

:2
echo setup Dynamic IP, please wait.
netsh interface ip set address %NAME% dhcp
netsh interface ip set dns %NAME% dhcp
echo Completed.
pause
goto 3

:3
exit
