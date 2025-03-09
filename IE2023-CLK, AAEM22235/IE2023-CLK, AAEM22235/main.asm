;
; IE2023-CLK, AAEM22235.asm
;
; Created: 24/02/2025 09:56:31 p. m.
; Author : ang50
;

.include "M328PDEF.inc"

;*****************************************************************************************************************
;Aspectos generales:
;	Uso de TIM0 en 1ms para multiplexación de Displays
;	Uso de TIM1 en 1s para conteo de tiempo general
;	Uso de XPointer para apuntar a una tabla de bytes de valores de displays
;	Uso de YPointer para apuntar a una tabla de bytes de días que tiene cada mes
;	Uso de una variable de conteo de segundos "SECSCOUNT"
;	Uso de una variable de conteo de minutos "MINSCOUNT"
;	Uso de una variable de conteo de horas "HRSCOUNT"
;	Uso de una variable de conteo de días "DAYSCOUNT"
;	Uso de una variable de conteo de meses "MNTHSCOUNT"
;*****************************************************************************************************************

;*****************************************************************************************************************
;Aspectos específicos:
;	Uso de una variable de almacenamiento de valor que debe mostrar DISPMINS0 "DISPMINS0_VALUE"
;	Uso de una variable de almacenamiento de valor que debe mostrar DISPMINS1 "DISPMINS1_VALUE"
;	Uso de una variable de almacenamiento de valor que debe mostrar DISPHRS0 "DISPHRS0_VALUE"
;	Uso de una variable de almacenamiento de valor que debe mostrar DISPHRS1 "DISPHRS1_VALUE"
;	Uso de una variable de almacenamiento para saber si existe alarma "IS_ALARM_SET"
;	Uso de una variable para guardar los minutos en que se estableció la alarma "ALARM_MINUTES"
;	Uso de una variable para guardar las horas en que se estableció la alarma "ALARM_HOURS"
;*****************************************************************************************************************

;*****************************************************************************************************************
;Algunos nombres de pines, datos y variables
.equ	B0					= 0
.equ	B1					= 1
.equ	PB					= 2
.equ	SET_UP				= 3
.equ	D0					= 0
.equ	D1					= 1
.equ	D2					= 2
.equ	D3					= 3
.equ	D4					= 4
.equ	BUZZER				= 5
.equ	DOTS				= 7
;*****************************************************************************************************************

;*****************************************************************************************************************
;Variables generales en DATA MEM empezando en la primera localidad disponible:
.DSEG

;Definiendo cada variable con nombres:
.equ	SECSCOUNT			= 0x0100
.equ	MINSCOUNT			= 0x0101
.equ	HRSCOUNT			= 0x0102
.equ	DAYSCOUNT			= 0x0103
.equ	MNTHSCOUNT			= 0x0104
.equ	DISPMODE_VALUE		= 0x0105
.equ	DISPMINS0_VALUE		= 0x0106
.equ	DISPMINS1_VALUE		= 0x0107
.equ	DISPHRS0_VALUE		= 0x0108
.equ	DISPHRS1_VALUE		= 0x0109
.equ	IS_ALARM_SET		= 0x010A
.equ	ALARM_MINS			= 0x010B
.equ	ALARM_HRS			= 0x010C
.equ	GEN_MODE			= 0x010D
.equ	SEL_MODE			= 0x010E
;*****************************************************************************************************************

;*****************************************************************************************************************
;Variables específicas en DATA MEM:

;Definiendo cada variable con nombres:
.equ	B0_PREV				= 0x0100
.equ	B1_PREV				= 0x0101
.equ	MODE_DISP_BLINK		= 0x0102
.equ	DAYSCOUNT			= 0x0103
.equ	MNTHSCOUNT			= 0x0104
.equ	DISPMINS0_VALUE		= 0x0105
.equ	DISPMINS1_VALUE		= 0x0106
.equ	DISPHRS0_VALUE		= 0x0107
.equ	DISPHRS1_VALUE		= 0x0108
.equ	ALARM				= 0x0109
.equ	ALARM_MINS			= 0x010A
.equ	ALARM_HRS			= 0x010B
;*****************************************************************************************************************



SETUP:
	*Sin prescaler global*

;*****************************************************************************************************************
;	Configurar PORTD (Localidad del DISP) como output
;	PORTD: XXXXXXXX	|	{DOTS,X,X,X,X,X,X,X}
	LDI		R16, 0b11111111
	OUT		DDRD, R16
	LDI		R16, 0b00000000	
	OUT		PORTD, R16
