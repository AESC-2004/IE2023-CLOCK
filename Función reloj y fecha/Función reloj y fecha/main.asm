;
; Función reloj y fecha.asm
;
; Created: 11/03/2025 08:47:04 p. m.
; Author : ang50
;


;***************************************************************************************************************************
; Función "Mostrar Hora" y "Mostrar Fecha" del reloj digital.
; Las funciones se deberán cambiar con el encoder.

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
;***************************************************************************************************************************


.include "M328PDEF.inc"


;***************************************************************************************************************************
; Algunas definiciones importantes:

; Valores de Timers
;.equ			T1VALUE_L			= 0xDC
;.equ			T1VALUE_H			= 0x0B
.equ			T1VALUE_L			= 0x06
.equ			T1VALUE_H			= 0x00
.equ			T0VALUE				= 6
;***************************************************************************************************************************

;***************************************************************************************************************************
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

; Variables de modo
.equ			MODO				= 0x0111

; Días de cada mes (Solo primera localidad para apuntar con el XPointer)
.equ			DIAS_DE_MESES		= 0x0200
;***************************************************************************************************************************

;***************************************************************************************************************************
; Memoria de programa

.CSEG
.org 0x0000
	RJMP SETUP
;Guardamos un salto a la sub-rutina "PIN_CHANGE" en el vector de interrupción necesario
.org PCI1addr ;Pin Change Interrupt 1 (PORTC)
	RJMP PC_INTERRUPT
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
;***************************************************************************************************************************

;***************************************************************************************************************************
; Registros de propósito general
.def			msCOUNT0		= R20 
.def			msCOUNT1		= R21
.def			sCOUNT			= R22 
;***************************************************************************************************************************


;***************************************************************************************************************************
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

	;***********************************************************************************************************************
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
	;***********************************************************************************************************************

	;***********************************************************************************************************************
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

	; PORTC: Entradas de encoder y optoacoplador	|		PORTC: {0,0,0,0,OA,B0,B1,PB}
	LDI		R16, 0
	OUT		DDRC, R16
	LDI		R16, 0b00000001							;		¡Solo PB requiere PULLUP!
	OUT		PORTC, R16
	;***********************************************************************************************************************

	;***********************************************************************************************************************
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
	LDI		R16, (0 << CS12) |(0 << CS11) | (1 << CS10)
	STS		TCCR1B, R16
	LDI		R16, (1 << TOIE1) 
	STS		TIMSK1, R16
	LDI		R16, T1VALUE_H
	STS		TCNT1H, R16
	LDI		R16, T1VALUE_L
	STS		TCNT1L, R16
	;***********************************************************************************************************************

	;***********************************************************************************************************************
	; Configuramos las interrupciones de PINCHANGE en PORTC:

	LDI		R16, (1 << PCIE1)
    STS		PCICR, R16	
	LDI		R16, 0b00000011							; ¡Solo queremos leer PB y B0!
	STS		PCMSK1, R16	
	;***********************************************************************************************************************

	;***********************************************************************************************************************
	; Algunos valores iniciales:

	; Valores iniciales de variables de conteo
	; Registros de propósito general
	LDI		msCOUNT0, 0
	LDI		msCOUNT1, 0
	LDI		sCOUNT, 0
	; R5=0
	LDI		R16, 0
	MOV		R5, R16	
	; Localidades en RAM
	LDI		R16, 0
	STS		MINUTOS_UNIDADES, R16
	STS		MINUTOS_DECENAS, R16
	LDI		R16, 0
	STS		HORAS_UNIDADES, R16
	LDI		R16, 0
	STS		HORAS_DECENAS, R16
	LDI		R16, 1
	STS		DIAS_UNIDADES, R16						; ¡Días debe empezar en 01!
	LDI		R16, 0
	STS		DIAS_DECENAS, R16
	LDI		R16, 1
	STS		MESES_UNIDADES, R16						; ¡Meses debe empezar en 01!
	LDI		R16, 0
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

	; Valor inicial del YPointer
	LDI		YL, LOW(DIAS_DE_MESES)
	LDI		YH, HIGH(DIAS_DE_MESES)

	;***********************************************************************************************************************

	SEI
