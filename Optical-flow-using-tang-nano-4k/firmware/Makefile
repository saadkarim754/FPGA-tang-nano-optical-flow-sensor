#============================================================================
# Makefile for Gowin EMPU Cortex-M3 Firmware
# Uses arm-none-eabi-gcc from STM32CubeIDE installation
#============================================================================

# Toolchain path (from STM32CubeIDE)
TOOLCHAIN_PATH = D:/stm32-softwares/STM32CubeIDE_2.0.0/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.13.3.rel1.win32_1.0.100.202509120712/tools/bin

CC      = $(TOOLCHAIN_PATH)/arm-none-eabi-gcc
OBJCOPY = $(TOOLCHAIN_PATH)/arm-none-eabi-objcopy
OBJDUMP = $(TOOLCHAIN_PATH)/arm-none-eabi-objdump
SIZE    = $(TOOLCHAIN_PATH)/arm-none-eabi-size

# Target
TARGET = optical_flow_fw

# CPU flags for Cortex-M3
CPU_FLAGS = -mcpu=cortex-m3 -mthumb -mfloat-abi=soft

# Compiler flags
CFLAGS  = $(CPU_FLAGS) -Os -g -Wall -std=c99
CFLAGS += -ffunction-sections -fdata-sections
CFLAGS += -ffreestanding -nostdlib

# Linker flags
LDFLAGS  = $(CPU_FLAGS) -T gw1nsr4c.ld
LDFLAGS += -Wl,--gc-sections
LDFLAGS += -nostartfiles -nostdlib
LDFLAGS += -lgcc

# Source files
C_SOURCES = main.c flow_calc.c
ASM_SOURCES = startup_gw1nsr4c.s

# Object files
OBJECTS = $(C_SOURCES:.c=.o) $(ASM_SOURCES:.s=.o)

# Build directory
BUILD_DIR = build

#============================================================================
# Build targets
#============================================================================
.PHONY: all clean

all: $(BUILD_DIR)/$(TARGET).bin $(BUILD_DIR)/$(TARGET).mi
	@echo "============================================"
	@echo "  Build complete!"
	@echo "  Binary: $(BUILD_DIR)/$(TARGET).bin"
	@echo "  Memory Init: $(BUILD_DIR)/$(TARGET).mi"
	@echo "============================================"
	$(SIZE) $(BUILD_DIR)/$(TARGET).elf

# Link
$(BUILD_DIR)/$(TARGET).elf: $(addprefix $(BUILD_DIR)/, $(OBJECTS)) | $(BUILD_DIR)
	$(CC) $(LDFLAGS) $^ -o $@

# Compile C
$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile ASM
$(BUILD_DIR)/%.o: %.s | $(BUILD_DIR)
	$(CC) $(CPU_FLAGS) -c $< -o $@

# Generate raw binary
$(BUILD_DIR)/$(TARGET).bin: $(BUILD_DIR)/$(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# Generate Intel HEX (needed by some Gowin tools)
$(BUILD_DIR)/$(TARGET).hex: $(BUILD_DIR)/$(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

# Generate Gowin Memory Init (.mi) file from binary
# Format: one 32-bit hex word per line, little-endian
$(BUILD_DIR)/$(TARGET).mi: $(BUILD_DIR)/$(TARGET).bin
	@echo Generating Gowin .mi file...
	@powershell -Command "$$bytes = [System.IO.File]::ReadAllBytes('$<'); $$lines = @(); for ($$i = 0; $$i -lt $$bytes.Length; $$i += 4) { $$w = [uint32]$$bytes[$$i]; if ($$i+1 -lt $$bytes.Length) { $$w = $$w -bor ([uint32]$$bytes[$$i+1] -shl 8) }; if ($$i+2 -lt $$bytes.Length) { $$w = $$w -bor ([uint32]$$bytes[$$i+2] -shl 16) }; if ($$i+3 -lt $$bytes.Length) { $$w = $$w -bor ([uint32]$$bytes[$$i+3] -shl 24) }; $$lines += $$w.ToString('X8') }; $$lines | Set-Content '$(BUILD_DIR)/$(TARGET).mi'"
	@echo Done: $(BUILD_DIR)/$(TARGET).mi

# Disassembly (for debugging)
$(BUILD_DIR)/$(TARGET).lst: $(BUILD_DIR)/$(TARGET).elf
	$(OBJDUMP) -d -S $< > $@

# Create build directory
$(BUILD_DIR):
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)

# Clean
clean:
	@if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)
	@echo Cleaned.
