
using PortAudio, SampledSignals, LibSndFile, FileIO, SipSynth, MIDI, WAV, RtMIDI
using BenchmarkTools

devs = PortAudio.devices()
@info "hello"
speaks = devs[end]
d = devs[end]
# mystream = PortAudioStream(speaks, 0, 2)
@info "hello"

RELEASE3 = 0.5 # s 
# const SR = Int(d.default_sample_rate) # 48000 samples/sec
# nsamples = RELEASE3 * SR

# note = name_to_pitch("A4")
# freq = midi_note_to_frequency(note)
# f = freq*2*π/SR
# xs = sin.(f * (1:nsamples))
# wavplay(xs, SR)

ports = list_midi_ports()
device = rtmidi_in_create_default()
rtmidi_open_port(device, ports[1]...)
# rtmidi_open_port(device, ports[2]...)

cb_ptr = @cfunction rtmidi_callback_func Cvoid (Cdouble, Ptr{Cuchar}, Csize_t, Ptr{EventCB})
cond = Base.AsyncCondition()
handle = Base.unsafe_convert(Ptr{Cvoid}, cond)
ecb = EventCB(handle, 0, C_NULL)
r_ecb = Ref(ecb)
rtmidi_in_set_callback(device, cb_ptr, r_ecb)

# buf_size = 512
# buf = zeros(buf_size)
# voices = 2
mystream = PortAudioStream(0, 1)
SR = mystream.sample_rate
ss = SinSource(eltype(mystream), mystream.sample_rate, [220, 330])
write(mystream, ss, 0.5s) 
write(mystream, ss, 0.5s) 
# ss = SinSource(eltype(mystream), mystream.sample_rate, [0])
# @edit SinSource(eltype(mystream), mystream.sample_rate, [220, 330])
# @benchmark SinSource(eltype(mystream), samplerate(mystream) * 0.8, [220, 330])
buf = SampleBuf(rand(Float32, 512, nchannels(mystream.sink)) * 0.1, samplerate(mystream))
freqs = [440, 550]
fs = map(f->2*π*f/SR, freqs)
setfield!(ss, :freqs, fs)
# ss.freqs = 
write(mystream, ss, 0.5s) 
# write(buf, ss) 
SR = Int(buf.samplerate)
buf_size = size(buf, 1)
amplitude = 0.5
notes_on = Set{UInt8}()
function handle_msg!(buf, ss, msg; verbose=true)
    # nbytes = 
    # if msg[1] == 0x90 && nbytes == 3
    if msg[1] == 0x90 && length(msg) == 3
        note = msg[2]
        push!(notes_on, note)
    # elseif msg[1] == 0x80 && nbytes == 2
    elseif msg[1] == 0x80 && length(msg) == 2
        note = msg[2]
        delete!(notes_on, note)
    end

    if !isempty(notes_on)
        freqs = midi_note_to_frequency.(notes_on)
        ss = SinSource(eltype(mystream), samplerate(mystream), freqs)
        # fs = map(f->2*π*f/SR, freqs)
        # setfield!(ss, :freqs, fs)
        # write(buf, )
        # buf .= sum(sin.(freq*2*π/SR * (1:buf_size)) for freq in freqs)
        # clamp!(buf, -1, 1)
        # @async write(mystream, ss)

    else 
        # buf .= 0
        # fill!(buf, 0)  
        # setfield!(ss, :freqs, [0.])
        ss = SinSource(eltype(mystream), samplerate(mystream), [0.])
    end
    nothing
end

function _callback_async_loop(mystream, buf, cond, r_ecb; verbose=true)
    while isopen(cond)
        wait(cond)
        msg = codeunits(unsafe_string(r_ecb[].message))
        handle_msg!(buf, ss, msg)

        # verbose && @info msg, notes_on
        verbose && println(msg, notes_on, ss.freqs)
        @async write(mystream, ss)
        # wavplay(buf, SR)
        # @asyncwavplay(buf, SR)
    end
end

cbloop = Task() do
    _callback_async_loop(mystream, buf, cond, r_ecb)
end





schedule(cbloop)

istaskdone(cbloop)
# msg = UInt8[0x90, 0x25, 0x30]
# handle_msg!(buf, ss, msg)

# cond = false
# flush(mystream)
# close(mystream)


# w, sr = wavread("/Users/anand/ableton_files/090721 Project/090721.wav")

# n = size(w, 1)

# for i in 0:(n÷buf_size)
#     arr = @view w[(i*512 + 1):(i+1)*512, :]
#     wavplay(arr, sr)
# end

# i = 1
# @benchmark @view w[(i*512 + 1):(i+1)*512, :]