;***************************************************************************************************************************


;***************************************************************************************************************************
; ¡Empieza el LOOP!
LOOP:

	;***********************************************************************************************************************
	; PRIMER PASO: Actualizar variables de conteo para parpadeo.

	REVISAR_PARPADEO:
		;Se cuenta con dos variables de conteo de milisegundos.
		;Cuando msCOUNT0=250, habrán transcurrido 250 milisegundos; incrementamos msCOUNT1 y reiniciamos msCOUNT0
		;Cuando msCOUNT1=2, habrán transcurrido 500ms; reiniciamos msCOUNT1, "toggleamos" los dos puntos (PD7)...
		;y nos vamos al SEGUNDO PASO
		;Si msCOUNT0!=250, revisamos msCOUNT1
		;Si msCOUNT!=2, nos vamos al SEGUNDO PASO
		CPI		msCOUNT0, 250
		BREQ	REINICIAR_msCOUNT0_E_INCREMENTAR_msCOUNT1
		REVISAR_msCOUNT1:
			CPI		msCOUNT1, 2
			BREQ	REINICIAR_msCOUNT1_Y_TOGGLE
			RJMP	REVISAR_sCOUNT	
		REINICIAR_msCOUNT0_E_INCREMENTAR_msCOUNT1:
			CLR		msCOUNT0
			INC		msCOUNT1
			RJMP	REVISAR_msCOUNT1
		REINICIAR_msCOUNT1_Y_TOGGLE:
			CLR		msCOUNT1
			SBI		PIND, 7
			RJMP	REVISAR_sCOUNT	
	;***********************************************************************************************************************

	;***********************************************************************************************************************
	; SEGUNDO PASO: Actualizar variables de conteo generales.

	REVISAR_sCOUNT:
		;Si sCOUNT=60, habrá transcurrido un minuto; reiniciamos sCOUNT, incrementamos MINUTOS...
		;y vamos a revisar el conteo de minutos
		;Si sCOUNT!=60, vamos a revisar el conteo de minutos
		CPI		sCOUNT, 60
		BREQ	REINICIAR_sCOUNT_E_INCREMENTAR_MINUTOS
		RJMP	REVISAR_MINUTOS
		REINICIAR_sCOUNT_E_INCREMENTAR_MINUTOS:
			;Revisamos si al incrementar MINUTOS_UNIDADES, este llega 10 para reiniciarlo y aumentar MINUTOS_DECENAS
			;Si no, solo incrementamos MINUTOS_UNIDADES y nos vamos a revisar el conteo de minutos
			CLR		sCOUNT
			LDS		R16, MINUTOS_UNIDADES
			INC		R16
			CPI		R16, 10
			BREQ	REINICIAR_MINUTOS_UNIDADES_E_INCREMENTAR_MINUTOS_DECENAS
			;Si MINUTOS_UNIDADES!=10, solo lo guardamos...
			STS		MINUTOS_UNIDADES, R16
			RJMP	REVISAR_MINUTOS
			REINICIAR_MINUTOS_UNIDADES_E_INCREMENTAR_MINUTOS_DECENAS:
				LDI		R16, 0
				STS		MINUTOS_UNIDADES, R16
				LDS		R16, MINUTOS_DECENAS
				INC		R16
				STS		MINUTOS_DECENAS, R16
				RJMP	REVISAR_MINUTOS

	REVISAR_MINUTOS:
		;Si MINUTOS_DECENAS=6, habrá transcurrido una hora; reiniciamos MINUTOS, incrementamos HORAS...
		;y vamos a revisar el conteo de horas
		;Si MINUTOS_DECENAS!=6, vamos a revisar el conteo de horas
		LDS		R16, MINUTOS_DECENAS
		CPI		R16, 6
		BREQ	REINICIAR_MINUTOS_E_INCREMENTAR_HORAS
		RJMP	REVISAR_HORAS
		REINICIAR_MINUTOS_E_INCREMENTAR_HORAS:
			;Revisamos si al incrementar HORAS_UNIDADES, este llega a 10 para reiniciarlo y aumentar HORAS_DECENAS
			;Si no, solo incrementamos HORAS_UNIDADES y nos vamos a revisar el conteo de horas	
			LDI		R16, 0
			STS		MINUTOS_UNIDADES, R16
			STS		MINUTOS_DECENAS, R16
			LDS		R16, HORAS_UNIDADES
			INC		R16
			CPI		R16, 10
			BREQ	REINICIAR_HORAS_UNIDADES_E_INCREMENTAR_HORAS_DECENAS
			;Si HORAS_UNIDADES!=10, solo lo guardamos...
			STS		HORAS_UNIDADES, R16
			RJMP	REVISAR_HORAS
			REINICIAR_HORAS_UNIDADES_E_INCREMENTAR_HORAS_DECENAS:	
				LDI		R16, 0
				STS		HORAS_UNIDADES, R16
				LDS		R16, HORAS_DECENAS
				INC		R16
				STS		HORAS_DECENAS, R16
				RJMP	REVISAR_HORAS

	REVISAR_HORAS:
		;Si HORAS=24, habrá transcurrido un día; reiniciamos HORAS, incrementamos DIAS...
		;y vamos a revisar el conteo de días
		;Si HORAS!=24, vamos a revisar el conteo de días
		;Para revisar si HORAS=24, sumamos HORAS_UNIDADES y HORAS_DECENAS*10
		LDS		R16, HORAS_UNIDADES
		LDS		R17, HORAS_DECENAS
		;Multiplicamos HORAS_DECENAS por 10 para sumarlo a HORAS_UNIDADES
		LDI		R18, 10								; Factor de multiplicación
		MUL		R17, R18							; El resultado se guarda en R0
		;Ahora sí: sumamos
		ADD		R16, R0
		CPI		R16, 24
		BREQ	REINICIAR_HORAS_E_INCREMENTAR_DIAS
		RJMP	REVISAR_DIAS
		REINICIAR_HORAS_E_INCREMENTAR_DIAS:
			;Revisamos si al incrementar DIAS_UNIDADES, este llega a 10 para reiniciarlo y aumentar DIAS_DECENAS
			;Si no, solo incrementamos DIAS_UNIDADES y nos vamos a revisar el conteo de días
			LDI		R16, 0
			STS		HORAS_UNIDADES, R16
			STS		HORAS_DECENAS, R16
			LDS		R16, DIAS_UNIDADES
			INC		R16
			CPI		R16, 10
			BREQ	REINICIAR_DIAS_UNIDADES_E_INCREMENTAR_DIAS_DECENAS
			;Si DIAS_UNIDADES!=10, solo lo guardamos...
			STS		DIAS_UNIDADES, R16
			RJMP	REVISAR_DIAS
			REINICIAR_DIAS_UNIDADES_E_INCREMENTAR_DIAS_DECENAS:
				LDI		R16, 0
				STS		DIAS_UNIDADES, R16
				LDS		R16, DIAS_DECENAS
				INC		R16
				STS		DIAS_DECENAS, R16
				RJMP	REVISAR_DIAS

	REVISAR_DIAS:
		;Si DIAS=DIAS_DEL_MES, habrá transcurrido el mes; reiniciamos DIAS (Al valor "01"), incrementamos MESES...
		;incrementamos YPointer, y vamos a revisar el conteo de meses
		;Si DIAS!=DIAS_DEL_MES, vamos a revisar el conteo de meses
		;Para revisar si DIAS=DIAS_DEL_MES, sumamos DIAS_UNIDADES y DIAS_DECENAS*10...
		;y lo comparamos con el valor al cual apunta YPointer según el mes en que nos encontremos
		LDS		R16, DIAS_UNIDADES
		LDS		R17, DIAS_DECENAS
		;Multiplicamos DIAS_DECENAS por 10 para sumarlo a DIAS_UNIDADES
		LDI		R18, 10								; Factor de multiplicación
		MUL		R17, R18							; El resultado se guarda en R0
		;Ahora sí: sumamos
		ADD		R16, R0
		LD		R17, Y
		CP		R16, R17
		BREQ	REINICIAR_DIAS_E_INCREMENTAR_MESES
		RJMP	REVISAR_MESES
		REINICIAR_DIAS_E_INCREMENTAR_MESES:
			;Revisamos si al incrementar MESES_UNIDADES, este llega a 10 para reiniciarlo y aumentar MESES_DECENAS
			;Si no, solo incrementamos MESES_UNIDADES y nos vamos a revisar el conteo de meses
			LDI		R16, 1
			STS		DIAS_UNIDADES, R16
			LDI		R16, 0
			STS		DIAS_DECENAS, R16				;¡Días debe empezar en 01!
			ADIW	Y, 1							;Incrementamos YPointer
			LDS		R16, MESES_UNIDADES
			INC		R16
			CPI		R16, 10
			BREQ	REINICIAR_MESES_UNIDADES_E_INCREMENTAR_MESES_DECENAS
			;Si MESES_UNIDADES!=10, solo lo guardamos...
			STS		MESES_UNIDADES, R16
			RJMP	REVISAR_MESES
			REINICIAR_MESES_UNIDADES_E_INCREMENTAR_MESES_DECENAS:
				LDI		R16, 0
				STS		MESES_UNIDADES, R16
				LDS		R16, MESES_DECENAS
				INC		R16
				STS		MESES_DECENAS, R16
				RJMP	REVISAR_MESES

	REVISAR_MESES:
		;Si MESES=13, habrá transcurrido el año; reiniciamos MESES (Al valor "01")...
		;¡Y vamos al TERCER PASO! ¡YEY!
		;Si MESES!=13, vamos al TERCER PASO
		;Para revisar si MESES=13, sumamos MESES_UNIDADES y MESES_DECENAS*10
		LDS		R16, MESES_UNIDADES
		LDS		R17, MESES_DECENAS
		;Multiplicamos MESES_DECENAS por 10 para sumarlo a MESES_UNIDADES
		LDI		R18, 10								; Factor de multiplicación
		MUL		R17, R18							; El resultado se guarda en R0
		;Ahora sí: sumamos
		ADD		R16, R0
		CPI		R16, 13
		BREQ	REINICIAR_MESES
		RJMP	REVISAR_MODO
		REINICIAR_MESES:
			LDI		R16, 1
			STS		MESES_UNIDADES, R16
			LDI		R16, 0
			STS		MESES_DECENAS, R16				;¡Meses debe empezar en 01!
			RJMP	REVISAR_MODO
	;***********************************************************************************************************************

	;***********************************************************************************************************************
	; TERCER PASO: Actualizar valores HEX para displays (Funciones TIME_DISPLAY y DATE_DISPLAY). Depende del valor de MODO.

	REVISAR_MODO:
		;Si MODO(0)=0, se muestra TIME_DISPLAY
		;Si no, se muestra DATE_DISPLAY
		LDS		R16, MODO
		ANDI	R16, 0b00000001
		CPI		R16, 0
		BREQ	TIME_DISPLAY
		RJMP	DATE_DISPLAY
		TIME_DISPLAY:
			;DISPMODE_VALUE debe ser "H", así que ajustamos el XPointer y guardamos
			LDI		XL, LOW(DISPMODE_H)
			LDI		XH, HIGH(DISPMODE_H)
			LD		R16, X
			STS		DISPMODE_VALUE, R16
			;Guardamos DISPS 0&1 con los HEX de MINUTOS_UNIDADES y MINUTOS_DECENAS respectivamente (Ajustamos el ZPointer)
			;MINUTOS_UNIDADES en DISP0:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MINUTOS_UNIDADES
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP0_VALUE, R16
			;MINUTOS_DECENAS en DISP1:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MINUTOS_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP1_VALUE, R16
			;Guardamos DISPS 2&3 con los HEX de HORAS_UNIDADES y HORAS_DECENAS respectivamente (Ajustamos el ZPointer)
			;HORAS_UNIDADES en DISP2:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, HORAS_UNIDADES
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP2_VALUE, R16
			;HORAS_DECENAS en DISP3:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, HORAS_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP3_VALUE, R16
			JMP		LOOP

		DATE_DISPLAY:
			;DISPMODE_VALUE debe ser "F", así que ajustamos el XPointer y guardamos
			LDI		XL, LOW(DISPMODE_F)
			LDI		XH, HIGH(DISPMODE_F)
			LD		R16, X
			STS		DISPMODE_VALUE, R16
			;Guardamos DISPS 0&1 con los HEX de DIAS_UNIDADES y DIAS_DECENAS respectivamente (Ajustamos el ZPointer)
			;DIAS_UNIDADES en DISP0:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, DIAS_UNIDADES
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP0_VALUE, R16
			;DIAS_DECENAS en DISP1:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, DIAS_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP1_VALUE, R16
			;Guardamos DISPS 2&3 con los HEX de MESES_UNIDADES y MESES_DECENAS respectivamente (Ajustamos el ZPointer)
			;MESES_UNIDADES en DISP2:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MESES_UNIDADES
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP2_VALUE, R16
			;MESES_DECENAS en DISP3:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MESES_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5							;R5=0
			LPM		R16, Z
			STS		DISP3_VALUE, R16
			JMP		LOOP

	;***********************************************************************************************************************

