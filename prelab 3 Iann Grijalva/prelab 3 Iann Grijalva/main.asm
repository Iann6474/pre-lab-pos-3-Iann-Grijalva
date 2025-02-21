;************************
; Universidad del Valle de Guatemala
; IE2025: Programación de Microcontroladores.
; PreLab2 Display.asm
;
; Created: 20/02/2025
; Author : Iann Grjalva
; Proyecto: prelab 3 
; Hardware: ATMega328P
;************************
.include "m328pdef.inc"

.org 0x0000
    RJMP inicio          

.org PCI0addr           ; dirección de la interrupción PCINT0 on-change
    RJMP pro            ; rutina de interrupción 

inicio:
    LDI R16, 0x0F      
    OUT DDRC, R16       ; configurar PORTC como salida
    CLR R16
    OUT PORTC, R16      ; apagar los leds en PORTC
    LDI R16, 0x00      
    OUT DDRB, R16       ; configurar PORTB como entrada
    LDI R16, (1 << PB3) | (1 << PB4)    ; activar pull-ups internos en PB3 y PB4
    OUT PORTB, R16
    LDI R16, (1 << PCIE0)              ; habilitar pcint en PORTB
    STS PCICR, R16
    LDI R16, (1 << PCINT3) | (1 << PCINT4) ; habilitar interrupciones en PB3 y PB4
    STS PCMSK0, R16
    LDI R17, 0x00   
    sei                 

MAIN_LOOP:
    RJMP MAIN_LOOP      

pro:
    PUSH R16           ; guardar R16 en la pila
    IN R16, PINB       ; leer el estado de PINB
    SBIC PINB, PB3     ; saltar si PB3 no esta presionado
    RCALL incr         ; si PB3 está presionado incrementar
    SBIC PINB, PB4     ; saltar si PB4 no esta presionado
    RCALL decr         ; si PB4 está presionado decrementar
    POP R16            ; restaurar R16 desde la pila
    RETI               ; salir de la interrupción

incr:
    RCALL DELAY         
    INC R17             ; incrementar el contador
    ANDI R17, 0x0F      ; mantener el contador en 4 bits 
    RCALL acled         ; actualizar los leds
    RET

decr:
    RCALL DELAY         
    DEC R17             ; decrementar el contador
    ANDI R17, 0x0F      ; mantener el contador en 4 bits 
    RCALL acled         ; actualizar los leds
    RET

acled:
    MOV R16, R17
    OUT PORTC, R16      ; mostrar el valor de R17 en los leds
    RET

DELAY:
    LDI R18, 0xFF       
DELAY_LOOP:
    DEC R18            
    BRNE DELAY_LOOP     
    RET
