;************************
; Universidad del Valle de Guatemala
; IE2025: Programación de Microcontroladores.
; PreLab2 Display.asm
;
; Created: 21/02/2025
; Author : Iann Grjalva
; Proyecto: lab 3 
; Hardware: ATMega328P
;************************

.include "m328pdef.inc"

.def alm = r16        ; registro para operaciones
.def dis = r17        ; almacena el valor actual del display
.def con = r18        ; contador para medir 1 segundo
.def lb = r19         ; almacena el estado de los leds en PORTC

.cseg
.org 0x0000
    RJMP inicio  
.org PCI0addr           
    RJMP inb  
.org 0x0020            ; dirección de la interrupción del timer0
    RJMP ISR_TMR0

inicio:
    ; habilitar los primeros 4 bits de PORTC como salida para los leds
    LDI R16, 0x0F      
    OUT DDRC, R16
    CLR R16
    OUT PORTC, R16    
    
    ; configurar PORTB como entrada y activar pull-up en PB3 y PB4
    LDI R16, 0x00      
    OUT DDRB, R16      
    LDI R16, (1 << PB3) | (1 << PB4) 
    OUT PORTB, R16

    ; permitir interrupciones por cambios en PB3 y PB4
    LDI R16, (1 << PCIE0)              
    STS PCICR, R16
    LDI R16, (1 << PCINT3) | (1 << PCINT4)
    STS PCMSK0, R16

    ; establecer PORTD como salida para controlar el display de 7 segmentos
    LDI alm, 0xFF
    OUT DDRD, alm

    ; guardar los valores de los números del display en la SRAM
    LDI ZH, 0x00
    LDI ZL, 0x00
    LDI alm, 0b00111111  ;  0
    ST Z+, alm
    LDI alm, 0b00000110  ;  1
    ST Z+, alm
    LDI alm, 0b01011011  ;  2
    ST Z+, alm
    LDI alm, 0b01001111  ;  3
    ST Z+, alm
    LDI alm, 0b01100110  ;  4
    ST Z+, alm
    LDI alm, 0b01101101  ;  5
    ST Z+, alm
    LDI alm, 0b01111101  ;  6
    ST Z+, alm
    LDI alm, 0b00000111  ;  7
    ST Z+, alm
    LDI alm, 0b01111111  ;  8
    ST Z+, alm
    LDI alm, 0b01101111  ;  9
    ST Z+, alm
    
    ; inicializar variables de control
    CLR dis
    CLR con
    CLR lb
    RCALL mostrarnumero
    
    ; configurar el timer0 para generar interrupciones periódicas cada 8ms
    LDI alm, (1 << CS02) | (1 << CS00)  
    OUT TCCR0B, alm
    LDI alm, 124                        
    OUT OCR0A, alm
    LDI alm, (1 << WGM01)               
    OUT TCCR0A, alm
    LDI alm, (1 << OCIE0A)              
    STS TIMSK0, alm
    
    SEI  ; interrupciones globales

MAIN_LOOP:
    RJMP MAIN_LOOP  

; interrupción PCINT0 para detectar cambios en los botones
inb:
    PUSH R16           ; guardar R16 antes de modificarlo
    IN R16, PINB       ; leer el estado actual de los pines de PORTB
    SBIC PINB, PB3     ; si PB3 está no esta presionado pasar a la siguiente instrucción
    RCALL INCREMENTO   ; si PB3 está esta presionado incrementar
    SBIC PINB, PB4     ; si PB4 está no esta presionado pasar a la siguiente instrucción
    RCALL DECREMENTO   ; si PB4 está presionado decrementar
    POP R16            ; restaurar el valor original de R16
    RETI               ; finalizar interrupción

INCREMENTO:
    INC lb             ; aumentar el contador de leds
		ANDI lb, 0x0F      ; asegurarse de que solo se usen los 4 bits inferiores
		RCALL acl          ; actualizar la salida en los leds
		RET

	DECREMENTO:
		DEC lb             ; reducir el contador de leds
		ANDI lb, 0x0F      ; mantener el valor dentro del rango permitido
		RCALL acl          ; actualizar la salida en los leds
		RET

	acl:
		MOV R16, lb
		OUT PORTC, R16     ; enviar el nuevo valor a PORTC para mostrarlo en los leds
		RET


	; interrupción timer0 se ejecuta cada 8ms

	ISR_TMR0:
		INC con            ; aumentar contador para medir el tiempo transcurrido
		CPI con, 125       ; verificar si ha pasado aproximadamente 1 segundo
		BRNE no_incrementar
		CLR con            ; resetear contador de tiempo
		INC dis            ; aumentar el número mostrado en el display
		CPI dis, 10         ; verificar si ha llegado al límite de 10
		BRNE no_reset
		CLR dis            ; reiniciar el contador del display a 0
	no_reset:
		RCALL mostrarnumero
	no_incrementar:
		RETI

	mostrarnumero:
		LDI ZH, 0x00
		LDI ZL, 0x00
		ADD ZL, dis        ; calcular la dirección de la tabla de segmentos
		LD alm, Z          ; obtener el patrón de segmentos correspondiente
		OUT PORTD, alm     ; actualizar el display con el número actual
		RET

	