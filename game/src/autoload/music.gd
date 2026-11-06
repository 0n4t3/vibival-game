extends Node
## Background music, played now and then like ambient game soundtracks: after
## a track ends there is a random quiet gap before the next one. How long the
## gaps are depends on Settings.music_frequency: Common fills about half the
## time with music, Rare about a fifth, and never more than MAX_SHARE of it.
## Tracks are never repeated back to back.
##
## The next track is scheduled as each one starts (its length plus the gap),
## not when the player says it has finished: that signal can go missing (web
## audio, the app put in the background), and then music would play back to
## back. However a track ends, the next can't start until the last one's
## share of the time allows it (quiet_until()), scene changes included.
## Music has its own audio bus, so its volume can be set apart from the master
## volume.
##
## Each scene sets its own start (Game.goto calls enter()): the title waits a
## while before any music, the tutorial lab has none, and a new world opens
## with Empty Basin before the random choice takes over.
##
## Tracks are the .mp3 and .ogg files in res://music, loaded at runtime (the
## project has no imported assets).

const DIR := "res://music"
const BUS := "Music"
const FADE := 3.0
## Full volume is a little louder than the game's other sounds.
const GAIN_DB := 3.0
## Quiet between tracks, [min, max]: seconds for Constant, and for Common and
## Rare a multiple of the length of the track that just ended (so about 50%
## and 20% of the time is music).
const GAPS := [[4.0, 12.0], [0.7, 1.3], [3.0, 5.0]]
## The most of the time music may play: Constant, Common, Rare.
const MAX_SHARE := [1.0, 0.6, 0.3]
## The first track after loading a world waits only part of a gap.
const FIRST_GAP := 0.25
const TITLE_WAIT := 30.0     # seconds on the title screen before any music
const OPENING := "res://music/empty-basin.mp3"
const OPENING_WAIT := 30.0   # into a new world (Common or Rare)
## The tutorial's elevator ride down to the lab (lab.gd) has its own music,
## fading in as you find yourself in the car and looping until you step
## out: this file (.mp3 or .ogg), kept out of the random choice.
const ELEVATOR := "res://music/elevator"
const ELEVATOR_IN := 2.0     # seconds to fade it in
const ELEVATOR_OUT := 0.8    # and out, quickly, once you are out of the car

var tracks: Array[String] = []
var current := ""         # path of the track playing or fading out
var wait := 0.0           # seconds until the next track starts

var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _streams := {}
var _fading := false
var _fade_time := FADE    # seconds the fade out takes
var _rising := 0.0        # dB a second while fading in
var _frequency := -1
var _clock := 0.0         # seconds since the game started, paused or not
var _started_at := -INF   # _clock when the last track started
var _started_len := 0.0   # and its length
var scene := ""
var queued := ""          # played next instead of a random track


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps playing while paused
	_rng.randomize()
	if AudioServer.get_bus_index(BUS) < 0:
		# Not add_bus(): on the web (Godot 4.7) appending a bus puts it before
		# Master in the browser's audio graph, and the send below then loops
		# Master and Music into each other, which silences all audio.
		AudioServer.bus_count += 1
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	tracks = find_tracks()
	Settings.changed.connect(_on_settings)
	_on_settings()
	enter("title")
	_dev_start.call_deferred()


func _dev_start() -> void:
	## --music starts a track at once.
	if Game.dev.has("music") and wait != INF:
		play_next()


func find_tracks() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.get_extension().to_lower() in ["mp3", "ogg"] and DIR.path_join(f.get_basename()) != ELEVATOR:
			out.append(DIR.path_join(f))
	out.sort()
	return out


