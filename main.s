;config information:
; HS Crystal.

;pin out:
; MCLR     VDD
; RA0      VSS
; RA1      RB15
; RB0      RB14
; RB1      RB13
; RB2      RB12
; RB3      RB11
; VSS      RB10
; RA2      Vcap
; RA3      VSS
; RB4      RB9
; RA4      RB8
; VDD      RB7
; RB5      RB6

;in use:
;  RB12-RB15 for audio out.
;  RA2, RA3 for crystal
;planned:
;  RB0-7 for button in.
;  RB8-11 for button group select.
;  RA0-2 for reading knobs (in combination with button group select)


;output with 10e4 cap and 5kOhm resistor @ 23 MIPS (LSB->MSB): 
;  Wait for charge (meaningless): 100000000000
;  Wait for ground: 1111 1011 1011 0000
;    MSB->LSB: 0000 1101 1101 1111
;    = 3551 in dec.
;    *4 (cycles per waitForGround loop) = 14204 cycles.
;    *16/23 = 9881 cycles @ 16 MIPS
;    ~60000 cycles to read 36 values
;    16000000 / 60000 = 267 times / sec
;  Take 2 (wait for ground):
;  LSB->MSB: 1111 1111 1011 0000
;  Take 3:
;  LSB->MSB: 1100 1111 1011 0000
;10e3 pF (stalls), 5kOhm @ 23 MIPS:
;10e4 pF 2kOhm @ 23 MIPS:
;  LSB->MSB: 0011 1100 1010 0000
;  1340*4 = 5360 cycles.
;10e4 pF 240 Ohm @ 23 MIPS:
;  LSB->MSB: 0001 1001 0000 0000
;  152*4 = 608 cycles

;DAC rate is tied to primary osc - changing PLL changes DAC rate.
;Triangle wave is abs(saw)*2-1
;  = saw*sign(saw)
;  = saw*asr(saw, 15)

.equ FOR_DEBUGGER, 0

.equ WSineWave, W14
;W14 is stack frame pointer (used by C++ compiler. Probably unused by me.)
;W15 is stack pointer.

.align 2

.bss 
.align 64
sampleBufferA: ;bit 5=0
	.space 32 ;16 samples
sampleBufferB: ;bit 5=1
	.space 32 ;16 samples.
sampleBufferEnd:
sampleBufferReadPtr: .space 2
;serialOutW: .space 2
.data

lastKeyVals0: .word 0x0000
lastKeyVals1: .word 0x0000
lastKeyVals2: .word 0x0000
lastKeyVals3: .word 0x0000

;lastSample: .word 0x0000
;frameNo: .word 0x0000

;minMaxSamp:
;minSamp: .word 0x8000
;maxSamp: .word 0x7fff

;note0cutLP: .word 0x7fff
;note0fbLP: .word 0x0000
;note0cutHP: .word 0x0001
;note0fbHP: .word 0x0000
;note0filt0: .word 0x0000
;note0filt1: .word 0x0000
;note0filt2: .word 0x0000
;note0filt3: .word 0x0000

note0v0idxHB: .word 0x0000 ;[garbage]:[table-index]
note0v0idxLW: .word 0x0000 ;fractional index into sine wave table.
note0v0invFreqLW: .word 0x0000 ;amount to add to idx each frame.
note0v0invFreqHB: .word 0x0000 ;[garbage]:[table-index]

note0v1idxHB: .word 0x0000 ;[garbage]:[table-index]
note0v1idxLW: .word 0x0000 ;fractional index into sine wave table.
note0v1invFreqLW: .word 0x0000 ;amount to add to idx each frame.
note0v1invFreqHB: .word 0x0000 ;[garbage]:[table-index]

note0v2idxHB: .word 0x0000 ;[garbage]:[table-index]
note0v2idxLW: .word 0x0000 ;fractional index into sine wave table.
note0v2invFreqLW: .word 0x0000 ;amount to add to idx each frame.
note0v2invFreqHB: .word 0x0002 ;[garbage]:[table-index]

