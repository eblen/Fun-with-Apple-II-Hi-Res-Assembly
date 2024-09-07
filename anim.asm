; Various codes for hi-res graphics, including useful subroutines, code to test
; them, and games that rely on them.

; Shape tables

org 6000

; Man and woman
.man_and_woman_shape_table
data 000603081C003E2A005D08001C5D00141400222200

org 6020

.snake_segment
data 0004022800280028002800
label bits_per_snake_segment 04

org 6100

; ------------------------- Code to test subroutines -------------------------
; Code to test moving of shapes horizontally. The result should be a tiny image
; of a man and woman, roughly in the middle of the screen, that moves from far
; left to far right, comes back, and repeats. Movement is made smooth by using
; the shape-shifting subroutine.

; Initialize graphics and data tables
jsra  .init_hires_graphics
jsra  .create_div7_table

; -------------------- Set shape and draw constants --------------------
label shape_addr_h 60
label shape_addr_l 00
label xcoord 50
label delay  80
label wait   FCA8

; Store shape information
ldai  .shape_addr_l
staz  .shape_table_addr
ldai  .shape_addr_h
staz  .shape_table_addr 1
ldai  .xcoord
staz  .shape_coords
ldai  00
staz  .shape_coords 1
; -------------------- End set shape and draw constants --------------------


; -------------------- Main loop --------------------
; Compute number of iterations to move shape across screen (.num_steps)

; Compute negative of width in number of pixels
; Y is unused except for erase subroutine call, so go ahead and set it.
ldaa  .man_and_woman_shape_table 2
tay
asl
asl
asl
eori  FF
clc
adci  02

; Add number of columns (255)
clc
adci  FF

zbyte num_steps
staz  .num_steps
tax ; loop counter


; Main loops (one for moving right and one for moving left)

; Loop that moves shape right
.main_loop_move_right

; Draw new shape
jsra  .draw_shape
ldai  .delay
jsra  .wait

dex
dex
beq   .main_loop_move_left


txa ; Preserve X and Y
pha
tya
pha

; Shift shape table for next coordinate
ldxz  .shape_coords 1
inx
inx
jsra  .shift_shape_table

; Restore Y
pla
tay

; Erase previous shape
ldxa  .man_and_woman_shape_table 1
jsra  .erase_square

incz  .shape_coords 1
incz  .shape_coords 1

pla ; Restore X
tax

bne   .main_loop_move_right ; always jumps

; Loop that moves shape left
.main_loop_move_left

; Draw new shape
jsra  .draw_shape
ldai  .delay
jsra  .wait

inx
inx
cpxz  .num_steps
beq   .main_loop_move_right

txa ; Preserve X and Y
pha
tya
pha

; Shift shape table for next coordinate
ldxz  .shape_coords 1
dex
dex
jsra  .shift_shape_table

; Restore Y
pla
tay

; Erase previous shape
ldxa  .man_and_woman_shape_table 1
jsra  .erase_square

decz  .shape_coords 1
decz  .shape_coords 1

pla ; Restore X
tax

bne   .main_loop_move_left ; always jumps

; Just freeze if we ever get here (depends on if above loop is infinite)
jsra  .draw_shape
.finished
jmpa  .finished
; -------------------- End main loop --------------------
; -------------------- End code to test subroutines --------------------

org 6200

; -------------------- Snake Game --------------------
label down  00
label up    01
label right 02
label left  03
label i E9
label j EA
label k EB
label l EC

; Snake data structure
; 0:    X coordinate of head
; 1:    Y coordinate of head
; 2:    Head direction
; 3:    X coordinate of tail
; 4:    Y coordinate of tail
; 5:    Tail direction
; 6:    length of snake's body, excluding the head
; 7-31: body segments (2 bits per segment, indicating its position relative to
;                      the prior segment or to the head for the first segment)
;       0: down
;       1: up
;       2: right
;       3: left
; Snake body can be from 0-100 segments long (head is always present)
zbyte snake_data 32 ; zbyte lengths are in decimal. SASM is inconsistent in
                    ; this case, since all other values are hexadecimal.
label snake_segments_offset 07

; Initialize graphics and data tables
jsra  .init_hires_graphics
jsra  .create_div7_table

