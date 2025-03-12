;
; Función reloj.asm
;
; Created: 11/03/2025 08:47:04 p. m.
; Author : ang50
;


;*****************************************************************************************************************
; Función "Mostrar Hora" y "Mostrar Fecha" del reloj digital.
; Las funciones, momentáneamente, se cambiarán en programación, no con la interfaz del usuario.

; --> Se utilizará TIM0 en 1ms para multiplexar displays y para incrementar variables de conteo de milisegundos.
; --> Se llevará la cuenta de milisegundos con registros de propósito general.
; --> Cuando ocurran 500ms, el programa "toggleará" los dos puntos del reloj para generar parpadeo.

; --> Cada display tendrá una localidad en RAM para guardar su valor HEX que tiene que "sacar" PORTD.

; --> Se utilizará TIM1 en 1s para conteo general de segundos.
; --> Se llevará la cuenta de segundos con un registro de propósito general.
; --> TIM1 tendrá prioridad sobre TIM0, por lo que, en TIM0, se activarán interrupciones anidadas SOLO de TIM1.

; --> Se utilizarán localidades de la RAM para guardar el conteo de minutos, horas y días.
; --> Cada conteo tendrá asociadas DOS variables: una para unidades y otra para decenas. 
; --> Esto para facilitar guardar los valores de cada display.

; --> En el MAIN LOOP, primero se actualizarán los valores de las variables de tiempo.
; --> Luego, se verificará si ya transcurrió el tiempo para "togglear" los dos puntos del reloj.
; --> Después, se guardarán los valores HEX que tendrá que mostrar cada display.
; --> Los valores a guardar dependerán si se quiere mostrar hora o fecha. 
;*****************************************************************************************************************


.include "M328PDEF.inc"


;*****************************************************************************************************************
; Algunas definiciones importantes:

; Valores de Timers
;.equ			T1VALUE_L			= 0xDC
;.equ			T1VALUE_H			= 0x0B
.equ			T1VALUE_L			= 0x00
.equ			T1VALUE_H			= 0x83
.equ			T0VALUE				= 6
;*****************************************************************************************************************

;*****************************************************************************************************************
; Localidades de memoria de datos 

; Variables de conteo
.equ			MINUTOS_UNIDADES	= 0x0101
.equ			MINUTOS_DECENAS		= 0x0102
.equ			HORAS_UNIDADES		= 0x0103
.equ			HORAS_DECENAS		= 0x0104
.equ			DIAS_UNIDADES		= 0x0105
.equ			DIAS_DECENAS		= 0x0106
.equ			MESES_UNIDADES		= 0x0107
.equ			MESES_DECENAS		= 0x0108

; Variables de cada display
.equ			DISPMODE_VALUE		= 0x0109
.equ			DISP0_VALUE			= 0x010A
.equ			DISP1_VALUE			= 0x010B
.equ			DISP2_VALUE			= 0x010C
.equ			DISP3_VALUE			= 0x010D

; "H", "F" y "A" para displays
.equ			DISPMODE_H			= 0x010E
.equ			DISPMODE_F			= 0x010F
.equ			DISPMODE_A			= 0x0110

; Días de cada mes (Solo primera localidad para apuntar con el XPointer)
.equ			DIAS_DE_MESES		= 0x0200
;*****************************************************************************************************************

;*****************************************************************************************************************
; Memoria de programa

.CSEG
.org 0x0000
	RJMP SETUP
; Guardamos un salto a la sub-rutina "TIM1_INTERRUPT" en el vector de interrupción necesario
.org OVF1addr
	RJMP TIM1_INTERRUPT
; Guardamos un salto a la sub-rutina "TIM0_INTERRUPT" en el vector de interrupción necesario
.org OVF0addr
	RJMP TIM0_INTERRUPT
; Guardamos una tabla para valores de DISP7SEG
.org 0x0040
	DISP7SEG:	
		.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
;*****************************************************************************************************************