note0v3idxHB: .word 0x0000 ;[garbage]:[table-index]
note0v3idxLW: .word 0x0000 ;fractional index into sine wave table.
note0v3invFreqLW: .word 0x0000 ;amount to add to idx each frame.
note0v3invFreqHB: .word 0x0002 ;[garbage]:[table-index]

note0v4idxHB: .word 0x0000 ;[garbage]:[table-index]
note0v4idxLW: .word 0x0000 ;fractional index into sine wave table.
note0v4invFreqLW: .word 0x0000 ;amount to add to idx each frame.
note0v4invFreqHB: .word 0x0000 ;[garbage]:[table-index]

oscVolSine: .word 0x0000 ;signed!
oscVolSaw: .word 0x0000 ;0x0800
oscVolTri: .word 0x0000 ;0x0900
oscVolSquare: .word 0x1000 ;0x0800

detuneVal: .word 0x0000
;instead of calculating ASDR envs like this,
;have an array of values and incr the idx every N frames.
;if using 64 frames, and max 2 seconds for each, 44100*2*3/64 = 4134 valus = 8268 bytes = about half of ram (yuck).

;save amt to incr vol by per 16 frames
;save amt to decr vol by every 16 frames (and sustain level)
;every 16 frames, add val.
;allows for max: 65536 / (44100 / 16) = 24 seconds of attack (and large steps at that value: 12sec, 8sec, 6sec, 4.8sec ...)
attackVol: .word 0x0000
decayVol: .word 0x0000
sustainVol: .word 0x00ff
;releaseVol: .word 0x0000

attackVolAdd: .word 0x7fff
decayVolAdd: .word 0xfffa ;should be negative.
;decayVolAdd: .word 0x0000
;releaseVolAdd: .word 0x0000 ;should be negative.

note0volume: .word 0x0000
note0volumeIncr: .word 0x7fff ;Either attackVolAdd, decayVolAdd, or releaseVolAdd
note0volumeThresholdL: .word 0x0000 ;0 if in attack mode. sustainVol if in decay mode, releaseVolAdd if in release mode.
note0volumeThresholdH: .word 0x7fff ;0xffff if NOT in attack mode. Otherwise, should be decayVolAdd - note0volumeIncr