;*****************************************************************************************************************

;*****************************************************************************************************************
;	Configurar PORTB como output
;	PORTB: 00XXXXXX	|	{0,0,BUZZER,{D4,3,2,1,0}}
	LDI		R16, 0b00111111
	OUT		DDRD, R16
	LDI		R16, 0b00000001		; Comienza un display encendido (D0)
	OUT		PORTD, R16
;*****************************************************************************************************************

;*****************************************************************************************************************
;	Configurar PORTC como input (¡No hay necesidad de pullup!)
;	PORTC: 00000000	|	{0,0,0,0,SET_UP,SW,B1,B0}
	LDI		R16, 0
	OUT		DDRD, R16
	OUT		PORTD, R16
;*****************************************************************************************************************

;*****************************************************************************************************************
;	Establecer TIM0 en modo Normal:
;		Prescaler TIM0 = 1024
;		TCNT0 = 178
;		Activar Máscara
;		Activar Bandera de INT
	LDI		R16, (1 << CS02) | (1 << CS00)
	OUT		TCCR0B, R16
	LDI		R16, (1 << TOIE0) 
	STS		TIMSK0, R16
	LDI		R16, 178
	OUT		TCNT0, R16
;*****************************************************************************************************************
	

LOOP:
;*****************************************************************************************************************
	;1. count variables:
	;	if	(SECSCOUNT == 60):
	;		jump	INCREMENT_MINUTES_COUNT_AND_RESET_SECONDS_COUNT
	;	if	(MINSCOUNT == 60):
	;		jump	INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT
	;	if (HRSCOUNT == 25):
	;		jump	RESET_HOURS_COUNT_AND_INCREMENT_DAYS_COUNT
	;
	; about them days in them months...
	;	if	(DAYSCOUNT == monthdays(puntero) ):
	;		jump	INCREMENT_MONTHS_COUNT_AND_SET_Y_POINTER_AND_RESET_DAYS_COUNT
	;	if	(MNTHSCOUNT == 13):
	;		jump	RESET_MONTHS_COUNT_AND_Y_POINTER


	; If the seconds counter is equal to 60secs, go to routine "INCREMENT_MINUTES_COUNT_AND_RESET_SECONDS_COUNT"
	; If not, check the minutes counter
	SECONDS_CHECK:
		LDS		R16, SECSCOUNT
		CPI		R16, 60
		BREQ	MINUTES_CHECK
		JMP		INCREMENT_MINUTES_COUNT_AND_RESET_SECONDS_COUNT
	; If the minutes counter is equal to 60mins, go to routine "INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT"
	; If not, check the hours counter
	MINUTES_CHECK:		
		LDS		R16, MINSCOUNT
		CPI		R16, 60
		BREQ	HOURS_CHECK
		JMP		INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT
	; If the hours counter is equal to 25 hours, go to routine "RESET_HOURS_COUNT_AND_INCREMENT_DAYS_COUNT"
	; If not, check the days counter
	HOURS_CHECK:	
		LDS		R16, HRSCOUNT
		CPI		R16, 25
		BREQ	DAYS_CHECK
		JMP		INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT
	; If the days counter is equal to the number of days of the month (YPointer), go to routine "INCREMENT_MONTHS_COUNT_AND_SET_Y_POINTER_AND_RESET_DAYS_COUNT"
	; If not, check the months counter
	DAYS_CHECK:
		LDS		R16, DAYSCOUNT
		LD		R17, Y
		CP		R16, R17
		BREQ	MONTHS_CHECK
		JMP		INCREMENT_MONTHS_COUNT_AND_SET_Y_POINTER_AND_RESET_DAYS_COUNT
	; If the months counter is equal to 13, go to routine "RESET_MONTHS_COUNT_AND_Y_POINTER"
	; If not, check the months counter	
	MONTHS_CHECK:
		LDS		R16, MNTHSCOUNT
		CPI		R16, 13
		BREQ	ALARM_CHECK
		JMP		RESET_MONTHS_COUNT_AND_Y_POINTER
;*****************************************************************************************************************
	
