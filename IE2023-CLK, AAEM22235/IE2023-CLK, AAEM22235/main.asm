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
;	Uso de TIM1 en 1s para conteo de tiempo general (Tiene prioridad sobre TIM0, por lo que, en Interrupt T0
;	se habilitarán interrupciones anidadas)
;
;	Uso de un display para mostrar el modo en que se enceuntra el reloj, y uso de otros 4 displays para mostrar
;	los datos necesarios (Hora, fecha o alarma)
;
;	Uso de XPointer para apuntar a una tabla de bytes de valores de displays
;	Uso de YPointer para apuntar a una tabla de bytes de días que tiene cada mes
;	Uso de una variable de conteo de segundos "SECSCOUNT"
;	Uso de DOS variables de conteo de minutos "MINSONESCOUNT" (Unidades) y "MINSTENSCOUNT" (Decenas)
;	Uso de DOS variables de conteo de horas "HRSONESCOUNT" y "HRSTENSCOUNT"
;	Uso de DOS variables de conteo de días "DAYSONESCOUNT" y "DAYSTENSCOUNT"
;	Uso de DOS variables de conteo de meses "MNTHSONESCOUNT" y "MNTHSTENSCOUNT"
;
;	Uso de dos máquinas de estados finitos. Una de selección de modo para el usuario (Seleccionar si se quiere
;	mostrar hora, fecha o alarma), y otra de configuración (Configurar fecha, hora o alarma). 
;
;	Uso de un encoder rotatorio (Con PUSHBUTTON integrado) y un SPDT como interfaz del usuario. 

;	Cuando el usuario quiera seleccionar qué modo se
;	debe mostrar, primero, se deberá presionar el PUSHBUTTON del encoder, y la perilla deberá variar en el 
;	"display de modo" si se muestra una "F" (Fecha), una "H" (Hora), o una "A" (Alarma); el display parpadeará 
;	en ese caso. Se establecerá el modo deseado hasta que el usuario vuelva a presionar el PUSHBUTTON.
;
;	Cuando el usuario quiera configurar algún modo (Fecha, Hora o Alarma), deberá "switchear" el SPDT. La 
;	perilla del encoder entonces cambiará los valores mostrados en los displays de datos. Primero se permitirá 
;	variar un par displays, y luego el otro (Primero minutos y luego horas los casos de "Hora" y "Alarma", y, 
;	primero días y luego meses en el caso de "Fecha"); el PUSHBUTTON del encoder dictaminará cuándo cambiar entre
;	pares de displays. Se saldrá del modo configuración cuando el SPDT sea "switcheado" a su estado previo antes
;	de la configuración.
;
;	Al estar en un estado de configuración de un modo, no se podrá cambiar a un estado de configuración de otro
;	modo.
;	
;*****************************************************************************************************************

;*****************************************************************************************************************
;Aspectos específicos:
;	Uso de una variable de almacenamiento de valor que debe mostrar DISP0 "DISP0_VALUE"
;	Uso de una variable de almacenamiento de valor que debe mostrar DISP1 "DISP1_VALUE"
;	Uso de una variable de almacenamiento de valor que debe mostrar DISP2 "DISP2_VALUE"
;	Uso de una variable de almacenamiento de valor que debe mostrar DISP3 "DISP3_VALUE"
;	Uso de una variable de almacenamiento para saber si existe alarma "IS_ALARM_SET"
;	Uso de una variable para guardar los minutos en que se estableció la alarma "ALARM_MINUTES"
;	Uso de una variable para guardar las horas en que se estableció la alarma "ALARM_HOURS"
;*****************************************************************************************************************

