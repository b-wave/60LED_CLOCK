;_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
;
;									DS1307.ASM
;
;--------------------------------------------------------------------------------
;
; Copyright (c) 2012 by Steve Botts, KD6VKF.  All rights reserved.
; Modified for WWVB CLOCK (4MHZ) 10/20/12 
; Original: March 23, 2001 for APRS WX Station
; Modified: 10/22/12 for WWVB RTC Receiver project
;--------------------------------------------------------------------------------
; This is the code for timestamping the wx packet
; it makes an I2C call to the clock chip, and 
; loads that data into the time registers for the
; purpose of timestamping the packet.
;_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

GetRTC_TIME
;________________________________________________________________
;
; Writes data to DS1307 RTC - gets set from config or WWVB
;________________________________________________________________

		movlw	0xD0			; address the DS1307
		movwf	OutByte			; read mode to put in register
		call	I2CStart		; address
		call	I2CWrite

		movlw	0x00			; start with reg. address for minutes
		movwf	OutByte
		call	I2CWrite
		call	I2CStop			; end this part of the transfer
		call	Delay25
		call	Delay25

		movlw	0xD1			; now address in read mode
		movwf	OutByte
		call	I2CStart		; repeated start condx
		call	I2CWrite

; read seconds (ADDR 00)	(DUMMY READ TEST)
		call	I2CRead			; 
		call	I2CAck

; read minutes (ADDR 01)
		call	I2CRead			; 
		call	I2CAck

		movfw	InByte
		andlw	b'00001111'		; mask raw for 1's digit
		movwf	Min1

		movfw	InByte
		andlw	b'01110000'		; get raw - mask 10's digit
		movwf	Min10			; put it in 10's digit register
		swapf	Min10, F		; swap nibbles

		andwf	Min1

; read hours (ADDR 02)
		call	I2CRead			
		call	I2CAck
		movfw	InByte
		andlw	b'00001111'		; mask raw for 1's digit
		movwf	Hour1			; save in Hours
 
		movfw	InByte
		andlw	b'00110000'		; get raw - mask 10's digit
		movwf	Hour10			; put it in 10's digit register
		swapf	Hour10, F		; swap nibbles

		goto	IICSTOP			;TEST  stop here for now

; read day of week (ADDR 03)
		call	I2CRead			; this is day of week, toss it? 
		call	I2CAck
		movfw	InByte
		andlw	b'00000111'		; get raw -> mask 7 day's digit
		movwf	DoW				; .save the byte -- we may use it

; read day  (ADDR 04)
		call	I2CRead			; read date
		call	I2CAck
		movfw	InByte
		andlw	b'00001111'		; get raw -> mask month's digit
		movwf	Day1			; save byte 
		movfw	InByte
		andlw	b'00110000'		; get raw - mask 10's digit
		movwf	Day10			; put it in 10's digit register
		swapf	Day10, F		; swap nibbles

; read month (ADDR 05)
		call	I2CRead			; read month
		call	I2CNack
		movfw	InByte
		andlw	b'00001111'		; get raw -> mask year's digit
		movwf	Month1			; save byte 
		movfw	InByte
		andlw	b'00010000'		; get raw - mask 10's digit
		movwf	Month10			; put it in 10's digit register
		swapf	Month10, F		; swap nibbles

; read year (ADDR 06)
		call	I2CRead			; read year
		call	I2CNack
		movfw	InByte
		andlw	b'00001111'		; get raw -> mask year's digit
		movwf	Year1			; save byte 
		movfw	InByte
		andlw	b'11110000'		; get raw - mask 10's digit
		movwf	Year10			; put it in 10's digit register
		swapf	Year10, F		; swap nibbles
IICSTOP:
		call	I2CStop			;DONE!
		call	Delay25
		call	Delay25

		return
;-----------------------------------------------------------------------
; 		Done with I2C transfer!
;
;-----------------------------------------------------------------------


	return


SetRTC_TIME
;________________________________________________________________
;
; Writes data to DS1307 RTC - gets set from config or WWVB
;________________________________________________________________

		movlw		0xD0			; chip address
		movwf		OutByte
		call		I2CStart
		call		I2CWrite
		movlw		0x00
		movwf		OutByte
		call		I2CWrite
		movlw		0x00
		movwf		OutByte
		call		I2CWrite
	;	bsf			STATUS, RP0

		movfw		Min1			;Minutes in BCD
	;	bcf			STATUS, RP0
		movwf		OutByte
		call		I2CWrite
	;	bsf			STATUS, RP0

		movfw		Hour1			; hours in BCD
	;	bcf			STATUS, RP0
		movwf		OutByte
		call		I2CWrite

		movlw		0x00		; day of the week dummy write Use DoW
		movwf		OutByte
		call		I2CWrite

	;	bsf		STATUS, RP0
		movfw		Day1		; Day
	;	bcf		STATUS, RP0
		movwf		OutByte
		call		I2CWrite

	;	bsf		STATUS, RP0
		movfw		Month1		;Month
	;	bcf		STATUS, RP0
		movwf		OutByte
		call		I2CWrite

	;	bsf		STATUS, RP0
		movfw		Year1		;Year
	;	bcf		STATUS, RP0
		movwf		OutByte
		call		I2CWrite
		call		I2CStop
		call		Delay25
		call		Delay25
		return