.align 2
;.palign 2
;.hword
.word 0xffff ;used to quickly load 0xffff into a register because [sineWave] is already in a reg.
sineWave: ;256 point, 2**15-1 amp
	.word 0x0
	.word 0x324
	.word 0x648
	.word 0x96a
	.word 0xc8c
	.word 0xfab
	.word 0x12c8
	.word 0x15e2
	.word 0x18f9
	.word 0x1c0b
	.word 0x1f1a
	.word 0x2223
	.word 0x2528
	.word 0x2826
	.word 0x2b1f
	.word 0x2e11
	.word 0x30fb
	.word 0x33df
	.word 0x36ba
	.word 0x398c
	.word 0x3c56
	.word 0x3f17
	.word 0x41ce
	.word 0x447a
	.word 0x471c
	.word 0x49b4
	.word 0x4c3f
	.word 0x4ebf
	.word 0x5133
	.word 0x539b
	.word 0x55f5
	.word 0x5842
	.word 0x5a82
	.word 0x5cb3
	.word 0x5ed7
	.word 0x60eb
	.word 0x62f1
	.word 0x64e8
	.word 0x66cf
	.word 0x68a6
	.word 0x6a6d
	.word 0x6c23
	.word 0x6dc9
	.word 0x6f5e
	.word 0x70e2
	.word 0x7254
	.word 0x73b5
	.word 0x7504
	.word 0x7641
	.word 0x776b
	.word 0x7884
	.word 0x7989
	.word 0x7a7c
	.word 0x7b5c
	.word 0x7c29
	.word 0x7ce3
	.word 0x7d89
	.word 0x7e1d
	.word 0x7e9c
	.word 0x7f09
	.word 0x7f61
	.word 0x7fa6
	.word 0x7fd8
	.word 0x7ff5
	.word 0x7fff
	.word 0x7ff5
	.word 0x7fd8
	.word 0x7fa6
	.word 0x7f61
	.word 0x7f09
	.word 0x7e9c
	.word 0x7e1d
	.word 0x7d89
	.word 0x7ce3
	.word 0x7c29
	.word 0x7b5c
	.word 0x7a7c
	.word 0x7989
	.word 0x7884
	.word 0x776b
	.word 0x7641
	.word 0x7504
	.word 0x73b5
	.word 0x7254
	.word 0x70e2
	.word 0x6f5e
	.word 0x6dc9
	.word 0x6c23
	.word 0x6a6d
	.word 0x68a6
	.word 0x66cf
	.word 0x64e8
	.word 0x62f1
	.word 0x60eb
	.word 0x5ed7
	.word 0x5cb3
	.word 0x5a82
	.word 0x5842
	.word 0x55f5
	.word 0x539b
	.word 0x5133
	.word 0x4ebf
	.word 0x4c3f
	.word 0x49b4
	.word 0x471c
	.word 0x447a
	.word 0x41ce
	.word 0x3f17
	.word 0x3c56
	.word 0x398c
	.word 0x36ba
	.word 0x33df
	.word 0x30fb
	.word 0x2e11
	.word 0x2b1f
	.word 0x2826
	.word 0x2528
	.word 0x2223
	.word 0x1f1a
	.word 0x1c0b
	.word 0x18f9
	.word 0x15e2
	.word 0x12c8
	.word 0xfab
	.word 0xc8c
	.word 0x96a
	.word 0x648
	.word 0x324
	.word 0x0
	.word -0x324
	.word -0x648
	.word -0x96a
	.word -0xc8c
	.word -0xfab
	.word -0x12c8
	.word -0x15e2
	.word -0x18f9
	.word -0x1c0b
	.word -0x1f1a
	.word -0x2223
	.word -0x2528
	.word -0x2826
	.word -0x2b1f
	.word -0x2e11
	.word -0x30fb
	.word -0x33df
	.word -0x36ba
	.word -0x398c
	.word -0x3c56
	.word -0x3f17
	.word -0x41ce
	.word -0x447a
	.word -0x471c
	.word -0x49b4
	.word -0x4c3f
	.word -0x4ebf
	.word -0x5133
	.word -0x539b
	.word -0x55f5
	.word -0x5842
	.word -0x5a82
	.word -0x5cb3
	.word -0x5ed7
	.word -0x60eb
	.word -0x62f1
	.word -0x64e8
	.word -0x66cf
	.word -0x68a6
	.word -0x6a6d
	.word -0x6c23
	.word -0x6dc9
	.word -0x6f5e
	.word -0x70e2
	.word -0x7254
	.word -0x73b5
	.word -0x7504
	.word -0x7641
	.word -0x776b
	.word -0x7884
	.word -0x7989
	.word -0x7a7c
	.word -0x7b5c
	.word -0x7c29
	.word -0x7ce3
	.word -0x7d89
	.word -0x7e1d
	.word -0x7e9c
	.word -0x7f09
	.word -0x7f61
	.word -0x7fa6
	.word -0x7fd8
	.word -0x7ff5
	.word -0x7fff
	.word -0x7ff5
	.word -0x7fd8
	.word -0x7fa6
	.word -0x7f61
	.word -0x7f09
	.word -0x7e9c
	.word -0x7e1d
	.word -0x7d89
	.word -0x7ce3
	.word -0x7c29
	.word -0x7b5c
	.word -0x7a7c
	.word -0x7989
	.word -0x7884
	.word -0x776b
	.word -0x7641
	.word -0x7504
	.word -0x73b5
	.word -0x7254
	.word -0x70e2
	.word -0x6f5e
	.word -0x6dc9
	.word -0x6c23
	.word -0x6a6d
	.word -0x68a6
	.word -0x66cf
	.word -0x64e8
	.word -0x62f1
	.word -0x60eb
	.word -0x5ed7
	.word -0x5cb3
	.word -0x5a82
	.word -0x5842
	.word -0x55f5
	.word -0x539b
	.word -0x5133
	.word -0x4ebf
	.word -0x4c3f
	.word -0x49b4
	.word -0x471c
	.word -0x447a
	.word -0x41ce
	.word -0x3f17
	.word -0x3c56
	.word -0x398c
	.word -0x36ba
	.word -0x33df
	.word -0x30fb
	.word -0x2e11
	.word -0x2b1f
	.word -0x2826
	.word -0x2528
	.word -0x2223
	.word -0x1f1a
	.word -0x1c0b
	.word -0x18f9
	.word -0x15e2
	.word -0x12c8
	.word -0xfab
	.word -0xc8c
	.word -0x96a
	.word -0x648
	.word -0x324

