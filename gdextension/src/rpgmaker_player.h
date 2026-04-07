#ifndef EASYRPG_RPGMAKER_PLAYER_H
#define EASYRPG_RPGMAKER_PLAYER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

#include <memory>
#include <functional>
#include <string>
#include <cstdint>

#include "multiplayer/mp_callbacks.h"

class GodotUi; // fwd from ynoengine

namespace godot {

class RPGMakerPlayer : public Node {
	GDCLASS(RPGMakerPlayer, Node)

public:
	RPGMakerPlayer();
	~RPGMakerPlayer() override;

	void set_game_path(const String& path);
	String get_game_path() const;

	void start_game();
	void stop_game();
	Ref<ImageTexture> get_frame_texture() const;
	bool is_running() const;

	void open_save_menu();

	void open_load_menu();

	void open_debug_menu();

	bool set_resolution(int width, int height);

	int get_screen_width() const;

	int get_screen_height() const;

	bool is_map_ready() const;
	void mp_set_session_active(bool active);
	void mp_notify_room_ready();

	PackedFloat32Array audio_pull_frames(int frame_count);

	int get_audio_sample_rate() const;

	void inject_key(int easyrpg_key_id, bool pressed);

	void set_mp_callbacks(MpCallbacks cbs) { mp_callbacks_ = std::move(cbs); }
	MpCallbacks& get_mp_callbacks() { return mp_callbacks_; }

	void mp_add_player(int id, int x, int y, const String& sprite_name, int sprite_index, int facing, int speed);

	void mp_remove_player(int id);

	void mp_move_player(int id, int x, int y);

	void mp_set_player_facing(int id, int facing);

	void mp_set_player_speed(int id, int speed);

	void mp_set_player_sprite(int id, const String& name, int index);

	void mp_set_player_transparency(int id, int transparency);

	void mp_set_player_hidden(int id, bool hidden);

	void mp_flash_player(int id, int r, int g, int b, int power, int frames);

	void mp_play_se(const String& name, int volume, int tempo, int balance);

	void mp_sync_local_player();

	void mp_set_player_name(int id, const String& name);

	void mp_set_player_system_graphic(int id, const String& sys_name);

	void mp_set_nametag_mode(int mode);

	void mp_set_room(int room_id);

	void mp_set_room_id(int room_id);

	void _ready() override;

	void _process(double delta) override;

	void _notification(int p_what);

protected:
	static void _bind_methods();

private:
	String game_path_;
	bool engine_running_ = false;
	GodotUi* godot_ui_ = nullptr;
	Ref<ImageTexture> frame_texture_;
	Ref<Image> frame_image_;
	MpCallbacks mp_callbacks_;

	void on_frame_ready(const uint8_t* pixels, int width, int height, int pitch);
};

} // namespace godot

#endif