;*****************************************************************************************************************
; Registros de propósito general
.def			msCOUNT0		= R20 
.def			msCOUNT1		= R21
.def			sCOUNT			= R22 
;*****************************************************************************************************************


;*****************************************************************************************************************
; Setup del código
SETUP:
    CLI

	;Deshabilitar serial (Importante; se utilizará PD para el display)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	;Configurar STACK
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	;*************************************************************************************************************
	; Guardamos algunos valores en RAM

	; Días de cada mes (Se le añade +1 a c/u para hacer la lógica correctamente)
	LDI		XL, LOW(DIAS_DE_MESES)
	LDI		XH, HIGH(DIAS_DE_MESES)
	LDI		R16, 32 ;Enero: 31 días
	ST		X+, R16
	LDI		R16, 29 ;Febrero: 28 días
	ST		X+, R16
	LDI		R16, 32 ;Marzo: 31 días
	ST		X+, R16
	LDI		R16, 31 ;Abril: 30 días
	ST		X+, R16
	LDI		R16, 31 ;Mayo: 31 días
	ST		X+, R16
	LDI		R16, 30 ;Junio: 30 días
	ST		X+, R16
	LDI		R16, 32 ;Julio: 31 días
	ST		X+, R16
	LDI		R16, 32 ;Agosto: 31 días
	ST		X+, R16 
	LDI		R16, 31 ;Septiembre: 30 días
	ST		X+, R16
	LDI		R16, 31 ;Octubre: 31 días
	ST		X+, R16
	LDI		R16, 30 ;Noviembre: 30 días
	ST		X+, R16
	LDI		R16, 32 ;Diciembre: 31 días
	ST		X+, R16

	; "H", "F" y "A" para displays
	LDI		R16, 0x76
	STS		DISPMODE_H, R16
	LDI		R16, 0x71
	STS		DISPMODE_F, R16
	LDI		R16, 0x77
	STS		DISPMODE_A, R16
	;*************************************************************************************************************

	;*************************************************************************************************************
	; Configuramos puertos I/O:

	; PORTD: Displays								|		PORTD: XXXXXXXX
	LDI		R16, 0xFF
	OUT		DDRD, R16
	LDI		R16, 0
	OUT		PORTD, R16

	; PORTB: Transistores de displays y Buzzer		|		PORTB: {0,0,BUZZER,DMODE,D3,D2,D1,D0}
	LDI		R16, 0xFF
	OUT		DDRB, R16
	LDI		R16, 0b00000001							;		¡Comienza un display encendido!
	OUT		PORTB, R16
	;*************************************************************************************************************

	;*************************************************************************************************************
	; Configuramos los timers:

	; Establecer TIM0 en modo Normal:
	; Prescaler TIM0 = 64 (Compartido con TIM2)
	; TCNT0 = 6
	; Activar Máscara
	; Activar Bandera de INT
	LDI		R16, (0 << CS02) |(1 << CS01) | (1 << CS00)
	OUT		TCCR0B, R16
	LDI		R16, (1 << TOIE0) 
	STS		TIMSK0, R16
	LDI		R16, T0VALUE
	OUT		TCNT0, R16
		
	; Establecer TIM1 en modo Normal:
	; Prescaler TIM0 = 256 
	; TCNT1H = 0B
	; TCNT1L = DC
	; Activar Máscara
	; Activar Bandera de INT
	;ESTE ES EL BUENO!!!! :
	;LDI		R16, (1 << CS12) |(0 << CS11) | (0 << CS10)
	;ESTE NO!!!:
	LDI		R16, (0 << CS12) |(1 << CS11) | (0 << CS10)
	STS		TCCR1B, R16
	LDI		R16, (1 << TOIE1) 
	STS		TIMSK1, R16
	LDI		R16, T1VALUE_H
	STS		TCNT1H, R16
	LDI		R16, T1VALUE_L
	STS		TCNT1L, R16
	;*************************************************************************************************************

	;*************************************************************************************************************
	; Algunos valores iniciales:

	; Valores iniciales de variables de conteo
	; Registros de propósito general
	LDI		msCOUNT0, 0
	LDI		msCOUNT1, 0
	LDI		sCOUNT, 0
	; R0=0
	LDI		R16, 0
	MOV		R0, R16	
	; Localidades en RAM
	LDI		R16, 0
	STS		MINUTOS_UNIDADES, R16
	STS		MINUTOS_DECENAS, R16
	STS		HORAS_UNIDADES, R16
	STS		HORAS_DECENAS, R16
	STS		DIAS_UNIDADES, R16
	STS		DIAS_DECENAS, R16
	STS		MESES_UNIDADES, R16
	STS		MESES_DECENAS, R16

	; Valores iniciales de displays
	LDI		XL, LOW(DISPMODE_H)
	LDI		XH, HIGH(DISPMODE_H)
	LD		R16, X
	STS		DISPMODE_VALUE, R16
	STS		DISP0_VALUE, R16
	STS		DISP1_VALUE, R16
	STS		DISP2_VALUE, R16
	STS		DISP3_VALUE, R16
	;*************************************************************************************************************

	SEI