;*****************************************************************************************************************
;Algunos nombres de pines, datos y variables
.equ	T0VALUE				= 6
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
.equ	MINSONESCOUNT		= 0x0101
.equ	MINSTENSCOUNT		= 0x0102
.equ	HRSONESCOUNT		= 0x0103
.equ	HRSTENSCOUNT		= 0x0104
.equ	DAYSONESCOUNT		= 0x0105
.equ	DAYSTENSCOUNT		= 0x0106
.equ	MNTHSONESCOUNT		= 0x0107
.equ	MNTHSTENSCOUNT		= 0x0108
.equ	DISPMODE_VALUE		= 0x0109
.equ	DISP0_VALUE			= 0x010A
.equ	DISP1_VALUE			= 0x010B
.equ	DISP2_VALUE			= 0x010C
.equ	DISP3_VALUE			= 0x010D
.equ	IS_ALARM_SET		= 0x010E
.equ	ALARM_MINSONES		= 0x010F
.equ	ALARM_MINSTENS		= 0x0110
.equ	ALARM_HRSONES		= 0x0111
.equ	ALARM_HRSTENS		= 0x0112
.equ	GEN_MODE			= 0x0113
.equ	SEL_MODE			= 0x0114
;*****************************************************************************************************************

;*****************************************************************************************************************
;Variables específicas en DATA MEM:

;Definiendo cada variable con nombres:
.equ	B0_PREV				= 0x0100
.equ	B1_PREV				= 0x0101
.equ	MODE_DISP_BLINK		= 0x0102
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
;		Prescaler TIM0 = 64
;		TCNT0 = 6
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
		BRNE	MINUTES_CHECK
		CALL	INCREMENT_MINUTES_COUNT_AND_RESET_SECONDS_COUNT
	; If the minutes counter is equal to 60mins, go to routine "INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT"
	; If not, check the hours counter
	MINUTES_CHECK:
		LDS		R16, MINSONESCOUNT		
		LDS		R17, MINSTENSCOUNT
		ADD		R16, R17
		CPI		R16, 60
		BRNE	HOURS_CHECK
		CALL	INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT
	; If the hours counter is equal to 24 hours, go to routine "RESET_HOURS_COUNT_AND_INCREMENT_DAYS_COUNT"
	; If not, check the days counter
	HOURS_CHECK:	
		LDS		R16, HRSONESCOUNT		
		LDS		R17, HRSTENSCOUNT
		ADD		R16, R17
		CPI		R16, 24
		BRNE	DAYS_CHECK
		CALL	INCREMENT_DAYS_COUNT_AND_RESET_HOURS_COUNT
	; If the days counter is equal to the number of days of the month (YPointer), go to routine "INCREMENT_MONTHS_COUNT_AND_SET_Y_POINTER_AND_RESET_DAYS_COUNT"
	; If not, check the months counter
	DAYS_CHECK:
		LDS		R16, DAYSONESCOUNT
		LDS		R17, DAYSTENSCOUNT
		ADD		R16, R17
		LD		R17, Y
		CP		R16, R17
		BRNE	MONTHS_CHECK
		CALL	INCREMENT_MONTHS_COUNT_AND_YPOINTER_AND_RESET_DAYS_COUNT
	; If the months counter is equal to 13, go to routine "RESET_MONTHS_COUNT_AND_Y_POINTER"
	; If not, check the alarm counter	
	MONTHS_CHECK:
		LDS		R16, MNTHSONESCOUNT
		LDS		R17, MNTHSTENSCOUNT
		ADD		R16, R17
		CPI		R16, 13
		BRNE	1
		CALL	RESET_MONTHS_COUNT_AND_Y_POINTER
		JMP		ALARM_CHECK
	
