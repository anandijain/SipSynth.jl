module SipSynth

midi_note_to_frequency(n) = ^(2, (n-69)/12) * 440

export midi_note_to_frequency

end # module
