;
; Prueba TIM1.asm
;
; Created: 11/03/2025 07:38:21 p. m.
; Author : ang50
;

;Este código busca multiplexar los displays cada segundo con el TIM1.
;Ahora, haremos que haya una cuenta únicamente de segundos. Se multiplexará con TIM0.


.include "M328PDEF.inc"

; Valores de Timers
.equ			T1VALUE_L			= 0xDC
.equ			T1VALUE_H			= 0x0B
.equ			T0VALUE				= 6

;Localidades de variables en RAM
.equ			SECSTENSCOUNT		= 0x0101
.equ			SECSHUNDSCOUNT		= 0x0102
.equ			DISPMODE_VALUE		= 0x0105
.equ			DISP0_VALUE			= 0x0106
.equ			DISP1_VALUE			= 0x0107
.equ			DISP2_VALUE			= 0x0108
.equ			DISP3_VALUE			= 0x0109

;Program mem.
.CSEG
.org 0x0000
	RJMP SETUP
;Guardamos un salto a la sub-rutina "TIM1_INTERRUPT" en el vector de interrupción necesario
.org OVF1addr
	RJMP TIM1_INTERRUPT
;Guardamos un salto a la sub-rutina "TIM0_INTERRUPT" en el vector de interrupción necesario
.org OVF0addr
	RJMP TIM0_INTERRUPT
;Guardamos una tabla para valores de DISP7SEG
.org 0x0040
	DISP7SEG:	
		.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

;Registros de propósito general
.def			SECSCOUNT			= R22 	

; Inicio del código
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

	;PORTB: Salidas: {0,0,BUZZER,D4,D3,D2,D1,D0}
	LDI		R16, 0xFF
	OUT		DDRB, R16
	LDI		R16, 0b00000001						;Comienza un display encendido
	OUT		PORTB, R16

	;PORTD: Displays
	LDI		R16, 0xFF
	OUT		DDRD, R16
	LDI		R16, 0
	OUT		PORTD, R16

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
	LDI		R16, (1 << CS12) |(0 << CS11) | (0 << CS10)
	STS		TCCR1B, R16
	LDI		R16, (1 << TOIE1) 
	STS		TIMSK1, R16
	LDI		R16, T1VALUE_H
	STS		TCNT1H, R16
	LDI		R16, T1VALUE_L
	STS		TCNT1L, R16

	;Valores iniciales de displays
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	LPM		R16, Z
	STS		DISPMODE_VALUE, R16
	STS		DISP0_VALUE, R16
	STS		DISP1_VALUE, R16
	STS		DISP2_VALUE, R16
	STS		DISP3_VALUE, R16

	;Valores iniciales de variables de conteo
	LDI		R16, 0
	STS		SECSTENSCOUNT, R16
	STS		SECSHUNDSCOUNT, R16

	;R0=0
	LDI		R16, 0
	MOV		R0, R16

	SEI

LOOP:

	;*************************************************************************************************************
	;Rutina para actualizar contadores

	CHECK_SECSCOUNT:
	;Revisar si SECSCOUNT=10
	;Si sí, reseteamos SECSCOUNT e incrementamos SECSTENSCOUNT
	;Si no, vamos a revisar si SECSTENS=10
	CPI		SECSCOUNT, 10
	BREQ	RESET_SECSCOUNT_AND_INCREMENT_SECSTENSCOUNT
	RJMP	CHECK_SECSTENSCOUNT

	CHECK_SECSTENSCOUNT:
		;Revisar si SECSTENS=10
		;Si sí, reseteamos SECSTENSCOUNT e incrementamos SECSHUNDSCOUNT
		;Si no, vamos a revisar a la rutina TIME_DISPLAY
		LDS		R16, SECSTENSCOUNT
		CPI		R16, 10
		BREQ	RESET_SECSTENSCOUNT_AND_INCREMENT_SECSHUNDSCOUNT
		RJMP	TIME_DISPLAY

	RESET_SECSCOUNT_AND_INCREMENT_SECSTENSCOUNT:
		;Limpiamos SECSCOUNT, incrementamos SECSTENSCOUNT, y nos vamos a revisar si SECSTENS=10
		CLR		SECSCOUNT
		LDS		R16, SECSTENSCOUNT
		INC		R16
		STS		SECSTENSCOUNT, R16
		RJMP	CHECK_SECSTENSCOUNT

	RESET_SECSTENSCOUNT_AND_INCREMENT_SECSHUNDSCOUNT:
		;Limpiamos SECSTENSCOUNT, incrementamos SECSHUNDSCOUNT, y nos vamos la rutina TIME_DISPLAY
		LDI		R16, 0
		STS		SECSTENSCOUNT, R16
		LDS		R16, SECSHUNDSCOUNT
		INC		R16
		STS		SECSHUNDSCOUNT, R16
		RJMP	TIME_DISPLAY	

	;*************************************************************************************************************

	;*************************************************************************************************************
	;Rutina para guardar en las variables DISPSVALUES los valores a mostrar en cada display
	;Usamos el puntero Z

	TIME_DISPLAY:
		DISPLAY_SECSONESCOUNT:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			ADD		ZL, SECSCOUNT
			LPM		R16, Z
			STS		DISP0_VALUE, R16
		DISPLAY_SECSTENSCOUNT:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, SECSTENSCOUNT
			ADD		ZL, R16
			LPM		R16, Z
			STS		DISP1_VALUE, R16
		DISPLAY_SECSHUNDSCOUNT:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, SECSHUNDSCOUNT
			ADD		ZL, R16
			LPM		R16, Z
			STS		DISP2_VALUE, R16
			JMP		LOOP	
		
;****************************RUTINA TIM1**************************************************************************
TIM1_INTERRUPT:
	;Empujamos resgistros al STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	
	;Reseteamos TIM1
	LDI		R16, T1VALUE_H
	STS		TCNT1H, R16
	LDI		R16, T1VALUE_L
	STS		TCNT1L, R16	

	;Incrementamos el contador de segundos
	INC		SECSCOUNT

	TIM1_EXIT:
		;Popping registers from the STACK
		POP		R16
		OUT		SREG, R16
		POP		R16
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