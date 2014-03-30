
;------------------------------------------------------------
;               LCD Routines
; FILE: lcd_16x2.asm
;------------------------------------------------------------
;  Macro

EStrobe MACRO                   ;  Strobe the "E" Bit
  bsf    E_LINE
  bcf    E_LINE
 ENDM

;EQUATES:
LCD_PORT	Equ	PORTA
LCD_TRIS	Equ	TRISA
LCD_E		Equ	0x04
LCD_RS		Equ	0x05			;LCD handshake lines
;LCD_RW		Equ	0x06			;not used at this time...

;--------------------------------------------------------------------------------
;
; Copyright (c) 2012 by Steve Botts, KD6VKF.  All rights reserved.
; Modified for WWVB CLOCK (4MHZ) 11/14/12 
;
;--------------------------------------------------------------------------------

;----------------------------------------------------------------------------------
;init_lcd
  
;
;        bcf     E_LINE                  ;E line low
;        bcf     RS_LINE                 ;RS low, control
;        call    delay_15mS              ;delay 15 mS
;        movlw   0x03                    ;8-bit, 5X7 mode
;        movwf   lcd_data
;        call    flipbit
;        call    pulse
;		call	delay_15mS
;        movlw   0x02                   ;4-bit, 5x7 mode
;        movwf   lcd_data
;        call    flipbit
;        call    pulse
;		call	delay_15mS
;        movlw   0x28                    ;4-bit, 5x7 mode
;        call    LCD_Cmd                 ;send both nybbles
;        movlw   0x0c                    ;display on, cursor off
;        call    LCD_Cmd
;        movlw   0x06                    ;increment mode
;        call    LCD_Cmd
;        movlw   0x01                    ;clear display
;        call    LCD_Cmd
; 		call	delay_15mS
;        return
;------------------------------------------------------------
;first_line_display
;        movlw   LINE_1
;        call    LCD_Cmd                 ;
;        return
;------------------------------------------------------------
;second_line_display
;        movlw   LINE_2
;        call    LCD_Cmd                 ;
;        return
;
;------------------------------------------------------------
;	Line_clear does whole line 
;	Line_stuff clears W number of chars
;------------------------------------------------------------
LCD_line_clear
	movlw	.20			;countdown from 20
LCD_line_stuff	
	movwf	lcd_count		;countdown from W 
line_clear_loop	
	movlw	" "
	movwf	lcd_data
	call	LCD_DAT
	decfsz	lcd_count,F
	goto	line_clear_loop
	return
;
;------------------------------------------------------------
;		clear LCD line
;------------------------------------------------------------
insert_space
	movlw	" "			;space to W
	movwf	lcd_data
	call	LCD_DAT			;W to LCD
	return
;	       
;------------------------------------------------------------
;		sends control byte to LCD
;------------------------------------------------------------
;LCD_CONT					
;        movwf   lcd_data                ;store w in lcd_data
;		bcf		RS_LINE						;control
;        call    delay_125uS
;        call    flipbit                 ;hi nibble to PORTB
;		call	pulse
;        swapf   lcd_data,F              ;swap MS and LS nybbles
;        call    flipbit                 ;output what was LS nybble
;		call	pulse
;		return
;------------------------------------------------------------
;		sends lcd_data to LCD
;------------------------------------------------------------
;LCD_DAT					
;       movwf   lcd_data                ;store w in lcd_data
;		bsf		RS_LINE					;data
;       call    delay_125uS
;        call    flipbit                 ;hi nibble to PORTB
;		call	pulse
;        swapf   lcd_data,F              ;swap MS and LS nybbles
;        call    flipbit                 ;output what was LS nybble
;		call	pulse
;		return
;------------------------------------------------------------
;		clears upper nibble of PORTB then writes
;		upper nibble of lcd_data to PORTB
; 	THIS WILL NEED TO CHANGE FOR 360CLOCK W/SWITCHES
;   ALSO LOOKS LIKE THE Y_LED "FLASH" COMES FROM HERE
;------------------------------------------------------------
;flipbit
;	movlw	0xF0
;	andwf	PORTB,F
;	movfw	lcd_data
;	andlw	0x0F
;	iorwf 	PORTA,F
;	return
;------------------------------------------------------------

pulse
        bsf     E_LINE                  ;pulse E line
        nop                             ;delay
        bcf     E_LINE
        call    delay_125uS             ;delay 125 uS
        return
;------------------------------------------------------------
;clear_LCD_display
;        movlw   0x01                    ;clear display
;        call    SendINS                  ;send to display
;        call    delay_15mS              ;allow 15 mS to clear
;        return


;-------------------------------------------------------------------------;
;                 Initialize the LCD                                      ;
;-------------------------------------------------------------------------;
;Initialise LCD
LCD_Init	call	Delay100		;wait for LCD to settle

		movlw	0x20			;Set 4 bit mode
		call	LCD_Cmd

		movlw	0x28			;Set display shift
		call	LCD_Cmd

		movlw	0x06			;Set display character mode
		call	LCD_Cmd

		movlw	0x0c			;Set display on/off and cursor command
		call	LCD_Cmd			;Set cursor off

		call	LCD_Clr			;clear display

		retlw	0x00

; command set routine
LCD_CONT:
LCD_Cmd		movwf	lcd_data
		swapf	lcd_data,	w	;send upper nibble
		andlw	0x0f			;clear upper 4 bits of W
		movwf	LCD_PORT
		bcf	LCD_PORT, LCD_RS	;RS line to 1
		call	Pulse_e			;Pulse the E line high

		movf	lcd_data,	w	;send lower nibble
		andlw	0x0f			;clear upper 4 bits of W
		movwf	LCD_PORT
		bcf	LCD_PORT, LCD_RS	;RS line to 1
		call	Pulse_e			;Pulse the E line high
		call 	Delay5
		retlw	0x00

