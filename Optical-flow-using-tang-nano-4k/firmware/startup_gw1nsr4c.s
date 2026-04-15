/**============================================================================
 * Startup Code for Gowin EMPU (GW1NSR-4C) Cortex-M3
 * Minimal vector table + reset handler
 * Compatible with arm-none-eabi-gcc
 *============================================================================*/

    .syntax unified
    .cpu cortex-m3
    .thumb

/*--------------------------------------------------------------------------
 * Vector Table (placed at SRAM base 0x20000000)
 *--------------------------------------------------------------------------*/
    .section .isr_vector, "a", %progbits
    .type g_pfnVectors, %object

g_pfnVectors:
    .word _estack               /* 0x00: Initial Stack Pointer */
    .word Reset_Handler         /* 0x04: Reset Handler */
    .word NMI_Handler           /* 0x08: NMI Handler */
    .word HardFault_Handler     /* 0x0C: Hard Fault Handler */
    .word MemManage_Handler     /* 0x10: MPU Fault Handler */
    .word BusFault_Handler      /* 0x14: Bus Fault Handler */
    .word UsageFault_Handler    /* 0x18: Usage Fault Handler */
    .word 0                     /* 0x1C: Reserved */
    .word 0                     /* 0x20: Reserved */
    .word 0                     /* 0x24: Reserved */
    .word 0                     /* 0x28: Reserved */
    .word SVC_Handler           /* 0x2C: SVCall Handler */
    .word DebugMon_Handler      /* 0x30: Debug Monitor Handler */
    .word 0                     /* 0x34: Reserved */
    .word PendSV_Handler        /* 0x38: PendSV Handler */
    .word SysTick_Handler       /* 0x3C: SysTick Handler */

    /* External Interrupts (Gowin EMPU) */
    .word UART0_Handler         /* 0x40: IRQ0  - UART0 */
    .word UART1_Handler         /* 0x44: IRQ1  - UART1 */
    .word Timer0_Handler        /* 0x48: IRQ2  - Timer0 */
    .word Timer1_Handler        /* 0x4C: IRQ3  - Timer1 */
    .word GPIO0_Handler         /* 0x50: IRQ4  - GPIO0 */
    .word USER_INT0_Handler     /* 0x54: IRQ5  - User Interrupt 0 (Frame Ready!) */
    .word USER_INT1_Handler     /* 0x58: IRQ6  - User Interrupt 1 */
    .word 0                     /* 0x5C: IRQ7  - Reserved */
    .word 0                     /* 0x60: IRQ8  - Reserved */
    .word 0                     /* 0x64: IRQ9  - Reserved */
    .word 0                     /* 0x68: IRQ10 - Reserved */
    .word 0                     /* 0x6C: IRQ11 - Reserved */
    .word 0                     /* 0x70: IRQ12 - Reserved */
    .word 0                     /* 0x74: IRQ13 - Reserved */
    .word 0                     /* 0x78: IRQ14 - Reserved */
    .word 0                     /* 0x7C: IRQ15 - Reserved */

    .size g_pfnVectors, . - g_pfnVectors

/*--------------------------------------------------------------------------
 * Reset Handler: Zero BSS, then call main()
 *--------------------------------------------------------------------------*/
    .section .text.Reset_Handler
    .weak Reset_Handler
    .type Reset_Handler, %function
Reset_Handler:
    /* Set stack pointer */
    ldr r0, =_estack
    mov sp, r0

    /* Zero-fill BSS section */
    movs r0, #0
    ldr r1, =_sbss
    ldr r2, =_ebss
bss_loop:
    cmp r1, r2
    bge bss_done
    str r0, [r1]
    adds r1, r1, #4
    b bss_loop
bss_done:

    /* Call main() */
    bl main

    /* If main returns, loop forever */
hang:
    b hang

    .size Reset_Handler, . - Reset_Handler

/*--------------------------------------------------------------------------
 * Default Handlers: Weak aliases to infinite loop
 *--------------------------------------------------------------------------*/
    .section .text.Default_Handler, "ax", %progbits
Default_Handler:
    b .
    .size Default_Handler, . - Default_Handler

    /* System exceptions */
    .weak NMI_Handler
    .thumb_set NMI_Handler, Default_Handler

    .weak HardFault_Handler
    .thumb_set HardFault_Handler, Default_Handler

    .weak MemManage_Handler
    .thumb_set MemManage_Handler, Default_Handler

    .weak BusFault_Handler
    .thumb_set BusFault_Handler, Default_Handler

    .weak UsageFault_Handler
    .thumb_set UsageFault_Handler, Default_Handler

    .weak SVC_Handler
    .thumb_set SVC_Handler, Default_Handler

    .weak DebugMon_Handler
    .thumb_set DebugMon_Handler, Default_Handler

    .weak PendSV_Handler
    .thumb_set PendSV_Handler, Default_Handler

    .weak SysTick_Handler
    .thumb_set SysTick_Handler, Default_Handler

    /* Peripheral interrupts */
    .weak UART0_Handler
    .thumb_set UART0_Handler, Default_Handler

    .weak UART1_Handler
    .thumb_set UART1_Handler, Default_Handler

    .weak Timer0_Handler
    .thumb_set Timer0_Handler, Default_Handler

    .weak Timer1_Handler
    .thumb_set Timer1_Handler, Default_Handler

    .weak GPIO0_Handler
    .thumb_set GPIO0_Handler, Default_Handler

    .weak USER_INT0_Handler
    .thumb_set USER_INT0_Handler, Default_Handler

    .weak USER_INT1_Handler
    .thumb_set USER_INT1_Handler, Default_Handler
