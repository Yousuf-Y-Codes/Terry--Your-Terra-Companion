extends Node

signal stats_updated(data: Dictionary)
signal stats_failed(error_message: String)

const CONFIG_PATH = "user://config.json"
const LEGACY_DIR = ".terry_companion"

var api_key: String = ""
var api_url: String = "https://hackatime.hackclub.com/api/hackatime/v1"
var music_enabled: bool = true
var sfx_enabled: bool = true
var music_theme: String = "dynamic" # "dynamic", "town", "battle"
var goal_hours: float = 10.0
var daily_goal: float = 1.5
var background_theme: String = "default" # "default" or "river"
var pet_mode_enabled: bool = false
var selected_project: String = ""
var available_projects: Array[String] = ["All Projects"]
var terry_scale: float = 1.0
var pet_flip_h: bool = false
var onboarded: bool = false
var trigger_tutorial_on_load: bool = false
var stats: Dictionary = {}
var daily_history: Array[Dictionary] = []
var streak_days: int = 0

var _http: HTTPRequest
var _timer: Timer
var _bgm: AudioStreamPlayer
var _bgm_tracks: Dictionary = {}
var _current_track_name: String = ""
var _bgm_tween: Tween
var _sfx_player: AudioStreamPlayer
var _sfx_dict: Dictionary = {}
var _is_fetching: bool = false
var session_seconds: float = 0.0
var total_app_seconds: float = 0.0
var _last_break_reminder: float = 0.0
var _last_save_time: float = 0.0

# Transition overlay
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	# 1. Setup smooth scene transition overlay
	_setup_transition_layer()

	# 2. Setup non-blocking HTTP request
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

	# 3. Setup 30-second refresh timer
	_timer = Timer.new()
	_timer.wait_time = 30.0
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)

	# 4. Setup BGM player & track library
	_bgm = AudioStreamPlayer.new()
	var town_stream = preload("res://assets/town.mp3")
	if town_stream:
		town_stream.loop = true
		_bgm_tracks["town"] = town_stream
	var battle_stream = load("res://assets/battle.mp3")
	if battle_stream:
		battle_stream.loop = true
		_bgm_tracks["battle"] = battle_stream
	if _bgm_tracks.has("town"):
		_bgm.stream = _bgm_tracks["town"]
		_current_track_name = "town"
	add_child(_bgm)

	# 5. Setup SFX generator & player
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -4.0
	add_child(_sfx_player)
	_init_sfx()

	# 6. Load config and do first fetch
	load_settings()
	_update_music()
	fetch_stats()

func _process(delta: float) -> void:
	session_seconds += delta
	total_app_seconds += delta

	# Autosave total app time every 60 seconds
	if session_seconds - _last_save_time >= 60.0:
		_last_save_time = session_seconds
		save_total_app_time()

	# Gentle break reminder every 50 minutes (3000 seconds)
	if session_seconds - _last_break_reminder >= 3000.0:
		_last_break_reminder = session_seconds
		if not stats.is_empty() and stats.get("mood", "") != "red":
			var reminder_stats = stats.duplicate()
			reminder_stats["title"] = "HYDRATION CHECK!"
			reminder_stats["msg"] = "You've been coding for 50m! Drink some water and stretch with Terry!"
			stats_updated.emit(reminder_stats)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_total_app_time()

func save_total_app_time() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {}
	parsed["total_app_seconds"] = total_app_seconds
	var wfile = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if wfile:
		wfile.store_string(JSON.stringify(parsed, "\t"))
		wfile.close()