func load_track(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	match path.get_extension().to_lower():
		"mp3":
			s = AudioStreamMP3.load_from_file(path)
		"ogg":
			s = AudioStreamOggVorbis.load_from_file(path)
	if s:
		_streams[path] = s
	return s


func enter(scene_name: String, fresh := false) -> void:
	## A new scene: fade out what is playing and wait for that scene's start.
	## `fresh` is a new world just begun.
	scene = scene_name
	stop()
	queued = ""
	var f: int = Settings.music_frequency
	if f == Settings.MusicFrequency.OFF or scene == "lab":
		wait = INF
	elif scene == "title":
		wait = TITLE_WAIT
	elif fresh and f != Settings.MusicFrequency.CONSTANT:
		queued = OPENING
		wait = OPENING_WAIT
	else:
		wait = next_gap() * FIRST_GAP


func elevator(on: bool) -> void:
	## Starts the elevator music (if there is a track for it and music is
	## on), or fades it out.
	if not on:
		if current.begins_with(ELEVATOR):
			stop(true, ELEVATOR_OUT)
		return
	if Settings.music_frequency == Settings.MusicFrequency.OFF:
		return
	for ext in ["ogg", "mp3"]:
		var path: String = ELEVATOR + "." + ext
		if not FileAccess.file_exists(path):
			continue
		var s := load_track(path)
		if s == null:
			continue
		s.set("loop", true)
		current = path
		_fading = false
		_player.stream = s
		_player.volume_db = -60.0
		_rising = 60.0 / ELEVATOR_IN
		_player.play()
		wait = INF
		return


func next_gap() -> float:
	## A random wait for the current frequency, or INF when music is off.
	var f: int = Settings.music_frequency
	if f >= GAPS.size():
		return INF
	var k := _rng.randf_range(GAPS[f][0], GAPS[f][1])
	return k if f == Settings.MusicFrequency.CONSTANT else k * track_length()


func track_length() -> float:
	## Length of the track that played last, or of an average one.
	var s := load_track(current) if current != "" else null
	if s:
		return s.get_length()
	var total := 0.0
	for t in tracks:
		total += load_track(t).get_length()
	return total / tracks.size() if not tracks.is_empty() else 180.0


func pick_track() -> String:
	## A random track, never the one that just played (unless it is the only one).
	if tracks.is_empty():
		return ""
	var choices := tracks.filter(func(t): return t != current)
	if choices.is_empty():
		choices = tracks
	return choices[_rng.randi() % choices.size()]


func quiet_until() -> float:
	## The earliest _clock the next track may start: after the last one and
	## enough quiet that it was no more than MAX_SHARE of the time.
	var f: int = Settings.music_frequency
	if f >= MAX_SHARE.size() or _started_at == -INF:
		return _started_at + _started_len
	return _started_at + _started_len / MAX_SHARE[f]


func playing() -> bool:
	return _player.playing and not _fading


func play_next() -> void:
	var path := queued if queued != "" else pick_track()
	queued = ""
	var s := load_track(path)
	if s == null:
		wait = next_gap()
		return
	current = path
	_fading = false
	_rising = 0.0
	_player.stream = s
	_player.volume_db = 0.0
	_player.play()
	_started_at = _clock
	_started_len = s.get_length()
	# The next one: after this track and a gap (never mind `finished`).
	wait = _started_len + next_gap()


func stop(fade := true, seconds := FADE) -> void:
	_rising = 0.0
	if not _player.playing:
		return
	if fade:
		_fading = true
		_fade_time = seconds
	else:
		_player.stop()


func _process(delta: float) -> void:
	_clock += delta
	if _rising > 0.0:
		_player.volume_db = minf(_player.volume_db + delta * _rising, 0.0)
		if _player.volume_db >= 0.0:
			_rising = 0.0
	if _fading:
		_player.volume_db -= delta * 60.0 / _fade_time
		if _player.volume_db <= -60.0:
			_player.stop()
			_fading = false
			_player.volume_db = 0.0
		return
	if wait == INF:
		return
	wait -= delta
	if wait > 0.0 or _clock < quiet_until():
		return
	if _player.playing:
		# Still going (a longer track than it said): a full gap after it.
		wait = next_gap()
		return
	play_next()


func _on_settings() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(Settings.music_volume, 0.0001)) + GAIN_DB)
	AudioServer.set_bus_mute(bus, Settings.music_volume <= 0.0)
	if Settings.music_frequency == _frequency:
		return
	_frequency = Settings.music_frequency
	if _frequency >= GAPS.size():
		stop()
		wait = INF
		queued = ""
	elif scene == "lab":
		wait = INF
	elif not _player.playing:
		# Don't make the player sit out a long gap picked for a rarer setting
		# (though the title screen still stays quiet for a while).
		wait = minf(wait, maxf(next_gap(), TITLE_WAIT if scene == "title" else 0.0))
