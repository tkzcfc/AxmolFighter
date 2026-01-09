@echo off
echo Formatting C++ files...

set "FORMAT_DIRS=Source "

set "IGNORE_FILES=md5.cpp md5.h sha-256.cpp sha-256.h FacebookManager.mm"
for /r "Source" %%f in (*.cpp, *.h, *.mm) do (
	set "SKIP_FILE="
    for %%I in (%IGNORE_FILES%) do (
        if "%%~nxf"=="%%I" set "SKIP_FILE=1"
    )
	if not defined SKIP_FILE (
		echo Formatting %%f
		clang-format -i "%%f"
	)
)

for /r "proj.ios_mac" %%f in (*.cpp, *.h, *.mm) do (
    set "SKIP_FILE="
    for %%I in (%IGNORE_FILES%) do (
        if "%%~nxf"=="%%I" set "SKIP_FILE=1"
    )
    if not defined SKIP_FILE (
        echo Formatting %%f
        clang-format --style=file:proj.ios_mac/.clang-format -i "%%f"
    )
)

echo Formatting complete!
pause