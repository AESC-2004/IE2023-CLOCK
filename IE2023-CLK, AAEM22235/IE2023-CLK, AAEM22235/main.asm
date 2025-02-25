;
; IE2023-CLK, AAEM22235.asm
;
; Created: 24/02/2025 09:56:31 p. m.
; Author : ang50
;

.include "M328PDEF.inc"

;*****************************************************************************************************************
;Aspectos generales:
;	Uso de TIM0 en 5ms para multiplexación de Displays
;	Uso de TIM1 en 1s para conteo de tiempo general
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
;	Uso de una variable de almacenamiento para saber si existe alarma "ALARM"
;	Uso de una variable para guardar los minutos en que se estableció la alarma "ALARM_MINUTES"
;	Uso de una variable para guardar las horas en que se estableció la alarma "ALARM_HOURS"
;*****************************************************************************************************************

;*****************************************************************************************************************
;Variables generales en DATA MEM empezando en la primera localidad disponible:
.DSEG
.org 0x0100
general_variables: .byte 20

;Definiendo cada variable con nombres:
.equ	SECSCOUNT			= 0x0100
.equ	MINSCOUNT			= 0x0101
.equ	HRSCOUNT			= 0x0102
.equ	DAYSCOUNT			= 0x0103
.equ	MNTHSCOUNT			= 0x0104
.equ	DISPMINS0_VALUE		= 0x0105
.equ	DISPMINS1_VALUE		= 0x0106
.equ	DISPHRS0_VALUE		= 0x0107
.equ	DISPHRS1_VALUE		= 0x0108
.equ	ALARM				= 0x0109
.equ	ALARM_MINUTES		= 0x010A
.equ	ALARM_HOURS			= 0x010B
;*****************************************************************************************************************



SETUP:
	*Sin prescaler global*

;*****************************************************************************************************************
;	Setear PORTD (Localidad del DISP) como output
;	PORTD: XXXXXXXX
	LDI		R16, 0b11111111
	OUT		DDRD, R16
	LDI		R16, 0b00000000
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
	counting for every count variable:
		if	(SECSCOUNT == 60):
			jump	INCREMENT_MINUTES_COUNT_AND_RESET_SECONDS_COUNT
		else if	(MINSCOUNT == 60):
			jump	INCREMENT_HOURS_COUNT_AND_RESET_MINUTES_COUNT
		else if (HRSCOUNT == 24):
			jump	RESET_HOURS_COUNT_AND_INCREMENT_DAYS_COUNT

	looking if the time stored is the same as the alarm set (if any):
		if	(A

	stablishing the mode:
		if (mode == time):
			jump	time
		else if (mode == date):
			jump	date
		else if (mode == alarm):
			jump	alarm


	TIME_SHOW:
	set every display with time values:
		



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




	
	
	