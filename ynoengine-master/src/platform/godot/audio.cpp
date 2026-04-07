#ifdef SUPPORT_AUDIO

#include "audio.h"
#include "audio_decoder.h"

GodotAudio::GodotAudio(const Game_ConfigAudio& cfg)
	: GenericAudio(cfg)
{
	SetFormat(SAMPLE_RATE, AudioDecoder::Format::S16, 2); // godot AudioStreamGenerator default
}

std::vector<int16_t> GodotAudio::PullFrames(int frame_count) {
	if (frame_count <= 0)
		return {};

	const int byte_count = frame_count * 2 * sizeof(int16_t); // stereo S16
	std::vector<uint8_t> raw(byte_count, 0);

	{
		std::lock_guard<std::mutex> lock(mutex_);
		Decode(raw.data(), byte_count);
	}

	std::vector<int16_t> out(frame_count * 2);
	std::memcpy(out.data(), raw.data(), byte_count);
	return out;
}

void GodotAudio::LockMutex() const {
	mutex_.lock();
}

void GodotAudio::UnlockMutex() const {
	mutex_.unlock();
}

#endif // SUPPORT_AUDIO
