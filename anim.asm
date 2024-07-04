; Code to test moving of shapes horizontally. The result should be a tiny image
; of a man and woman, roughly in the middle of the screen, that moves from far
; left to far right. Movement is not yet smooth (no shape shifting) but drawing
; routine now uses pixel (instead of byte) coordinates for horizontal position
; and width.

; Shape table (man and woman)
org 5FF4
data 081C3E2A5D081C5D14142222

org 6000

; -------------------- Initialize graphics mode --------------------
label graphics  C050
label hires     C057
label page1     C054
label mixoff    C052
label target    2000
label num_lines C0
label num_rows  FF

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
; -------------------- End initialize graphics mode --------------------


; -------------------- Create table of div 7 values --------------------
; Code to make a table of dividends of 7, which occupies page 8 ($800 to $8FF).
; This table is useful for pixel calculations (horizontal) in hi-res since,
; annoyingly, each byte in hi-res memory represents 7 pixels rather than 8.

; The table only goes to 255 rather than 279. However, this is not much of a
; limitation because these values are used for starting addresses for shapes,
; which leaves three bytes for the shape width.

; Warning: This must be done after initializing hi-res graphics or "anomalies"
; appear in the graphics. Not sure why, but it has to do with where the table
; is stored, which relates to lo-res graphics.
label div7_table_addr 0800

ldai  00
ldxi  00
ldyi  00

.div7_table_fill_loop
staay .div7_table_addr
inx
cpxi  07
bne   .div7_row_continue

tax
inx
txa
ldxi  00

.div7_row_continue
iny
bne   .div7_table_fill_loop
; -------------------- End create table of div 7 values --------------------


; -------------------- Set shape and draw constants --------------------
label shape_addr_h 5F
label shape_addr_l F4
label height 06
label width  0E
label xcoord 50
label ycoord 00
label delay  FF
label wait   FCA8

; Store shape information
ldai  .shape_addr_l
staz  .shape_table_addr
ldai  .shape_addr_h
staz  .shape_table_addr 1
ldai  .xcoord
staz  .shape_coords
ldai  .ycoord
staz  .shape_coords 1
ldxi  .height
ldyi  .width
; -------------------- End set shape and draw constants --------------------


; -------------------- Main loop --------------------
; Compute number of iterations to move shape to end of screen
ldai  .num_rows
sec
sbci  .ycoord
sbci  .width

; Main loop. Move shape.
.main_loop_start
jsra  .draw_shape
pha
ldai  .delay
jsra  .wait
pla
jsra  .draw_shape
incz  .shape_coords 1
sec
sbci  01
bne   .main_loop_start

; Just freeze on completion
jsra  .draw_shape
.finished
jmpa .finished
; -------------------- End main loop --------------------


; Subroutine to draw a shape described by a shape table
; Input: Zero-page shape table address (not table itself) in "shape_table_addr"
;        Zero-page shape coordinates in "shape_coords" ([0, 191] and [0-255])
;        height of table in X
;        width of table in Y
; All registers and zbytes are restored.
zbyte shape_table_addr 2
zbyte shape_coords     2

; Subroutine start
.draw_shape

; Save registers and zero bytes
pha
txa
pha
tya
pha
ldaz  .shape_coords 1
pha
ldaz  .shape_coords
pha

; Set shape table address in load instruction.
ldaz  .shape_table_addr
staa  .shape_table_load_instr 1
ldaz  .shape_table_addr 1
staa  .shape_table_load_instr 2

; Set maximum X (in .shape_coords)
txa
clc
adcz  .shape_coords
staz  .shape_coords

; Set Y
tya
ldxz  .shape_coords 1
ldyax .div7_table_addr

; Save starting y coordinate (not needed for x coordinate)
zbyte y_start
styz  .y_start

; Set maximum Y (in .shape_coords+1)
clc
adcz  .shape_coords 1
tax
ldaax .div7_table_addr
staz  .shape_coords 1

; Set X (must use original .shape_coords, which is on stack)
pla
tax
pha

.draw_shape_loop_start
jsra  .line_index_to_address

; Write to screen
.shape_table_load_instr
ldaa  0000
eorny .line_address
stany .line_address

; Increment above load address for next loop
inca  .shape_table_load_instr 1
ldaa  .shape_table_load_instr 1
bne   .no_shape_table_addr_overflow
inca  .shape_table_load_instr 2
.no_shape_table_addr_overflow

; Check for end of row
iny
cpyz  .shape_coords 1
bne   .draw_shape_loop_start

; Reset row and check if this is last row
ldyz  .y_start
inx
cpxz  .shape_coords
bne   .draw_shape_loop_start

; Restore registers and zero bytes and return
pla
staz  .shape_coords
pla
staz  .shape_coords 1
pla
tay
pla
tax
pla
rts
; -------------------- End subroutine --------------------


; Subroutine to convert line index (0-191) into line address
; Input:  line index in X
; Output: two-byte line address in ".line_address"
; A, X, and Y are either not used or restored on exit.
zbyte line_address 2

; Data used to convert line indices to line addresses
.line_address_high_bytes
data 2024282C3034383C

.line_address_offsets ; 2-byte addresses in little endian format
data 00008000000180010002800200038003                                                                                                              
data 2800A8002801A8012802A8022803A803                                                                                                              
data 5000D0005001D0015002D0025003D003                

; Subroutine start
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
; -------------------- End subroutine --------------------