;*****************************************************************************************************************


;*****************************************************************************************************************
; ¡Empieza el LOOP!
LOOP:
	JMP		LOOP
;*****************************************************************************************************************


;****************************RUTINA TIM1**************************************************************************
TIM1_INTERRUPT:
	RETI
;*****************************************************************************************************************


;****************************RUTINA TIM0**************************************************************************
TIM0_INTERRUPT:	
	;Pushing registers to the STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16

	;Enabling interrupts (For TIM1 only, so PCIE is disabled)
	SEI
	LDI		R16, (0 << PCIE1)
    STS		PCICR, R16
	
	;Routine to reset TIM0
	LDI		R16, T0VALUE
	OUT		TCNT0, R16

	;Routine for muxing the displays
	;If bit D(n) is cleared, that bit wasn´t powering a Display, so, we don´t care
	;If	bit D(n) is set, that bit was powering a Display, so we clear D(n) and set D(n+1)
	SBIC	PINB, 0
	RJMP	SET_D1_AND_CLEAR_D0
	SBIC	PINB, 1
	RJMP	SET_D2_AND_CLEAR_D1
	SBIC	PINB, 2
	RJMP	SET_D3_AND_CLEAR_D2
	SBIC	PINB, 3
	RJMP	SET_D4_AND_CLEAR_D3
	SBIC	PINB, 4
	RJMP	SET_D0_AND_CLEAR_D4
	RJMP	TIM0_EXIT

		SET_D1_AND_CLEAR_D0:
			SBI		PINB, 0
			LDS		R16, DISP1_VALUE
			OUT		PORTD, R16
			SBI		PINB, 1
			RJMP	TIM0_EXIT

		SET_D2_AND_CLEAR_D1:
			SBI		PINB, 1
			LDS		R16, DISP2_VALUE
			OUT		PORTD, R16
			SBI		PINB, 2
			RJMP	TIM0_EXIT

		SET_D3_AND_CLEAR_D2:
			SBI		PINB, 2
			LDS		R16, DISP3_VALUE
			OUT		PORTD, R16
			SBI		PINB, 3
			RJMP	TIM0_EXIT

		SET_D4_AND_CLEAR_D3:
			SBI		PINB, 3
			LDS		R16, DISPMODE_VALUE
			OUT		PORTD, R16
			SBI		PINB, 4
			RJMP	TIM0_EXIT

		SET_D0_AND_CLEAR_D4:
			SBI		PINB, 4
			LDS		R16, DISP0_VALUE
			OUT		PORTD, R16
			SBI		PINB, 0
			RJMP	TIM0_EXIT
	
	TIM0_EXIT:
		;Popping registers from the STACK
		POP		R16
		OUT		SREG, R16
		POP		R16
		RETI
;*****************************************************************************************************************