noteInvFreqs: ; low, high. Suitable for a dword move.
	.word 0x8ce5
	.word 0x1
	.word 0xa47f
	.word 0x1
	.word 0xbd80
	.word 0x1
	.word 0xd7fe
	.word 0x1
	.word 0xf40f
	.word 0x1
	.word 0x11cb
	.word 0x2
	.word 0x314c
	.word 0x2
	.word 0x52ac
	.word 0x2
	.word 0x7608
	.word 0x2
	.word 0x9b7f
	.word 0x2
	.word 0xc330
	.word 0x2
	.word 0xed3d
	.word 0x2
	.word 0x19cb
	.word 0x3
	.word 0x48fe
	.word 0x3
	.word 0x7b00
	.word 0x3
	.word 0xaffb
	.word 0x3
	.word 0xe81d
	.word 0x3
	.word 0x2396
	.word 0x4
	.word 0x6297
	.word 0x4
	.word 0xa558
	.word 0x4
	.word 0xec11
	.word 0x4
	.word 0x36fe
	.word 0x5
	.word 0x8660
	.word 0x5
	.word 0xda7b
	.word 0x5
	.word 0x3395
	.word 0x6
	.word 0x91fc
	.word 0x6
	.word 0xf600
	.word 0x6
	.word 0x5ff7
	.word 0x7
	.word 0xd03b
	.word 0x7
	.word 0x472b
	.word 0x8
	.word 0xc52e
	.word 0x8
	.word 0x4ab0
	.word 0x9

.text
;.global __reset
.global _main
.global __DAC1LInterrupt
.global __DAC1RInterrupt

;__reset:
_main:
	;;bclr RCON, #1
	;btss RCON, #0 ;power-on-reset
	;	goto outputLowAndPause
	;btsc RCON, #4 ;watchdog timer
	;	goto outputLowAndPause
	;btsc RCON, #9 ;bad config
	;	goto outputLowAndPause
	;;btsc IFS4, #15
	;;	goto __DAC1LInterrupt
	;;btsc IEC4, #15
	;;	goto __DAC1LInterrupt
	;;btsc RCON, #1
	;;	goto outputLowAndPause
	bclr RCON, #5 ;disable watchdog timer. SWDTEN
initSP:
	;mov #0x4000, W0 ;stack-pointer limit address
	;mov W0, SPLIM
	;mov #__SP_init, W15       ;Initalize the Stack Pointer
    ;mov #__SPLIM_init, W0     ;Initialize the Stack Pointer Limit Register
    ;mov W0, SPLIM
    ;nop                       ;Add NOP to follow SPLIM initialization
initClock: ;MIPS = 7.37 / 8(default) * PLLFBD / 2
	;PLLFBD=50 yields 23.03 MIPS, 46.06 MHz clock.
	;PLLFBD=80 yields 36.85 MIPS
	;PLLFBD=84 yields 38.69 MIPS
	;PLLFBD=85 yields 39.15 MIPS
	;External OSC @ 22.1184 MHz
	; 0=interrupts don't effect osc. 0000=peripheral clocks same as primary. 000 = FRC div by 1. 00 = N2=postdiv 2
    ; 0(U), 00010 = prediv by 2+2 = 4.
    ;N1 = 4, M = 28, N2=2
	; 22.1184 * 28 / (4*2) / 2 = 38.7 MIPS
	;note: divide by 7 for dac
	;dac = 22.1184 * 28 / (4*2) / 7 / 256 = 43.200 kHz
	mov #0b0000000000000110, W0
	mov W0, CLKDIV
	nop
	mov #26, W0
	mov W0, PLLFBD ;mul by 26+2 = 28.
	nop