; Draw a sample snake to start
ldai  20 ; X coordinate
staz  .snake_data
ldai  20 ; Y coordinate
staz  .snake_data 1
ldai  .up ; Set "up" as initial head direction
staz  .snake_data 2
ldai  FF ; X coordinate for tail... value doesn't really matter
staz  .snake_data 3
ldai  FF ; Y coordinate for tail... value doesn't really matter
staz  .snake_data 4
ldai  FF ; Tail direction... value doesn't really matter
staz  .snake_data 5
ldai  0C ; length 12
staz  .snake_data 6
ldai  F0 ; 2 left, 2 down
staz  .snake_data 7
ldai  AA ; 4 right
staz  .snake_data 8
ldai  55 ; 4 up
staz  .snake_data 9

; Input: Zero-page shape table address (not table itself) in "shape_table_addr"
;        Zero-page shape coordinates in "shape_coords" ([0, 191] and [0-255])
;        (pixel coordinates for horizontal, which are converted to byte
;         coordinates internally as needed)

; Initialize shape table and coordinates
ldai  20
staz  .shape_table_addr
ldai  60
staz  .shape_table_addr 1
ldaz  .snake_data
staz  .shape_coords
ldaz  .snake_data 1
staz  .shape_coords 1


; Store step size for snake's vertical and horizontal movement.
; Vertical step size is just the height. Horizontal step size is in bits
; (pixels). It depends on how many bits are used for the snake segment, a number
; less than width * 8, which includes padding bits (for frame shifting). So
; we define that as a label below the shape table (see above).
zbyte snake_vertical_step
ldaa  .snake_segment 1
staz  .snake_vertical_step

; Currently, we use 4 bits for the segment.
zbyte snake_horizontal_step
ldai  .bits_per_snake_segment
staz  .snake_horizontal_step

; First drawing of snake, which is done once to draw head and all segments
; Registers
; X: segment pattern (4 segments per byte)
; Y: loop counter (segment index)

; Loop to draw snake
ldyi  FF
.draw_next_segment

; First iteration will draw the head of the snake rather than a segment
txa
pha
tya
pha
ldxz  .shape_coords 1
jsra  .shift_shape_table
jsra  .draw_shape
pla
tay
pla
tax

; Bail if no more segments to draw
iny
cpyz  .snake_data 6 ; length of snake
beq   .end_drawing_of_snake_segments

; Load new segment pattern every 4th iteration (includes first iteration)
tya
andi  03
bne   .keep_current_segment_byte

; Compute segment index
tya
lsr
lsr
clc
adci  .snake_segments_offset
tax

; Load segment pattern into X
ldazx .snake_data
tax
; End load new segment pattern
.keep_current_segment_byte

; Move segment based on leftmost two bits of X
txa

