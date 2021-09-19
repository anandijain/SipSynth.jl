# this was made manually, so if looking at my binarybuilder issue, this was not done with --deploy="anandijain/libportaudio_jll.jl", which is broken

# micdev = devs[3]
using PortAudio, SampledSignals, LibSndFile, FileIO, SipSynth
devs = PortAudio.devices()
mic = PortAudioStream("MacBook Pro Microphone", 1, 0)
buf = read(mic, 2s)
close(mic)
save("data/grooovin2.wav", buf)
using FileIO
save("data/grooovin2.wav", buf)
# save("data/grooovin2.ogg", buf)


# airpods_out = devs[3]
# micdev = devs[5]
# PortAudioStream(micdev, airpods_out, 1, 2) do stream
#     write(stream, stream)
# end