initRegs:
	mov #sineWave, WSineWave
	mov #sampleBufferA, W0
	mov W0, sampleBufferReadPtr
initPorts:
	mov #0x00ff, W0
	mov W0, TRISB ;RB8-15 output, 0-7 input.
	mov #0x0fff, W0
	mov W0, AD1PCFGL ;make all analog pins be digital i/o
	;call outputHigh
	;bclr PORTB, #4
	;goto idle
	;goto blink
initSynth:
	mov #note0v2invFreqLW, W0
	call setInvFreq
initDSP:
	;bclr CORCON, #12 ;US. 0=signed multiplies
	;nop
	;bclr CORCON, #7 ;SATA. 0=saturation disabled
	;nop
	;bclr CORCON, #6 ;SATB
	;nop
	;bclr CORCON, #5 ;SATDW. data space write from DSP. 0=saturation disabled.
	;nop
	;bset CORCON, #0 ;IF. 1=integer data. 0=1.15 fixed point.
	mov #0b1, W0
	mov W0, CORCON
	nop
initDAC:
	;dacL uses RB15, RB14. DacR uses 13 and 12
	;Auxiliary clock config
	;(U), (U), 0=FRC with PLL, 00=no aux oscillator (b/c using FRC), 111=divide by 1. 0=use aux clock. (U)*7
	mov #0b0000011100000000, W0
	mov W0, ACLKCON
	;1=enable left differential, (U), 0=disable Left midpoint, (U), (U), 0=interrupt on Not Full, (R), (R)
	;same but for right channel.
	;             \/
	mov #0b1000000010000000, W0
	mov W0, DAC1STAT
	nop
	;default data (in case of underrun):
	mov #0x0000, W0
	mov W0, DAC1DFLT
	;clr DAC1DFLT
	nop
	;1=enable, (U),  0=run in idle, 1=amplify in sleep, (U), (U), (U), 1=signed samples,
	;(U), clock div minus 1
	;             \/
	mov #0b0001000100000110, W0
	mov W0, DAC1CON
	nop
	bset DAC1CON, #15 ;enable dac.
	nop
	bset IEC4, #15; DAC1LIE - enable DAC left interrupt
	bset IEC4, #14; DAC1RIE - enable DAC right interrupt
	nop
	;bset DAC1CON, #0
	;bset DAC1CON, #1
	;bset DAC1CON, #8
	;bset DAC1CON, #12
	;bset DAC1CON, #15
	;mov #0, W0
	;mov W0, DAC1LDAT ;trigger interrupt stuff.
	goto idle

dropNote: ;takes ptr to lowFreq:highFreq of note to drop.
	return ;not implemented
playNote: ;takes ptr to lowFreq:highFreq of note to play.
	push W0
	push W1
	push W2
	;mov #noteInvFreqs, W0
	mov.d [W0], W2
	mov #note0v2invFreqLW, W0
	;add #4, W0
	mov.d W2, [W0]
	call setInvFreq
	;note0volume: .word 0x0000
	;note0volumeIncr: .word 0x7fff ;Either attackVolAdd, decayVolAdd, or releaseVolAdd
	;note0volumeThresholdL: .word 0x0000 ;0 if in attack mode. sustainVol if in decay mode, releaseVolAdd if in release mode.
	;note0volumeThresholdH: .word 0x7fff
	clr note0volume
	mov attackVolAdd, W0
	mov W0, note0volumeIncr
	clr note0volumeThresholdL
	pop W2
	pop W1
	pop W0
	return
