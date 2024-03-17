@echo off
echo DECKER OS BUILDSCRIPT
echo Assembling Master Boot Record
nasm -O0 -f bin -o ./bin/mbr.bin ./src/mbr.asm -I decker/src/architecturedefines/arvhitecturedefines.asm
pause