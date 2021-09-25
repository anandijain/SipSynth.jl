using PortAudio, Base.Threads, ConcurrentCollections, StaticArrays
using StaticArrays
using Base.Iterators

using PortAudio, SampledSignals, LibSndFile, FileIO, SipSynth, MIDI, WAV, RtMIDI
using BenchmarkTools


mystream = PortAudioStream(0, 1)

BUFSIZE = 512
CHANNELS = 1
SR = mystream.sample_rate
SR = 48000.
RELEASE = Int(SR) # samples (1s)
amps = (1:-(1//RELEASE):0)[1:end-1]
# arr = zeros(BUFSIZE, CHANNELS)
arr = rand(BUFSIZE, CHANNELS)
arr = rand(BUFSIZE)
buf = SVector{size(arr)...}(arr)

q = LinkedConcurrentRingQueue{typeof(arr)}()
# q = LinkedConcurrentRingQueue{typeof(buf)}()
# notes_on = ConcurrentQueue{Set{UInt8}}()
notes_on = Set{UInt8}()

# q = Conc{typeof(arr)}();
freqs = [440, 440*3/2]

function make_signal(freqs)
    signal = sum(sin.(freq*2*π/SR * (1:BUFSIZE)) for freq in freqs)
    # @. signal = amps * signal
    signal
end

function make_signal2(freqs)
    sum(sin.(freq*2*π/SR * (1:BUFSIZE)) for freq in freqs)
end

write(mystream, make_signal(freqs))
# write(mystream, buf)
# push!(q, signal[1:BUFSIZE])

function partition_and_push!(q, signal)
    map(x->push!(q, x), Iterators.partition(signal, BUFSIZE))
end

function handle_msg!(q, msg; verbose=true)
    # on = popfirst!(notes_on)
    if msg[1] == 0x90 && length(msg) >= 3
        note = msg[2]
        push!(notes_on, note)
    elseif msg[1] == 0x80 && length(msg) == 2
        note = msg[2]
        delete!(notes_on, note)
    end

    if !isempty(notes_on)
        # buf .= 
        # partition_and_push!(q, buf)
        push!(q, make_signal2(midi_note_to_frequency.(notes_on)))
    end

    verbose && println(msg)
    nothing
end
 
function play_buffer!(q, mystream)
    prev = r_ecb[].message
    while true 
        message =  r_ecb[].message
        if message != C_NULL && message != prev
            msg = codeunits(unsafe_string(message))
            handle_msg!(q, msg; verbose=false)
            prev = msg
        end
        buf = trypopfirst!(q)
        # @info buf
        
        if buf === nothing  # queue is empty, write zeros
            continue
        else 
            # println(buf.value[1])
            write(mystream, buf.value)
        end
    end
    # return "foo"
end


# function _callback_async_loop(q, cond, r_ecb; verbose=true)
#     while isopen(cond)
#         wait(cond)
#         msg = codeunits(unsafe_string(r_ecb[].message))
#         handle_msg!(q, msg)
#         verbose && println(msg)
#     end
# end

# cbloop = Task() do
#     _callback_async_loop(q, cond, r_ecb)
# end

# schedule(cbloop)

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

play_buffer!(q, mystream)
# play_buffer!(q)

# msg = UInt8[0x90, 0x45, 0x30]
# handle_msg!(q, msg)