; Code to test subroutine mapping line indices to line addresses. The result
; should be 6 diagonal lines, 32 bytes wide, sloping down.

org 6000

; Initialize graphics mode
label graphics C050
label hires    C057
label page1    C054
label mixoff   C052
label target   2000

ldaa   .graphics
ldaa   .hires
ldaa   .page1
ldaa   .mixoff

; Now blank all pixels
.clr1
ldai  00
ldyi  00

; Do actual blanking of byte
.clr
stany 26
iny
bne   .clr
; End inner loop

incz  27
ldaz  27
cmpi  40
bcc   .clr1
; End outer loop
; End blanking of all pixels

; Begin main loop through line indices
ldxi  BF ; 192 lines

.draw_byte
jsra  .line_index_to_address
txa
andi  1F
tay
ldai  FF
stany .line_address

dex
cpxi  FF
bne   .draw_byte

.finished
jmpa  .finished
; End main loop

; Data used by subroutine to convert line indices to line addresses
zbyte line_address 2 ; return value

.line_address_high_bytes
data 2024282C3034383C

.line_address_offsets ; 2-byte addresses in little endian format
data 00008000000180010002800200038003                                                                                                              
data 2800A8002801A8012802A8022803A803                                                                                                              
data 5000D0005001D0015002D0025003D003                

; Subroutine to convert line index (0-191) into line address
; Input:  line index in X
; Output: two-byte line address in ".line_address"
; A, X, and Y are either not used or restored on exit.
.line_index_to_address

; Save A and Y (X is not changed)
pha
tya
pha

; Set high byte
txa 
andi  07
tay
ldaay .line_address_high_bytes
staz  .line_address 1

; Get index for offset table
txa
ror
ror
ror
andi  1F
clc
rol ; x2 because entries are two bytes

; Set low byte
tay
ldaay .line_address_offsets
staz  .line_address

; Add high byte to high byte set earlier
iny
ldaay .line_address_offsets
clc
adcz  .line_address 1
staz  .line_address 1

; Restore registers and return
pla
tay
pla
rts