func _init_sfx() -> void:
	# 1. Chirp (Happy poke/bounce)
	var wav_chirp = AudioStreamWAV.new()
	wav_chirp.format = AudioStreamWAV.FORMAT_16_BITS
	wav_chirp.mix_rate = 22050
	var samples_c = int(0.16 * 22050)
	var bytes_c = PackedByteArray()
	bytes_c.resize(samples_c * 2)
	var phase_c = 0.0
	for i in range(samples_c):
		var t = float(i) / float(samples_c)
		var freq = lerpf(520.0, 1150.0, t * t)
		phase_c += (freq * TAU) / 22050.0
		var env = sin(t * PI)
		var s = int(sin(phase_c) * env * 14000.0)
		bytes_c.encode_s16(i * 2, s)
	wav_chirp.data = bytes_c
	_sfx_dict["chirp"] = wav_chirp

	# 2. Pop (Button click/hover)
	var wav_pop = AudioStreamWAV.new()
	wav_pop.format = AudioStreamWAV.FORMAT_16_BITS
	wav_pop.mix_rate = 22050
	var samples_p = int(0.06 * 22050)
	var bytes_p = PackedByteArray()
	bytes_p.resize(samples_p * 2)
	var phase_p = 0.0
	for i in range(samples_p):
		var t = float(i) / float(samples_p)
		var freq = lerpf(480.0, 160.0, t)
		phase_p += (freq * TAU) / 22050.0
		var env = pow(1.0 - t, 2.0)
		var s = int(sin(phase_p) * env * 15000.0)
		bytes_p.encode_s16(i * 2, s)
	wav_pop.data = bytes_p
	_sfx_dict["pop"] = wav_pop

	# 3. Chime (Milestone/Celebration)
	var wav_chime = AudioStreamWAV.new()
	wav_chime.format = AudioStreamWAV.FORMAT_16_BITS
	wav_chime.mix_rate = 22050
	var samples_ch = int(0.35 * 22050)
	var bytes_ch = PackedByteArray()
	bytes_ch.resize(samples_ch * 2)
	var phase_ch = 0.0
	for i in range(samples_ch):
		var t = float(i) / float(samples_ch)
		var freq = 523.25
		if t > 0.66:
			freq = 783.99
		elif t > 0.33:
			freq = 659.25
		phase_ch += (freq * TAU) / 22050.0
		var env = sin(fposmod(t * 3.0, 1.0) * PI) * (1.0 - t * 0.5)
		var s = int((sin(phase_ch) + 0.3 * sin(phase_ch * 2.0)) * env * 10000.0)
		bytes_ch.encode_s16(i * 2, s)
	wav_chime.data = bytes_ch
	_sfx_dict["chime"] = wav_chime

func play_sfx(sfx_name: String, pitch_variance: float = 0.06) -> void:
	if not sfx_enabled or not _sfx_dict.has(sfx_name) or _sfx_player == null:
		return
	_sfx_player.stream = _sfx_dict[sfx_name]
	if pitch_variance > 0.0:
		_sfx_player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		_sfx_player.pitch_scale = 1.0
	_sfx_player.play()

func _setup_transition_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128 # On top of everything
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	add_child(_fade_layer)

func transition_to_scene(target_scene: String, duration: float = 0.25) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		get_tree().change_scene_to_file(target_scene)
		var tween_in = create_tween()
		tween_in.tween_property(_fade_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_in.finished.connect(func():
			_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_is_transitioning = false
		)
	)

func get_current_background_texture() -> Texture2D:
	if background_theme == "river":
		return preload("res://assets/terry_walking_across _river.png")
	return preload("res://assets/APP_BACKGROUND.png")

func load_settings() -> void:
	music_enabled = true
	sfx_enabled = true
	music_theme = "dynamic"

	if not FileAccess.file_exists(CONFIG_PATH):
		_try_migrate_legacy()
		save_settings(api_key, true, background_theme, pet_mode_enabled, selected_project, terry_scale, 1 if pet_flip_h else 0, 1 if onboarded else 0, 1, music_theme)
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return

	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		api_key = str(parsed.get("api_key", "")).strip_edges()
		api_url = str(parsed.get("api_url", api_url)).strip_edges()
		music_enabled = bool(parsed.get("music_enabled", true))
		sfx_enabled = bool(parsed.get("sfx_enabled", true))
		music_theme = str(parsed.get("music_theme", "dynamic"))
		goal_hours = float(parsed.get("goal_hours", 10.0))
		daily_goal = float(parsed.get("daily_goal", 1.5))
		background_theme = str(parsed.get("background_theme", "default"))
		pet_mode_enabled = bool(parsed.get("pet_mode_enabled", false))
		selected_project = str(parsed.get("selected_project", ""))
		terry_scale = float(parsed.get("terry_scale", 1.0))
		pet_flip_h = bool(parsed.get("pet_flip_h", false))
		onboarded = bool(parsed.get("onboarded", false))
		total_app_seconds = float(parsed.get("total_app_seconds", 0.0))

