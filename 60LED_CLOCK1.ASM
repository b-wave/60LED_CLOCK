;_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
;
;                       60LED_CLOCK1.ASM
;
;
;--------------------------------------------------------------------------------
;
;   KD6VKF WWVB time data Decoder
;
; (c)2012 Steve Botts 				
; Based on wwvb162.asm by , Mike Berg aka N0QBH	4/11/11	
; Modified: 10/22/12 for WWVB RTC Receiver project
;--------------------------------------------------------------------------------
;PURPOSE:	
;	
;	
; Decodes WWVB time data and sisplays on 7-SEG and 60 LEDs
;   This is for the "PIC Clock 360" Hardware.  
;   http://www.pictronicsonline.com/Clock360WWVB/Description.htm
; 
;       i2c = DS1307 (PFC8583p - IC2)
;       SPI = LED 7-SEG DECODER CHIP (MAX7219 - IC8)
;       SPI = LED OUTPUT PORTS (MCP23S17SP x4 IC$, IC5, IC6 and IC7)
;       INPUT =  WWVB RTC Module CMRR-6P TIME CODE OUT (SV3- TCO) 
;       OUTPUTS(2) =  BUZZER and RELAY Outputs
;       Temp sensor is a DS 
;			 
;              LCD LAYOUT #1:
;_______________________________________
; POS = 0 1 2 3 4 5 6 7 8 9 A B C D E F
; LINE1	H H : m m : s s _ + T Z d _ _ * 
; LINE2 D D / M M / Y Y _ _ S 9 ! _ 0 0
; LINE2 1 2 3 4 5 6 7 8 9 0 S 9 # P C C
;_______________________________________
;
;              LCD LAYOUT #1a:
;_______________________________________
; POS = 0 1 2 3 4 5 6 7 8 9 A B C D E F
; LINE1	H H : m m : s s + Z U T C ! d *
; LINE2 D D / M M / Y Y _ _ S 9 9 _ 0 0
; LINE2 1 2 3 4 5 6 7 8 9 0 S 9 9 P C C
;_______________________________________
;
;
; Revision History:
;
;
;
;_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/


        LIST    P=16F886
	    ERRORLEVEL	-302	;Ignore Message [302] : Register in operand not in bank 0.  Ensure that bank bits are correct.
		ERRORLEVEL	-202	;Ignore Warning [202]: Argument out of range.  Least significant bits used.
		ERRORLEVEL	-305	;Ignore Warning [305]: Using default destination of 1 (file).

;		radix   hex
        include <P16F886.INC>     ;PIC Chip Include File

;Program Configuration Register 1
		__CONFIG    _CONFIG1, _INTOSCIO & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOR_OFF & _IESO_OFF & _FCMEN_OFF & _DEBUG_OFF & _LVP_OFF

;Note, Watch Dog timer can be turned on later in program with SWDTEN bit in WDTCON register

;Program Configuration Register 2
		__CONFIG    _CONFIG2, _BOR21V & _WRT_OFF

;============================== VECTORS ===============================
 
;CODE START VECTOR
		ORG	0			; start of main loop code
		nop
		goto	main
;INTERRUPT VECTOR
		ORG	4			;Interrupt routine code
		goto	int_service


;============================== VARIABLE DEFINITIONS ===============================
 
w_temp      EQU 0x7D  ; variable used for context saving 
status_temp EQU 0x7E  ; variable used for context saving 
pclath_temp EQU 0x7F  ; variable used for context saving 
 
;------------------------------------------------------------						
        cblock  0x20			;(ADD) 
;------------------------------------------------------------

;	Misc
                temp            ;(20h) General Temp storage 
                count           ;(21h) General counter

;	PW Discriminator
                mS				;(22h)
                pw_mS			;(23h)
                sort_temp		;(24h)
                p_count			;(25h)
                buffer			;(26h)

;   WWVB FRAMES             
                frame_0			;(27h)
                frame_1			;(28h)
                frame_2			;(29h)
                frame_3			;(2Ah)
                frame_4			;(2Bh)
                frame_5			;(2Ch)
;  WWVB RESULTS               
                data_byte0		;(2D)results
                data_byte1		;(2E)
                data_byte2		;(2F)
                data_byte3		;(30h)
                data_byte4		;(31)
                data_byte5		;(32)

;  100 per second counter                                                                                              
                hund_per_sec	;(33)

;	Time Zone
                offset_tz		;(34) timezone
                TimeZone		;(35) LCD DISPLAY TZ INDEX 


; SIGNAL QUALITY

;	Signal Strength = 0 -> 99
				signal			;(36)
;   Sync Counter
                s_count			;(37)

 
;	LCD DISPLAY              
				lcd_data		;(38) LCD display data                                
				lcd_count		;(39) 
       
;	DELAY COUNTERS                     
				delay_count		; (3A)delay routines
				bit_count		; (3B)

; 	TIMEKEEPING STRORAGE
				seconds			; (3C)
				old_seconds		; (3D)
				minutes			; (3E)
				old_minutes		; (3F)
				hours			; (40h)
				old_hours		;(41)
				day				;(42)
				month			;(43)
				wwvb_minutes	;(44)		
				wwvb_hours		;(45)
				wwvb_days_hi	;(46)
				wwvb_days_lo	;(47)
				wwvb_year		;(48)

;Hex-decimal conversion HEX
		        hex_hi  		; (49h) H
        		hex_lo			; (4a)  L
