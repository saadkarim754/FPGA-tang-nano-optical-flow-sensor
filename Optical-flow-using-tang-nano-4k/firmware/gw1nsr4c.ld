/*============================================================================
 * Linker Script for Gowin EMPU (GW1NSR-4C) Cortex-M3
 * Memory: 16KB SRAM at 0x20000000 (program + data)
 *         No flash — code runs from SRAM initialized via bitstream
 *============================================================================*/

MEMORY
{
    /* SRAM: 16KB, used for both code and data */
    SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 16K
}

/* Entry point */
ENTRY(Reset_Handler)

/* Stack at top of SRAM */
_estack = ORIGIN(SRAM) + LENGTH(SRAM);

SECTIONS
{
    /* Vector table must be at the start of SRAM */
    .isr_vector :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector))
        . = ALIGN(4);
    } > SRAM

    /* Code */
    .text :
    {
        . = ALIGN(4);
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        . = ALIGN(4);
        _etext = .;
    } > SRAM

    /* Initialized data */
    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > SRAM

    /* Uninitialized data (BSS) */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > SRAM

    /* Ensure minimum stack space */
    ._stack :
    {
        . = ALIGN(8);
        . = . + 0x400;  /* 1KB minimum stack */
        . = ALIGN(8);
    } > SRAM
}
