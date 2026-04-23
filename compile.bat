
@echo off
sjasmplus.exe --zxnext=cspect NextPlayer.asm --lst=NextPlayer.lst --sym=NextPlayer.sym.txt
if errorlevel 1 (
    echo.
    echo *** BUILD FAILED ***
    pause
    exit /b 1
)
echo.
echo *** BUILD OK: memdump.bin ***
echo Copy 'memdump' to /dot/ folder on your Next SD card.
D:\Source\Assembler\CSpect\hdfmonkey.exe put D:\Source\Assembler\CSpect\cspect-next-2gb.img NextPlayer.nex /
echo Usage: .memdump

echo Spoustim CSpect...
D:\Source\Assembler\CSpect\CSpect.exe -zxnext -basickeys -tv -mmc=D:\Source\Assembler\CSpect\cspect-next-2gb.img 

