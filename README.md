# Code for Hi-Res Graphics and Audio on Apple II

This repository includes subroutines and applications for
Hi-Res graphics and audio on Apple II. The code is written
in SASM assembler (see my "SASM-simple-6502-assembler"
repository) and consists of two files:

## anim.asm:

The main file, which contains subroutines for more easily
working with hi-res graphics, a test application at $6000,
and a snake game (in progress) at $6200. The subroutines
begin at $7000 and support drawing, erasing, frame-shifting,
and collision detection of hi-res color graphics.

## audio.asm:

An attempt to make it easier to play notes and tones on the
Apple II. The subroutine for playing notes begins at $7000,
a testing routine is at $6000, and a program to play "Happy
Birthday" is at $6100. I used the pitch detector (below) to
figure out values for each note.

## Usage:

Usage is similar to the description in the Apple II README
from the SASM project, except that I currently use the
Virtual II emulator, which has a wonderful debugger (called
the "Inspector"). I now use the Apple IIe ROM, which has one
additional step since it boots into the BASIC prompt.
Execute "call -151" to get to the monitor, where the machine
code output by SASM can be pasted (under the "edit" menu).
Be sure to turn the color monitor on and set the speed high,
temporarily, to paste the code much faster. Finally, of
course, run the code from the above addresses (type
"6200G", for example, instead of "A00G").

# Resources

Virtual ][ (emulator) at
*https://virtualii.com/*
Copyright Gerard Putter

*Hi-Res Graphics and Animation Using Assembly Language*
by Leonard I. Malkin

Pitch Detector at
*https://www.onlinemictest.com/tuners/pitch-detector/*
Copyright Online Mic Test

*Apple II Monitors Peeled*
by W. E. Dougherty