;*************************Count Variables Routines****************************************************************

	INCREMENT_MINUTES_COUNT_AND_RESET_SECONDS_COUNT:
		;Increment minutes count
		LDI		R16, 1
		LDS		R17, MINSONESCOUNT
		LDS		R18, MINSONESCOUNT
		ADD		R17, R16
		ADC		R18, R0
		STS		MINSONESCOUNT, R17
		STS		MINSTENSCOUNT, R18
		;Reset seconds Count
		CLR		R16
		STS		SECSCOUNT, R16
		RET

	INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT:
		;Increment hours count
		LDI		R16, 1
		LDS		R17, HRSONESCOUNT
		LDS		R18, HRSTENSCOUNT
		ADD		R17, R16
		ADC		R18, R0
		STS		HRSONESCOUNT, R17
		STS		HRSTENSCOUNT, R18
		;Reset minutes Count
		CLR		R16
		STS		MINSONESCOUNT, R16
		STS		MINSTENSCOUNT, R16
		RET

	INCREMENT_DAYS_COUNT_AND_RESET_HOURS_COUNT:
		;Increment days count
		LDI		R16, 1
		LDS		R17, DAYSONESCOUNT
		LDS		R18, DAYSTENSCOUNT
		ADD		R17, R16
		ADC		R18, R0
		STS		DAYSONESCOUNT, R17
		STS		DAYSTENSCOUNT, R18
		;Reset hours Count
		CLR		R16
		STS		HRSONESCOUNT, R16
		STS		HRSTENSCOUNT, R16
		RET

	INCREMENT_MONTHS_COUNT_AND_YPOINTER_AND_RESET_DAYS_COUNT:
		;Increment months count
		LDI		R16, 1
		LDS		R17, MNTHSONESCOUNT
		LDS		R18, MNTHSTENSCOUNT
		ADD		R17, R16
		ADC		R18, R0
		STS		MNTHSONESCOUNT, R17
		STS		MNTHSTENSCOUNT, R18
		;Increment YPointer
		ADIW	Y, 1
		;Reset days count
		LDI		R16, 1
		STS		DAYSONESCOUNT, R16
		CLR		R16
		STS		DAYSTENSCOUNT, R16
		RET

	RESET_MONTHS_COUNT_AND_Y_POINTER:
		;Reset months count
		LDI		R16, 1
		STS		MNTHSONESCOUNT, R16
		CLR		R16
		STS		MNTHSTENSCOUNT, R16
		RET
		;Reset YPointer
		LDI		YL, LOW(MNTHSDAYS)
		LDI		YH, HIGH(MNTHSDAYS)
		RET

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
		LDS		R17, HRSONESCOUNT
		LDS		R18, HRSTENSCOUNT
		ADD		R17, R18
		CP		R16, R17
		BREQ	ALARM_MINUTES_CHECK
		JMP		stablishing them modes
	;If there is an alarm set, HRSCOUNT is equal to ALARM_HRS, and MINSCOUNT is equal to ALARM_MINS... 
	;go to routine "ALARM_RING_MODE"
	;If not, go to check them modes
	ALARM_MINUTES_CHECK:
		LDS		R16, ALARM_MINS
		LDS		R17, MINSONESCOUNT
		LDS		R18, MINSTENSCOUNT
		ADD		R17, R18
		CP		R16, R17
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
		;Set DISPMODE_VALUE with "H" ("Hora");
		;Set XPointer
		;Store the value of XPointer in DISPMODE_VALUE
		LDI		XL, LOW(DISPMODE_H)
		LDI		XH, HIGH(DISPMODE_H)
		LD		R16, X
		STS		DISPMODE_VALUE, R16
		;Set DISPS 0&1 with "MINSCOUNT":
		;MINSONES
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, MINSONESCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP0_VALUE, R16
		;MINSTENS
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, MINSTENSCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP1_VALUE, R16
		;Set DISPS 2&3 with "HRSCOUNT":
		;HRSONES
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, HRSONESCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP2_VALUE, R16
		;HRSTENS
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, HRSTENSCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP3_VALUE, R16
;*****************************************************************************************************************


