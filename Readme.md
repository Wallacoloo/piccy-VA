Piccy-VA: A monophonic virtual-analog synthesizer with 5-voice detune for Microchip's dsPIC33FJ128GP802, coded in PIC assembly.

Sound
------
Each note is comprised of 5 oscillators that are each slightly detuned from the primary frequency, summed together and enveloped by a linear Attack-Decay-Sustain-Release (ADSR) envelope.

Each oscillator is a (configurable) linear combination of a square, sawtooth, and sinewave.

The audio is then output (in mono) using the PIC's builtin DAC, running at 43.2 kHz.

I/O
------

One of eight notes (one octave of the A-minor scale) can be triggered by pulling the appropriate
pin *low* on RB0-RB7, and then released by pulling it high.

Audio is output across RB12 and RB13.

An external 22.1184 MHz crystal is expected to be placed across RA2-RA3.

Etc
------

These files were recovered from a backup and imported to git - the original files date to early 2013. The build script / Makefile is missing, but the original project was created in MPlab and should build OK if compiled alongside the `p33FJ128GP802.inc` file that ships with MPlab.
