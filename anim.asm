; Code to test moving of shapes horizontally. The result should be a tiny image
; of a man and woman, roughly in the middle of the screen, that moves from far
; left to far right. Movement should now be smooth with the new shape shifting
; subroutine.

; Shape table (man and woman)
org 5FEB
.shape_table
data 000603081C003E2A005D08001C5D00141400222200

org 6000

; -------------------- Initialize graphics mode --------------------
label graphics  C050
label hires     C057
label page1     C054
label mixoff    C052
label target    2000
label num_lines C0
label num_cols  FF

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
label shape_addr_l EB
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
; -------------------- End set shape and draw constants --------------------


; -------------------- Main loop --------------------
; Compute number of iterations to move shape to end of screen

; Compute negative of width in number of pixels
ldaa  .shape_table 2
asl
asl
asl
eori  FF
clc
adci  01

; Combine with total number of columns and coordinate
clc
adci  .num_cols
sec
sbci  .ycoord

; Main loop. Move shape.
.main_loop_start
jsra  .draw_shape
pha
ldai  .delay
jsra  .wait
jsra  .wait
jsra  .wait
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
;        (pixel coordinates for horizontal, which are converted to byte
;         coordinates internally as needed)
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

; Shift shape
; Do first since subroutine does not preserve registers
ldxz  .shape_coords 1
jsra  .shift_shape_table

; Set shape table address in load instruction.
; Warning: We only increment address low byte by two to get to raw shape data.
; This will not work if the low byte overflows or if we add more header data.
; TODO: Create a more robust solution for this problem.
ldxz  .shape_table_addr
inx
inx
inx
stxa  .draw_shape_table_load_instr 1
ldaz  .shape_table_addr 1
staa  .draw_shape_table_load_instr 2

; Set X and maximum X (in .shape_coords)
ldai  01
tay
ldxz  .shape_coords
txa
clc
adcny .shape_table_addr
staz  .shape_coords

; Save starting coordinate (in bytes) for Y
ldyz  .shape_coords 1
ldaay .div7_table_addr

zbyte y_start
staz  .y_start

; Set maximum Y (in .shape_coords + 1 in bytes)
ldai  02
tay
ldaz  .y_start
clc
adcny .shape_table_addr
staz  .shape_coords 1

; Finally, set Y
ldyz  .y_start

; Now we can start drawing
.draw_shape_loop_start
jsra  .line_index_to_address

; Write to screen
.draw_shape_table_load_instr
ldaa  0000
eorny .line_address
stany .line_address

; Increment above load address for next loop
inca  .draw_shape_table_load_instr 1
ldaa  .draw_shape_table_load_instr 1
bne   .no_shape_table_addr_overflow_while_drawing
inca  .draw_shape_table_load_instr 2
.no_shape_table_addr_overflow_while_drawing

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

; Subroutine to shift a shape table for a given column
; Input:  Zero-page shape table address (not table itself) in "shape_table_addr"
;         Column in X
; Output: Shape table is shifted for drawing at the given column 
; Note:   Does not preserve registers. shape_table_addr is not changed.
.shift_shape_table

; Store shape table size now while A and Y are free
zbyte shape_table_size 2
ldai  01
tay
ldany .shape_table_addr
staz  .shape_table_size
iny
ldany .shape_table_addr
staz  .shape_table_size 1

; Set Y = 0 and A = X (column)
ldai  00
tay
txa

; Compute shift value from column C, which is C % 7
; Formula is C % 7 = ( (C % 8) + (C / 7) ) % 8
andi  07
clc
adcax .div7_table_addr
andi  07

; Compare old and new shift values and use different routines for shift left vs
; shift right. Store the difference in "shift_counter" and don't forget to
; store new shift value into shape table when done.

; cache new shift value
tax

; Compute and store the difference
sec
sbcny .shape_table_addr
zbyte shift_counter
staz  .shift_counter

; Store new shift value to shape table
txa
stany .shape_table_addr

; Branch to correct routine
; The two routines are very similar, differing mostly in the opcodes used
; (adc vs sbc, rol vs ror, inc vs dec, bmi vs bpl, etc.)
bcs   .shift_right_outer_loop