;*****************************************************************************************************************	
	;2. looking if the time stored is the same as the alarm set (if any):
	;	if (IS_ALARM_SET == 1):
	;		jump	VERIFY_ALARM_HOURS
	;	else
	;		skip
	;	
	;	VERIFY_ALARM_HOURS:
	;		if	(HRSCOUNT == ALARM_HRS)
	;			jump	VERIFY_ALARM_MINUTES
	;		else
	;			jump	stablishing modes
	;
	;	VERIFY_ALARM_MINUTES:
	;		if	(MINSCOUNT == ALARM_MINS):
	;			change mode to alarm ring mode
	;		else 
	;			jump	stablishing modes


	;If there is an alarm set, go to routine "ALARM_HOURS_CHECK"
	;If not, go to check them modes
	ALARM_CHECK:
		LDS		R16, IS_ALARM_SET
		CPI		R16, 0xFF
		BREQ	ALARM_HOURS_CHECK
		JMP		stablishing them modes
	;If there is an alarm set and HRSCOUNT is equal to ALARM_HRS, go to routine "ALARM_MINUTES_CHECK"
	;If not, go to check them modes
	ALARM_HOURS_CHECK:
		LDS		R16, ALARM_HRS
		LDS		R17, HRSCOUNT
		CP		R16, R17
		BREQ	ALARM_MINUTES_CHECK
		JMP		stablishing them modes
	;If there is an alarm set, HRSCOUNT is equal to ALARM_HRS, and MINSCOUNT is equal to ALARM_MINS... 
	;go to routine "ALARM_RING_MODE"
	;If not, go to check them modes
	ALARM_MINUTES_CHECK:
		LDS		R16, ALARM_MINS
		LDS		R17, MINSCOUNT
		BREQ	ALARM_RING_MODE
		JMP		stablishing them modes
;*****************************************************************************************************************	

;*****************************************************************************************************************	
;	3. stablishing them modes:
;	general modes:
;		if (GEN_MODE == TIME):
;			jump	TIME_DISPLAY
;		if (GEN_MODE == TIME_SET):
;			jump	TIME_SET_DISPLAY
;		if (GEN_MODE == DATE):
;			jump	DATE_DISPLAY
;		if (GEN_MODE == DATE_SET):
;			jump	DATE_SET_DISPLAY
;		if (GEN_MODE == ALARM):
;			jump	ALARM_DISPLAY
;		if (GEN_MODE == ALARM_SET):
;			jump	ALARM_SET_DISPLAY
;
;	selection modes:
;		if	(SEL_MODE == F):
;			jump	MODE_DISPLAY_F
;		if	(SEL_MODE == F_BLINK):
;			jump	MODE_DISPLAY_F_BLINK
;		if	(SEL_MODE == H):
;			jump	MODE_DISPLAY_H
;		if	(SEL_MODE == H_BLINK):
;			jump	MODE_DISPLAY_H_BLINK
;		if	(SEL_MODE == A):
;			jump	MODE_DISPLAY_A
;		if	(SEL_MODE == A_BLINK):
;			jump	MODE_DISPLAY_A_BLINK


	GENERAL_MODES_CHECK:
		LDS		R16, GEN_MODE
		CPI		R16, TIME
		BREQ	TIME_DISPLAY
		CPI		R16, TIME_SET
		BREQ	TIME_SET_DISPLAY
		CPI		R16, DATE
		BREQ	DATE_DISPLAY
		CPI		R16, DATE_SET
		BREQ	DATE_SET_DISPLAY
		CPI		R16, ALARM
		BREQ	ALARM_DISPLAY
		CPI		R16, ALARM_SET
		BREQ	ALARM_SET_DISPLAY
;*****************************************************************************************************************	

