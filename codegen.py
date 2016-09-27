#!/usr/bin/python2
"""Script used to generate wavetables and lookup-tables needed for the assembly code
"""

S_RATE = 43200. # audio samples per second
def genSineWave(numPoints, amp):
    """Evaluate one cycle of `amp*sin(t)` at n=numPoints points
    """
    from math import sin, pi
    for i in xrange(numPoints):
        p = int(round(amp*sin(2*pi*i/numPoints)))
        yield p

def printSineWave(numPoints, amp, padding="\t"):
    """Create the assembly .words for a sine wave table
    """
    for p in genSineWave(numPoints, amp):
        print padding + ".word " + hex(p)

def genNoteFrequencies():
    """Solve for the frequency, in Hertz, of N notes, starting at C3
    """
    for i in xrange(32):
        yield 440 * 2**((i+3-12)/12.)
def genNoteInvFrequencies():
    for f in genNoteFrequencies():
        yield int(round(f / S_RATE * 2**24))
def printNoteInvFrequencies(padding="\t"):
    """Create the assembly .words for a note -> period (in samples) lookup table
    """
    for i in genNoteInvFrequencies():
        print padding + ".word " + hex(i&0xffff)
        print padding + ".word " + hex(i>>16)

def genToggleNotes():
    for i in xrange(8):
        print """		btsc W1, #%i
			btsc W2, #%i
				call playNote
			btss W2, #%i
				call dropNote
		    add #4, W0""" %(i, i, i)
        
