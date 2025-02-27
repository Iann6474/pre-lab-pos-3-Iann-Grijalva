;************************
; Universidad del Valle de Guatemala
; IE2025: Programaci�n de Microcontroladores.
; PreLab2 Display.asm
;
; Created: 24/02/2025
; Author : Iann Grjalva
; Proyecto: poslab 3 
; Hardware: ATMega328P
;************************
.include "m328pdef.inc"

.def alm = r16        ; operaciones generales
.def bincon = r17 ; contador binario 
.def con = r18        ; timer
.def temp = r19       ; registro temporal
.def segundos = r20   ; contador de segundos 
.def camb = r21 ; bandera para alternar entre displays (0=unidades, 1=decenas)
.def div = r22   ; registro temporal para divisiones
.def decenas = r23    ; almacena las decenas del contador
.def unidades = r24   ; almacena las unidades del contador

.cseg
.org 0x0000
    RJMP inicio       ; salta a la etiqueta inicio cuando el microcontrolador arranca
.org PCI0addr           
    RJMP pro          ; salta al manejador de interrupci�n de los botones
.org 0x0020            ; direcci�n de la interrupci�n del timer0
    RJMP ISR_TMR0      ; salta al manejador de interrupci�n del timer

inicio:
   
    ; PC4 y PC5 como salidas para controlar los displays
    LDI alm, 0x3F     
    OUT DDRC, alm      
        LDI alm, (1 << PC4) | (1 << PC5)  ; pongo en 1 los pines 4 y 5 para apagar displays
    OUT PORTC, alm     ; actualizo el puerto c
    
    LDI alm, 0x00     
    OUT DDRB, alm      ; configuro el puerto b como entradas pull up
    LDI alm, (1 << PB3) | (1 << PB4)  
    OUT PORTB, alm   

    LDI alm, (1 << PCIE0)              ; habilito interrupciones en el puerto b
    STS PCICR, alm                     
    LDI alm, (1 << PCINT3) | (1 << PCINT4)  ; habilito los pines 3 y 4 para interrupciones
    STS PCMSK0, alm                    ; guardo la m�scara de los pines que generan interrupciones

    LDI alm, 0xFF      
    OUT DDRD, alm      ; configuro todo el puerto d como salidas para los segmentos

    ; Guardar los valores de los n�meros del display en la SRAM
    LDI ZH, HIGH(0x0100)  ; cargo la parte alta de la direcci�n de memoria
    LDI ZL, LOW(0x0100)   ; cargo la parte baja de la direcci�n de memoria
    LDI alm, 0b00111111  ;  patr�n para mostrar 0 en el display
    ST Z+, alm            ; guardo en memoria y aumento el puntero
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
    
   
    CLR segundos       ; pongo a cero el contador de segundos
    CLR camb           ; inicializo la bandera para mostrar primero unidades
    CLR con            ; pongo a cero el contador del timer
    CLR bincon    ; pongo a cero el contador binario
    RCALL acled        ; llamo a la funci�n para inicializar los leds
    RCALL actualizar_digitos  ; calculo las decenas y unidades iniciales
    
    ; Configurar el timer0 para generar interrupciones peri�dicas aproximadamente cada 10ms
    LDI alm, (1 << CS02) | (0 << CS01) | (1 << CS00)  ;  prescaler a 1024
    OUT TCCR0B, alm    ; registro de control del timer
    LDI alm, 155       ; cargo 155 para contar hasta ese valor (da aprox 10ms)
    OUT OCR0A, alm     
    LDI alm, (1 << WGM01)  
    OUT TCCR0A, alm    ; actualizo el registro de control del timer
    LDI alm, (1 << OCIE0A)  
    STS TIMSK0, alm    ; actualizo la m�scara de interrupciones del timer
    
    SEI  ; interrupciones globales 

MAIN_LOOP:
    RJMP MAIN_LOOP     ; bucle infinito todo se hace en las interrupciones

; Interrupci�n PCINT0 para detectar cambios en los botones
pro:
    PUSH alm           
    IN alm, PINB       
    SBRS alm, PB3      ; si el bit 3 est� a 0 salta la siguiente instrucci�n
    RCALL incr         ; si no salt� llama a la funci�n de incremento
    SBRS alm, PB4      ; si el bit 4 est� a 0 salta la siguiente instrucci�n
    RCALL decr         ; si no salt� llama a la funci�n de decremento
    POP alm            
    RETI               ; regreso de la interrupci�n

incr:
    RCALL DELAY        
    INC bincon    ; incremento el contador binario en 1
    ANDI bincon, 0x0F  ; mantener solo 4 bits
    RCALL acled        ; actualizo los leds con el nuevo valor
    RET                 ; regreso de la subrutina

