; Code to test subroutine for drawing shape tables. The result should be a
; tiny image of a man and woman that is roughly in the middle of the screen.

; Shape table (man and woman)
org 5FF4
data 081C3E2A5D081C5D14142222

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

; Store shape information
ldai  F4
staz  .shape_table_addr
ldai  5F
staz  .shape_table_addr 1
ldai  50
staz  .shape_coords
ldai  0F
staz  .shape_coords 1
ldxi  06
ldyi  02

; Draw shape and halt
jsra  .draw_shape
.finished
jmpa  .finished

zbyte shape_table_addr 2
zbyte shape_coords     2
; Subroutine to draw a shape described by a shape table
; Input: Zero-page shape table address (not table itself) in "shape_table_addr"
;        Zero-page shape coordinates in "shape_coords" ([0, 191] and [0-39])
;        height of table in X
;        width of table in Y
; No registers are preserved and zbytes are overwritten.
.draw_shape

; Set shape table address in load instruction.
ldaz .shape_table_addr
staa .shape_table_load_instr 1
ldaz .shape_table_addr 1
staa .shape_table_load_instr 2

; Initialize X and maximum X (stored in .shape_coords)
txa
ldxz  .shape_coords
clc
adcz  .shape_coords
staz  .shape_coords

; Initialize Y and maximum Y (stored in .shape_coords+1)
tya
ldyz  .shape_coords 1

; Unlike X, we need to save the starting y coordinate
zbyte y_start
styz  .y_start ; Unlike X, we need to preserve starting y coordinate

clc
adcz  .shape_coords 1
staz  .shape_coords 1

.loop_start
jsra  .line_index_to_address

.shape_table_load_instr
ldaa  0000
stany .line_address

; Increment above load address for next loop
inca  .shape_table_load_instr 1
ldaa  .shape_table_load_instr 1
bne   .no_shape_table_addr_overflow
inca  .shape_table_load_instr 2
.no_shape_table_addr_overflow

iny
cpyz  .shape_coords 1
bne   .loop_start

ldyz  .y_start
inx
cpxz  .shape_coords
bne   .loop_start
rts

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

