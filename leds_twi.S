
; Copyright (c) 2021 ozforester. All rights reserved.
; Use of this source code is goverened by a MIT license
; that can be found in the LICENSE file.

; ATmega8 @4MHz internal osc. (H:D9, L:23)
; scans twi bus and blinks two nibbles of the first answered device (w/o W bit)
; (to be continued as blinking via PCF8574AT extension)


#include <avr/io.h>
#include <util/twi.h>

#undef __SFR_OFFSET
#define __SFR_OFFSET 0
#define START 	  0x08
#define REP_START 0x10
#define SLAW_ACK  0x18
;#define SLAW_NACK 0x20
;#define DATA_ACK  0x28
;#define DATA_NACK 0x30

temp =    16			; common use reg
counter = 17			; delay counter reg
code =    18			; blink code reg
address = 19			; scanned address reg

.section .text			; code section

.global main                    ;
main:				;
	rcall port_init		; out,low
	rcall timer_init	; timer0
	rcall twi_init		; 100kHz
	rcall twi_scan		; downwards 127..0 (0 = no answer)
        cpi address, 0          ; there was no answer
        brne main1              ; if not cleared
	rcall error_blink	; error blink
	main1:			;
	; $address$		;
	rcall code_blink	; blink address nibbles
	ret			;

twi_scan:			;
	ldi address, 127	; will step backward
	twscan1:		;
	rcall twi_start		; start/rep_start
	rcall twi_slaw		; slave addres + w
	cpi temp, 0xFF		; touched?
	breq twscan2		; if not cleared
	clr temp		; (temp=0x00)
	subi address, 1		; else next address
	cpi address, 0		; last address
	breq twscan2		;
	rjmp twscan1		;
	twscan2:		;
	rcall twi_stop		;
	ret			;

twi_slaw:					;
	ldi temp, address			; 0x3F slave address
	lsl temp				; 0x7E << (0x3F slave address + 0), R/W = W
	out TWDR, temp				;
	ldi temp, (1<<TWINT)|(1<<TWEN)		;
	out TWCR, temp				; go
	slaw1:					;
        in temp, TWCR                           ;
        sbrs temp, TWINT                        ; skip if sent
        rjmp slaw1                              ; or cycle
        in temp, TWSR                           ; read status
        andi temp, 0xF8                         ;
        cpi temp, SLAW_ACK                      ;
	breq slaw2				; acked (stay temp untouched)
	ser temp				; else (temp=0xFF)
	slaw2:					;
	ret					;

twi_start:						;
	ldi temp, ((1<<TWINT)|(1<<TWSTA)|(1<<TWEN))	;
	out TWCR, temp					; go
	start1:						;
	in temp, TWCR					;
	sbrs temp, TWINT				; skip if sent
        rjmp start1                                     ;
	in temp, TWSR					; read status
	andi temp, 0xF8					;
	cpi temp, START					;
	breq start2					;
        cpi temp, REP_START                             ;
        breq start2                                     ;
	rcall error_blink				; error (blinking loop)
	start2:						;
	ret						; acked

twi_stop:						;
	ldi r16, (1<<TWINT)|(1<<TWEN)|(1<<TWSTO)	;        out TWCR, temp                                  ;
	ret						;

error_blink:			;
        eb:                     ;
        sbi PORTB, 0            ; B0 high
        ldi counter, 1          ; delay on
        rcall delay             ;
        cbi PORTB, 0            ; B0 low
        ldi counter, 5          ; delay off
        rcall delay             ;
        rjmp eb                 ;
        ret                     ;

code_blink:                     ;
	lsr address		; r/w inclusive if comment
	again:			;
	cpi address, 0		; if 0 it blinks constantly so skip
	breq c3			; while zero address may appear
	mov temp, address	; load high nibble
	swap temp		;
	andi temp, 0x0F		;
	mov code, temp		;
	c1:			;
        rcall led_blink         ;
	subi code, 1		;
	brne c1			;
        ldi counter, 15         ; pause between
        rcall delay             ;
        mov temp, address       ; load low nibble
        andi temp, 0x0F         ;
        mov code, temp          ;
	c2:                     ;
        rcall led_blink         ;
        subi code, 1            ;
        brne c2                 ;
        ldi counter, 60         ; pause after
        rcall delay             ;
	rjmp again		;
	c3:			;
        ret                     ;

led_blink:                      ; blink once
        sbi PORTD, 7            ; D7 high
        ldi counter, 1          ; delay on
        rcall delay             ;
        cbi PORTD, 7            ; D7 low
        ldi counter, 5          ; delay off
        rcall delay             ;
        ret                     ;

delay:                          ; counter itself decrements by t0 isr
wait:                           ;
        cpi counter, 0          ; just wait 0
        brne wait               ;
        ret                     ; voila

port_init:			;
	sbi DDRD, 7		; D7 output
	cbi PORTD, 7		; D7 low
	ret			;

twi_init:			; 100 kHz @4MHz clock
	ldi temp, 0b00001100	; 4000000 / ( 16 + 2*TWBR * 4^TWPS )
	out TWBR, temp		; 12
        in temp, TWSR	        ;
        ori temp, 0b00000000    ; 1
	;ori temp, 0b00000011	; 64
	out TWSR, temp		;
	ret			;

timer_init:			; TIMER0 (65 ms @4MHz)
        ldi temp, (1<<CS00)     ;
        ori temp, (1<<CS02)     ;
        out TCCR0, temp         ;
        ldi temp, (1<<TOIE0)    ;
        out TIMSK, temp         ;
        sei                     ;
	ret			;

.global TIMER0_OVF_vect		; doc
TIMER0_OVF_vect:		; counter--
	push temp		;
	in temp, SREG		; z in main loop
	subi counter, 1		;
	out SREG, temp		;
	pop temp		;
	reti			;

.global __vector_default        ; Note [10] nongnu.org assembly
__vector_default:		;
	reti			;

.end
