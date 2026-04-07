#ifndef EP_MP_CALLBACKS_H
#define EP_MP_CALLBACKS_H

#include <functional>
#include <string>

struct MpCallbacks {
	std::function<void(int x, int y)> on_moved;
	std::function<void(int dir)> on_facing;
	std::function<void(int spd)> on_speed;
	std::function<void(const std::string& name, int idx)> on_sprite;
	std::function<void(int x, int y)> on_jumped;
	std::function<void(int r, int g, int b, int p, int f)> on_flash;
	std::function<void(int t)> on_transparency;
	std::function<void(bool hidden)> on_hidden;
	std::function<void(int map_id, int x, int y)> on_teleported;
	std::function<void(const std::string& n, int vol, int tempo, int bal)> on_se;
	std::function<void(const std::string& sys)> on_system;
	std::function<void(int map_id)> on_map_changed;
	std::function<void(int sw_id, int val)> on_switch_set;
	std::function<void(int var_id, int val)> on_variable_set;
	std::function<void(int ev_id, bool action)> on_event_triggered;
};

#endif