; First, though, copy direction to tail position direction
; (Only last iteration's value is actually needed.)
staz  .snake_data 5
lsrz  .snake_data 5
lsrz  .snake_data 5
lsrz  .snake_data 5
lsrz  .snake_data 5
lsrz  .snake_data 5
lsrz  .snake_data 5

clc
rol
bcs   .move_segment_left_or_right

; Move up or down
rol
tax ; Store segment pattern for next iteration (rotated left twice)
ldaz  .shape_coords
bcs   .move_segment_up
adcz  .snake_vertical_step
staz  .shape_coords
bcc   .end_move_segment ; should always jump
.move_segment_up
sbcz  .snake_vertical_step
staz  .shape_coords
bcs   .end_move_segment ; should always jump

; Move left or right
.move_segment_left_or_right
rol
tax ; Store segment pattern for next iteration (rotated left twice)
ldaz  .shape_coords 1
bcs   .move_segment_left
adcz  .snake_horizontal_step
staz  .shape_coords 1
bcc   .end_move_segment ; should always jump
.move_segment_left
sbcz  .snake_horizontal_step
staz  .shape_coords 1
.end_move_segment
jmpa  .draw_next_segment
.end_drawing_of_snake_segments
; end drawing of snake segments

; Store tail coordinates needed in main loop
ldaz .shape_coords
staz .snake_data 3
ldaz .shape_coords 1
staz .snake_data 4

; -------------------- Main Snake Game Loop --------------------
.snake_game_main_loop

; Pause between drawing and moving
ldai  FF
jsra  .wait

; -------------------- Move Snake Head --------------------
; Change direction if a valid key is pressed
; Currently, we use i,k,j,l (up, down, left, and right respectively)

; Check for valid key press and change head direction if found
; Suggestion: This could be implemented as a loop through a data structure
; mapping keys to directions, making it easier to change the key map.
; Registers
; A: Next head direction
; X: Key pressed (return value from subroutine)
jsra  .check_for_keyboard_input

ldaz  .snake_data 2 ; A gets old direction by default

cpxi  .i
bne   .key_is_not_up
ldai  .up
jmpa  .end_map_key_to_new_head_direction

.key_is_not_up
cpxi  .k
bne   .key_is_not_up_or_down
ldai  .down
jmpa  .end_map_key_to_new_head_direction

.key_is_not_up_or_down
cpxi  .j
bne   .key_is_not_up_or_down_or_left
ldai  .left
jmpa  .end_map_key_to_new_head_direction

.key_is_not_up_or_down_or_left
cpxi  .l
bne   .end_map_key_to_new_head_direction
ldai  .right
.end_map_key_to_new_head_direction
staz  .snake_data 2 ; Store new direction

; Move head according to direction
; Registers
; A: coordinate (either X or Y)
; X: head direction from snake data structure
ldaz  .snake_data   ; X coordinate
ldxz  .snake_data 2 ; Head direction
cpxi  .up
bne   .dir_is_not_up
sec
sbcz  .snake_vertical_step ; up
staz  .snake_data
jmpa  .end_check_for_user_input

.dir_is_not_up
cpxi  .down
bne   .dir_is_not_up_or_down
clc
adcz  .snake_vertical_step ; down
staz  .snake_data
jmpa  .end_check_for_user_input

.dir_is_not_up_or_down
ldaz  .snake_data 1 ; Y coordinate
cpxi  .left
bne   .dir_is_not_up_or_down_or_left
sec
sbcz  .snake_horizontal_step ; left
staz  .snake_data 1
jmpa  .end_check_for_user_input

.dir_is_not_up_or_down_or_left
cpxi  .right
bne   .end_check_for_user_input
clc
adcz  .snake_horizontal_step ; right
staz  .snake_data 1
.end_check_for_user_input

; ------------------ End Move Snake Head ------------------

; ------------ Check if screen bounds reached ------------

ldaz  .snake_data
; Top of screen
cmpi  FF
beq   .snake_game_over

; Bottom of screen
cmpi  BF ; 191 decimal
beq   .snake_game_over

ldaz  .snake_data 1
; Left or right boundary
cmpi  00
beq   .snake_game_over
bne   .snake_game_continues
; ---------- End Check if screen bounds reached ----------

; -------------------- Game over --------------------
; For now, just pause
; Place code here, instead of outside the main loop, so that relative branching
; can be used.
.snake_game_over
jmpa  .snake_game_over
; ------------------ End Game over ------------------
.snake_game_continues

; ------------------ Move Snake Segments ------------------
; Move snake by right-shifting segment bytes
; Registers
; X: Snake data byte number
; Y: Outer loop counter (rotate twice since there are two bits per segment)

; Compute last byte of snake data (snake length + 3)
ldaz  .snake_data 6
clc
adci  03
lsr
lsr
clc
adci  .snake_segments_offset
zbyte snake_data_end_byte
staz  .snake_data_end_byte

; Initialize X and Y
ldxi  .snake_segments_offset
ldyi  02

; Inner loop to rotate bytes
.shift_segment_bytes_outer_loop
clc

.shift_segment_bytes_inner_loop
txa
eorz  .snake_data_end_byte ; Compare here in case length is zero
                           ; Use eor to preserve the carry flag
beq   .end_shift_segment_bytes_inner_loop
ldazx .snake_data
ror
stazx .snake_data
inx
bne   .shift_segment_bytes_inner_loop ; always jumps
.end_shift_segment_bytes_inner_loop

; Check if one more outer loop is needed (2 total)
ldxi  .snake_segments_offset
dey
bne   .shift_segment_bytes_outer_loop
; End segment shifting

; Set first segment direction to opposite of head direction
; Note: Needs to abort if length is zero
ldaz  .snake_data 2
eori  01 ; Set to opposite direction
clc
ror
ror
ror
oraz  .snake_data 7
staz  .snake_data 7
; ---------------- End Move Snake Segments ----------------

; -------------- Draw snake (just draw head and erase tail) --------------

; Draw head
ldxz  .snake_data
stxz  .shape_coords
ldxz  .snake_data 1
stxz  .shape_coords 1
jsra  .shift_shape_table
jsra  .detect_collision
cmpi  00
bne   .snake_game_over
jsra  .draw_shape

; Erase tail
ldxz  .snake_data 3
stxz  .shape_coords
ldxz  .snake_data 4
stxz  .shape_coords 1
jsra  .shift_shape_table
jsra  .erase_shape

; Store new tail coordinates based on old tail direction.
; Note that new tail position is opposite of old tail direction
; (So decrement for "right" and increment for "left" for example.)
ldaz  .snake_data 5
lsr
bcs   .old_tail_is_up_or_left
lsr
bcs   .old_tail_is_right
ldaz  .snake_data 3
sec
sbcz  .snake_vertical_step ; down
staz  .snake_data 3
bcs   .end_set_new_tail ; always jumps
.old_tail_is_right
ldaz  .snake_data 4
sbcz  .snake_horizontal_step ; right
staz  .snake_data 4
bcs   .end_set_new_tail ; always jumps
.old_tail_is_up_or_left
lsr
bcs   .old_tail_is_left
ldaz  .snake_data 3
adcz  .snake_vertical_step ; up
staz  .snake_data 3
bcc   .end_set_new_tail ; always jumps
.old_tail_is_left
ldaz  .snake_data 4
clc
adcz  .snake_horizontal_step ; left
staz  .snake_data 4
.end_set_new_tail

; Store new tail direction

; Compute index of pattern (byte) containing tail
ldaz  .snake_data 6 ; snake length
sec
sbci  01
lsr
lsr
clc
adci  .snake_segments_offset

; Load pattern to X
tax
ldazx .snake_data
tax

; Compute exact location of tail in this byte
ldaz  .snake_data 6 ; snake length
sec
sbci  01
andi  03
eori  03
tay
iny
txa

; Shift tail bits to the end
dey
beq  .end_shift_tail_pattern
.shift_tail_pattern
lsr
lsr
dey
bne  .shift_tail_pattern
.end_shift_tail_pattern

; Store result
andi  03
staz  .snake_data 5

; ------------------ End draw snake ------------------

jmpa .snake_game_main_loop

; ------------------ End Snake Game ------------------


; ---------------- Begin subroutines ----------------
org 7000

; Subroutines to handle drawing, erasing, and frame-shifting of shape tables

; Subroutine to draw, erase, or detect collision of a shape described by a
; shape table with three entry points:
; ".draw_shape" or ".erase_shape" or ".detect_collision"
; Both draw and erase are "careful" in that only pixels set in the shape table
; are affected. Draw does no erasing and erase does no drawing nor does it erase
; pixels not set in the shape table. This improves on "eor" drawing and erasing,
; which can destroy other shapes and requires alternating drawing and erasing.

; Currently, collision detection just indicates any collision of the shape with
; another object (a pixel that is set both in the shape table and already in the
; screen buffer). Later, more information about the collision will be returned.

; Input:  Zero-page shape table address (not table itself) in "shape_table_addr"
;         Zero-page shape coordinates in "shape_coords" ([0, 191] and [0-255])
;         (pixel coordinates for horizontal, which are converted to byte
;          coordinates internally as needed)
; Output: none except for collision detection
;         A: whether collision occurred (0: no, non-zero: yes)
; All registers and zbytes are restored except A when doing collision detection.
zbyte shape_table_addr 2
zbyte shape_coords     2
zbyte draw_or_erase_or_dc ; Draw or erase shape or detect collision?
                          ; 0: draw, $40: erase, $C0: detect collision
                          ; Bits 6 and 7 are readable by the "bit" op

; Subroutine start
; Set whether to draw or erase based on subroutine entry point
.draw_shape
pha
ldai  00
staz  .draw_or_erase_or_dc
beq   .finish_setting_shape_subroutine_op

.erase_shape
pha
ldai  40
staz  .draw_or_erase_or_dc
bne   .finish_setting_shape_subroutine_op

.detect_collision
ldai  C0
staz  .draw_or_erase_or_dc
.finish_setting_shape_subroutine_op

; Save registers and zero bytes
txa
pha
tya
pha
ldaz  .shape_coords 1
pha
ldaz  .shape_coords
pha

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

; Now we can start drawing, erasing, or detecting a collision
.draw_shape_loop_start
jsra  .line_index_to_address

; Do actual drawing, erasing, or detecting
.draw_shape_table_load_instr
ldaa  0000
bitz  .draw_or_erase_or_dc

; Use overflow flag, which is unchanged by logical operations
bvs   .erase_shape_table_bytes_or_dc

; Careful draw: Do no erasing of other pixels
orany .line_address
bvc   .store_new_screen_byte ; always jumps

; Careful erase: Only erase pixels set in the shape table
; Formula is (not B) & A where B is the shape table pattern
; and A is the existing pattern.
.erase_shape_table_bytes_or_dc

bitz  .draw_or_erase_or_dc
bmi   .detect_shape_table_collision
eori  FF
andny .line_address

.store_new_screen_byte
stany .line_address
jmpa  .skip_shape_table_collision_detection ; always jumps
                                            ; no suitable flag for relative jump!

.detect_shape_table_collision
; Running out of registers! Need another storage byte.
zbyte shape_subroutine_tmp_byte
staz  .shape_subroutine_tmp_byte

; Save X and Y to stack
txa
pha
tya
pha

; Set X and Y for subroutine call
ldxz  .shape_subroutine_tmp_byte ; shape table byte
ldany .line_address ; screen byte
tay

; Call subroutine and save return value in tmp byte
jsra  .check_for_byte_collision
staz  .shape_subroutine_tmp_byte

; Restore X and Y
pla
tay
pla
tax

; Now handle collision
ldaz  .shape_subroutine_tmp_byte
bne   .end_shape_table_subroutine

.skip_shape_table_collision_detection
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

; Set no collision in case this is collision detection
ldai  00

.end_shape_table_subroutine
; Restore registers and zero bytes and return
tax ; In case we need to return A
pla
staz  .shape_coords
pla
staz  .shape_coords 1
pla
tay

; For collision detection, return A rather than restoring it
bitz .draw_or_erase_or_dc
bpl  .no_return_value_from_shape_subroutine

pla ; saved X value
; Swap A and X and return
staz .shape_subroutine_tmp_byte
txa
ldxz .shape_subroutine_tmp_byte
rts

; For other cases, restore registers normally
.no_return_value_from_shape_subroutine
pla
tax
pla
rts
; -------------------- End subroutine --------------------


; Subroutine to erase a square on the screen.
; This is a simpler version of the draw/erase subroutine, because we only need
; to fill in zeroes and do not need a shape table. However, this means ALL
; pixels are erased in the square, unlike ".erase_shape."
; Input: Zero-page shape coordinates in "shape_coords" ([0, 191] and [0-255])
;        (pixel coordinates for horizontal, which are converted to byte
;         coordinates internally as needed)
;        X: Height of shape in bytes
;        Y: Length of shape in bits
; All registers and zbytes are restored.

; Subroutine start
.erase_square

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

; Set X and maximum X (in .shape_coords)
txa
ldxz  .shape_coords
clc
adcz  .shape_coords
staz  .shape_coords

; Compute starting coordinate (in bytes) for Y
tya ; Save width for later
pha
ldyz  .shape_coords 1
ldaay .div7_table_addr

zbyte y_start
staz  .y_start
tay

; Set Y and maximum Y (in .shape_coords + 1 in bytes)
pla ; width
clc
adcz  .y_start
staz  .shape_coords 1

; Now we can start erasing
.erase_square_loop_start
jsra  .line_index_to_address

; Write to screen
ldai  00
stany .line_address

; Check for end of row
iny
cpyz  .shape_coords 1
bne   .erase_square_loop_start

; Reset row and check if this is last row
ldyz  .y_start
inx
cpxz  .shape_coords
bne   .erase_square_loop_start

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

; Do the shifting. Afterwards, restore bit 7 and set bit 6 to the shifted in
; value. In other words, swap bits 6 and 7.
.shift_shape_table_left_load_instr
ldaay 0000
ror
jsra  .swap_bits_6_and_7
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
stxa  .shift_shape_table_right_load_instr  1
stxa  .shift_shape_table_right_store_instr 1
ldxz  .shape_table_addr 1
stxa  .shift_shape_table_right_load_instr  2
stxa  .shift_shape_table_right_store_instr 2

; Initialize X (Y = 0 already)
ldai  00
tax

.shift_right_middle_loop
clc
.shift_right_inner_loop

; Do the shifting. First, though, make sure bit 7 is preserved and bit 6 gets
; put into the carry. In other words, swap bits 6 and 7.
.shift_shape_table_right_load_instr
ldaa  0000
jsra  .swap_bits_6_and_7
rol
.shift_shape_table_right_store_instr
staa  0000
   
; Increment above addresses for next loop
inca  .shift_shape_table_right_load_instr  1
inca  .shift_shape_table_right_store_instr 1
bne   .no_shape_table_addr_overflow_while_shifting_right
inca  .shift_shape_table_right_load_instr  2
inca  .shift_shape_table_right_store_instr 2
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


; Useful subroutines for dealing with hi-res graphics

; Subroutine to initialize Hi-Res graphics mode
.init_hires_graphics

label graphics  C050
label hires     C057
label page1     C054
label mixoff    C052

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
rts
; -------------------- End subroutine --------------------


; Subroutine to create table of div 7 values
; Code to make a table of dividends of 7, which occupies page 8 ($800 to $8FF).
; This table is useful for pixel calculations (horizontal) in hi-res since,
; annoyingly, each byte in hi-res memory represents 7 pixels rather than 8.

; The table only goes to 255 rather than 279. However, this is not much of a
; limitation because these values are used for starting addresses for shapes,
; which leaves three bytes for the shape width.

; Warning: This must be done after initializing hi-res graphics or "anomalies"
; appear in the graphics. Not sure why, but it has to do with where the table
; is stored, which relates to lo-res graphics.
.create_div7_table

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
rts
; -------------------- End subroutine --------------------


; Subroutine to swap bits 6 and 7
; This is very useful for hi-res graphics when shifting shape tables, either
; before a left shift or after a right shift. We often want to preserve bit 7
; (color information) and either shift out or shift in bit 6, which is part of
; the shape.
; Input:  A
; Output: A with bits swapped
; Status flags are preserved
.swap_bits_6_and_7

; Algorithm is to xor with 11000000 when the two bits differ (when A is in the
; range [01000000, 10111111]).
php
cmpi  40
bcc   .exit_bit_swap_subroutine
cmpi  C0
bcs   .exit_bit_swap_subroutine
eori  C0 ; Flip bits 6 and 7
.exit_bit_swap_subroutine
plp
rts

; Subroutine to check for and read keyboard input
; Similar to KEYIN except that it only checks for input once.
; Input:  none
; Output: X: key value or 00 if none
.check_for_keyboard_input
label KBD     C000
label KBDSTRB C010

ldxi  00
bita  .KBD
bpl   .end_check_for_keyboard_input
ldxa  .KBD
bita  .KBDSTRB

.end_check_for_keyboard_input
rts

; Subroutine to check for collision of a shape table
; Input: Zero-page shape table address (not table itself) in "shape_table_addr"
;        Zero-page shape coordinates in "shape_coords" ([0, 191] and [0-255])
;        (pixel coordinates for horizontal, which are converted to byte
;         coordinates internally as needed)
.check_for_shape_table_collision


; Subroutine to detect collision between two color bytes
; Input: X: first byte
;        Y: second byte
; Output: A: whether there was a collision (0: no, non-zero: yes)
; This subroutine assumes only a single color per byte.
; Strategy is to zero the color bit (bit 7), rendering it irrelevant,
; and then shift bytes that are on odd columns so that any combination of
; odd and even columns can be compared.
.check_for_byte_collision
zbyte color_bytes_modified 2

; Modify byte 1
txa
andi  7F ; zero color bit
stxz  .color_bytes_modified
andi  55 ; 01010101 (test if an even column is set)
bne   .color_byte_1_is_on_even_columns
clc
rolz  .color_bytes_modified
.color_byte_1_is_on_even_columns

; Modify byte 2
tya
andi  7F ; zero color bit
styz  .color_bytes_modified 1
andi  55 ; 01010101 (test if an even column is set)
bne   .color_byte_2_is_on_even_columns
clc
rolz  .color_bytes_modified 1
.color_byte_2_is_on_even_columns

; Compare them
ldaz  .color_bytes_modified
andz  .color_bytes_modified 1
rts