func save_settings(new_key: String, new_music: bool, new_bg: String = "", new_pet: bool = false, new_proj: String = "", new_scale: float = -1.0, new_flip: int = -1, new_onboarded: int = -1, new_sfx: int = -1, new_theme: String = "") -> void:
	api_key = new_key.strip_edges()
	music_enabled = new_music
	if not new_bg.is_empty():
		background_theme = new_bg
	pet_mode_enabled = new_pet
	selected_project = new_proj
	if new_scale > 0.0:
		terry_scale = new_scale
	if new_flip >= 0:
		pet_flip_h = (new_flip == 1)
	if new_onboarded >= 0:
		onboarded = (new_onboarded == 1)
	if new_sfx >= 0:
		sfx_enabled = (new_sfx == 1)
	if not new_theme.is_empty():
		music_theme = new_theme

	var data = {
		"api_key": api_key,
		"api_url": api_url,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
		"music_theme": music_theme,
		"goal_hours": goal_hours,
		"daily_goal": daily_goal,
		"background_theme": background_theme,
		"pet_mode_enabled": pet_mode_enabled,
		"selected_project": selected_project,
		"terry_scale": terry_scale,
		"pet_flip_h": pet_flip_h,
		"onboarded": onboarded,
		"total_app_seconds": total_app_seconds
	}

	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

	_update_music()
	set_pet_mode(pet_mode_enabled)
	_timer.start()
	fetch_stats()

func set_onboarded(is_onboarded: bool) -> void:
	onboarded = is_onboarded
	save_settings(api_key, music_enabled, background_theme, pet_mode_enabled, selected_project, terry_scale, 1 if pet_flip_h else 0, 1 if onboarded else 0)

func play_music_track(preferred_track: String, fade_duration: float = 0.4) -> void:
	var track_to_play = preferred_track
	if music_theme == "town":
		track_to_play = "town"
	elif music_theme == "battle":
		track_to_play = "battle"

	if not _bgm_tracks.has(track_to_play):
		return
	if _current_track_name == track_to_play and _bgm.playing:
		return
	_current_track_name = track_to_play

	if not music_enabled:
		_bgm.stream = _bgm_tracks[track_to_play]
		return

	if _bgm.playing and fade_duration > 0.0:
		if _bgm_tween and _bgm_tween.is_valid():
			_bgm_tween.kill()
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm, "volume_db", -36.0, fade_duration * 0.4).set_trans(Tween.TRANS_SINE)
		_bgm_tween.finished.connect(func():
			_bgm.stream = _bgm_tracks[track_to_play]
			_bgm.play()
			var tween_in = create_tween()
			tween_in.tween_property(_bgm, "volume_db", 0.0, fade_duration * 0.6).set_trans(Tween.TRANS_SINE)
		)
	else:
		_bgm.volume_db = 0.0
		_bgm.stream = _bgm_tracks[track_to_play]
		_bgm.play()

func _update_music() -> void:
	if music_enabled:
		var target_track = _current_track_name if not _current_track_name.is_empty() else "town"
		if music_theme == "town":
			target_track = "town"
		elif music_theme == "battle":
			target_track = "battle"

		if _bgm_tracks.has(target_track):
			_bgm.stream = _bgm_tracks[target_track]
			_current_track_name = target_track
		if not _bgm.playing and _bgm.stream != null:
			_bgm.volume_db = 0.0
			_bgm.play()
	else:
		if _bgm.playing:
			_bgm.stop()

func _on_timer_timeout() -> void:
	fetch_stats()

func fetch_stats() -> void:
	if _is_fetching:
		return

	if api_key.is_empty():
		stats = {
			"mood": "yellow",
			"title": "WELCOME TO TERRY!",
			"msg": "Click Settings to paste your Hackatime API key!",
			"today_str": "0h 00m",
			"week_str": "0h 00m",
			"today_hours": 0.0,
			"week_hours": 0.0,
			"time_left_str": "--"
		}
		stats_updated.emit(stats)
		return

	var dates = _get_week_dates()
	var clean_url = api_url.rstrip("/")
	var url = "%s/users/current/summaries?start=%s&end=%s" % [clean_url, dates.monday, dates.today]
	var headers = PackedStringArray([
		"Authorization: Bearer %s" % api_key,
		"Accept: application/json",
		"User-Agent: Terry-Companion/1.0"
	])

	_is_fetching = true
	var err = _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_is_fetching = false
		stats_failed.emit("Network error: %s" % error_string(err))

