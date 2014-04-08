; BitBang I2C Routines
;
;--------------------------------------------------------------------------------
;
; Copyright (c) 2012 by Steve Botts, KD6VKF.  All rights reserved.
; Modified for WWVB CLOCK (4MHZ) 10/20/12 
; Original March 23, 2001
;
;--------------------------------------------------------------------------------
;
; This is a set of I2C routines.  RA2 is SCL and RA3 is SDA.  Registers that must
; be defined include:
;
; BitCount (bit index)
; OutByte (Data to be transmitted should be put in this register before Transmit is called)
; InByte (Data received is left in this register following the Receive call)
;
; These routines run at an approximate clock rate of 65 kHz for a 10 MHz PIC oscillator.
; The spec for I2C lists a maximum of 100 kHz or 400 kHz for the fast bus devices.
; appropriate modifications to Delay25 should be made to raise the clock rate.  
;
; This assumes the SDA and SCL lines are pulled high, 1 = input (Hi ZO) and 0=OUTPUT 0
; to pull the line low.  This uses both th TRIsB and PORTB
;----------------------------------------------------------------------------------

I2CInit
; we need to use RB0 and RB1 for these on the clock project...
;SCL		equ		0x07		; use RA7 for SCL 
;SDA		equ		0x06		; use RA6 for SDA
SCL		equ		0x00		; use RB0 for SCL 
SDA		equ		0x01		; use RB1 for SDA

		banksel TRISB       ; select correct bank 
		bsf		STATUS, RP0	; select bank 1
		bcf		TRISB,  SCL	; set SCL as output
		bcf		TRISB,  SDA	; set SDA as output
		bcf		STATUS, RP0	; select bank 0

		banksel PORTB       ; select correct bank 
		bsf		PORTB, SCL	; set SCL high
		bsf		PORTB, SDA	; set SDA high
		Bank0

		return

;----------------------------------------------------------------------------------

I2CStart	
		bsf		PORTB, SDA	; make sure lines are high
		call	Delay25
		bsf		PORTB, SCL

		call	Delay25		; wait 2.5 usec
		bcf		PORTB, SDA	; bring SDA low
		call	Delay25		; wait 2.5 usec
		bcf		PORTB, SCL	; bring SCL low
		return				; that's it - return

;----------------------------------------------------------------------------------

I2CWrite
		movlw	0x08		; initialize bit index
		movwf	BitCount

Next	call	Delay25		; wait 2.5 usec
		btfss	OutByte, 7	; test and send bit
		bcf		PORTB, SDA	; if bit is 0, make output pin low
		btfsc	OutByte, 7
		bsf		PORTB, SDA	; if bit is 1, make output pin high
		call	Delay25		; wait 2.5 usec
		bsf		PORTB, SCL	; bring clock high
		rlf		OutByte		; rotate to next bit
		call	Delay25		; wait one bit period
		call	Delay25
		bcf		PORTB, SCL	; bring clock low
		decfsz	BitCount	; are we done yet?
		goto	Next		; no, send the next bit

		banksel TRISB       ; select correct bank 
;		bsf		STATUS, RP0	; select bank 1
		bsf		TRISB, SDA 	; make RA3 an input
		bcf		STATUS, RP0	; done

		call	Delay25
		call	Delay25		; wait 2.5 usec
		bsf		PORTB, SCL	; make SCL high
		call	Delay25		; wait one bit period for ACK
		call	Delay25		;  from the slave chip
		bcf		PORTB, SCL	; bring SCL low

		bsf		STATUS, RP0	; select bank 1
		bcf		TRISB, SDA 	; make RA3 an output again
;		bcf		STATUS, RP0	; done
		Bank0
		call	Delay25		; wait 2.5 usec

		return					; finished - return to main
;----------------------------------------------------------------------------------

I2CStop
		bsf		PORTB, SCL	; bring SCL high
		call	Delay25		; wait 2.5 usec
		bsf		PORTB, SDA	; bring SDA high
		call	Delay25		; wait 2.5 usec
		return				; finished - return to main

;----------------------------------------------------------------------------------

I2CRead
		movlw	0x08		; set bit index
		movwf	BitCount

		bsf		STATUS, RP0	; select bank 1
		bsf		TRISB, SDA	; make SDA an input
		bcf		STATUS, RP0	; done

NextIn	call	Delay25		; wait
		rlf		InByte		; MSB first
		bsf		PORTB, SCL	; set clock high
		call	Delay25		; wait
		btfss	PORTB, SDA	; read input bit
		bcf		InByte, 0	; if 0, set bit 0
		btfsc	PORTB, SDA
		bsf		InByte, 0	; if 1, set bit 1

		call	Delay25		; wait
		bcf		PORTB, SCL	; set clock low
		call	Delay25		; wait
		decfsz	BitCount	; test bit index
		goto	NextIn		; not done yet

		bsf		STATUS, RP0	; select bank 1
		bcf		TRISB, SDA	; make SDA an output
		bcf		STATUS, RP0	; done
		bcf		PORTB, SDA	; make sure SDA is low

		return				; back to main

;----------------------------------------------------------------------------------

I2CAck
		bcf		PORTB, SDA	; clear SDA
		call	Delay25		; wait
		bsf		PORTB, SCL	; set clock
		call	Delay25		; wait one  bit period
		call	Delay25
		bcf		PORTB, SCL	; bring clock low
		call	Delay25		; wait
		return				; return to main

;----------------------------------------------------------------------------------

I2CNack
		bsf		PORTB, SDA	; bring SDA high
		call	Delay25		; wait
		bsf		PORTB, SCL	; set clock
		call	Delay25		; wait one  bit period
		call	Delay25
		bcf		PORTB, SCL	; bring clock low
		call	Delay25
		bcf		PORTB, SDA	; bring SDA low
		call	Delay25		; wait
		return				; return to main

;----------------------------------------------------------------------------------

Delay25	goto		$+1		; 2.2 usec delay loop
		goto		$+1
		goto		$+1
		goto		$+1
		return

;----------------------------------------------------------------------------------

