; Subroutine to play a given sound (pitch) for a given length of time along
; with a main loop to test it.
;
; The subroutine attempts to normalize the sound durations so that they all
; play roughly the same length of time for a given length value. It also
; tries to create a useful range of sounds and lengths. It is not perfect,
; though. High notes (< 0x10) have short lengths, low notes near the upper
; range are hard to tell apart, and lengths are not exactly the same duration
; for each note.
;
; To test, set the label values below and call the main routine (0x6000)
; or call the subroutine directly (0x7000) after setting X and Y.
org 6000

label first_pitch 10
label last_pitch  D0
label pitch_step  08
label tone_length 80

ldai  .first_pitch
.sound_test_main_loop
pha
tax
ldyi  .tone_length
jsra  .play_sound
pla
clc
adci  .pitch_step
cmpi  .last_pitch
bcc   .sound_test_main_loop
rts

org 7000

; Subroutine to play a given sound (pitch) for a given length of time
; Input:  X: pitch Y: length
.play_sound

; Values for AND'ing with BIT instruction
; Necessary because BIT does not support immediate values.
zbyte bit_mask_3
zbyte bit_mask_7
ldai  03
staz  .bit_mask_3
ldai  07
staz  .bit_mask_7

; Compute decrement (amount to decrease time remaining on each outer loop)
; This is a coarse-grained approach since each group of 16 pitches will have
; the same decrement.
zbyte decrement
txa
clc
lsr
lsr
lsr
lsr
staz  .decrement

; Make sure decrement > 0
; This keeps high pitches from running forever but, unfortunately, also makes
; them too short.
bne   .decrement_not_zero
ldai  01
staz  .decrement
.decrement_not_zero

; Store pitch and put time remaining on stack
zbyte sound_pitch
stxz  .sound_pitch
tya
pha
ldyi  00

; Main Loop
; Registers:
; A: modulo counter for inner loop (to slow down decrementing X)
; X: index for inner loop
; Y: modulo counter for outer loop (to slow down decrementing A)
; Outer loop
.sound_outer_loop
; Actually toggle speaker
bita  30C0

; A becomes modulo counter (when to decrement X)
ldai  01

clc
; Inner loop. Delay for toggling speaker.
.speaker_delay
adci  01
bitz  .bit_mask_3
bne   .speaker_delay
dex
bne   .speaker_delay
; End inner loop

; Set X for next inner loop
ldxz  .sound_pitch

; Check if we should decrement time remaining on this iteration
iny
tya
bitz  .bit_mask_7
bne   .sound_outer_loop

; Adjust time remaining. Bail once it reaches zero.
pla
sec
sbcz  .decrement
pha
bcs   .sound_outer_loop
pla
rts