setInvFreq:
	;having turned the note value into a index-incrementation value, configure the detune voices.
	;ptr to noteXv2invFreqLW in W0
	;that voice has essentially already been set. set the other 4 by detuning by detuneVal (global)
	mov detuneVal, W1
	mov.d [W0], W2 ;low invIdx in W2, high invIdx in W3
	LAC W3, A
	mov W2, ACCAL
	mul.uu W1, W3, W4 ;LB in W4. HB in W5.
	mul.uu W1, W2, W6 ;LB in W7, ignore W6.
	add W4, W7, W6 ;low in W6
	addc W5, #0, W5 ;high in W5
	LAC W5, B
	mov W6, ACCBL

	;now root is in ACCA, detune amt in ACCB
	add A
	mov ACCAH, W1
	mov W1, [W0+#10] ;move to v3 high.
	mov ACCAL, W1
	mov W1, [W0+#8] ;move to v3 low.
	add A
	mov ACCAH, W1
	mov W1, [W0+#18] ;move to v4 high.
	mov ACCAL, W1
	mov W1, [W0+#16] ;move to v4 low.
	sub A
	sub A ;now back at root.
	sub A
	mov ACCAH, W1
	mov W1, [W0-#6] ;move to v1 high.
	mov ACCAL, W1
	mov W1, [W0-#8] ;move to v1 low.
	sub A
	mov ACCAH, W1
	mov W1, [W0-#14] ;move to v0 high.
	mov ACCAL, W1
	mov W1, [W0-#16] ;move to v0 low.
	return


__DAC1LInterrupt:
	bclr IFS4, #15 ;DAC1LIF - clear interrupt.
	;call outputLow
	push W0
	mov sampleBufferReadPtr, W0
	mov [W0], W0
	mov W0, DAC1LDAT
	inc2 sampleBufferReadPtr
	pop W0
	retfie

fillSampleBufferB:
	mov W10, sampleBufferReadPtr ;direct reading to buffer A.
	mov W1, W10
	goto fillSampleBuffer
tryCalcNext16Samples:
	mov sampleBufferReadPtr, W2
	mov #sampleBufferA, W10
	mov #sampleBufferEnd, W0
	mov #sampleBufferB, W1
	CPSNE W0, W2
		goto fillSampleBufferB
	CPSEQ W1, W2 ;if reading at position B, fill buffer A
		return
fillSampleBuffer: ;W10 reserved as ptr to place sample at.
	;calculate filter coeffs:
	;mov #1
	;div.u Wm, Wn ;result placed in W0, remainder in W1.
	do #15, calcNextSampleEnd
calcNextSample:
	mov #note0v0idxHB, W8 ;load wavetable addr
	clr B
	mov #oscVolSine, W9
	mov [W9++], W7
	;W8 reserved for register addressing.
	;W9 for osc volumes.
	do #4, endAddVoice
	addVoice0:
		LAC [W8++], #1, A ;note0v#idxHB
		mov.d [W8++], W0 ;note0v#idxLW in W0, note0v#invFreqLW in W1
		mov [W8++], W2 ;note0v#idxFreqHB
		add W0, W1, W0
		addc W2, #0, W2
		mov W0, ACCAL
		ADD W2, A

		;mov #1, W6
		;LAC [W8++], #1, A ;note0v#idxHB
		;bset CORCON, #12 ;temporarily work with unsigned multiplies.
		;mov [W8++], W5 ;note0v#idxLW
		;;mov W5, ACCAL
		;MAC W6*W5, A, [W8]+=2, W5 ;must be unsigned multiply
		
		;mov [W8++], W5 ;note0v0invFreqLW
		;MAC W6*W5, A, [W8]+=2, W5 ;could use y-memory to load oscVolSine here too.
		;add W5, A
		;bclr CORCON, #12 ;back to signed multiplies.

		;mov ACCAL, W0

		mov W0, [W8-#6];mov W1, note0v#idxLW ;save low.
		SAC A, #-1, W4 ;move table-idx to register
		and #0x1fe, W4 ;only preserve index bits.
		mov W4, [W8-#8];mov W4, note0v#idxHB ;save
		
		mov [W4+WSineWave], W4
		;mov oscVolSine, W7
		MAC W4*W7, B, [W9]+=4, W7 ;add sine wave
		SAC A, #-8, W4 ;already shifted 1 earlier. Capture saw wave.
		;mov oscVolSaw, W7
		;lsr W4, #1, W4
		MAC W4*W7, B, [W9]-=2, W7 ;add saw wave.
		asr W4, #15, W5 ;now either 0x0000 or 0xffff
		btg W5, #15 ;now either 0x8000 or 0x7fff
		;mov oscVolSquare, W7
		MAC W5*W7, B, [W9]-=4, W7 ;add square wave.
		mul.ss W4, W5, W4 ;low in W4: high in W5.
		;mov oscVolTri, W7
	endAddVoice: MAC W5*W7, B, [W9]+=2, W7 ;add tri (?)

	SAC B, #0, W4 ;shift 2 if mic'ing
	ASDRUpdate1:
	mov note0volume, WREG	
	mul.su W4, W0, W4 ;W4:low, W5:high
	calcNextSampleEnd: mov W5, [W10++]
	
	;update ASDR envelope:
	add note0volumeIncr, WREG
	;bra C, switchToDecay
	;cp note0volumeThresholdH
	btsc W0, #15 ;>0x7fff ?
		bra LT, switchToDecay
	cp note0volumeThresholdL
		bra GT, switchToHoldOrKillNote ;wreg < note0volumeThresholdL
	ASDRUpdate2:
	mov WREG, note0volume
	return
	switchToDecay:
		mov note0volumeThresholdH, WREG
		mov decayVolAdd, W5
		mov W5, note0volumeIncr
		mov sustainVol, W5
		mov W5, note0volumeThresholdL
		;mov [WSineWave-#2], W5 ;0xffff
		;mov W5, note0volumeThresholdH
		goto ASDRUpdate2
	switchToHoldOrKillNote:
		clr note0volumeIncr
		goto ASDRUpdate2
	;mov W4, DAC1LDAT
	;retfie
	;return

	;inc2 frameNo
	;btsc frameNo, #9
	;	clr frameNo
	;mov #sineWave, W0
	;mov frameNo, W1
	;;mov #frameNo, W1
	;;mov [W1], W1
	;add W0, W1, W0
	;;add frameNo, WREG
	;mov [W0], W1
	;ASR W1, #2, W2
	;mov W2, DAC1LDAT
	;retfie
__DAC1RInterrupt:
	bclr IFS4, #14 ;DAC1RIF - clear interrupt.
	clr DAC1RDAT
	retfie

	;mov #sineWave, W0
	;mov frameNo, W1
	;add W0, W1, W0
	;mov [W0], W1
	;ASR W1, #2, W2
	;mov W2, DAC1RDAT
	;retfie

	;mov #150, W1
	;mov lastSample, W2
	;add W2, W1, W0 ;W0 = last sample(W2) + 2400(W1) 
	;mov W0, lastSample
	;LSR W0, #2, W1
	;mov W1, DAC1LDAT
	;retfie
	

	;inc frameNo
	;btsc frameNo, #11
	;	call outputHigh
	;btss frameNo, #11
	;	call outputLow
	;clr W0
	;mov W0, DAC1LDAT
	;retfie

	;mov lastSample, W0
	;mov frameNo, W2
	;mov #32, W1
	;cpsne W2, W1 ;32
	;	;mov #0x7fff, W0
	;	mov #0, W0
	;mov #64, W1
	;cpsne W2, W1
	;	;mov #0x8000, W0
	;	mov #0xffff, W0
	;btsc frameNo, #6 ;64
	;	clr frameNo
	;mov W0, lastSample
	;mov W0, DAC1LDAT
	;retfie

;outputHigh:
;	;mov #0x0000, W0
;	;mov W0, TRISB ;RB0-15 all output
;	mov #0xFFFF, W0
;	mov W0, PORTB ;RB0-15 all output high
;	return
;outputLow:
;	;clr TRISB
;	clr PORTB
;	;mov #0x0000, W0
;	;mov W0, TRISB
;	;mov #0x0000, W0
;	;mov W0, PORTB ;RB0-15 all output low
;	return
;inputAll:
;	mov #0x0FFF, W0
;	mov W0, TRISB
;	return
;configRBIn:
;	clr PORTB
;	clr TRISB
;	bset TRISB, #6
;	return
;waitForGroundOnRBIn:
;	inc serialOutW
;	btsc PORTB, #6
;		bra waitForGroundOnRBIn
;	return
;waitForChargeOnRBIn:
;	btss PORTB, #6
;		bra waitForChargeOnRBIn
;	return

;testSerialOut:
;	mov #0b101, W0
;	call outputSerialW0
;blink:
;	call outputHigh
;	call delay2p25
;	call outputLow
;	call delay2p25
;	goto blink
;testDischargeTime:
;	call outputHigh
;	call delay2p25 ;wait for charge
;	call outputLow
;	call delay2p6
;	call configRBIn
;	call waitForChargeOnRBIn
;	call waitForGroundOnRBIn ;wait for cap to drain.
;	call outputHigh
;	call delay2p26
;	call outputLow
;	call delay2p24
;	call outputHigh
;	call delay2p21 ;flash high to indicate done.
;	call outputLow
;	call delay2p26
;	mov serialOutW, W0
;	call outputSerialW0

;outputSerialW0bitAndShift: ;output bit 0, then shift right 1.
;	mov W0, serialOutW
;	;push W0
;	call outputHigh
;	call delay2p20 ;output short
;	btsc serialOutW, #0
;		call delay2p25 ;output long
;	call outputLow
;	lsr serialOutW, WREG
;	bra delay2p25 ;LED off
;	;return
;
;outputSerialW0: ;output the contents of W0 to the led serially.
;	;short on = 0.
;	;long on = 1.
;	call outputSerialW0NibbleAndShift
;	call outputSerialW0NibbleAndShift
;	call outputSerialW0NibbleAndShift
;outputSerialW0NibbleAndShift:
;	call outputSerialW0bitAndShift
;	call outputSerialW0bitAndShift
;	call outputSerialW0bitAndShift
;	bra outputSerialW0bitAndShift

goto idle

delay2p26:
	call delay2p25
delay2p25: ;33,554,432 cycles
	call delay2p24
delay2p24:
	call delay2p23
delay2p23: ;8,388,608 cycles
	call delay2p22
delay2p22:
	call delay2p21
delay2p21:
	call delay2p20
delay2p20:
	call delay2p19
delay2p19:
	call delay2p18
delay2p18:
	call delay2p17
delay2p17:
	call delay2p16
delay2p16:
	call delay2p15
delay2p15:
	call delay2p14
delay2p14: ;16384
	repeat #16378
	nop
	return
delay2p6: ;32
	repeat #26
	nop
	return

;outputLowAndPause:
;	call outputLow
idle:
	nop
	call tryCalcNext16Samples
	;call pollKeys
	pollKeys:
		mov PORTB, W2
		and #0b0011, W2
		mov lastKeyVals0, W1
		cp W2, W1
		bra eq, idle
		;now test for individual note changes:
		mov W2, lastKeyVals0
		xor W2, W1, W1
		mov #noteInvFreqs, W0
		btsc W1, #0
			btsc W2, #0
				call playNote
			btss W2, #0
				call dropNote
		add #4, W0
		btsc W1, #1
			btsc W2, #1
				call playNote
			btss W2, #1
				call dropNote
		add #4, W0
		btsc W1, #2
			btsc W2, #2
				call playNote
			btss W2, #2
				call dropNote
		add #4, W0
		btsc W1, #3
			btsc W2, #3
				call playNote
			btss W2, #3
				call dropNote
		add #4, W0
		btsc W1, #4
			btsc W2, #4
				call playNote
			btss W2, #4
				call dropNote
		add #4, W0
		btsc W1, #5
			btsc W2, #5
				call playNote
			btss W2, #5
				call dropNote
		add #4, W0
		btsc W1, #6
			btsc W2, #6
				call playNote
			btss W2, #6
				call dropNote
		add #4, W0
		btsc W1, #7
			btsc W2, #7
				call playNote
			btss W2, #7
				call dropNote
		;btsc PORTB, #1
		;	clr oscVolSquare
	;.if FOR_DEBUGGER
	;	call __DAC1LInterrupt
	;.endif
	goto idle

.end