;*****************************************************************************************************************
;	DATE_DISPLAY:
;	set every display with date values:

	DATE_DISPLAY:
		;Set DISPMODE_VALUE with "F" ("Fecha"):
		;Set XPointer
		;Store the value of XPointer in DISPMODE_VALUE
		LDI		XL, LOW(DISPMODE_F)
		LDI		XH, HIGH(DISPMODE_F)
		LD		R16, X
		STS		DISPMODE_VALUE, R16
		;Set DISPS 0&1 with "DAYSCOUNT":
		;DAYSONES
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, DAYSONESCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP0_VALUE, R16
		;DAYSTENS
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, DAYSTENSCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP1_VALUE, R16
		;Set DISPS 2&3 with "MNTHSCOUNT":
		;MNTHSONES
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, MNTHSONESCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP2_VALUE, R16
		;MNTHSTENS
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, MNTHSTENSCOUNT
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP3_VALUE, R16
;*****************************************************************************************************************


;*****************************************************************************************************************
;	ALARM_DISPLAY:
;	set every display with alarm values:

	ALARM_DISPLAY:
		;Set DISPMODE_VALUE with "A" ("Alarma"):
		;Set XPointer
		;Store the value of XPointer in DISPMODE_VALUE
		LDI		XL, LOW(DISPMODE_A)
		LDI		XH, HIGH(DISPMODE_A)
		LD		R16, X
		STS		DISPMODE_VALUE, R16
		;Set DISPS 0&1 with "ALARM_MINS":
		;ALARM_MINSONES
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, ALARM_MINSONES
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP0_VALUE, R16
		;ALARM_MINSTENS
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, ALARM_MINSTENS
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP1_VALUE, R16
		;Set DISPS 2&3 with "ALARM_HRS":
		;ALARM_HRSONES
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, ALARM_HRSONES
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP2_VALUE, R16
		;ALARM_HRSTENS
		LDI		XL, LOW(DISP7SEG)
		LDI		XH, HIGH(DISP7SEG)
		LDS		R16, ALARM_HRSTENS
		ADD		XL, R16
		ADC		XH, R0
		LD		R16, X
		STS		DISP3_VALUE, R16
;*****************************************************************************************************************


;****************************RUTINA TIM0**************************************************************************
;To multiplex displays

TIM0_INTERRUPT:
	;If bit D(n) is cleared, that bit wasn´t powering a Display, so, we don´t care
	;If bit D(n) is set, that bit was ´powering a Display, so we clear D(n) and set D(n+1)
	SBIC	PINB, D0
	RJMP	SET_D1_AND_CLEAR_D0
	SBIC	PINB, D1
	RJMP	SET_D2_AND_CLEAR_D1
	SBIC	PINB, D2
	RJMP	SET_D3_AND_CLEAR_D2
	SBIC	PINB, D3
	RJMP	SET_D4_AND_CLEAR_D3
	SBIC	PINB, D4
	RJMP	SET_D0_AND_CLEAR_D4
	TIM0_EXIT:
		RETI

	SET_D1_AND_CLEAR_D0:
		SBI		PINB, D0
		LDS		R16, DISP1_VALUE
		OUT		PORTD, R16
		SBI		PINB, D1
		RJMP	TIM0_EXIT

	SET_D2_AND_CLEAR_D1:
		SBI		PINB, D1
		LDS		R16, DISP2_VALUE
		OUT		PORTD, R16
		SBI		PINB, D2
		RJMP	TIM0_EXIT

	SET_D3_AND_CLEAR_D2:
		SBI		PINB, D2
		LDS		R16, DISP3_VALUE
		OUT		PORTD, R16
		SBI		PINB, D3
		RJMP	TIM0_EXIT

	SET_D4_AND_CLEAR_D3:
		SBI		PINB, D3
		LDS		R16, DISP4_VALUE
		OUT		PORTD, R16
		SBI		PINB, D4
		RJMP	TIM0_EXIT

	SET_D0_AND_CLEAR_D4:
		SBI		PINB, D4
		LDS		R16, DISP0_VALUE
		OUT		PORTD, R16
		SBI		PINB, D0
		RJMP	TIM0_EXIT

;*****************************************************************************************************************




	
	
	