;
; IE2023-CLK, AAEM22235.asm
;
; Created: 24/02/2025 09:56:31 p. m.
; Author : ang50
;


Aspectos generales:
	Uso de TIM0 en 5ms para multiplexación de Displays
	Uso de TIM1 en 1s para conteo de tiempo general
	Uso de una variable de conteo de segundos "SECSCOUNT"
	Uso de una variable de conteo de minutos "MINSCOUNT"
	Uso de una variable de conteo de horas "HRSCOUNT"
	Uso de una variable de conteo de días "DAYSCOUNT"
	Uso de una variable de conteo de meses "MNTHSCOUNT"

Aspectos específicos:
	Uso de una variable de almacenamiento de valor que debe mostrar DISPMINS0 "DISPMINS0_VALUE"
	Uso de una variable de almacenamiento de valor que debe mostrar DISPMINS1 "DISPMINS1_VALUE"
	Uso de una variable de almacenamiento de valor que debe mostrar DISPHRS0 "DISPHRS0_VALUE"
	Uso de una variable de almacenamiento de valor que debe mostrar DISPHRS1 "DISPHRS1_VALUE"



SETUP:
	*Sin prescaler global*
	Setear PORTD (Localidad del DISP) como output
	Establecer TIM0 en modo Normal:
		Prescaler TIM0 = 1024
		TCNT0 = 178
		Activar Máscara
		Activar Bandera de INT

LOOP:
	if (mode == time_show) & (last_mode != time_show):
		jump	timer_time_show_set
	else if (mode == time_show) & (last_mode == time_show):
		jump	time_show



TIME_SHOW:


TIMER_TIME_SHOW:
	set the timer at 5ms
	jump	time_show



;****************************RUTINA TIM0****************************
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

;*******************************************************************




	
	
	