; Routine for shifting left
decz  .shift_counter

.shift_left_outer_loop
incz  .shift_counter
bpl   .end_left_shifting

; Initialize shape table address in two instructions
; Warning: We only increment address low byte by three to get to raw shape data.
; This will not work if the low byte overflows or if we add more header data.
; TODO: Create a more robust solution for this problem.
ldxz  .shape_table_addr
inx
inx
inx
stxa  .shift_shape_table_left_load_instr   1
stxa  .shift_shape_table_left_store_instr  1
ldxz  .shape_table_addr 1
stxa  .shift_shape_table_left_load_instr   2
stxa  .shift_shape_table_left_store_instr  2

; Initialize X and Y.
ldai  00
tax
ldyz  .shape_table_size 1
dey

.shift_left_middle_loop
clc
.shift_left_inner_loop

; Do the shifting. Because only 7 bits are used for the shape, we manually
; set the carry for the next rotation based on the new value of bit 7. Ignore
; bit 7 otherwise, but this will probably change once we start handling colors.
.shift_shape_table_left_load_instr
ldaay 0000
ror
bpl   .no_carry_on_left_shift
orai  40
bne   .carry_on_left_shift
.no_carry_on_left_shift
andi  BF
.carry_on_left_shift
.shift_shape_table_left_store_instr
staay 0000
   
; Check for end of row
dey
bpl   .shift_left_inner_loop

; Increment above addresses for next inner loop
ldaa  .shift_shape_table_left_load_instr 1
clc
adcz  .shape_table_size 1
staa  .shift_shape_table_left_load_instr  1
staa  .shift_shape_table_left_store_instr 1
bvc   .no_shape_table_addr_overflow_while_shifting_left
inca  .shift_shape_table_left_load_instr  2
inca  .shift_shape_table_left_store_instr 2
.no_shape_table_addr_overflow_while_shifting_left

; Reset row and check if this is last row
; Use eor to preserve the carry flag
ldyz  .shape_table_size 1
dey
inx
cpxz  .shape_table_size
bne   .shift_left_middle_loop

; Start over in case another shift is needed
beq   .shift_left_outer_loop

.end_left_shifting
rts

; Routine for shifting right
.shift_right_outer_loop

decz  .shift_counter
bmi   .end_right_shifting

; Initialize shape table address in two instructions
; Warning: We only increment address low byte by three to get to raw shape data.
; This will not work if the low byte overflows or if we add more header data.
; TODO: Create a more robust solution for this problem.
ldxz  .shape_table_addr
inx
inx
inx
stxa  .shift_shape_table_right_instr 1
stxa  .shift_shape_table_right_instr 4
ldxz  .shape_table_addr 1
stxa  .shift_shape_table_right_instr 2
stxa  .shift_shape_table_right_instr 5

; Initialize X (Y = 0 already)
ldai  00
tax

.shift_right_middle_loop
clc
.shift_right_inner_loop

; Do the shifting. Because only 7 bits are used for the shape, we manually
; set the carry for the next rotation based on the new value of bit 7. Ignore
; bit 7 otherwise, but this will probably change once we start handling colors.
.shift_shape_table_right_instr
rola  0000
bita  0000
clc
bpl   .no_carry_on_right_shift
sec
.no_carry_on_right_shift
   
; Increment above addresses for next loop
inca  .shift_shape_table_right_instr 1
inca  .shift_shape_table_right_instr 4
bne   .no_shape_table_addr_overflow_while_shifting_right
inca  .shift_shape_table_right_instr 2
inca  .shift_shape_table_right_instr 5
.no_shape_table_addr_overflow_while_shifting_right

; Check for end of row
; Use eor to preserve the carry flag
iny
tya
eorz  .shape_table_size 1
bne   .shift_right_inner_loop

; Reset row and check if this is last row
ldai  00
tay
inx
cpxz  .shape_table_size
bne   .shift_right_middle_loop

; Start over in case another shift is needed
beq   .shift_right_outer_loop

.end_right_shifting
rts

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

