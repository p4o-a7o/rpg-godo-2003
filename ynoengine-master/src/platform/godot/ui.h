#ifndef EP_PLATFORM_GODOT_UI_H
#define EP_PLATFORM_GODOT_UI_H

#include "baseui.h"
#include "color.h"
#include "rect.h"
#include "system.h"
#include "audio.h"

#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

class GodotUi final : public BaseUi {
public:
	GodotUi(int width, int height, const Game_Config& cfg);

	bool ProcessEvents() override;

	void UpdateDisplay() override;

	void vGetConfig(Game_ConfigVideo& cfg) const override;

	bool vChangeDisplaySurfaceResolution(int new_width, int new_height) override;

#if SUPPORT_AUDIO
	AudioInterface& GetAudio() override;
#endif

	const uint8_t* GetFramePixels() const;

	int GetFramePitch() const;

	int GetFrameWidth() const;

	int GetFrameHeight() const;

	void SetKeyState(int key_id, bool pressed);

	using FrameCallback = std::function<void(const uint8_t*, int, int, int)>;
	void SetFrameCallback(FrameCallback cb);

#if SUPPORT_AUDIO
	std::vector<int16_t> PullAudioFrames(int frame_count);

	int GetAudioSampleRate() const;
#endif

private:
#if SUPPORT_AUDIO
	std::unique_ptr<AudioInterface> audio_;
#endif

	FrameCallback frame_callback_;
};

#endif