;*****************************************************************************************************************
;	TIME_DISPLAY:
;	set every display with time values:

	TIME_DISPLAY:
		;Set DISPMODE_VALUE with "H";
		;Set XPointer
		;Store the value of XPointer in DISPMODE_VALUE
		LDI		XL, LOW(DISPMODE_H)
		LDI		XH, HIGH(DISPMODE_H)
		LD		R16, X
		STS		DISPMODE_VALUE, R16
		;Set DISPSMINS with "MINSCOUNT":
		;Separate UNITS and DECS given MINSCOUNT
		SEPARATE_MINUTES_DEC_UNITS:
			LDS		R16, MINSCOUNT
			LDI		R17, 0						;DEC count
			MINUTES_DIV_LOOP:
				SUBI	R16, 10					;Sub 10
				BRCS	END_MINUTES_DIV			;If Carry=1, R16<10, so the loop ends
				INC		R17						;Inc DEC count
				RJMP	MINUTES_DIV_LOOP		;Loop til' R16<10
			END_MINUTES_DIV:
				LDI		R18, 10
				ADD		R16, R18				;Since last sub exceeded 0, R16 must be corrected adding it 10
												;R16 will then store them units 
		STORE_MINUTES_DEC_UNITS:
			;Store units
			LDI		XL, LOW(DISP7SEG)
			LDI		XH, HIGH(DISP7SEG)			;Set XPointer at DISP7SEG "0" position
			ADD		XL, R16
			ADC		XH, R0						;Add Xpointer the value of units
			LD		R16, X
			STS		DISPMINS0_VALUE, R16		;Store the value of units in DISPMINS0_VALUE
			;Store decs
			LDI		XL, LOW(DISP7SEG)			
			LDI		XH, HIGH(DISP7SEG)			;Set XPointer at DISP7SEG "0" position
			ADD		XL, R17
			ADC		XH, R0						;Add Xpointer the value of decs
			LD		R16, X
			STS		DISPMINS1_VALUE, R16		;Store the value of units in DISPMINS1_VALUE
		;Set DISPSHRS with "HRSCOUNT":
		;Separate UNITS and DECS given HRSCOUNT (Same logic)
		SEPARATE_HOURS_DEC_UNITS:
			LDS		R16, HRSCOUNT
			LDI		R17, 0						;DEC count
			HOURS_DIV_LOOP:
				SUBI	R16, 10					;Sub 10
				BRCS	END_HOURS_DIV			;If Carry=1, R16<10, so the loop ends
				INC		R17						;Inc DEC count
				RJMP	HOURS_DIV_LOOP			;Loop til' R16<10
			END_HOURS_DIV:	
				LDI		R18, 10
				ADD		R16, R18				;Since last sub exceeded 0, R16 must be corrected adding it 10
												;R16 will then store them units 
		STORE_HOURS_DEC_UNITS:
			;Store units
			LDI		XL, LOW(DISP7SEG)
			LDI		XH, HIGH(DISP7SEG)			;Set XPointer at DISP7SEG "0" position
			ADD		XL, R16
			ADC		XH, R0						;Add Xpointer the value of units
			LD		R16, X
			STS		DISPHRS0_VALUE, R16			;Store the value of units in DISPHRS0_VALUE
			;Store decs
			LDI		XL, LOW(DISP7SEG)			
			LDI		XH, HIGH(DISP7SEG)			;Set XPointer at DISP7SEG "0" position
			ADD		XL, R17
			ADC		XH, R0						;Add Xpointer the value of decs
			LD		R16, X
			STS		DISPHRS1_VALUE, R16			;Store the value of units in DISPHRS1_VALUE		



;****************************RUTINA TIM0***************************************************************************
TIM0_INTERRUPT:
	if (DISPMINS0 == 1):
		jump	SET_DISPMINS1
	else if (DISPMINS1 == 1):
		jump	SET_DISPHRS0
	else if (DISPHRS0 == 1):
		jump	SET_DISPHRS1
	else if (DISPHRS1 == 1):
		jump	SET_DISPMINS0
	TIM0_return:
		reti

	SET_DISPMINS0:
		Toggle DISPHRS1
		set the X pointer at DISPMINS0:
			LDI	X(LOW), Vector First Position (LOW)
			LDI	X(HIGH), Vector First Position (HIGH)
			ADIW	X, DISPMINS0_VALUE
		OUT	PORTD, X
		Toggle	DISPMINS0
		jump	TIM0_return
	
	SET_DISPMINS1:
		Toggle DISPMINS0
		set the X pointer at DISPMINS1:
			LDI	X(LOW), X Position (LOW)
			LDI	X(HIGH), X Position (HIGH)
			ADIW	X, DISPMINS1_VALUE
		OUT	PORTD, X
		Toggle	DISPMINS1
		jump	TIM0_return

	SET_DISPHRS0:
		Toggle DISPMINS1
		set the X pointer at DISPHRS0:
			LDI	X(LOW), Vector First Position (LOW)
			LDI	X(HIGH), Vector First Position (HIGH)
			ADIW	X, DISPHRS0_VALUE
		OUT	PORTD, X
		Toggle	DISPHRS0
		jump	TIM0_return

	SET_DISPHRS1:
		Toggle DISPHRS0
		set the X pointer at DISPHRS1:
			LDI	X(LOW), Vector First Position (LOW)
			LDI	X(HIGH), Vector First Position (HIGH)
			ADIW	X, DISPHRS1_VALUE
		OUT	PORTD, X
		Toggle	DISPHRS1
		jump	TIM0_return

;******************************************************************************************************************




	
	
	