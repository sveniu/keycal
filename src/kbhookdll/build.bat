@echo off

\masm32\bin\ml /c /coff /Cp kbhook.asm

\masm32\bin\Link /SECTION:.bss,S  /DLL /DEF:kbhook.def /SUBSYSTEM:WINDOWS /LIBPATH:\masm32\lib kbhook.obj

pause