SendASCII:
LCD_CharD	addlw	0x30			;add 0x30 to convert to ASCII

LCD_DAT:
SendCHAR:
LCD_Char	movwf	lcd_data
		swapf	lcd_data,	w	;send upper nibble
		andlw	0x0f			;clear upper 4 bits of W
		movwf	LCD_PORT
		bsf	LCD_PORT, LCD_RS	;RS line to 1
		call	Pulse_e			;Pulse the E line high

		movf	lcd_data,	w	;send lower nibble
		andlw	0x0f			;clear upper 4 bits of W
		movwf	LCD_PORT
		bsf	LCD_PORT, LCD_RS	;RS line to 1
		call	Pulse_e			;Pulse the E line high
		call 	Delay5
		retlw	0x00

first_line_display:
LCD_Line1	movlw	0x80			;move to 1st row, first column
		call	LCD_Cmd
		retlw	0x00
second_line_display:
LCD_Line2	movlw	0xc0			;move to 2nd row, first column
		call	LCD_Cmd
		retlw	0x00

LCD_Line1W	addlw	0x80			;move to 1st row, column W
		call	LCD_Cmd
		retlw	0x00

LCD_Line2W	addlw	0xc0			;move to 2nd row, column W
		call	LCD_Cmd
		retlw	0x00

LCD_CurOn	movlw	0x0d			;Set display on/off and cursor command
		call	LCD_Cmd
		retlw	0x00

LCD_CurOff	movlw	0x0c			;Set display on/off and cursor command
		call	LCD_Cmd
		retlw	0x00

clear_LCD_display:
LCD_Clr		movlw	0x01			;Clear display
		call	LCD_Cmd
		call	Delay15				;this command takes a few mSec so wait..15
		retlw	0x00

;-------------------------------------------------------------------------;
;              Send the character in W out to the LCD                     ;
;-------------------------------------------------------------------------;
;SendASCII
;  addlw '0'                     ;  Send nbr as ASCII character
;SendCHAR                        ;  Send the Character to the LCD
;  movwf  lcd_data                   ;  Save the Temporary Value
;  swapf  lcd_data, w                ;  Send the High Nybble
;  banksel PORTA       ; select bank 0 as default bank 
;
;  bsf    RS_LINE                    ;  RS = 1
;  call   NybbleOut
;  movf   lcd_data, w                ;  Send the Low Nybble
;  bsf    RS_LINE
;  call   NybbleOut
;  return

;-------------------------------------------------------------------------;
;              Send an instruction in W out to the LCD                    ;
;-------------------------------------------------------------------------;
;SendINS                 ;  Send the Instruction to the LCD
;  movwf  lcd_data			;  Save the Temporary Value
;  swapf  lcd_data, w		;  Send the High Nybble
;  andlw  0x0f			;  clear upper 4 bits of W
; 
;  bcf    RS_LINE        ;  RS = 0
;  call   NybbleOut
;  movf   lcd_data, w        ;  Send the Low Nybble
;  bcf    RS_LINE
;  call   NybbleOut
;  return

;-------------------------------------------------------------------------;
;              Send the lower nibble in W out to the LCD                        ;
;-------------------------------------------------------------------------;
;NybbleOut                       ;  Send a Nybble to the LCD
; 		movf	lcd_data, w			;send lower nibble
;		andlw	0x0f			;clear upper 4 bits of W
;		movwf	PORTA
;		bcf		RS_LINE			;RS line to 0
;		EStrobe		 			;Pulse the E line high
;		call 	Dlay5
;		nop
;		return

;-------------------------------------------------------------------------;
;                   Output the UTC message on the LCD                           ;
;-------------------------------------------------------------------------;
;OutMessage:
;  movwf  FSR                    ;  Point at first letter
;OutLoop:
;  movf   FSR, w                 ;  Get pointer into W
;  incf   FSR, f                 ;  Set up for next letter
;  call  header_0                 ;  Get character to output
;  iorlw  0                      ;  At the End of the Message?
;  btfsc  STATUS, Z              ;  Skip if not at end
;  return                        ;  Yes - Equal to Zero
;  call   SendCHAR               ;  Output the ASCII Character
;  goto   OutLoop                ;  Get the next character

;-------------------------------------------------------------------------;
;                   Common commands for LCD                           ;
;-------------------------------------------------------------------------;


;;-----------------------------------------------------------------------;
;                           Delay routine                               ;
;-----------------------------------------------------------------------;
Delay5:
Dlay5    movlw 5               ; delay for 15 milliseconds
nmsec:                         ; delay for # msec in W on entry
         nop                   ; each nop is 0.122 milliseconds
         nop
         nop                   ; each total loop is 8 X 0.122 = 0.976 msec
         nop
         addlw H'FF'           ; same as subtracting 1 from W
         btfss STATUS, Z       ; skip if result is zero
         goto nmsec            ; this is  2 X 0.122 msec
         return                ; back to calling point


Delay255	movlw	0xff		;delay 255 mS
			goto	nmsec
Delay100	movlw	d'100'		;delay 100mS
			goto	nmsec
Delay50		movlw	d'50'		;delay 50mS
			goto	nmsec
Delay20		movlw	d'20'		;delay 20mS
			goto	nmsec
Delay15		movlw	d'15'		;delay 5.000 ms (4 MHz clock)
			goto	nmsec
Pulse_e		bsf	LCD_PORT, LCD_E
		nop
		bcf	LCD_PORT, LCD_E
		retlw	0x00