decr:
    RCALL DELAY       
    DEC bincon    ; decremento el contador binario en 1
    ANDI bincon, 0x0F  ; mantengo solo 4 bits
    RCALL acled        ; actualizo los leds
    RET                 ; regreso de la subrutina

acled:
    
    IN temp, PORTC     ; leo el estado actual del puerto c
    ANDI temp, 0x30    ; hago and para mantener solo pc4 y pc5
    MOV alm, bincon  ; copio el valor del contador a alm
    ANDI alm, 0x0F     ; aseguro que solo uso los 4 bits menos significativos
    OR alm, temp       ; combino con los bits de control de displays
    OUT PORTC, alm     ; actualizo el puerto c 
    RET                 ; regreso de la subrutina

DELAY:
    LDI temp, 0xFF     
DELAY_LOOP:
    DEC temp           ; decremento el contador 
    BRNE DELAY_LOOP    ; mientras no sea cero, sigo en el bucle
    RET                 ; cuando llega a cero, salgo del retardo

ISR_TMR0:
    ; Actualizar display 
    RCALL mostrarnumero  ; llamo a la funci�n que actualiza el display
    
    INC con            ; incremento el contador de tiempo
    CPI con, 100       ; comparo si lleg� a 100 (10ms * 100 = 1 segundo)
    BRNE no_incrementar_segundos  ; si no es 100 salto
    CLR con            ; si lleg� a 100 reseteo el contador
    
    ; Incrementar segundos 
    INC segundos       ; incremento el contador de segundos
    CPI segundos, 60   ; comparo si lleg� a 60 segundos
    BRNE no_reset_segundos  ; si no es 60 salto
    CLR segundos       ; si lleg� a 60 reinicio a 0
no_reset_segundos:
    RCALL actualizar_digitos  ; recalculo decenas y unidades
no_incrementar_segundos:
    RETI                ; regreso de la interrupci�n

actualizar_digitos:
    ; Calcular decenas y unidades
    MOV alm, segundos   ; copio el valor de segundos a alm
    LDI div, 10         ; cargo 10 como divisor
    CLR decenas         ; pongo a cero el contador de decenas
div_loop:
    CPI alm, 10         ; comparo si alm es menor que 10
    BRLO div_end        ; si es menor termino de dividir
    SUBI alm, 10        ; si no resto 10
    INC decenas         ; incremento el contador de decenas
    RJMP div_loop       ; vuelvo a comparar
div_end:
    MOV unidades, alm   ; lo que queda en alm son las unidades
    RET                  ; regreso de la subrutina

mostrarnumero:
    LDI ZH, HIGH(0x0100)  ; cargo la direcci�n base de la tabla en sram
    LDI ZL, LOW(0x0100)   ; parte baja de la direcci�n
    
    CPI camb, 0          ; comparo si estamos en modo unidades
    BRNE mostrar_decenas  ; si no es 0, salto a mostrar decenas
    
    ; mostrar unidades en PC4
    MOV alm, unidades     ; copio el valor de unidades
    ADD ZL, alm           ; sumo al puntero para ubicar el patr�n correcto
    BRCC no_carry_u       ; si no hay carry sigo
    INC ZH                ; si hay carry incremento 
no_carry_u:
    LD alm, Z             ; cargo el patr�n de segmentos desde la memoria
    OUT PORTD, alm        ; actualizo el puerto d con el patr�n
    
    ; activar display de unidades, desactivar decenas 
    ; guardo los bits del contador binario 
    IN temp, PORTC       ; leo el estado actual
    ANDI temp, 0x0F      ; mantengo solo los bits del contador
    ORI temp, (1 << PC5) ; pongo a 1 pc5 para apagar ese display
    ANDI temp, ~(1 << PC4) ; pongo a 0 pc4 para encender ese display
    OUT PORTC, temp      ; actualizo el puerto
    
    LDI camb, 1          ; cambio la bandera para la pr�xima vez
    RET                    ; regreso
    
mostrar_decenas:
    ; mostrar decenas 
    MOV alm, decenas      ; copio el valor de decenas
    ADD ZL, alm           ; sumo al puntero para encontrar el patr�n
    BRCC no_carry_d       ; si no hay carry sigo
    INC ZH                ; si hay carry incremento
no_carry_d:
    LD alm, Z             ; cargo el patr�n desde memoria
    OUT PORTD, alm        ; actualizo el puerto d
    
    ; activar display de decenas, desactivar unidades 
    ; guardar los bits del contador binario 
    IN temp, PORTC       ; leo estado actual
    ANDI temp, 0x0F      ; mantengo solo bits del contador
    ORI temp, (1 << PC4) ; pongo a 1 pc4 para apagar ese display
    ANDI temp, ~(1 << PC5) ; pongo a 0 pc5 para encender ese display
    OUT PORTC, temp      ; actualizo el puerto
    
    LDI camb, 0          ; cambio la bandera a 0 para mostrar unidades despu�s
    RET  