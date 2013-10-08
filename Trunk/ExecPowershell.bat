@echo off

rem %1 is the name of the powershell script to execute.

powershell.exe -executionPolicy Unrestricted -Command "& { %1 }"