;***************************************************************************************************************************


;***************************************************************************************************************************
; ¡Rutinas de interrupción!

TIM1_INTERRUPT:
	;Empujamos registros al STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	PUSH	R17
	PUSH	R18
	;¡No hay interrupciones anidadas!
	;Reseteamos TIM1
	LDI		R16, T1VALUE_H
	STS		TCNT1H, R16
	LDI		R16, T1VALUE_L
	STS		TCNT1L, R16	
	;Incrementamos el contador de segundos
	INC		sCOUNT
	TIM1_EXIT:
		;Sacamos registros del STACK
		POP		R18
		POP		R17
		POP		R16
		OUT		SREG, R16
		POP		R16
		RETI

PC_INTERRUPT:
	;Empujamos registros al STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	PUSH	R17
	PUSH	R18
	;Habilitamos interrupciones anidadas (Solo para TIM1, así que se desactiva TIMSK0)
	LDI		R16, (0 << TOIE0) 
	STS		TIMSK0, R16
	SEI
	;Es de aclarar: El encoder cambiará su funcionalidad según el modo general en que se encuentre el reloj, pero...
	;de momento solo interesa cambiar MODO.
	;Si MODO(1)=1, se habilita cambiar de modo. Si MODO(1)=0, NO se habilita cambiar de modo.
	;MODO(0) almacena si se quiere mostrar TIME o DATE.
	;Solo me importan los flancos de bajada de PINC0 (PB del encoder)
	;Solo me importan los falncos de bajada de PINC1 (Perilla del encoder)
	;Entonces:
	;Si PINC0 está encendido, no me importa... lo salto
	;Si está en flanco de bajada, el PB fue presionado y CAMBIAMOS MODO(1).
	SBIS	PINC, 0
	RJMP	CAMBIAR_MODO_1
	REVISAR_PINC1:
	;Si PINC1 está encendido, no me importa... lo salto
	;Si está en flanco de bajada, cambió la perilla; revisamos si cambiamos MODO(0) o no.
	SBIS	PINC, 1
	RJMP	CAMBIAR_MODO_0
	;Si ninguno está en flanco de bajada, salimos
	RJMP	PC_EXIT
	CAMBIAR_MODO_1:
		;Revisamos si MODO(1) ESTABA encendido
		;Si sí, lo apagamos, y vamos a revisar PINC1
		;Si no, lo encendemos, y vamos a revisar PINC1
		LDS		R16, MODO
		ANDI	R16, 0b00000010
		CPI		R16, 0b00000010
		BREQ	DESHABILITAR_MODO_1
		RJMP	HABILITAR_MODO_1
		DESHABILITAR_MODO_1:
			LDI		R16, 0
			LDS		R17, MODO
			ANDI	R17, 0b00000001
			OR		R16, R17
			STS		MODO, R16
			RJMP	REVISAR_PINC1
		HABILITAR_MODO_1:
			LDI		R16, 0b00000010
			LDS		R17, MODO
			ANDI	R17, 0b00000001
			OR		R16, R17
			STS		MODO, R16
			RJMP	REVISAR_PINC1
	CAMBIAR_MODO_0:
		;Revisamos si es correcto modificar MODO(0) con base en la bandera en MODO(1)
		;Si MODO(1) está encendida, SÍ CAMBIAMOS MODO(0); revisamos PINC2 para saber si incrementar o decrementar
		;Si no... NO CAMBIAMOS MODO(0) y nos salimos
		LDS		R16, MODO
		ANDI	R16, 0b00000010
		CPI		R16, 0b00000010
		BREQ	REVISAR_PINC2
		RJMP	PC_EXIT
		REVISAR_PINC2:
			;Si PINC2 está encendido, es ADELANTE
			;Si PINC2 está apagado, es ATRAS
			SBIS	PINC, 2
			RJMP	DECREMENTAR_MODO_0
			RJMP	INCREMENTAR_MODO_0
		DECREMENTAR_MODO_0:
			LDS		R16, MODO
			ANDI	R16, 0b00000001
			CPI		R16, 0
			BREQ	ENCENDER_MODO_0
			RJMP	APAGAR_MODO_0
		INCREMENTAR_MODO_0:
			LDS		R16, MODO
			ANDI	R16, 0b00000001
			CPI		R16, 0
			BREQ	ENCENDER_MODO_0
			RJMP	APAGAR_MODO_0
			ENCENDER_MODO_0:
			LDS		R16, MODO
			ORI		R16, 0b00000001
			STS		MODO, R16
			APAGAR_MODO_0:
			LDS		R16, MODO
			ANDI	R16, 0b00000010
			STS		MODO, R16
	PC_EXIT:
		;Re-habilitamos TIMSK0
		LDI		R16, (0 << TOIE0) 
		STS		TIMSK0, R16
		;Y sacamos registros del STACK
		POP		R18
		POP		R17
		POP		R16
		OUT		SREG, R16
		POP		R16
		RETI

