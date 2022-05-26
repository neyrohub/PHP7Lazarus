@echo off
SET THEFILE=C:\lazarus64\ProjectsMy\PhpScreen\PhpScreen_Laz_02\php_screen_lazarus.dll
echo Linking %THEFILE%
C:\lazarus64\fpc\3.2.0\bin\x86_64-win64\ld.exe -b pei-x86-64  --gc-sections  -s --dll  --entry _DLLMainCRTStartup   --base-file base.$$$ -o C:\lazarus64\ProjectsMy\PhpScreen\PhpScreen_Laz_02\php_screen_lazarus.dll C:\lazarus64\ProjectsMy\PhpScreen\PhpScreen_Laz_02\link.res
if errorlevel 1 goto linkend
dlltool.exe -S C:\lazarus64\fpc\3.2.0\bin\x86_64-win64\as.exe -D C:\lazarus64\ProjectsMy\PhpScreen\PhpScreen_Laz_02\php_screen_lazarus.dll -e exp.$$$ --base-file base.$$$ 
if errorlevel 1 goto linkend
C:\lazarus64\fpc\3.2.0\bin\x86_64-win64\ld.exe -b pei-x86-64  -s --dll  --entry _DLLMainCRTStartup   -o C:\lazarus64\ProjectsMy\PhpScreen\PhpScreen_Laz_02\php_screen_lazarus.dll C:\lazarus64\ProjectsMy\PhpScreen\PhpScreen_Laz_02\link.res exp.$$$
if errorlevel 1 goto linkend
goto end
:asmend
echo An error occurred while assembling %THEFILE%
goto end
:linkend
echo An error occurred while linking %THEFILE%
:end
