extends Node
## AudioManager - music playback with crossfade, pooled SFX playback.
## All audio is generated at build time (tools/gen-audio.js).

signal music_started(track_name: String, bpm: float)

const MUSIC_DIR := "res://assets/audio/"
const SFX_DIR := "res://assets/audio/"

var _music_player: AudioStreamPlayer
var _music_player2: AudioStreamPlayer
var _crossfade_tween: Tween
var _current_track := ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _loaded_sfx: Dictionary = {}

var bpm := 120.0
var beat_sec := 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_music_player2 = AudioStreamPlayer.new()
	_music_player2.bus = "Music"
	add_child(_music_player2)
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.max_polyphony = 8
		add_child(p)
		_pool.append(p)


func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, name)


func get_bus_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(SettingsManager.get_audio("master")))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),
		linear_to_db(SettingsManager.get_audio("music")))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),
		linear_to_db(SettingsManager.get_audio("sfx")))


func _load_music(name: String) -> AudioStreamWAV:
	var p := MUSIC_DIR + "music_" + name + ".wav"
	if not ResourceLoader.exists(p):
		return null
	return load(p) as AudioStreamWAV


func play_music(track: String, fade := 1.0) -> void:
	if track == _current_track:
		if not _music_player.playing and not _music_player2.playing:
			_start_music(track, _music_player, fade)
		return
	_current_track = track
	var stream := _load_music(track)
	if stream == null:
		return
	bpm = float(stream.loop_end - stream.loop_begin)
	# load bpm metadata json
	var meta_path := MUSIC_DIR + "music_" + track + ".json"
	if ResourceLoader.exists(meta_path):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if meta is Dictionary:
			bpm = float(meta.get("bpm", 120.0))
	beat_sec = 60.0 / max(bpm, 1.0)
	# pick the idle player, crossfade
	var from: AudioStreamPlayer = _music_player if _music_player.playing else _music_player2
	var to: AudioStreamPlayer = _music_player2 if from == _music_player else _music_player
	_start_music(track, to, fade)
	if _crossfade_tween:
		_crossfade_tween.kill()
	_crossfade_tween = create_tween()
	if from.playing:
		_crossfade_tween.tween_property(from, "volume_db", -40.0, fade)
		_crossfade_tween.parallel().tween_property(to, "volume_db", 0.0, fade)
		_crossfade_tween.tween_callback(from.stop)
	else:
		_crossfade_tween.tween_property(to, "volume_db", 0.0, 0.01)
	music_started.emit(track, bpm)


func _start_music(track: String, player: AudioStreamPlayer, fade: float) -> void:
	var stream := _load_music(track)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = -40.0 if fade > 0.1 else 0.0
	player.play()
	if fade > 0.1:
		create_tween().tween_property(player, "volume_db", 0.0, fade)


func stop_music(fade := 0.8) -> void:
	if _crossfade_tween:
		_crossfade_tween.kill()
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_property(_music_player, "volume_db", -40.0, fade)
	_crossfade_tween.parallel().tween_property(_music_player2, "volume_db", -40.0, fade)
	_crossfade_tween.tween_callback(_music_player.stop)
	_crossfade_tween.tween_callback(_music_player2.stop)
	_current_track = ""


func music_position() -> float:
	if _music_player.playing:
		return _music_player.get_playback_position()
	if _music_player2.playing:
		return _music_player2.get_playback_position()
	return 0.0


func beat_phase() -> float:
	return fmod(music_position(), beat_sec) / max(beat_sec, 0.001)


func is_beat_start(threshold := 0.04) -> bool:
	return beat_phase() < threshold


func play_sfx(name: String, volume := 1.0, pitch := 1.0) -> void:
	var stream: AudioStreamWAV = _get_sfx(name)
	if stream == null:
		return
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(clampf(volume, 0.0, 1.5))
	p.play()


func _get_sfx(name: String) -> AudioStreamWAV:
	if _loaded_sfx.has(name):
		return _loaded_sfx[name]
	var p := SFX_DIR + "sfx_" + name + ".wav"
	if not ResourceLoader.exists(p):
		return null
	var s := load(p) as AudioStreamWAV
	_loaded_sfx[name] = s
	return s
