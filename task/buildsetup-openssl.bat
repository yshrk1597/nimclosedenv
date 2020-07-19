rem Copyright (c) 2020 Hiroki YASUHARA
rem MIT License - Look at LICENSE.txt for details.

cd /d "%~dp0"

rem add perl to path 
rem set PATH=D:\Local\strawberry-perl-5.30.2.1-64bit-portable\perl\bin;%PATH%

rem call vcvarsall.bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64

pushd ..\src\openssl-1.1.1g

perl Configure VC-WIN64A no-asm no-shared no-filenames no-tests no-ui-console zlib -static

nmake build_generated
nmake crypto\buildinf.h

popd
pause