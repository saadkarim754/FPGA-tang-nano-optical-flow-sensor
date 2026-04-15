@echo off
REM ============================================================================
REM Build script for Gowin EMPU Cortex-M3 Firmware
REM Uses arm-none-eabi-gcc from STM32CubeIDE installation
REM ============================================================================

set TOOLCHAIN=D:\stm32-softwares\STM32CubeIDE_2.0.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.13.3.rel1.win32_1.0.100.202509120712\tools\bin

set CC=%TOOLCHAIN%\arm-none-eabi-gcc.exe
set OBJCOPY=%TOOLCHAIN%\arm-none-eabi-objcopy.exe
set SIZE=%TOOLCHAIN%\arm-none-eabi-size.exe

set TARGET=optical_flow_fw
set CPU_FLAGS=-mcpu=cortex-m3 -mthumb -mfloat-abi=soft
set CFLAGS=%CPU_FLAGS% -Os -g -Wall -std=c99 -ffunction-sections -fdata-sections -ffreestanding -nostdlib

if not exist build mkdir build

echo [1/4] Compiling startup...
%CC% %CPU_FLAGS% -c startup_gw1nsr4c.s -o build\startup_gw1nsr4c.o
if errorlevel 1 goto :error

echo [2/4] Compiling main.c...
%CC% %CFLAGS% -c main.c -o build\main.o
if errorlevel 1 goto :error

echo [3/4] Compiling flow_calc.c...
%CC% %CFLAGS% -c flow_calc.c -o build\flow_calc.o
if errorlevel 1 goto :error

echo [4/4] Linking...
%CC% %CPU_FLAGS% -T gw1nsr4c.ld -Wl,--gc-sections -nostartfiles -nostdlib build\startup_gw1nsr4c.o build\main.o build\flow_calc.o -lgcc -o build\%TARGET%.elf
if errorlevel 1 goto :error

echo Generating binary...
%OBJCOPY% -O binary build\%TARGET%.elf build\%TARGET%.bin

echo.
echo ============================================
echo   BUILD SUCCESSFUL!
echo ============================================
%SIZE% build\%TARGET%.elf
echo.
echo   ELF:    firmware\build\%TARGET%.elf
echo   Binary: firmware\build\%TARGET%.bin
echo ============================================

goto :done

:error
echo.
echo *** BUILD FAILED ***
exit /b 1

:done