TIM0_INTERRUPT:	
	;Empujamos registros al STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	PUSH	R17
	PUSH	R18
	;Habilitamos interrupciones anidadas (Solo para TIM1, así que se desactiva PCIE)
	LDI		R16, (0 << PCIE1)
    STS		PCICR, R16
	SEI
	;Reseteamos TIM0
	LDI		R16, T0VALUE
	OUT		TCNT0, R16
	;Incrementamos el contador de milisegundos
	INC		msCOUNT0
	;Rutina para multiplexar displays ("D(n)" se refiere a "Display(n)"):
	;Si el bit D(n) está apagado, el bit no estaba encendiendo un transistor, entonces no le damos importancia
	;Por el contrario, si el bit D(n) está encendido, el bit estaba encendiendo un transistor, así que apagamos...
	;el PIN D(n) y encendemos el PIN D(n+1)
	SBIC	PORTB, 0
	RJMP	ENCENDER_D1_Y_APAGAR_D0
	SBIC	PORTB, 1
	RJMP	ENCENDER_D2_Y_APAGAR_D1
	SBIC	PORTB, 2
	RJMP	ENCENDER_D3_Y_APAGAR_D2
	SBIC	PORTB, 3
	RJMP	ENCENDER_D4_Y_APAGAR_D3
	SBIC	PORTB, 4
	RJMP	ENCENDER_D0_Y_APAGAR_D4
	RJMP	TIM0_EXIT
		ENCENDER_D1_Y_APAGAR_D0:
			;Primero apagamos D0 (Evitamos "ghosting")
			SBI		PINB, 0
			;Cargamos el valor de DISP1 a R16
			LDS		R16, DISP1_VALUE
			;Para verificar si se deben encender o apagar los dos puntos, revisamos el estado actual de PORTD
			;El valor de PD7 varía por el PRIMER PASO del LOOP
			;Entonces, cargamos PD7 a un registro vacío (R18), y, como los valores HEX guardados SIEMPRE tienen a PD7...
			;apagado, hacemos un OR entre el valor de DISP1 y el registro con el valor de PD7 (R16 OR R18)
			IN		R17, PORTD
			BST		R17, 7
			LDI		R18, 0
			BLD		R18, 7
			OR		R16, R18
			;Subimos el valor resultante a PORTD
			OUT		PORTD, R16
			;Y encendemos D1
			SBI		PINB, 1
			RJMP	TIM0_EXIT
		ENCENDER_D2_Y_APAGAR_D1:
			;Primero apagamos D1 (Evitamos "ghosting")
			SBI		PINB, 1
			;Cargamos el valor de DISP2 a R16
			LDS		R16, DISP2_VALUE
			;Verificamos el valor de los dos puntos...
			IN		R17, PORTD
			BST		R17, 7
			LDI		R18, 0
			BLD		R18, 7
			OR		R16, R18
			;Subimos el valor resultante a PORTD
			OUT		PORTD, R16
			;Y encendemos D2
			SBI		PINB, 2
			RJMP	TIM0_EXIT
		ENCENDER_D3_Y_APAGAR_D2:
			;Primero apagamos D2 (Evitamos "ghosting")
			SBI		PINB, 2
			;Cargamos el valor de DISP3 a R16
			LDS		R16, DISP3_VALUE
			;Verificamos el valor de los dos puntos...
			IN		R17, PORTD
			BST		R17, 7
			LDI		R18, 0
			BLD		R18, 7
			OR		R16, R18
			;Subimos el valor resultante a PORTD
			OUT		PORTD, R16
			;Y encendemos D3
			SBI		PINB, 3
			RJMP	TIM0_EXIT
		ENCENDER_D4_Y_APAGAR_D3:
			;Primero apagamos D3 (Evitamos "ghosting")
			SBI		PINB, 3
			;Cargamos el valor de DISPMODE (Ojo) a R16
			LDS		R16, DISPMODE_VALUE
			;Verificamos el valor de los dos puntos...
			IN		R17, PORTD
			BST		R17, 7
			LDI		R18, 0
			BLD		R18, 7
			OR		R16, R18
			;Subimos el valor resultante a PORTD
			OUT		PORTD, R16
			;Y encendemos D4
			SBI		PINB, 4
			RJMP	TIM0_EXIT
		ENCENDER_D0_Y_APAGAR_D4:
			;Primero apagamos D4 (Evitamos "ghosting")
			SBI		PINB, 4
			;Cargamos el valor de DISP0 a R16
			LDS		R16, DISP0_VALUE
			;Verificamos el valor de los dos puntos...
			IN		R17, PORTD
			BST		R17, 7
			LDI		R18, 0
			BLD		R18, 7
			OR		R16, R18
			;Subimos el valor resultante a PORTD
			OUT		PORTD, R16
			;Y encendemos D0
			SBI		PINB, 0
			RJMP	TIM0_EXIT
	TIM0_EXIT:
		;Rehabilitamos PCIE
		LDI		R16, (1 << PCIE1)
		STS		PCICR, R16
		;Y sacamos registros del STACK
		POP		R18
		POP		R17
		POP		R16
		OUT		SREG, R16
		POP		R16
		RETI
;***************************************************************************************************************************