;Hex-decimal conversion DEC
       			thousands		; (4b) DEC 1000's
				hundreds		; (4c) DEC 100's
       			tens			; (4d DEC 10's
       			ones			; (4e) 1's

;stores/reads EE timezone offset
				ee_addr			; (4f)
				ee_data			; (50h)

;program FLAGS
				FLAGS			; (51)
				FLAGS2			; (52)

;Interrupt Register storage
				ampm			; (53) int routine
				temp_S			; (54h)	 

;I2C storage Registers
				BitCount		;bit index (55h)
				OutByte			;(56H) Data to be transmitted should be put in this register before Transmit is called
				InByte 			;(57h) Data received is left in this register following the Receive call

;DS1307 Temp Storage
				Day10			;(58h)
				Day1			;(59)
				Hour10			;(5A)
				Hour1			;(5B)
				Min10			;(5C)
				Min1			;(5D)
				Month10			;(5E)
				Month1			;(5F)
				Year10			;(60)
				Year1			;(61)
				DoW				;(62) Day of week

;SPI Temp Storage
				spi_data		;(63)  SPI DATA 
				spi_count		;(64) SPI CLOCK
;LED STORAGE
				SecADD			;(65)
				SecPORT			;(66)
				SecDATA			;(67)
				DATA2B			;(68)
				DATA3A			;(69)
				DATA3B			;(6A)
				LED_bits		;(6B)
				ShiftCNT		;(6C)
				COMAND			;(6D)
				COUNT1			;(6E)
				DATCOM			;(6F)			
        		endc
;
;============================== CONSTANTS ===============================
;
;LCD
LINE_1		equ	0x80		;LCD LINE #1 START address
LINE_2		equ	0xC0		;LCD LINE #2 START address


;DELAY LOOP COUNTERS
US_60		equ	.195		;60 uS
US_125		equ	.130		;125 uS
MS_5		equ	.20			;5 mS
MS_15		equ	.60			;15 mS
MS_60		equ	.240		;60 mS

;TIMING
HUNDTH_SEC	equ	.5000	;(2uS per count)+70(tweak)
ONESEC		equ	.100	;1 second
HALFSEC		equ	.50		;500mS 

;ASCII CHARS
CR			equ	0x0d		;carriage return
LF			equ	0x0a		;linefeed
REQ_CHAR	equ	CR			;

; WWVB DISCRIMINATOR PULSE WIDTHS
PULSE_0		equ	.20		;0
PULSE_1		equ	.50		;1
PULSE_P		equ	.80		;P
LAST_P		equ	.60		;end of p count


;=================== MAX7219CNG ===================== 
;
; 			7 SEG DISPLAY CHIP CONSTANTS  
;  
;==================================================== 
;7219 REGISTER ADDRESSES
						;15 14 13 12 11 10 09 08
DIG0 		equ	0x01	;x  x  x  x  0  0  0  1
DIG1 		equ	0x02	;x  x  x  x  0  0  1  0
DIG2 		equ	0x03	;x  x  x  x  0  0  1  1
DIG3 		equ	0x04	;x  x  x  x  0  1  0  0 
DIG7		equ	0x08	;x  x  x  x  1  0  0  0
DEC_MODE	equ	0x09	;x  x  x  x  1  0  0  1
INTENSITY	equ	0x0A	;x  x  x  x  1  0  1  0
SCAN_LIMT	equ	0x0B	;x  x  x  x  1  0  1  1
SHUTDOWN	equ	0x0C	;x  x  x  x  1  1  0  0  (BIT1 = 0 FOR NORMAL OP)
DISP_TST	equ	0x0F	;x  x  x  x  1  1  1  1

;7219 REGISTER DATA
						;D7 D6 D5 D4 D3 D2 D1 D0
ALL_CODE_B	equ	0x0FF	;1  1  1  1  1  1  1  1	 (ALL BITS ARE SEVEN SEG DECODES)
MIN_INTEN	equ	0x01	;x  x  x  x  0  0  0  1	 (PWM = 3/32 or 2/16)
MAX_INTEN	equ	0x0F	;x  x  x  x  1  1  1  1 (PWM = 31/32 or 15/16)
SCAN3		equ	0x03	;x  x  x  x  0  0  1  1 (SCANS DIGITS 0, 1, 2, 3 ONLY)

;CODE-B TABLE
;
; REGISTER DATA=        7-SEGMENT CHARACTER= 
; ===============        ==================
; 
;  *7 6 5 4 3 2 1 0      DP* A B C D E F G (ON SEGMENTS = 1)
;  -- - - - - - - -      --  - - - - - - -
;0 *x X X X 0 0 0 0      X   1 1 1 1 1 1 0 
;1 *x X X X 0 0 0 1      X   0 1 1 0 0 0 0
;2 *x X X X 0 0 1 0      X   1 1 0 1 1 0 1
;3 *x X X X 0 0 1 1      X   1 1 1 1 0 0 1
;4 *x X X X 0 1 0 0      X   0 1 1 0 0 1 1
;5 *x X X X 0 1 0 1      X   1 0 1 1 0 1 1
;6 *x X X X 0 1 1 0      X   1 0 1 1 1 1 1
;7 *x X X X 0 1 1 1      X   1 1 1 0 0 0 0
;8 *x X X X 1 0 0 0      X   1 1 1 1 1 1 1
;9 *x X X X 1 0 0 1      X   1 1 1 1 0 1 1
;— *x X X X 1 0 1 0      X   0 0 0 0 0 0 1 (dash)
;E *x X X X 1 0 1 1      X   1 0 0 1 1 1 1
;H *x X X X 1 1 0 0      X   0 1 1 0 1 1 1
;L *x X X X 1 1 0 1      X   0 0 0 1 1 1 0
;P *x X X X 1 1 1 0      X   1 1 0 0 1 1 1
;_ *x X X X 1 1 1 1      X   0 0 0 0 0 0 0 (blank)
;
;D7* = DP

;
;===================  MCP23S17SP ===================== 
;
; 			LED 60 SECOND & STATUS LED DISPLAYS  
;  
;==================================================== 
;
;ACCEESS:	BANK=1	BANK=0**
;IODIRA		0X00	0X00
;IODIRB		0X10	0X01
;IOCON1		0X05	0X0A
;IOCON2		0X15	0X0B
;GPIOA		0X09	0X12
;GPIOB		0X19	0X13
;OLATA		0X15	0X14
;OLATB		0X1A	0X15
; ** USED IN 360CLOCK
LED_IC4		equ	0x40	;IC4  (LED3 - LED19)= 1SEC -> 15SEC
LED_IC5		equ	0x42	;IC5  (LED20 - LED35)= 16SEC -> 31SEC
LED_IC6		equ	0x44	;IC6  (LED36 - LED51)= 32SEC -> 47SEC
LED_IC7		equ	0x46	;IC7  (LED52 - LED63) = 48SEC -> 59SEC
LED_66		equ	0x46	;IC7  LED66 = 0SEC GPB6 (01000000)

;============================== MACROS ===============================
;Macros to select the register bank
;Many bank changes can be optimized when only one STATUS bit changes

Bank0		MACRO			;macro to select register bank 0
		bcf	STATUS,RP0
		bcf	STATUS,RP1
		ENDM

Bank1		MACRO			;macro to select register bank 1
		bsf	STATUS,RP0
		bcf	STATUS,RP1
		ENDM

Bank2		MACRO			;macro to select register bank 2
		bcf	STATUS,RP0
		bsf	STATUS,RP1
		ENDM

Bank3		MACRO			;macro to select register bank 3
		bsf	STATUS,RP0
		bsf	STATUS,RP1
		ENDM

 
;============================== HARDWARE ===============================
; 
; Notes: These are all changed on the latest board for the LED Chip.
; (RA0 - RA5 were the old LED CATHODE SEGMENTS Not connected in this version)
; LCD is wired to these unused pins for testing...
;
;==========================PORT A=======================================
; REG - (Pin)  [LABEL]  (pin)            |I/O
;=================================================================
;  RA0 - (2)[LCD_DB4] (11)		|output 
;  RA1 - (3)[LCD_DB5] (12)		|output
;  RA2 - (4)[LCD_DB6] (13)		|output
;  RA3 - (5)[LCD_DB7] (14)		|output
;  RA4 - (6)[LCD_E]   (6)		|output
;  RA5 - (7)[LCD_RS]   (4)		|output
;  RA6 - (10)[CS_] 23S17(9)		|output
;  RA7 - (9)[CLKI] (n.c.)		|output N.C.

#define	LCD_DB4		PORTA,0		;LCD DAT	|0
#define	LCD_DB5		PORTA,1		;LCD DAT	|0
#define	LCD_DB6		PORTA,2		;LCD DAT	|0
#define	LCD_DB7		PORTA,3		;LCD DAT	|0
#define E_LINE      PORTA,4     ;LCD E		|0
#define RS_LINE     PORTA,5     ;LCD RS		|0
#define CS_			PORTA,6		;P23S17SP(9)|0
#define  pin9		PORTA,7		;N.C. CLKI	|0
; PORTA=b'0000 0000'

;==========================PORT B=======================================
;  REG - (Pin)  [LABEL]  SIGNAL        	|I/O
;=================================================================
;  RB0 - (21) [SCL] I2C Clock          	|output          
;  RB1 - (22) [SDA] I2C Data           	|in/out 
;  RB2 - (23) [TEMP]  DS18B20  			|1-Wire?           
;  RB3 - (24) [TCO]  WWVB TIME CODE		|input                
;  RB4 - (25) [SEL_SW] Switch(S5)		|input
;  RB5 - (26) [LAP_SW] Switch(S4)		|input
;  RB6 - (27) [STA_SW] Switch(S3)		|input
;  RB7 - (28) [MOD_SW] Switch(S2)		|input
;PORTB =b'1111 1100' 

#define	I2CSCL	PORTB,0		;I2C Clock		|1 = hi Z
#define	I2CSDA	PORTB,1		;I2C Data		|1 = hi Z
#define DS1820	PORTB,2     ;TEMP INPUT		|1
#define DATA_IN	PORTB,3     ;WWVB CODE		|1
#define SEL_SW	PORTB,4		;Switch(S5)		|1
#define LAP_SW	PORTB,5		;Switch(S4)		|1 
#define STA_SW	PORTB,6		;Switch(S3)		|1
#define MOD_SW	PORTB,7		;Switch(S3)		|1
;
;==========================PORT C=======================================
;  REG - (Pin)  [LABEL]  SIGNAL             |I/O
;=================================================================
;  RC0 - (11) [MCS-] CHIP SELECT (LOAD PIN 12) for MAX7219 |output
;  RC1 - (12) [MSI ] DATA IN (DIN pin 1) for MAX7219       |output 
;  RC2 - (13) [BUZZER]                                     |output
;  RC3 - (14) [N/A] ?VUSB?                                 |N.C.
;  RC4 - (15) [MSCK] CLOCK IN (DIN pin 13) for MAX7219     |output
;  RC5 - (16) [SCK]   SPI Clock MCP23S17SP                 |output 
;  RC6 - (17) [RLY]  Relay control bit                     |output
;  RC7 - (18) [SI] SPI data for MCP23S17SP                 |output
; =b'00000000'

#define MCS		PORTC,0     ;CHIP SELECT for 7219 7-SEG
#define MSI		PORTC,1     ;DATA IN for 7219 7-SEG
#define BUZZER	PORTC,2     ;BUZZER
#define pin14	PORTC,3     ;N.C. VUSB
#define MSCK	PORTC,4		;SPI CLOCK for 7219 7-SEG
#define SCK		PORTC,5		;SPI CLOCK  for MCP23S17
#define RLY		PORTC,6		;RELAY CONTROL
#define SI		PORTC,7		;SPI DATA  for MCP23S17

;=============================OLD HARDWARE PINS:====================================
;

;#define	SCL			PORTA,4		;I2C SCL
;#define	SDA			PORTA,5		;I2C SDA
;#define	CONFIG_SW	PORTA,4		;switch input
;#define	Y_LED	    PORTB,0     ;LED YELLOW (6)
;#define 	RS_LINE     PORTB,3     ;LCD RS

;============================== PROGRAM FLAGS: ===============================

;
#define BIT_FLAG	FLAGS,0		;data bit buffer
#define	P_FLAG		FLAGS,1		;rxd P bit
#define	D_FLAG		FLAGS,2		;good data set
#define	ACT_FLAG	FLAGS,3		;pulse status
#define	NEW_DATA	FLAGS,4		;new data available

#define	SEC_FLAG	FLAGS2,0	;LCD update
#define SRX_FLAG	FLAGS2,1	;input change
#define	LEAP_YR		FLAGS2,2	;leap year indicator
#define	SIGN_FLAG	FLAGS2,3	;timezone +/-
#define G_LED		FLAGS2,5	;GREEN LED State
#define DST_WARN	FLAGS2,6	;1 = DST STARTS IN 24H, 0 = DST ENDS IN 24H
#define DST_NOW		FLAGS2,7	;1 = use DST


;============================== TIME FLAGS ==============================
;#define DST_NOW		offset_tz,7	;1 = use DST
;#define DST_WARN	offset_tz,6	;1 = DST STARTS IN 24H, 0 = DST ENDS IN 24H
#define tz_sign		offset_tz,4	;+/- sign flag

;
;============================== ASCII STRINGS ===============================
;
header_0
	addwf	PCL,F
	dt	" WWVB",0		;5 char long
;---------------------------------------------------------------------------------------
;Daylight saving time (DST) and standard time (ST) 
;information is transmitted at seconds57 and 58
;When ST is in effect, bits 57 and 58 are set to 0. 
;When DST is in effect, bits 57 and 58 are set to 1. 
;On the day of a change from ST to DST bit 57 changes from 0 to 1
;at 0000 UTC, and bit 58 changes from 0 to 1 exactly 24 hours later. 
;

DST_
	addwf	PCL,F
	dt	" DST",0		;4 char long


DST_START
;On the day of a change from ST to DST bit 57 changes from 0 to 1
;at 0000 UTC, and bit 58 changes from 0 to 1 exactly 24 hours later. 
;
	addwf	PCL,F
	dt	" TONITE!",0		;8 char long

DST_END
;On the day of a change from DST back to ST bit 57 changes from 1 to 0 
;at 0000 UTC, and bit 58 changes from 1 to 0 exactly 24 hours later.
;
	addwf	PCL,F
	dt	" ENDING!",0		;8 char long
;
LY
;A leap year indicator is transmitted at second 55. If it is set to 1, the current year is a
;leap year. The bit is set to 1 during each leap year after January 1 but before February 29.
;It is set back to 0 on January 1 of the year following the leap year.
	addwf	PCL,F
	dt	" LY = ",0		;6 char long
;
LS
;A leap second indicator is transmitted at second 56. If this bit is high, it indicates that
;a leap second will be added to UTC at the end of the current month. The bit is set to
;1 near the start of the month in which a leap second is added. It is set to 0 immediately
;after the leap second insertion.

	addwf	PCL,F
	dt	" LS = ",0		;6 char long
;

char_TRUE
	addwf	PCL,F
	dt	"TRUE ",0		;5 char long
;
char_FALSE
	addwf	PCL,F
	dt	"FALSE",0		;5 char long

;TIME ZONES
header_tz
	addwf	PCL,F
	dt	"ZONE= ",0		;6 char long
UTC
	addwf	PCL,F
	dt	" UTC",0		;4 char long
EST
	addwf	PCL,F
	dt	" EST",0		;4 char long
CST
	addwf	PCL,F
	dt	" CST",0		;4 char long
MST
	addwf	PCL,F
	dt	" MST",0		;4 char long
PST
	addwf	PCL,F
	dt	" PST",0		;4 char long

;
;========================== TABLES ===============================
;

monthly
	addwf	PCL,F
	dt	0,.31,.28,.31,.30,.31,.30	;
	dt	.31,.31,.30,.31,.30,.31		;	
;
frame_check
	addwf	PCL,F
	dt	2,2,0,0,0,1,0,0,0,0	; P0
	dt	2,0,0,0,0,1,0,0,0,0	; P1
	dt	2,0,0,0,0,1,0,0,0,0	; P2
	dt	2,0,0,0,0,1,0,0,0,0	; P3
	dt	2,0,0,0,0,1,0,0,0,0	; P4
	dt	2,0,0,0,0,1,0,0,0,0	; P5
							
;
;======================= MAIN CODE ===================================

main
 
;------------------------------------------------------------
; Microcontroller initialization
;------------------------------------------------------------
     banksel        OSCCON 
;------------------------------------------------------------
;NOTE:
; This may not be needed - if using the default clock speed
;
;		movlw b'01110000'	;8MHZ
;		movlw b'01100001'	;4MHZ (default)+ SCS = 61
;		movwf	OSCCON
		bsf     OSCCON,SCS   ;switch on internal clock
		nop
		nop

clock_start
     btfss        OSCCON,HTS    ;HFINTOSC stable? 
     goto        main        ;no, try again 

;------------------------------------------------------------
;Set System Clock speed
;CONFIG1 Set:
;101 = INTOSC oscillator: CLKOUT function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN
;100 = INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN
;The HFINTOSC is enabled by selecting any frequency
;between 8 MHz and 125 kHz by setting the IRCF<2:0>
;bits of the OSCCON register ? 000. 
;Then, set the ;System Clock Source (SCS) bit of the OSCCON register to ‘1’
;The HF Internal Oscillator (HTS) bit of the OSCCON
;register indicates whether the HFINTOSC is stable or not.

;------------------------------------------------------------


;		Bank0				;Config Ports in Bank 0


;------------------------------------------------------------
; I/O Port Set-up
;------------------------------------------------------------

     banksel ANSELH      ; select correct bank 
     clrf    ANSELH      ; all PORTB pins digital, not analogue 

		banksel ANSEL     ; select correct bank 
		clrf	ANSEL	;set PORT A for digital I/O

       banksel   OPTION_REG
		bcf     OPTION_REG,NOT_RBPU

;
;     banksel PORTB       ; select correct bank 
 ;    clrf    PORTB       ; all PORTB outputs low (if set output) 

     banksel PORTC       ; select correct bank 
		clrf	PORTC


  		banksel PORTA       ; select bank 0 as default bank 
 		clrf	PORTA


;	Bank1				;Now config bank 1 regs
;		bsf     STATUS,RP0              ;switch to bank 1

	
;------------------------------------------------------------
; BIT       7   6   5   4   3   2   1   0
; DIR       OUT OUT OUT IN  0UT OUT OUT OUT
; PORTA 	0   0   0   1   0   0   0   0 
;------------------------------------------------------------

        movlw   b'00000000'             ;port A in/outputs
		banksel TRISA       ; select correct bank 
        movwf   TRISA


;------------------------------------------------------------
; BIT       7   6   5   4   3   2   1   0
; DIR       OUT OUT OUT OUT IN  SW SW  SW  
; PORTB		0	0	0	0	1	1	1	1
;------------------------------------------------------------

		movlw   b'11111111'		;port B ALL intputs
		banksel TRISB       	; select correct bank 
        movwf   TRISB

		banksel WPUB			;enable weak pullups on PORTB
		movlw   b'11111111'		;port B 1= enabled 0= disabled
 		movwf	WPUB			;just in case
;------------------------------------------------------------
; BIT       7   6   5   4   3   2   1   0
; DIR       OUT OUT OUT OUT 0UT OUT OUT OUT
; PORTC		0	0	0	0	0	0	0	0		
;------------------------------------------------------------

        movlw   b'00000000'     ;port C in/outputs
		banksel TRISC           ; select correct bank 
        movwf   TRISC

;Make sure to turn off interrupts for the rest of the config
	banksel INTCON                  ; select correct bank
	bcf	INTCON,GIE		;global ints off
	btfsc	INTCON,GIE
	goto	$-2			;wait for it...


;TMR1 INT
;To enable the interrupt on rollover, you must set
;these bits:
; Timer1 interrupt enable bit of the PIE1 register
; PEIE bit of the INTCON register
; GIE bit of the INTCON register
;The interrupt is cleared by clearing the TMR1IF bit in
;the Interrupt Service Routine



;PIR1 Timer perif interrupt
;bit 0 TMR1IF: Timer1 Overflow Interrupt Flag bit
;1 = The TMR1 register overflowed (must be cleared in software)
;0 = The TMR1 register did not overflow

        clrf    PIR1                    ;reset perif interrups



        movlw   b'00000100'             ;post/1, pre/1, on
        movwf   T2CON                   ;timer 2

;TIMER1 CONTROL REGISTER
; T1CON: 
;       bit 7 = T1GINV: 0
;       bit6 = TMR1GE: 0 
;       bit 5-4 T1CKPS<1:0>: Timer1 Input Clock Prescale Select bits
;               11 = 1:8 Prescale Value
;               10 = 1:4 Prescale Value
;               01 = 1:2 Prescale Value *USE*?
;               00 = 1:1 Prescale Value
;       bit 3 = T1OSCEN: 0
;       bit2 T1SYNC:0 (bit is ignored if TMR1CS = 0)
;       bit1 TMR1ON: Timer1 On bit (1 = 0n  0 = off)
;TMR1CS = 0 (fosc/4)
;TMR1ON = 1 T1 Gate should be disabled -> TMR1GE = 0
;TMR1IF = 1 when TMR1H TMR1L overflow
	banksel	T1CON

		movlw	b'00010000'		;T1/2
		movwf	T1CON			;timer 1 setup
;
;INTCON ( FOR TMR1)
;       BIT7 GIE = 1 TO ENABLE GLOBAL INTERRUPTS
;       BIT6 PEIE = 1 PERIF INTERRUPT ENABLE 
;Timer PEIE on	we can do this later (BIT 6 = 1)	
	banksel	INTCON
    movlw   b'01000000'             ;PEIE on
	movwf	INTCON



;silence the buzzer
	Bank0			;Now - back to page 0
	bsf BUZZER		;make sure the buzzer is OFF!

	call	clear_regs	;clear out the c-block F registers

;let the LCD settle form power up a little before init
	call	Delay100
    call    LCD_Init	;set up LCD display
	call	Delay255

;===================== LCD TEST ==============================
	goto	start1	
	movlw	6			;test line 2 + Col in W	
	call	LCD_Line2W
	call	Delay100

	movlw	'H'	;	
	call	LCD_Char

	movlw	'e'	;	
	call	LCD_Char

	movlw	'l'	;	
	call	LCD_Char

	movlw	'p'	;	
	call	LCD_Char


	call	LCD_Line1

	movlw	'S'	;	
	call	LCD_Char

;	call	Delay255

	movlw	'e'	;	
	call	LCD_Char

;	call	Delay255

	movlw	'n'	;	
	call	LCD_Char

;	call	Delay255

	movlw	'd'	;	
	call	LCD_Char


;===================== LCD TEST MESSAGES ==============================
start1			;jump here to skip


;===================TESTING 7 SEGMENT DISPLAY CHIP=====================
	call	INIT_SEGMENTS		;sets up 7219

	movlw	0x0A	;Set the LED INTENSITY
	call	SET_INTENSITY

;	call	I2CInit

;============TEST STUFF 'HELP'=======================================
   		movlw	0x0C 		;H *x X X X 1 1 0 0      X   0 1 1 0 1 1 1
		movwf	Hour10		;TENS 
		movlw	0x0B 		;E *x X X X 1 0 1 1      X   1 0 0 1 1 1 1
		movwf	Hour1		;ONES 
		movlw	0x0D 		;L *x X X X 1 1 0 1      X   0 0 0 1 1 1 0
		movwf	Min10		;TENS
 		movlw	0x0E 		;P *x X X X 1 1 1 0      X   1 1 0 0 1 1 1
		movwf	Min1		;ONES 
;============TEST STUFF 'HELP'=======================================
		movlw	0x59			; set up the minutes registers;
		movwf	Min1
		movlw	0x23			; set up the hours registers
		movwf	Hour1

;		call	GetRTC_TIME		;DS1307 +I2C test
;		movfw	wwvb_minutes	;(44)
;		movwf	Min1
		
;		movfw	wwvb_hours		;(45)
;		movwf	Hour1

		movfw	Min1
		andlw	b'01110000'		; get raw - mask 10's digit
		movwf	Min10			; put it in 10's digit register
		swapf	Min10, F		; swap nibbles

		movlw	b'00001111'		; mask raw for 1's digit
		andwf	Min1

		movfw	Hour1
		andlw	b'00110000'		; get raw - mask 10's digit
		movwf	Hour10			; put it in 10's digit register
		swapf	Hour10, F		; swap nibbles

		movlw	b'00001111'		; mask raw for 1's digit
		andwf	Hour1
		
;		call	GetRTC_TIME
;		call	SEGMENT_TIME	;tests it now as 23:59
;		goto	$-1


 

;The LEDs were wired active low set the bits hi for off..
;	bsf		R_LED			;turn off RED LED
;	bsf		Y_LED			;turn off YELLOW LED	
;	bsf		G_LED			;turn off GREEN LED	
	
;	call	clear_regs

	Bank0

;pre-load counters 
	movlw	.100
	movwf	old_seconds
	movwf	old_minutes
	movwf	old_hours		;insure immediate update
	movlw	ONESEC
	movwf	hund_per_sec		;preload .01 sec counter
	clrf	signal			;reset signal counter to S0

;some tests we can put here for now...and delete later
;	call	do_rx_indicate		;TEST Show RSSI (0-99)
;	call	GetRTC_TIME		;TEST update the display
;	call	SEGMENT_TIME	;TEST 7-SEGMENT displays

;turn on interrupts

; PEIE bit of the INTCON register
; GIE bit of the INTCON register

	banksel	INTCON
	bsf		INTCON,GIE	;General ints on
	bsf		INTCON,PEIE 	;ints on

	banksel	PIE1
	bsf		PIE1,TMR1IE	;timer1 int on

;turn on timer1
	banksel T1CON
	bsf		T1CON,TMR1ON		;timer1 on


;=====================CLEAR LEDS ===================================

	call	MCP23S17Init	;initialize the LED PORTS
	call	CLEAR_LEDS		;make sure all second LEDs are off
	bsf		G_LED			;Set to turn off GREEN LED
	

;	goto 	load_tz_default 	; Skip switch test for now
;
;======================= TIME ZONE SET ================================
;

; Set up to configure TZ or run normally?
;	btfss	CONFIG_SW		;test power up button pushed
;if switch is closed do configure
;	goto 	load_tz_default 	; Skip switch test for now

;	goto	tz_config		;do configure
;
;========================== CONFIGURE TZ WITH THE NV ================================
;
;else get the stored TZ values from EE ROM...
;
;	clrf	ee_addr			;get stored value
;	call	ee_read			;	
;	movfw	ee_data			;
;	andlw	b'00001111'		;lower nibble
;	sublw	.12				;
;	bnc		load_tz_default	;Default will be UTC (Z)

;	movfw	ee_data			;
;	andlw	b'00011111'		;
;	movwf	offset_tz		;load value
;
;============================= DONE TZ FROM NV ======================================
;
;	goto	wait_new_pulse	; All done! Go to main loop and let the ISR do the rest

;
;====================== CONFIGURE TZ WITH THE DEFAULT ===============================
;
;Unless we skipped it...  then we use UTC for DEFAULT w/ no offsets

load_tz_default 
	Bank0
	clrf	offset_tz		; default = UTC -0

	movlw	8
	movwf	TimeZone
	movwf	offset_tz
	bcf		DST_NOW			;Use (ST)
	bcf		DST_WARN		;Clear DST change bit

	goto	wait_new_pulse	; Finally...DONE. go to main loop.

;
;======================= TZ CONFIG CODE ===================================
;
; This ia all going to change... WWVB is not even avalible outside US
; Unless UTC is used no reason for 23 other timesones!!!
; Loop will be UTC -> EST -> CST -> MST -> PST
; two other parameter will be also configured:
; 1.  Use DST? = TRUE/FALSE
; So if selected and DST is in effect 
; then, the displayed "S" will be repaced by "D" 
; UTC does not use DST so it defaults to FALSE.
; 2. Day of Week (DOW)setting SUN, MON, TUE, WED, THU, FRI, SAT
;--------------------------------------------------------------------------

;tz_config
;	clrf	lcd_count		;clear pointer
;	movlw	LINE_1			;1st position
;	call	LCD_CONT			;
;tz_loop0
;	movfw	lcd_count
;	call	header_tz		;display "Offset"
;	movwf	lcd_data
;	movfw	lcd_data		;test for zero
;	bz		tz_loop2		;leave if 0 is returned
;	call	LCD_DAT
;	incf	lcd_count,F
;	goto	tz_loop0
;tz_loop2
;	movlw	LINE_1 +8		;2nd 1/2
;	call	LCD_CONT			;display
;	clrf	lcd_count		;will be counter
;	bcf	SEC_FLAG		
;get_syncd
;	btfss	SEC_FLAG
;	goto	get_syncd		;wait for edge
;	bcf	SEC_FLAG
;
;tz_loop1
;	movlw	LINE_1 +8		;2nd 1/2
;	call	LCD_CONT			;display
;	movlw	"+"
;	btfss	lcd_count,4		;
;	movlw	"-"
;	movwf	lcd_data
;	call	LCD_DAT			;send sign
;	movfw	lcd_count
;	andlw	b'00001111'		;mask hi nibble		
;	movwf	hex_lo	
;	clrf	hex_hi
;	call	hd_convert		;display current
;
;	movlw	" "
;	movwf	lcd_data
;	movfw	tens
;	xorlw	"0"			;
;	bz	loop1_ones		;if 0, skip next
;	movfw	tens
;	movwf	lcd_data
;loop1_ones
;	call	LCD_DAT			;10's
;	movfw	ones	
;	movwf	lcd_data
;	call	LCD_DAT			;1's
;input_scan
;	btfsc	CONFIG_SW			;toggle still low?
;	goto	store_current_value	;no
;	btfss	SEC_FLAG		;yes, sec flag hi yet?
;	goto	input_scan		;no
;	bcf		SEC_FLAG		;yes, clear
;
;	incf	lcd_count,W
;	andlw	b'00001111'		;
;	xorlw	.13
;	bz		swap_sign
;	incf	lcd_count,F
;	goto	tz_loop1		;display new value
;
;swap_sign
;	movlw	.16
;	addwf	lcd_count,F		;inc hi nibble
;	movlw	b'00010000'		;mask all but bit 4
;	andwf	lcd_count,F
;	goto	tz_loop1		;display new value
;
;store_current_value
;	movfw	lcd_count
;	movwf	offset_tz		;store in working reg
;	clrf	ee_addr
;	movfw	offset_tz
;	movwf	ee_data
;	call	ee_write		;store value & sign
;
;	call	clear_LCD_display
;
;	End of configure routine			

;
;======================= MAIN LOOP ROUTINE =============================
;

wait_new_pulse

	Bank0
 
;
	call	do_rx_indicate		; Show RSSI (0-99)


;	bcf		DST_NOW
;	btfsc   SEL_SW 		; PORT B DATA_IN SEL_SW 
;	bsf		DST_NOW			


; testo						;lets stop here...
;	   	banksel PORTB       ; select correct bank ;
;		movlw  0x00			;CLEAR PM
;	    btfss   SEL_SW 		; PORT B DATA_IN SEL_SW 
;		movlw 	0x80		;set output bit if data is ONE
;		Bank0
;		movwf	ampm
;		call	PM_LED
;		goto	testo

;let's test LED
; 		bsf		G_LED		;LED off - normal
;	    btfss   SEL_SW 		; PORT B DATA_IN SEL_SW 
;		bcf		G_LED		;LED on if pressed




	btfsc	NEW_DATA			;flag set?
	goto	P0					;Yes - check pulse width

	btfsc	SEC_FLAG			;One Second?
	call	update_time_display	;YES! update the display every second
;	call	SEGMENT_TIME	;


	goto	wait_new_pulse		;loop --->> ISR does the rest
;_____________________________________________________________
;
;	WWVB Pulse Width Discriminator
;_____________________________________________________________

; Is it a "0" ?
P0	
	bcf		P_FLAG			;clear P_FLAG
	movlw	PULSE_0 -3		;+/- Jitter
	subwf	pw_mS,W			;pw_mS - 0 min
	bnc		bad_pulse		;pw_mS < 0 min
	movlw	PULSE_0 +3
	movwf	sort_temp
	movfw	pw_mS
	subwf	sort_temp,W		;0 max - pw_mS	
	bnc		P1				;pulse wider than 0 max
	bcf		BIT_FLAG		;bit 0, flag clear
	movlw	LINE_1 +.15
	movwf	lcd_data
	call	LCD_CONT	
	movlw	"0"
	movwf	lcd_data
	call	LCD_DAT			;send '0'
;	bsf		R_LED			;turn off RED LED
	goto	framer
; Is it "1" ?
P1
	movlw	PULSE_1 -4
	subwf	pw_mS,W			;pw_mS - 1 min
	bnc		bad_pulse		;pw_mS < 1 min
	movlw	PULSE_1 +4
	movwf	sort_temp
	movfw	pw_mS
	subwf	sort_temp,W		;1 max - pw_mS	
	bnc		P2				;pulse wider than 1 max
	bsf		BIT_FLAG		;bit 1, flag set
	movlw	LINE_1 +.15
	movwf	lcd_data
	call	LCD_CONT	
	movlw	"1"
	movwf	lcd_data
	call	LCD_DAT			;send '1'
; Show PWD result on LCD
;	bsf		R_LED			;turn off RED LED
	goto	framer			; Check for Valid Frame position

; Is it a "P" ?		
P2
	movlw	PULSE_P -6
	subwf	pw_mS,W			;pw_mS - P min

;Nope - it is to narrow
	bnc		bad_pulse		;pw_mS < P min
	movlw	PULSE_P +6
	movwf	sort_temp
	movfw	pw_mS
	subwf	sort_temp,W		;P max - pw_mS	
;Nope - it is too wide...
	bnc		bad_pulse		;pulse wider than P max

;Yes it is a "P" position inficator....
	bsf		P_FLAG			;good P pulse, set P_FLAG
	movlw	LINE_1 +.15
	movwf	lcd_data
	call	LCD_CONT	
	movlw	"P"
	movwf	lcd_data
	call	LCD_DAT			;send 'P'
;	bsf		R_LED			;turn off RED LED

; Found a P prepare to show bits on LCD
	movlw	LINE_2 			; clear the frame space
	movwf	lcd_data
	call	LCD_CONT	
	movlw	.10				;clear 10
	movwf	lcd_count		;countdown from W 
	call	line_clear_loop	

;ALIGN THE FRAME AND ESTIMATES SIGNAL QUALITY	
framer

;FIRST, CALCULATE SIGNAL SINCE WE KNOW IT IS GOOD NOW INCREASES IT 
;THE SIGNAL'S STRENGTH ESTIMATE UNTIL WE GET TO S9 (BEST INDICATION)

	movfw	signal			;Get the latest count
	xorlw	.99				;S9+
	bz		no_sig_inc		;thats as good as it gets
	incf	signal,F		;not yet add to the signal

no_sig_inc
	bcf		NEW_DATA		;clear flag

;WHILE FRAMING THE DATE DISPLAY IS REPLACED SO WE CAN WATCH THE BITS
;This will show 1s and 0s for each P frame instad of the DD/MM/YY
;	bcf		Y_LED			;turn on yellow LED	
	call	Y_LED_ON		;turn on yellow LED	
	movlw	LINE_2 +.13		;+1
	movwf	lcd_data
	call	LCD_CONT

;WE CAN SHOW "#" TO INDICATE FRAME IS GOOD ON LCD 
;...JUST IN CASE WE DONT HAVE LEDS ON THE OUTPUT PINS	

;	movlw	"#"				;Framing is good
;	movwf	lcd_data
;	call	LCD_DAT			;send '#'

;GOT A GOOD POSITION LENGTH AS WELL - SO SHOW IT
	movlw	"P"
	movwf	lcd_data
	call	LCD_DAT			;send 'P'

;WE WILL ALSO SHOW WHICH BIT POSITION IS BEING DECODED
;WITH THE THE P COUNTER
	movfw	p_count	
	movwf	hex_lo
	clrf	hex_hi
	call 	hd_convert		;hex  to ascii

; Show frame posiiton counter P00 -> P59
	movfw	tens			;Show Position #
	movwf 	lcd_data
	call	LCD_DAT
	movfw	ones			;Show Bit #
	movwf	lcd_data
	call	LCD_DAT			;

;This shows the counter if any valid bit is there
	movfw	p_count			;test contents of buffer
	bz		no_disp			; SKIP it  if  = 0

;<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;SHOW THE BIT FOUND LAST FROM THE DISCRIMINATOR ON THE LCD
;
;	This puts 0 or 1  starting @ line 2 + Count
;<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	movfw	ones			; ASCII count
 	addlw	0x90			; = 0xc0 (line2) - 0x30 ("0")
	movwf	lcd_data
	call	LCD_CONT	
	movlw	"0"				;
	btfsc	BIT_FLAG			;flag low?
	movlw	"1"				;no
	movwf	lcd_data
	call	LCD_DAT			;send '0' or '1'
;<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;
;ERROR DISPLAY AND CHECK
;
no_disp
	movfw	p_count			;pointer to W
	call	frame_check		;lookup next
	movwf	buffer			;store W in buffer
	movfw	buffer			;test contents of buffer
	bz		make_byte		;W = 0
	movlw	1
	xorwf	buffer,W		;
	bz		skip_bit		;W = 1			`
	movlw	2	
	xorwf	buffer,W		;
	bnz		bad_frame		;W > 2

	btfss	P_FLAG			;expect PFLAG set
	goto	bad_frame		;seen P flag, reset
	incf	p_count,F		;inc pointer
	clrf	buffer			;reset bit storage
	goto	wait_new_pulse
	
; Assemble a Byte from the Received Valid framed bits
make_byte
	btfsc	P_FLAG			;test for P pulse
;	goto	bad_pulse		;seen P flag, reset
	goto	bad_frame		;seen P flag, reset

	call	bits2bytes		;roll result into array				
	incf	p_count,F		;inc p counter
	clrf	buffer			;reset bit storage
;	
	movlw	LAST_P			;test for p count end
	xorwf	p_count,W
	skpz
	goto	wait_new_pulse	;Next Bit!

;	Good Data! we have a valid WWVB Frame

	movfw	data_byte0		;xfer data -> Frame array
	movwf	frame_0			;
	movfw	data_byte1		;
	movwf	frame_1			;
	movfw	data_byte2		;
	movwf	frame_2			;
	movfw	data_byte3		;
	movwf	frame_3			;
	movfw	data_byte4		;
	movwf	frame_4			;
	movfw	data_byte5		;
	movwf	frame_5			;
	clrf	p_count			;reset p counter for next frames
;
; Show we are happy with the Sync 
;
	movlw	LINE_1 +.15
	movwf	lcd_data
	call	LCD_CONT	
	movlw	"S"
	movwf	lcd_data
	call	LCD_DAT			;send 'S'
	incf	s_count,F	
;Finally...
	bsf		D_FLAG			;We have a good data set
	goto	convert_BCD		; Use it now to set the clock!
						
;Here is where we end up with all the bad data
;Skip it we can't use it so Frame is not good

skip_bit	
	btfsc	P_FLAG			;test for P pulse
;	goto	bad_pulse		;seen P flag, reset
	goto	bad_frame		;seen P flag, reset

	incf	p_count,F		;inc p counter
	clrf	buffer			;reset bit storage

	goto	wait_new_pulse	
;	
bad_pulse				;out of spec pulse
;	bcf		R_LED			;turn on RED LED
	movlw	LINE_1 +.15
	movwf	lcd_data
	call	LCD_CONT	
	movlw	" "					;Blank! 
	movwf	lcd_data
	call	LCD_DAT				;'error'

;No need to show frame bits since it is broken now
	call	update_MDY_display 	;OK then just show old stuff

bad_frame
;	bsf		Y_LED			;turn off yellow LED	
	call	Y_LED_OFF			;turn off yellow LED	
	bcf		NEW_DATA		;clear flag
	clrf	p_count			;reset p counter
	bcf		D_FLAG			;clear flag	
;<><>probabily don't need this "P"osition display???
	movlw	LINE_2 +.13		;show we are not happy  - either way
	movwf	lcd_data
	call	LCD_CONT

;SHOW ERROR ON LCD IF NO LEDS ARE ON THE I/O PINS	
;	movlw	"!"				;these have been replaced with LEDa
;	movwf	lcd_data
;	call	LCD_DAT			;send '!'
	movlw	" "				;clear 'P'
	movwf	lcd_data
	call	LCD_DAT	
	call	Sync_hour	
		
	call	update_MDY_display ; TEST OK then just show old stuff
	movf	signal,F			;zero test
	bz		end_sig_ck			;if SIGNAL = 0 skip next
	decf	signal,F			;not yet decrement the signal

end_sig_ck

	goto	wait_new_pulse		;start over		
;
;---------------------- WWVB WORD FRAME --------------------------------
;	Hex data is converted to usable ASCII
; 
convert_BCD
	clrf	wwvb_minutes
	clrf	wwvb_hours
	clrf	wwvb_days_hi
	clrf	wwvb_days_lo
	clrf	wwvb_year
;=============== WWVB MINUTES BITS ARE IN FRAME 0 =============
;S (P0) BITS 0 - 6 = 0M TO 59M	
	movlw	.1		
	btfsc	frame_0,0			;calc wwvb minutes BIT 0
	addwf	wwvb_minutes,F		
	movlw	.2
	btfsc	frame_0,1			;calc wwvb minutes BIT 1
	addwf	wwvb_minutes,F
	movlw	.4
	btfsc	frame_0,2			;calc wwvb minutes BIT 2
	addwf	wwvb_minutes,F	
	movlw	.8
	btfsc	frame_0,3			;calc wwvb minutes BIT 3
	addwf	wwvb_minutes,F
	movlw	.10
	btfsc	frame_0,4			;calc wwvb minutes BIT 4
	addwf	wwvb_minutes,F		
	movlw	.20
	btfsc	frame_0,5			;calc wwvb minutes BIT 5
	addwf	wwvb_minutes,F
	movlw	.40
	btfsc	frame_0,6			;calc wwvb minutes BIT 6
	addwf	wwvb_minutes,F	

;=============== WWVB HOURS BITS ARE IN FRAME 1 =============
;(P1)	BITS 0 TO 5 = 0H - 23H
	movlw	.1
	btfsc	frame_1,0		;calc wwvb hours BIT 0
	addwf	wwvb_hours,F
	movlw	.2
	btfsc	frame_1,1		;calc wwvb hours BIT 1
	addwf	wwvb_hours,F	
	movlw	.4
	btfsc	frame_1,2		;calc wwvb hours BIT 2
	addwf	wwvb_hours,F	
	movlw	.8
	btfsc	frame_1,3		;calc wwvb hours BIT 3
	addwf	wwvb_hours,F	
	movlw	.10
	btfsc	frame_1,4		;calc wwvb hours BIT 4
	addwf	wwvb_hours,F	
	movlw	.20
	btfsc	frame_1,5		;calc wwvb hours BIT 5
	addwf	wwvb_hours,F
	
;=============== WWVB DAYS BITS ARE IN FRAME 3 AND 2 =============	
;(P3) BITS 4 - 7 = 1S DIGIT (P2) BITS 0 - 3 = 10S DIGIT (P2) BIT 4 = 100 BIT 5 = 200
; = 1 - 366 
; 
	movlw	.1
	btfsc	frame_3,4
	addwf	wwvb_days_lo,F		;calc wwvb days
	movlw	.2
	btfsc	frame_3,5
	addwf	wwvb_days_lo,F
	movlw	.4
	btfsc	frame_3,6
	addwf	wwvb_days_lo,F
	movlw	.8
	btfsc	frame_3,7
	addwf	wwvb_days_lo,F			
;
	movlw	.10
	btfsc	frame_2,0
	addwf	wwvb_days_lo,F
	movlw	.20
	btfsc	frame_2,1
	addwf	wwvb_days_lo,F
	movlw	.40
	btfsc	frame_2,2
	addwf	wwvb_days_lo,F
	movlw	.80
	btfsc	frame_2,3
	addwf	wwvb_days_lo,F
;			
	movlw	.100
	btfss	frame_2,4
	goto	wwvb_200		;
	addwf	wwvb_days_lo,F
	skpnc
	incf	wwvb_days_hi,F		;inc on overflow of low byte
wwvb_200		
	movlw	.200
	btfsc	frame_2,5
	addwf	wwvb_days_lo,F
	skpnc
	incf	wwvb_days_hi,F		;inc on overflow of low byte
;
;=============== WWVB YEARS BITS ARE IN FRAME 5 AND 4 =============	
;
	movlw	.1
	btfsc	frame_5,4
	addwf	wwvb_year,F		;calc wwvb year
	movlw	.2
	btfsc	frame_5,5
	addwf	wwvb_year,F
	movlw	.4
	btfsc	frame_5,6
	addwf	wwvb_year,F
	movlw	.8
	btfsc	frame_5,7
	addwf	wwvb_year,F			
;
	movlw	.10
	btfsc	frame_4,0
	addwf	wwvb_year,F
	movlw	.20
	btfsc	frame_4,1
	addwf	wwvb_year,F
	movlw	.40
	btfsc	frame_4,2
	addwf	wwvb_year,F
	movlw	.80
	btfsc	frame_4,3
	addwf	wwvb_year,F	
;
month_calc
;IS IT A LEAP YEAR?
;A leap year indicator is transmitted at second 55. If it is set to 1, the current year is a
;leap year. The bit is set to 1 during each leap year after January 1 but before February 29.
;It is set back to 0 on January 1 of the year following the leap year.


	bsf	LEAP_YR
	btfss	frame_5,3		;1=leap year(4-11-11)
	bcf	LEAP_YR			;leap year test
;
	movfw	wwvb_minutes
	movwf	minutes
	movfw	wwvb_hours
	movwf	hours
;
;	DST BITS
;
	bsf		DST_NOW			;Use (DST)
	btfss	frame_5,0		;1=DST 0=ST
	bcf		DST_NOW			;use (ST)


;Daylight saving time (DST) and standard time (ST) 
;information is transmitted at seconds57 and 58
;When ST is in effect, bits 57 and 58 are set to 0. 
;When DST is in effect, bits 57 and 58 are set to 1. 
;On the day of a change from ST to DST bit 57 changes from 0 to 1
;at 0000 UTC, and bit 58 changes from 0 to 1 exactly 24 hours later. 
;
	bsf		DST_WARN		;DST CHANGE WARNING
	btfss	frame_5,1		;1=DST STARTS IN 24H 0=DST ENDS in 24H
	bcf		DST_WARN		;NOT SET CLEAR THE FLAG
	btfsc	frame_5,0		;SET + DST=1 then clear the warning flag (11)
	bcf		DST_WARN

;
;	adding/subtracting timezone
;

	movf	offset_tz,F		;zero test
	bz		zulu_solong		;if TZ = 0 skip next
	btfss	offset_tz,4		;test sign
	goto	zulu_minus
zulu_plus
	movfw	offset_tz

	andlw	b'00001111'
	addwf	hours,F			;check for >23
	movfw	hours
	sublw	.24			;24 - W
	bz		at_zulu
	goto	tz_work_done		;done, start over
;
	movlw	.24
	subwf	hours,F			;hours - 24
	goto	tz_work_done		;start over
;
at_zulu
	clrf	hours			;reset to zero
	goto	tz_work_done		;start over
;
zulu_minus
	movfw	offset_tz
	andlw	b'00001111'
	subwf	hours,W	
	bz		at_zulu			;zero, offset = hours

	bnc		sub_w_hours		;offset > hours
	movfw	offset_tz
	andlw	b'00001111'
	subwf	hours,F			;hours - offset
	goto	tz_work_done
sub_w_hours:
	movfw	hours
	subwf	offset_tz,W		;offset - hours = delta

	sublw	.24
	movwf	hours			;24 - delta
;
;
tz_work_done:
	btfsc	offset_tz,4		;test sign
	goto	zulu_add
zulu_away:
	movfw	wwvb_hours
	subwf	hours,W
	bnc		zulu_solong		;wwvbhours > hours
	movf	wwvb_days_lo,F		;check for 0
	bnz		zulu_away1		;not 0
	movf	wwvb_days_hi,F		;0, check hi byte
	bz		zulu_solong		;hi byte 0, exit no dec
	decf	wwvb_days_hi,F		;hi byte -1
zulu_away1:
	decf	wwvb_days_lo,F		;subtract a day
	goto	zulu_solong
zulu_add:
	movfw	wwvb_hours
	subwf	hours,W
	bc		zulu_solong		;
	movlw	.1
	addwf	wwvb_days_lo,F		;add a day
	skpnc
	incf	wwvb_days_hi,F
	
zulu_solong:
;
	movfw	wwvb_days_hi
	movwf	hex_hi
	movfw	wwvb_days_lo
	movwf	hex_lo	
	clrf	count

month_calc_loop:
	movfw	count
	call	monthly			;lookup table to W
	movwf	buffer			;buffer W
	movlw	.2
	xorwf	count,W			;test for Feb
	bnz	L0			;not Feb (2)
	btfsc	LEAP_YR			;test leap year flag (1=LY)
	incf	buffer,F		;add one day
L0
	movfw	buffer			;buffer to W	
	subwf	hex_lo,F
	bz	M2			;
	bc	M0			;lookup <  days_lo
	movfw	hex_hi			;hex_hi = 0?
	bz	M1			;yes	
	decf	hex_hi,F		;lookup = > days_lo	
M0
	incf	count,F			;no
	goto	month_calc_loop		;lookup days < days_hi,lo
M1
	movfw	count			;
	movwf	month			;count = month
	movfw	buffer
	addwf 	hex_lo,W		;remainder = day	
	movwf	day
	goto	update_time
M2
	movfw	hex_hi			;hex_hi = 0?
	bz	M3			;yes	
	goto	M0
M3
	movfw	count			;
	movwf	month			;count = month
	movfw	buffer
	movwf	day
;	
;	
update_time
	movlw	.59				;frame data is valid at HH:MM:00
	movwf	seconds			;set up to rollover to :00 next at update
	clrf	old_seconds		;zero out the old counter as well 	

	goto	wait_new_pulse	;Go back and wait for next interrupt.
;
;
;======================= INTERRUPT SERVICE ROUTINE ===========================
;

int_service

     movwf   w_temp            ; save off current W register contents 
     movf    STATUS,w          ; move status register into W register 
     movwf   status_temp       ; save off contents of STATUS register 
     movf    PCLATH,w   ; move pclath register into w register 
     movwf   pclath_temp   ; save off contents of PCLATH register 

     Bank0

;


;	btfss	PIR1,TMR1IF		;
;	goto	serial_receive_handler	;serial interrupt	
;
	bcf		PIR1,TMR1IF		;clear flag
	movlw	high HUNDTH_SEC
	subwf	TMR1H,F			;1/100th sec timeout
	movlw	low HUNDTH_SEC
	subwf	TMR1L,F
	skpc
	decf	TMR1H,F			;carry
	incf	mS,F			;inc pulse timer
;
	btfss	ACT_FLAG		;get pulse status
	goto	D1			;pulse is inactive
	btfss	DATA_IN			;pulse active, check
	goto	D2			;still low & counting
	movfw	mS			;pulse ended
	movwf	pw_mS			;buffer result	
	bcf		ACT_FLAG		;PW captured, clear PULSE
	bsf		NEW_DATA		;set new data flag
	goto	D2			;
D1
	btfsc	DATA_IN			;data still hi?
	goto	D2			;yes, exit
	clrf	mS			;no, zero timer
	bsf		ACT_FLAG		;set status flag
D2					
 	decfsz	hund_per_sec,F		;1 second timeout
	goto 	end_interrupt
;
	movlw	ONESEC
	movwf	hund_per_sec		;reload 1 second timeout
	incf	seconds,W
	bsf		SEC_FLAG		;signal LCD update	
	xorlw	.60
	bz		another_minute
	incf	seconds,F		;inc seconds
	goto 	end_interrupt

another_minute	
	clrf	seconds			;>59 seconds
	incf	minutes,W
	xorlw	.60
	bz	another_hour
	incf	minutes,F		;inc minutes
	goto 	end_interrupt
another_hour	
	clrf	minutes

;******************ZERO SYNC COUNT**************************
	clrf	s_count		;reset sync count for the hour

;*******************SET CHIME FLAG***************************
;!!!!!!!!!!!!!!!!!!!!!!!!NOW!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;*******************SET CHIME FLAG***************************

	incf	hours,W
	xorlw	.24
	bz		another_day
	incf	hours,F			;inc hours	
	goto 	end_interrupt
another_day	
	clrf	hours
	btfsc	D_FLAG			;test valid data
	goto 	end_interrupt		;valid, skip next
	movlw	.1
	addwf	wwvb_days_lo,F
	skpnc
	incf	wwvb_days_hi,F		;inc day
;	call	month_calculation
	goto 	end_interrupt	
;
;serial_receive_handler
;	btfss	PIR1,RCIF
;	goto	end_interrupt
;        movlw   b'00000110'
;        andwf   RCSTA,W                 ;check error flags
;        bnz     serial_error
;        movfw   RCREG
;        movwf   rx_serial               ;xfer data byte to rx_serial;
;	bsf	SRX_FLAG		;
;	xorlw	REQ_CHAR		;SRX_FLAG set if REQ_CHAR seen
;	skpz
;	bcf	SRX_FLAG		;
;        goto    end_interrupt
;serial_error
;        btfss   RCSTA,FERR
;        goto    check_orrun
;        movfw   RCREG                   ;read byte, don't store
;check_orrun
;        btfss   RCSTA,OERR
;        goto    end_interrupt
;        bcf     RCSTA,CREN
;        nop
;        bsf     RCSTA,CREN              ;cycle CREN bit to reset	
end_interrupt


        movf    pclath_temp,w   ; retrieve copy of PCLATH register 
        movwf   PCLATH    		; restore pre-isr PCLATH register contents 
        movf    status_temp,w     ; retrieve copy of STATUS register 
        movwf   STATUS            ; restore pre-isr STATUS register contents 
        swapf   w_temp,f 
        swapf   w_temp,w          ; restore pre-isr W register contents 
        retfie                    ; return from interrupt 
 
  
;======================= SUBROUTINE CODE ===========================
;
clear_regs
	Bank0
	movlw	0x20
	movwf 	FSR
clear_loop
	clrf	INDF
	incf	FSR,W
	xorlw	0x7f
	bz	all_clear
	incf	FSR,F
	goto	clear_loop
all_clear	
	return
;	
;------------------------------------------------------------
;
bits2bytes
	setc
	btfss	BIT_FLAG
	clrc
	rlf	data_byte5,F		;rotate bits in
	rlf	data_byte4,F		;to data registers
	rlf	data_byte3,F		;
	rlf	data_byte2,F		;
	rlf	data_byte1,F		;
	rlf	data_byte0,F		;
	return													
;			
;------------------------------------------------------------
;               hex to decimal convert hex registers (hi-lo)
;------------------------------------------------------------
;
hd_convert
        movlw   0x30                    	;all zero ascii
        movwf   ones
        movwf   tens
        movwf   hundreds
        movwf   thousands
thou_hd
        movlw   0x03
        subwf   hex_hi,W
        bnc     hund_hd
        movlw   0x03
        subwf   hex_hi,F
        movlw   0xe8
        subwf   hex_lo,W
        bnc     thou_check
do_lo1
        movlw   0xe8
        subwf   hex_lo,F
        incf    thousands,F             	;1000's + 1
        goto    thou_hd
thou_check
        movfw   hex_hi
        skpnz
        goto    add_back_1k
        decf    hex_hi,F
        goto    do_lo1
add_back_1k
        movlw   0x03
        addwf   hex_hi,F
hund_hd
        movlw   0x64
        subwf   hex_lo,W
        bnc     hund_check
do_lo2
        movlw   0x64
        subwf   hex_lo,F
        incf    hundreds,F              	;100's + 1
        goto    hund_hd
hund_check
        movfw   hex_hi
        skpnz
        goto    tens_hd
        decf    hex_hi,F
        goto    do_lo2
tens_hd
        movlw   0x0a
        subwf   hex_lo,F
        bnc     add_back_10
        incf    tens,F                  	;10's + 1
        goto    tens_hd
add_back_10
        movlw   0x0a
        addwf   hex_lo,F
        movfw   hex_lo
        addwf   ones,F                  	;remainder = 1's
        return
;
;------------------------------------------------------------
;	EEMEM read write
;------------------------------------------------------------
;
ee_write
	movlw	EEADR
	movwf	FSR
	movfw	ee_addr
	movwf	INDF
	movlw	EEDATA
	movwf	FSR
	movfw	ee_data
	movwf	INDF
;
	bsf	STATUS,RP0
	bsf	EECON1,WREN
off_int
	bcf	INTCON,GIE		;ints off
	btfsc	INTCON,GIE		;insure int are off
	goto	off_int				
	movlw	0x55
	movwf	EECON2
	movlw	0xaa
	movwf	EECON2
	bsf	EECON1,WR
ee_wr_wait
	btfsc	EECON1,WR
	goto	ee_wr_wait
	bcf	EECON1,WREN
	bsf	INTCON,GIE		;ints on
	bcf	STATUS,RP0
	return
ee_read
	movlw	EEADR
	movwf	FSR
	movfw	ee_addr
	movwf	INDF
	bsf	STATUS,RP0
	bsf	EECON1,RD
	bcf	STATUS,RP0
	movlw	EEDATA
	movwf	FSR
	movfw	INDF
	movwf	ee_data	
	return
;        

;==============================================================================
;
; Writes HH:MM:SS to LCD Display
;
;==============================================================================

update_time_display

	bcf	SEC_FLAG			;clear flag
	movfw	hours
	xorwf	old_hours,W		;hours change?
	bz	check_minutes	;no, check minutes
	movlw	LINE_1 +.0		;yes
	call	LCD_Cmd		;write to 0 position
	movfw	hours
	movwf	old_hours		;update old hours
	movwf	hex_lo
	clrf	hex_hi
	call	hd_convert		;hours to LCD
	movfw	tens
	movwf	Hour10			;hours to LED
	movwf	lcd_data
	call	LCD_DAT	
	movfw	ones
	movwf	Hour1			;hours to LED
	movwf	lcd_data
	call	LCD_DAT	
	movlw	":"
	movwf	lcd_data
	call	LCD_DAT			;insert semicolon
;	

check_minutes	
	movfw	minutes
	xorwf	old_minutes,W		;minutes change?
	bz		check_seconds		;no, check seconds
	movlw	.3			;yes
    call	LCD_Line1W		;write to 3 position
	movfw	minutes
	movwf	old_minutes		;update old minutes	
	movwf	hex_lo
	clrf	hex_hi
	call	hd_convert
	movfw	tens			;minutes to LCD
 	movwf	Min10			;minutes to LED
	movwf	lcd_data
	call	LCD_DAT	
	movfw	ones
 	movwf	Min1			;minutes to LED
	movwf	lcd_data
	call	LCD_DAT
	movlw	":"
	movwf	lcd_data
	call	LCD_DAT			;insert semicolon
;--------------------------------------------------
;clear out old "frame data" 
;--------------------------------------------------
	movlw	.10
	movwf	lcd_data
        call	LCD_Line1W		;to R side
	call	insert_space
	call	insert_space
	call	insert_space		;clear old

;--------------------------------------------------
;	Insert time zone offset +/-12
;---------------------------------------------------
	movlw	.08
        movwf	lcd_data
        call	LCD_Line1W
;
	movfw	TimeZone
	movwf	offset_tz

	btfsc   DST_NOW		; DST?
	decf	offset_tz,F			; Yes Spring AHEAD! (increment the offset)


	movlw	"-"
	btfss	offset_tz,4		;
	movlw	"+"
	movwf	lcd_data
	call	LCD_DAT			;send sign


	movfw	offset_tz

	andlw	b'00001111'		;mask hi nibble		
	movwf	hex_lo	
	clrf	hex_hi
	call	hd_convert		;display current
;
	movfw	tens
	xorlw	"0"			;
	bz	little_ones		;if 0, skip 10's
	movfw	tens
	movwf	lcd_data
	call	LCD_DAT			;10's
little_ones
	movfw	ones	
	movwf	lcd_data
	call	LCD_DAT			;1's

;<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
; DISPLAY the Time Zone on the LCD
;<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
; need to expand to the 4 US Time Zones: ExT, CxT,MxT, PxT and
; with x = "S"tandard Time or "D"aylight saving Time when active
;<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
	movfw	TimeZone
	bz		Z0			;using ZULU!  No offset, No DST

	movfw	TimeZone
	xorlw	.8			;PST?
	bz	Z4				;yes
	movfw	TimeZone
	xorlw	.7			;MST?
	bz	Z3				; 
	movfw	TimeZone
	xorlw	.6			;CST?
	bz	Z2				; 
	movfw	TimeZone
	xorlw	.5			;EST?
	bz	Z1				;
			;all else use UTC
Z0:
  movwf  FSR                    ;  Point at first letter
OutUTC1:
  movf   FSR, w                 ;  Get pointer into W
  incf   FSR, f                 ;  Set up for next letter
  call  UTC                     ; Characters to display " UTC"
  iorlw  0                      ;  At the End of the Message?
  btfsc  STATUS, Z              ;  Skip if not at end
  goto   OnTime                 ;  Yes - Equal to Zero
  call   SendCHAR               ;  Output the ASCII Character
  goto   OutUTC1                ;  Get the next character
  goto   OnTime                 ;  Yes - Equal to Zero


Z4:
  movwf  FSR                    ;  Point at first letter
PST1:
  movf   FSR, w                 ;  Get pointer into W
  incf   FSR, f                 ;  Set up for next letter
  call  PST                     ; Characters to display " PST"
  iorlw  0                      ;  At the End of the Message?
  btfsc  STATUS, Z              ;  Skip if not at end
  goto   OffsetDST                 ;  Yes - check if DST is needed
  call   SendCHAR               ;  Output the ASCII Character
  goto   PST1                ;  Get the next character
Z3:

  movwf  FSR                    ;  Point at first letter
MST1:
  movf   FSR, w                 ;  Get pointer into W
  incf   FSR, f                 ;  Set up for next letter
  call  MST                     ; Characters to display " MST"
  iorlw  0                      ;  At the End of the Message?
  btfsc  STATUS, Z              ;  Skip if not at end
  goto   OffsetDST                 ;  Yes - check if DST is needed
  call   SendCHAR               ;  Output the ASCII Character
  goto   MST1                ;  Get the next character

Z2:

  movwf  FSR                    ;  Point at first letter
CST1:
  movf   FSR, w                 ;  Get pointer into W
  incf   FSR, f                 ;  Set up for next letter
  call  CST                     ; Characters to display " CST"
  iorlw  0                      ;  At the End of the Message?
  btfsc  STATUS, Z              ;  Skip if not at end
  goto   OffsetDST                 ;  Yes - check if DST is needed
  call   SendCHAR               ;  Output the ASCII Character
  goto   CST1                ;  Get the next character
Z1:

  movwf  FSR                    ;  Point at first letter
EST1:
  movf   FSR, w                 ;  Get pointer into W
  incf   FSR, f                 ;  Set up for next letter
  call  EST                     ; Characters to display " EST"
  iorlw  0                      ;  At the End of the Message?
  btfsc  STATUS, Z              ;  Skip if not at end
  goto   OffsetDST                 ;  Yes - check if DST is needed
  call   SendCHAR               ;  Output the ASCII Character
  goto   EST1                ;  Get the next character

OffsetDST:
	movlw	.12
	call	LCD_Line1W			;write to 16 position
	movlw	"S"
	btfsc   DST_NOW
	movlw	"D"
	call	SendCHAR

	movlw	.10
	call	LCD_Line1W			;write to 10th position
	movlw	" "
	btfsc   DST_WARN
	movlw	"~"
	call	SendCHAR
	
;	movfw	FLAGS2
;
;	andlw	b'11000000'
;	sublw	b'01000000'		; =01? 
;	bz		ds_warn			;zero, offset = hours
;	movlw	" "				;no clear indic
;	call	SendCHAR
;	goto	OnTime
;ds_warn:
;	movlw	"~"			;yes- DST will happen soon!
;	call	SendCHAR




OnTime:

;==============================================================================
;
; writes a "*" when on-time indicator to LCD Display + GREEN LED ON
;
;==============================================================================


	movlw	.14
	call	LCD_Line1W			;write to 16 position		
	movlw	"*"
 	bcf		G_LED			;turn on GREEN LED
	
	btfss	D_FLAG			;check on the minute
	movlw	" "
	movwf	lcd_data		;display "*" if fresh wwvb
	call	LCD_DAT

	btfss	D_FLAG			;check on the minute
 	bsf		G_LED			;turn off GREEN LED	
	
;
;==============================================================================
;
; Writes DD:MM:YY to LCD Display
; Writes HH:MM to 7-SEGMENT DISPLAYS
;
;==============================================================================

update_MDY_display:
	movfw	p_count			;*TEST* any frame count?
	bz		no_frame		; none  = 0 OK to do date
	goto	check_seconds	; skip date space is being used now!
							; no frame display:
							; then go ahead and send MDY
no_frame:
	call	second_line_display	;LCD line #2
	movfw	month				;display month
	movwf	hex_lo
	clrf	hex_hi
	call 	hd_convert
	movfw	tens			;tens of months
	movwf 	lcd_data
	call	LCD_DAT
	movfw	ones			;months
	movwf	lcd_data
	call	LCD_DAT
	movlw	"/"
	movwf	lcd_data
	call	LCD_DAT
	movfw	day				;display day:
	movwf	hex_lo
	clrf	hex_hi
	call 	hd_convert
	movfw	tens			;tens of days
	movwf 	lcd_data
	call	LCD_DAT
	movfw	ones			;days
	movwf	lcd_data
	call	LCD_DAT	
	movlw	"/"
	movwf	lcd_data
	call	LCD_DAT
; 	movlw	"2"			;don't display century year
;	movwf	lcd_data
; 	call	LCD_DAT
; 	movlw	"0"
; 	movwf	lcd_data
; 	call	LCD_DAT	
	movfw	wwvb_year		;display year:	
	movwf	hex_lo
	clrf	hex_hi
	call 	hd_convert
	movfw	tens			;tens yesrs
	movwf 	lcd_data
	call	LCD_DAT
	movfw	ones			;years
	movwf	lcd_data
	call	LCD_DAT			

	call	insert_space	;erase any frame display 
	call	insert_space

	clrf	lcd_count		;clear pointer
;display_DST
;	movfw	lcd_count
;	call	DST_		;display " DST"
;	movwf	lcd_data
;	movfw	lcd_data		;test for zero
;	bz		check_seconds		;leave if 0 is returned
;	call	LCD_DAT
;	incf	lcd_count,F
;	goto	display_DST

check_seconds
	movlw	LINE_1 +.6
	movwf	lcd_data
	call	LCD_Cmd			;write to 6 position
	movfw	seconds			;
	movwf	hex_lo
	clrf	hex_hi
	call	hd_convert
	movfw	tens			;seconds to LCD
	movwf	lcd_data
	call	LCD_DAT	
	movfw	ones
	movwf	lcd_data
	call	LCD_DAT

	movfw	seconds			;60 LED position
 
	call	SEGMENT_TIME	;update the LED Displays as well

	return


;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<SIGNAL>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;
; DISPLAYS "R" or "R" + "S" Values.  Depending on if we are decoding a
; TIMECODE frame or not.  
;_______________________________________
; POS = 0 1 2 3 4 5 6 7 8 9 A B C D E F
; ............................* *...* *
; LINE2 D D / M M / Y Y _ _ R 9 9 _ 5 9  = "R" + "S" (NOT framing)
; LINE2 1 2 3 4 5 6 7 8 9 0 S 5 9 P 5 9  = "S" + "P" (WHILE framing)
;_______________________________________
;
;*= max counts shown, the "P"osition count is added elsewhere in code
;
; The "R" Display shows the count of good bits vs. bad bits making it
; thru the PW descriminator. This count gives an indication on how good
; the signal has been for the last 90 Sec.  This helps to find a sutible
; location for the antenna since the counter is bound from R00 -> R99
;
; The "S" Display simply shows how many times the clock has found a Sync
; for this current hour. it ranges from S0 -> S59. This counter resets
; each hour, so a "perfect" score is 59 out of 59 syncs.  The way to judge
; the signal is to compair this count with the number of minutes in each hour.
;
; For example: S10 at :10(MIN) is perfect signal S10 @ :50 means we only detected 
; a frame 10x in the last :50 min...propigation was Poor -> Fair for this hour
;
;===========================================================================
do_rx_indicate:

	movlw	.10
	call	LCD_Line2W			;write to position	
	call	Delay100
;This shows the counter if any valid bit is there
	movfw	p_count			;test contents of buffer
	bnz		S_disp			; SKIP it  if  = 0
	
	movlw	'R'				;"R"eceived signal = 00 -> 99
	movwf	lcd_data		
	call	LCD_Char
;	call	Delay100
	
	movfw	signal	
	movwf	hex_lo
	clrf	hex_hi
	call 	hd_convert		;hex  to ascii
	movfw	tens			;Show SIG MSB
	movwf 	lcd_data
	call	LCD_Char
	movfw	ones			;Show SIG LSB
	movwf	lcd_data
	call	LCD_Char			;
	return

S_disp:
	movlw	'S'				;"S"yncs for this hourl = 00 -> 59
	movwf	lcd_data		
	call	LCD_Char

Sync_hour:
	movfw	s_count	
	movwf	hex_lo
	clrf	hex_hi
	call 	hd_convert		;hex  to ascii
	movfw	tens			;Show SIG MSB
	movwf 	lcd_data
	call	LCD_Char
	movfw	ones			;Show SIG LSB
	movwf	lcd_data
	call	LCD_Char			;
	return

;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<SIGNAL>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



;------------------------------------------------------------
;	Delay loops
;------------------------------------------------------------
delay_60uS
	movlw	.1
	movwf	delay_count
	movlw	US_60
	movwf	TMR2
	goto	T2_delay_loop
;
delay_125uS
	movlw	.1
	movwf	delay_count
	movlw	US_125
	movwf	TMR2
	goto	T2_delay_loop
;
delay_500uS
	movlw	.2
	movwf	delay_count
	clrf	TMR2
	goto	T2_delay_loop
;
delay_5mS
	movlw	MS_5
	movwf	delay_count
	clrf	TMR2
	goto	T2_delay_loop	
;
delay_15mS
	movlw	MS_15
	movwf	delay_count
	clrf	TMR2
	goto	T2_delay_loop
;
delay_60mS
	movlw	MS_60	
	movwf	delay_count
	clrf	TMR2
;
T2_delay_loop
	bcf	PIR1,TMR2IF		;256 uS per rollover
T22	
	btfss	PIR1,TMR2IF
	goto	T22
	decfsz	delay_count,F
	goto	T2_delay_loop
	return
; _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
;
;			DS1307A.ASM
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
; ADDR - BIT7 BIT6  BIT5  BIT4 : BIT3 BIT2 BIT1 BIT0 |FUNCTION (RANGE)
; 00h  -  CH   10S   10S  10S  : 1s   1s   1s   1s   |Seconds (00–59)
; 01h  -  0    10M   10M  10M  : 1m   1m   1m   1m   |Minutes (00–59)
; 02h  -  0    24H   10H  10H  : 10H  10H  10H  10H  |Hours (0 - 23)
; 02h  -  0    12H   P/A  10H  : 10H  10H  10H  10H  |Hours (1 - 12)
; 03h -   0    0     0    0    :  0   D1   D2   D3   |DOW  (01–07)
; 04h -   0    0     10D  10D  : 1D   1D  1D    1D   |Date (01–31
; 05h -   0    0     0    10MO : 1MO  1MO 1MO   1MO  |Month (01–12
; 06h -   10's of  Years       :   1's of Years      |Year (00–99
; 07h -   OUT  0     0  SQWE   : 0   0  RS1   RS0    |Control (NA)
; 08h–3Fh                                            |RAM 56 x 8 (00h–FFh)
;
;_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

I2C_PORT equ PORTB
I2C_TRIS equ TRISB

;
;======================================================================
;How to:
;Bit bang the SPI ports...
;
;----------------------------------------------------------------------
;EN   -________________--  Enables are  active low - 
;DATA ____-___----__---__  spi_data -> SPI_DOUT pin (0x5B = 0101-1011)
;CLK  __-_-_-_-_-_-_-_-__  TOGGLES -> SPI_CLK pin 8x (index in i_main)
;
;======================================================================
;spi_out movwf   spi_data
;        movlw   8				;shift 8 bits
;        movwf   i_main			;index reg
;
;		 bcf     EN	             ;set ENable pin (ACTIVE LOW)		
;spi_dat bcf     PORTC,SPI_CLK   ;set the clock low (just in case)
;        bcf     PORTC,SPI_DOUT   ;clear output bit 
;        btfsc   spi_data,7		  ;Test MSB...
;        bsf     PORTC,SPI_DOUT  ;set output bit if data is ONE
;        rlf     spi_data,f      ;Left shift data
;
;        bsf     PORTC,SPI_CLK   ;set clock high   DATA VALID NOW
;        decfsz  i_main,f		 ;dec the index (minimum pulse width)
;		 nop				     ;optional hold(s) for slower devices
;        goto    spi_dat         ;loop 8 times...
;
;		 bsf     EN			     ;DONE reset ENable (active low)
;        bcf     PORTC,SPI_DOUT  ;reset data pin low
;        return
;
;==============================================================================
; W= DATA To TRANSMIT TO 7219
; MCS	CHIP SELECT for 7219 7-SEG
; MSI	DATA IN for 7219 7-SEG
; MSCK	SPI CLOCK for 7219 7-SEG
;
;TIMING DIAGRAM:
;LOAD __--------------------------------------------------___-- <MCS> = ACTIVE LOW
;CLOCK___-__-__-__-__-__-__-__-___-__-__-__-__-__-__-__-___    <MSCK> = 16
;DATA  15 14 13 12 11 10 09 D8 |D7 D6 D5 D4 D3 D2 D1 D0
;       X  X  X  X <---ADDR--> |MSB<-----DATA------>LSB  
;     ----------------------------------------------------
;
;*  The host communicates with the MAX7219 using three signals: DATA, CLK, and LOAD.  This
;*  modules bit-bangs them, but Motorola's SPI interface (or similar interface from other
;*  manufacturers) may also be used to simplify and speed up the data transfer.
;*                   ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___
;*    DATA _________|D15|D14|D13|D12|D11|D10|D09|D08|D07|D06|D05|D04|D03|D02|D01|D00|______
;*         ________    __    __    __    __    __    __    __    __    __    __    ________
;*    CLK          |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|
;*                __________________________________________________________________    ___
;*    LOAD ______|                                                                  |__|
;*

;==============================================================================
;Setup the 7219 7 Segment decoder commands
;==============================================================================

INIT_SEGMENTS
	   banksel PORTC       ; select correct bank 

		bcf     MCS			;reset ENable pin (ACTIVE LOW)
		nop
		movlw	0x0c		;Set  Mode
;		bsf     MCS			;set ENable pin (ACTIVE LOW)
		nop
		call	spi_out		;address
		movlw	0x01		;1= normal op
		call	spi_out		;data

		bsf     MCS			;load = reset ENable 
		bcf     MCS			;reset ENable pin (ACTIVE LOW)

		nop
		nop
;		bcf     MCS			;load = reset ENable 
;		return




SET_DECODE7
		banksel PORTC       ; select correct bank 
		bcf     MCS			;reset ENable pin (ACTIVE LOW)

		movlw	0x09	;Set Decode Mode
		call	spi_out		;address
		movlw	0xFF	;All bits are 7-Segment DECODED
		call	spi_out		;data

		bsf     MCS			;load = reset ENable 
		bcf     MCS			;load = reset ENable 

;		return
SET_SCAN
		banksel PORTC       ; select correct bank 
		bcf     MCS			;set ENable pin (ACTIVE LOW)

		movlw	0x0B	;Set the SCAN LIMIT
		call	spi_out		;address
		movlw	0x05	;Only 0, 1, 2, 3, 4, 5 are scanned
		call	spi_out		;data

		bsf     MCS			;load = reset ENable 
		bcf     MCS			;load = reset ENable 

		return

;		movlw	0x0A	;Set the LED INTENSITY

SET_INTENSITY
		banksel PORTC       ; select correct bank 
		bcf     MCS			;set ENable pin (ACTIVE LOW)

		bcf     MCS			;set ENable pin (ACTIVE LOW)
		call	spi_out		;address
		movlw	0x06	;Brightest = 0x0f
		call	spi_out		;data

		bsf     MCS			;load = reset ENable 
		bcf     MCS			;load = reset ENable 

		return


SET_MIN_INTENSITY
		banksel PORTC       ; select correct bank 

		movlw	INTENSITY	;Set the LED INTENSITY
		bcf     MCS			;set ENable pin (ACTIVE LOW)
		call	spi_out		;address
		movlw	MIN_INTEN	;Brightest
		call	spi_out		;data
		bsf     MCS			;load = reset ENable 
		return
;==============================================================================
;
; writes HH:MM to 7 Segment LED Displays
;
;==============================================================================
SEGMENT_TIME


		banksel PORTC       ; select correct bank 
		bcf     MCS			;load = reset ENable 
		nop
		nop
;DIG1 (LSB) =  Ones Minutes
		bcf     MCS			;set ENable pin (ACTIVE LOW)

		movlw	0x01 		;First Digit (10s hours)
		call	spi_out		;address
 		movfw	Hour10		;TENS 


		call	spi_out		;data
		bsf     MCS			;load = reset ENable 

;DIG2 =  Tens Minutes
		bcf     MCS			;set ENable pin (ACTIVE LOW)

		movlw	0x02 		;Second Digit (1s hours)
		call	spi_out		;address
		movfw	Hour1		;ONES 

		call	spi_out		;data
		bsf     MCS			;load = reset ENable 

;DIG2 =  Ones Hours
		bcf     MCS			;set ENable pin (ACTIVE LOW)
		movlw	0x03 		;Third Digit (10's Min)
		call	spi_out		;address
		movfw	Min10		;TENS MIN(5C)

		call	spi_out		;data
		bsf     MCS			;load = reset ENable 

;DIG3  = (MSB) Tens Hours
		bcf     MCS			;set ENable pin (ACTIVE LOW)
		movlw	0x04 		;Fourth Digit (1s Digit)
		call	spi_out		;address
		movfw	Min1		;ONES MIN(5D)

		call	spi_out		;data
		bsf     MCS			;load = reset ENable

 
;DIG4  = Colon LEDs
		bcf     MCS			;set ENable pin (ACTIVE LOW)
		movlw	0x05 		;Fourth Digit (1s Digit)
		call	spi_out		;address

		movlw	0x00 		;First Digit + Colon
		btfss	seconds,0	;TICK 
		movlw	0x80 		;First Digit + Colon

		call	spi_out		;data
		bsf     MCS			;load = reset ENable

		movfw	seconds
 		call     ShiftLEDS

		return

	btfss	seconds,0	;TiCK 
	goto	led_tick
	call	LED_TEST55	;ToCK 
	goto	led_tock		;loop --->> ISR does the rest
led_tick:	
	call	LED_TESTAA		;0101 test pattern
led_tock:


		return

;DIG5  = PM LED OFF
		bcf     MCS			;set ENable pin (ACTIVE LOW)
		movlw	0x06 		;Fourth Digit (1s Digit)
		call	spi_out		;address
		movlw	0x00 		;PM=off
;		movfw	Min1		;ONES MIN(5D)

		call	spi_out		;data
		bsf     MCS			;load = reset ENable


		return

;DIG5  = PM LED ON
Y_LED_ON:

		bcf     MCS			;set ENable pin (ACTIVE LOW)
		movlw	0x06 		;Fourth Digit (1s Digit)
		call	spi_out		;address
		movlw	0x80 		;Fourth Digit (1s Digit)
		call	spi_out		;data
		bsf     MCS			;load = reset ENable
		return

Y_LED_OFF:
		bcf     MCS			;set ENable pin (ACTIVE LOW)
		movlw	0x06 		;Fourth Digit (1s Digit)
		call	spi_out		;address
		movlw	0x00 		;Fourth Digit (1s Digit)
		call	spi_out		;data
		bsf     MCS			;load = reset ENable

		return
PM_LED:

		bcf     MCS			;set ENable pin (ACTIVE LOW)
		movlw	0x06 		;Fourth Digit (1s Digit)
		call	spi_out		;address
		movfw	ampm		;Fourth Digit (1s Digit)
		call	spi_out		;data
		bsf     MCS			;load = reset ENable
		return

;			
;======================================================================
;Bit bang the 7219 7 Segment decoder SPI ports
;
;----------------------------------------------------------------------
;
;*    DATA ________|D07|D06|D05|D04|D03|D02|D01|D00|______
;*    CLK ____________-___-___-___-___-___-___-___-_______ 
;*        
;======================================================================

spi_out
   banksel PORTC       ; select correct bank 
		movwf   spi_data
		movlw   8				;shift 8 bits
		movwf   spi_count		;bit count

;
		
spi_dat	
	bcf		MSCK			;reset the clock 
	nop
	bcf		MSI				;clear output bit 
        btfsc   spi_data,7		;Test MSB...
	bsf     MSI				;set output bit if data is ONE
	rlf     spi_data,f      ;Left shift data
;
	bsf		MSCK  			;set clock  DATA VALID NOW
	nop				     ;optional hold(s) for slower devices

	decfsz  spi_count,f		 ;dec the index (minimum pulse width)
	goto    spi_dat         ;loop 8 times...
;
	bcf     MSI  			;reset data pin
	bcf		MSCK			;reset the clock 

	return
;

		include		lcd_16x2.asm	; LCD routines	
;		include		i2c.asm			; I2C routines	
;		include		DS1307.asm		; RTC routines	
;		include		DS1307A.asm		; RTC routines	

	return


;===============================SET UP THE MCP23S17============================
; W= DATA To TRANSMIT TO 23S17
;
;  RC5 (16) - SCK  SPI CLK	MCP23S17SP (12) YEL		|output 
;  RA6 (10)-  CS_  SPI CS 	MCP23S17SP (11) RED		|output
;  RC7 (18) - SI SPI DATA	MCP23S17SP (13) ORG     |output

;         ______                                                                                ________
;    CS_        |______________________________________________________________________________|      
;                 ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ 
;    SI   _______| 0 | 1 | 0 | 0 |*A2|*A1|*A0|R/W|A07|A06|A05|A04|A03|A02|A01|A00|_.............________
;                |<-----opcode (cont byte)------>|<--------REGISTER ADDRESS----->|<----DATA--->
;  `......(bit)....1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16............24_________
;    SCK  _________-___-___-___-___-___-___-___-___-___-___-___-___-___-___-___-__..........__-_________ 
;
;   * Address pins are enabled/disabled via IOCON.HAEN = 1/0
;     R/W = 0 (WRITE)  R/W = 1 (READ)
;
; If BANK = 1, the registers associated with each port are segregated. 
; Registers associated with PORTA are mapped from address 00h - 0Ah and 
; Registers associated with PORTB are mapped from 10h - 1Ah.
; If BANK = 0, the A/B registers are paired. 
; For example: IODIRA is mapped to address 00h and
; IODIRB is mapped to the next address (address01h)
; these transfers are typically done in three bytes:
; 	CS = 0
;1. SENDBYTE(OPCODE)
;2. SENDBYTE(ADDRESS)
;3. SENDBYTE (DATA)
; 	CS = 1 
;
;
;-----------------------------REGISTER ADDRESSES USED---------------------------

LEDADD	equ	0X40
IODIRB	equ	0X01
IOCON	equ	0X0A
GPIOA	equ	0X12
GPIOB	equ	0X13
OLATA	equ	0X14
OLATB	equ	0X15
	
;------------------------------------------------------------------------------
; 
; Did this the hard way...no loops to maks sure each reg was programmed.
; the config was verified by buss pirate sniff
;==============================================================================

MCP23S17Init:
        banksel PORTA       ; select correct bank 
		bsf	CS_     		;make sure it is not selected
        banksel PORTC       ; select correct bank 
		bcf	SI             ;set SI low before we start
		bcf	SCK             ;set SCK low before we start
        banksel PORTA       ; select correct bank 
 
		Bank0
;-----------------------------------------------------------
;1A. Send SPI bytes [0x40 0x0A 0x08] (configures IOCONA reg)
;
;-----------------------------------------------------------

		bcf	CS_     		;select chip = 0 and start transfers...
		movlw	0x40
        call    send_byte   ; (opcode) Cont Byte

        movlw	0x0A
        call    send_byte    ;(address) IOCON  Byte
                             ;(Data) Byte = 0x08 bank=0, SEQOP=0N, HAEN=1
	    movlw	b'00001000'     
        call    send_byte 

        banksel PORTA           ; select correct bank 
        bsf	CS_            		;RESET the CHIP SELECT
        nop
;-----------------------------------------------------------
;1B. Send SPI bytes[0x40 0x0B 0x08](configures IOCONB reg)
;
;-----------------------------------------------------------



		bcf	CS_     		;select chip = 0 and start transfers...
		movlw	0x40
        call    send_byte   ; (opcode) Cont Byte
 
		movlw	0x0B
        call    send_byte    ;(address) IOCON  Byte
                             ;(Data) Byte = 0x08 bank=0, SEQOP=0N, HAEN=1
	    movlw	b'00001000'     
        call    send_byte 

        banksel PORTA           ; select correct bank 
        bsf	CS_            		;RESET the CHIP SELECT
        nop
;-----------------------------------------------------------
; 2A. Send SPI bytes to set PORTA direction all outs
;IODIRA TO OUTPUTS:
;[0x40(0x00)0x00(0x00)0x00(0x00)]
;[0x42(0x00)0x00(0x00)0x00(0x00)]
;[0x44(0x00)0x00(0x00)0x00(0x00)]
;[0x46(0x00)0x00(0x00)0x00(0x00)]
;-----------------------------------------------------------

        bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x40
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x00
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
       bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x42
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x00
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
      bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x44
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x00
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
      bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x46
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x00
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
;-----------------------------------------------------------
;2B. IODIRB TO OUTPUTS:
;[0x40(0x00)0x01(0x00)0x00(0x00)]
;[0x42(0x00)0x01(0x00)0x00(0x00)]
;[0x44(0x00)0x01(0x00)0x00(0x00)]
;[0x46(0x00)0x01(0x00)0x00(0x00)]
;-----------------------------------------------------------

       bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x40
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x01
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
       bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x42
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x01
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
      bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x44
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x01
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
      bcf	CS_             ;SET the CHIP SELECT = 0
		movlw	0x46
        call    send_byte   ; (opcode) Cont Byte
        movlw	0x01
        call    send_byte    ;(address)Byte
      	movlw	0x00
        call    send_byte    ;(Data) Byte
 		banksel	PORTA           ; select correct bank 
		bsf		CS_             ;RESET the CHIP SELECT = 1
		nop
;-----------------------------------------------------------
; Now we are done with the basic chip's configs...
; it is ready to simply write to the GPIO ports
;-----------------------------------------------------------

		goto	CLEAR_LEDS

;===========================================================
;These set ALL the LEDs to some standard patterns: 
;alternates, all on, all off
;===========================================================

LED_TEST55:
		movlw	0x55		;TEST PATTERN 0101
		movwf	DATCOM
		goto	WRITE_60
LED_TESTAA:
		movlw	0xAA		;TEST PATTERN 1010
		movwf	DATCOM
		goto	WRITE_60
SET_LEDS:
		movlw	0xFF		;ALL LEDS ON
		movwf	DATCOM
		goto	WRITE_60

CLEAR_LEDS:
		clrf	DATCOM		;ALL LEDS OFF...CLEAR DATA

WRITE_60:
		comf	DATCOM,f		;LEDs are inverted
		movlw	0x04			;LOOP COUNT
		movwf	COUNT1
				
		movlw	LEDADD			;equ	0x40
		movwf	COMAND			

;This loop simpley populates all the seconds LEDs with the byte pattern
; Well, no so simple - 
;               ...it also sets/clears the Status bit on B port..if needed
W_LOOP:
;SEND TO PORTA/B SIDE...
		call    SendA
		call    SendB

		incf	COMAND,f	;2X = POINTS TO NEXT CHIP address
		incf	COMAND,f

		decfsz  COUNT1,f     ;dec the index 
		goto     W_LOOP      ;loops 4 times...0x40, 0x42, 0x44, and 0x46		

LED_DONE:
		return
;---------------------------------------------------------------------------
; SUBROUTINES to SEND WORD to GIPO PORTA and PORTB 
; (may change to use INCREMENT = TRUE)
;
; Input must have already set:
; COMMND = Chip address+W
; DATCOM = LED Pattern
;---------------------------------------------------------------------------
                ;SENDS to GPIO PORTA SIDE.
SendA:
		bcf		CS_             ;SET the CHIP SELECT = 0

		movfw	COMAND	   		; 1. SEND (opcode) Cont Byte		
		call    send_byte

		movlw	GPIOA			; 2. SEND (address)Registers 0x12 + 0x13

		call    send_byte  

		movfw	DATCOM			; 3. SEND (data) Pattern Byte
		call    send_byte    

		bsf		CS_		;RESET the CHIP SELECT = 1
		nop

                movlw	GPIOA			; Saves 0x12 for current
                movwf   SecPORT			;(66) = PORT
		return
;---------------------------------------------------------------------------
                ;SENDS to GPIO PORTB SIDE
                ;...and LED STATE BIT for LED66 (B.5 on 0x46)
                ;Since the MSB pattern will overwrite these bits
;---------------------------------------------------------------------------
SendB:
		nop
		bcf	CS_             ;SET the CHIP SELECT = 0

		movfw	COMAND	   		; 1. SEND (opcode) Cont Byte	
		call    send_byte

		movlw	GPIOB			; 2. SEND (address) B Registers0x13
		call    send_byte   
		
		movfw	COMAND           
		sublw	0x46			;Is the the last port?
		bz      STATUS_LED              ;yes, add in the status bits
SS_B6:

		movfw	DATCOM			; 3. SEND (data) Pattern Byte
		call    send_byte    

		bsf		CS_             ;RESET the CHIP SELECT = 1
 		return

STATUS_LED:          
		btfsc   G_LED		;Test LED STATE..
		goto    SLED1
		bcf     DATCOM,6		;reset set output bit6 if data is 0
		goto    SS_B6
SLED1:
		bsf     DATCOM,6		;set output bit6 if data is 1
		goto    SS_B6

;=============================================================================
; 60LED SECONDS DISPLAY
;=============================================================================
; Enters with W = Seconds. position
; Exit the bit postion for th LED (shifted W times)
; this can be LED01 - LED60  NOTE: No check is made for <59SEC
; Sets the proper GPIOA or GPIOB when the bit shifts to carry
;---------------------------------------------------------------------------
;   |<---GPIOB--->|   |<---GPIOA--->| 
; C 7 6 5 4 3 2 1 0 C 7 6 5 4 3 2 1 0
; 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 #1
; 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 #2
; 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 #3
; ...
; 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 #8
; 0 0 0 0 0 0 0 0 0 C 0 0 0 0 0 0 0 0 #9
; 0 0 0 0 0 0 0 0 1 C 0 0 0 0 0 0 0 0 #9A
; 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 #9B
; 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 #10
; ...
; 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 #16
; C 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 #17
; ------> NEXT CHIP ADDDRESS!-------> #17A
; C 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 #17B (LSB)
; 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 #1 (18th shift)
; 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 #2 (19th shift...)
; ...ETC.
;---------------------------------------------------------------------------

ShiftLEDS:

		movwf	ShiftCNT        ;W=Seconds --> to counter
		bnz		not0
		call	CLEAR_LEDS

not0:
		incf	ShiftCNT, f
		clrc
;SET UP STARTING @ 0-SEC LED

NotZero
		movlw	LEDADD		;0x40 = CHIP #1
		movwf	COMAND	

ShiftLSB:
		clrdc
		movlw	0x01
		movwf   LED_bits
NextA_LED:
		movfw   LED_bits

		movwf	DATCOM	        ;
		comf	DATCOM,f		;LEDs are inverted

;		call    SendA           ; show where we are
       	movlw	GPIOA			; 2. SEND (address) B Registers0x13
       	movwf   SecPORT			;(66)= PORT


		movfw	ShiftCNT 
		bz      SEC_DONEA         ;at :00SEC -->DONE
		
		decfsz   ShiftCNT,f     ;dec the seconds count index
		goto	shiftb
		goto     SEC_DONEA
shiftb:
		clrc
        rlf     LED_bits,f
		btfsc	STATUS,C  		;More bits needed...? 
		goto	ShiftMSB		;yes - shift to Port B
		goto     NextA_LED      ; nope get next bit       

ShiftMSB:
		;Yes- the carry is set so we need MSB display on Port B
		clrc
		clrdc
		movlw   0x01          	;set LSB for 9th bit 
		movwf   LED_bits

NextB_LED:
		movfw   LED_bits

		movwf   DATCOM
		comf	DATCOM,f	;LEDs are inverted

;		call    SendB           ; show where we are

       	movlw	GPIOB			; 2. SEND (address) B Registers0x13
       	movwf   SecPORT			;(66)= PORT

		movfw	ShiftCNT 
		bz      SEC_DONEB         ;at :60SEC -->DONE

		decfsz  ShiftCNT,f     ;dec the index (SECONDS)
		goto	shifth
		goto     SEC_DONEB       ;found the seconds yet? 
shifth:
		clrc
		rlf     LED_bits,f 
		btfsc	STATUS,C  ;More bits needed...? 
		goto	nextchp
		goto     NextB_LED      ; nope get next bit       

nextchp:					;yes- point to next chip
 		movlw	0xff
		movwf   DATCOM
		call	SendB		;clear out A

		incf	COMAND,f	;2X = POINTS TO NEXT CHIP's address
		incf	COMAND,f

		goto    ShiftLSB       ;start again at A on the next chip    ShiftLSB 
SEC_DONEA: 
		call    SendA  
		movfw	COMAND          ;saves the current bit location
		movwf   SecADD		;(65)= CHIP ADDR
		movfw	DATCOM				
		movwf   SecDATA		;(67)= Bit Pattern 
		movlw	0xff
		movwf   DATCOM
		call	SendB		;clear out b
		call	SendB		;clear out A

		return
SEC_DONEB: 
		call    SendB  
		movfw	COMAND          ;saves the current bit location
		movwf   SecADD		;(65)= CHIP ADDR
		movfw	DATCOM				
		movwf   SecDATA		;(67)= Bit Pattern 
		movlw	0xff
		movwf   DATCOM
		call	SendA		;clear out A
		movfw	seconds

		return

;======================================================================
;Send Byte (8-bits) in spi_data to MCP23S17 SPI ports...
;w/ standard 8-bit SPI, set the CS before sending.
;----------------------------------------------------------------------
;                          
;   SI ________|D07|D06|D05|D04|D03|D02|D01|D00|______
;   SCK __________-___-___-___-___-___-___-___-_______ 
;      
;======================================================================

send_byte:
	Bank0
	banksel PORTC          ; select correct bank 

	movwf	spi_data
	clrc
	movlw	h'08'		;shift 8 bits
	movwf	spi_count	;bit count

m_loop:	

	btfsc   spi_data,7		;Test MSB...
	bsf     SI			;set output bit if data is ONE
	rlf     spi_data,f      ;Left shift data
	nop
;CLOCK PULSE
	bsf		SCK  		;set clock  DATA VALID NOW
	bcf		SCK			;reset the clock 
	bcf		SI					;clear output bit 
	decfsz  spi_count,f     ;dec the index (minimum pulse width)
	goto    m_loop        ;loop 8 times...	

	return

;===============TEST 60=================================
; NOTE: inf loop  for debugging only.
; Count is in seconds, SEL_SW increments count for test
; LCD and 7SEG must be initialized before using this test

;--------------------------------------------------------
test60:						;lets stop here...
	banksel PORTB       ; select correct bank ;
	clrf	seconds	 ;CLEAR COUNTER
;	movlw	0x59	 ; or set up the minutes registers
;		movwf	Min1

T60:
	btfsc   SEL_SW 		; SEL_SW pushed (low)?
	incf	seconds,f  	; set output bit if data is ONE
	nop                     ; debounce
	nop
	nop
	btfsc   SEL_SW 		; SEL_SW released(hi)? 
	goto	$-1             ;wait for release

	movfw	seconds
	xorlw	.59			;lets just do 1 min...
	bz	test60          ;one minute!  all done
;show it on displays here for test
        call    check_seconds
        movfw   seconds
        call     ShiftLEDS
	goto	T60
;===============TEST 60=================================

;===============TEST TZ================================
; NOTE: inf loop  for debugging only.
; Count is in seconds, SEL_SW increments count for test


;--------------------------------------------------------
testTZ:						;lets test the timed zone display
	banksel PORTB       	; select correct bank ;
	btfsc   SEL_SW 			; SEL_SW pushed (low)?
	incf	TimeZone,f  	; set output bit if data is ONE
	nop                     ; debounce
	nop

	movfw	TimeZone
	xorlw	.4				;lets just do 4 zones
	bnz		TZ1          	;
	clrf	TimeZone		;CLEAR COUNTER
TZ1:
		return
;===============TEST TZ=================================

;------------------------------------------------------------
	end
;------------------------------------------------------------
;
;Copyright (c) 2013, Steve Botts aka KD6VKF
;All rights reserved.
;