func _on_http_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_fetching = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var err_msg = "Could not fetch stats (HTTP %d)" % response_code
		if response_code == 401 or response_code == 403:
			err_msg = "Invalid API Key! Please re-check in Settings."
		stats_failed.emit(err_msg)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		stats_failed.emit("Failed to parse Hackatime response")
		return

	var data: Dictionary = parsed

	# Week cumulative seconds
	var cumulative = data.get("cumulative_total", {})
	var week_sec: float = 0.0
	if typeof(cumulative) == TYPE_DICTIONARY:
		week_sec = float(cumulative.get("seconds", 0.0))
	var week_hours: float = snappedf(week_sec / 3600.0, 0.01)

	# Today seconds (last item in data list)
	var days_list = data.get("data", [])
	var today_sec: float = 0.0
	if typeof(days_list) == TYPE_ARRAY and not days_list.is_empty():
		var last_day = days_list[-1]
		if typeof(last_day) == TYPE_DICTIONARY:
			var grand_total = last_day.get("grand_total", {})
			if typeof(grand_total) == TYPE_DICTIONARY:
				today_sec = float(grand_total.get("total_seconds", 0.0))
	var today_hours: float = snappedf(today_sec / 3600.0, 0.01)

	# Extract available project names for the dropdown
	var found_projects: Array[String] = ["All Projects"]
	if typeof(days_list) == TYPE_ARRAY:
		for day in days_list:
			if typeof(day) == TYPE_DICTIONARY:
				for p in day.get("projects", []):
					if typeof(p) == TYPE_DICTIONARY:
						var p_name = str(p.get("name", "")).strip_edges()
						if not p_name.is_empty() and not found_projects.has(p_name):
							found_projects.append(p_name)
	available_projects = found_projects

	# If a specific project is selected, override week and today seconds with that project only
	if not selected_project.is_empty() and selected_project != "All Projects":
		var proj_week_sec: float = 0.0
		var proj_today_sec: float = 0.0
		if typeof(days_list) == TYPE_ARRAY:
			for i in range(days_list.size()):
				var day = days_list[i]
				if typeof(day) == TYPE_DICTIONARY:
					for p in day.get("projects", []):
						if typeof(p) == TYPE_DICTIONARY and str(p.get("name", "")) == selected_project:
							var s = float(p.get("total_seconds", 0.0))
							proj_week_sec += s
							if i == days_list.size() - 1:
								proj_today_sec = s
		week_hours = snappedf(proj_week_sec / 3600.0, 0.01)
		today_hours = snappedf(proj_today_sec / 3600.0, 0.01)

	# Build 7-day history array
	var history: Array[Dictionary] = []
	var streak: int = 0
	if typeof(days_list) == TYPE_ARRAY:
		for day in days_list:
			if typeof(day) == TYPE_DICTIONARY:
				var day_range = day.get("range", {})
				var date_str = str(day_range.get("date", ""))
				var grand_tot = day.get("grand_total", {})
				var sec = float(grand_tot.get("total_seconds", 0.0))
				var h = snappedf(sec / 3600.0, 0.01)
				history.append({
					"date": date_str,
					"seconds": sec,
					"hours": h,
					"hours_str": format_hours(h)
				})
				if h >= (daily_goal * 0.8):
					streak += 1
				elif h == 0.0:
					streak = 0
	daily_history = history
	streak_days = streak

	stats = compute_status(week_hours, today_hours)
	stats["daily_history"] = daily_history
	stats["streak_days"] = streak_days
	stats_updated.emit(stats)

func compute_status(week_hours: float, today_hours: float) -> Dictionary:
	var now = Time.get_datetime_dict_from_system()
	var py_weekday = (now.weekday + 6) % 7
	var day_number = py_weekday + 1

	var days_to_sunday = (6 - py_weekday) % 7
	var sec_passed_today = now.hour * 3600 + now.minute * 60 + now.second
	var sec_left_today = max(0, 86400 - sec_passed_today)
	var total_sec_left = days_to_sunday * 86400 + sec_left_today
	var hours_left_in_week: float = total_sec_left / 3600.0

	var expected_by_tonight: float = minf(goal_hours, day_number * daily_goal)
	var week_needed: float = maxf(0.0, goal_hours - week_hours)
	var needed_for_tonight: float = maxf(0.0, expected_by_tonight - week_hours)

	var mood: String = "green"
	var title: String = ""
	var msg: String = ""

	if week_needed > hours_left_in_week:
		mood = "red"
		title = "EVICTION NOTICE"
		msg = "Cooked! Need %s, but only %s left!" % [format_hours(week_needed), format_hours(hours_left_in_week)]
	elif hours_left_in_week <= 24.0 and week_needed > 0.0:
		mood = "red"
		title = "SUNDAY DANGER ZONE"
		msg = "Under 24h left! Log %s before midnight!" % [format_hours(week_needed)]
	elif week_hours >= goal_hours:
		mood = "green"
		title = "QUOTA COMPLETED!"
		msg = "Terry is proud of you! All %sh done for the week!" % [str(goal_hours)]
	elif needed_for_tonight <= 0.0:
		mood = "green"
		title = "DAY %d COMPLETE!" % day_number
		msg = "Passed Day %d target! %s left for the week." % [day_number, format_hours(week_needed)]
	elif needed_for_tonight <= (daily_goal / 2.0):
		mood = "green"
		title = "ON TRACK"
		msg = "Almost at Day %d target! Just %s more tonight." % [day_number, format_hours(needed_for_tonight)]
	else:
		mood = "yellow"
		title = "YOU NEED TO WORK!!"
		msg = "Log %s more tonight to reach Day %d target!" % [format_hours(needed_for_tonight), day_number]

	return {
		"mood": mood,
		"title": title,
		"msg": msg,
		"today_hours": today_hours,
		"week_hours": week_hours,
		"today_str": format_hours(today_hours),
		"week_str": format_hours(week_hours),
		"daily_goal_str": format_hours(daily_goal),
		"goal_hours_str": format_hours(goal_hours),
		"time_left_str": format_hours(hours_left_in_week)
	}

static func format_hours(hours: float) -> String:
	var total_minutes = roundi(hours * 60.0)
	var h = int(total_minutes / 60)
	var m = int(total_minutes % 60)
	return "%dh %02dm" % [h, m]

func get_total_app_time_string() -> String:
	return format_seconds(total_app_seconds)

func get_session_time_string() -> String:
	return format_seconds(session_seconds)

static func format_seconds(total_secs: float) -> String:
	var total_minutes = int(total_secs / 60.0)
	var h = int(total_minutes / 60)
	var m = int(total_minutes % 60)
	return "%dh %02dm" % [h, m]

func _get_week_dates() -> Dictionary:
	var now_unix = Time.get_unix_time_from_system()
	var now_dt = Time.get_datetime_dict_from_system()
	var py_weekday = (now_dt.weekday + 6) % 7
	var monday_unix = now_unix - (py_weekday * 86400)
	var monday_dt = Time.get_date_dict_from_unix_time(int(monday_unix))

	return {
		"monday": "%04d-%02d-%02d" % [monday_dt.year, monday_dt.month, monday_dt.day],
		"today": "%04d-%02d-%02d" % [now_dt.year, now_dt.month, now_dt.day]
	}

func _try_migrate_legacy() -> void:
	var home = OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	if home.is_empty():
		return

	var legacy_file = home.path_join(LEGACY_DIR).path_join("config.json")
	if not FileAccess.file_exists(legacy_file):
		return

	var f = FileAccess.open(legacy_file, FileAccess.READ)
	if not f:
		return
	var text = f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("api_key"):
			api_key = str(parsed["api_key"]).strip_edges()
		save_settings(api_key, music_enabled, background_theme)
		
func set_pet_mode(enabled: bool) -> void:
	pet_mode_enabled = enabled
	if enabled:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		get_tree().root.transparent_bg = true
	else:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		get_tree().root.transparent_bg = false
