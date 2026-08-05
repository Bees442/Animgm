function audio_clear() {
    if (audio_instance != -1) { audio_stop_sound(audio_instance); audio_instance = -1; }
    if (audio_sound != -1) {
        if (audio_kind == "wav") audio_free_buffer_sound(audio_sound);
        else if (audio_kind == "ogg") audio_destroy_stream(audio_sound);
        audio_sound = -1;
    }
    if (audio_file_buf != -1) { buffer_delete(audio_file_buf); audio_file_buf = -1; }
    audio_path = "";
    audio_kind = "";
    audio_duration = 0;
    audio_trim_start = 0;
    audio_trim_end = 0;
    audio_offset_fr = 0;
}

function wav_parse(_buf) {
    var _size = buffer_get_size(_buf);
    if (_size < 44) return noone;
    buffer_seek(_buf, buffer_seek_start, 0);
    if (buffer_read(_buf, buffer_u32) != 0x46464952) return noone;
    buffer_read(_buf, buffer_u32);
    if (buffer_read(_buf, buffer_u32) != 0x45564157) return noone;

    var _fmt_found = false, _data_off = -1, _data_len = 0;
    var _channels = 0, _rate = 0, _bits = 0, _audio_fmt = 0;
    while (buffer_tell(_buf) + 8 <= _size) {
        var _id   = buffer_read(_buf, buffer_u32);
        var _csz  = buffer_read(_buf, buffer_u32);
        var _body = buffer_tell(_buf);
        var _next = _body + _csz + (_csz & 1);
        if (_id == 0x20746d66) {
            _audio_fmt = buffer_read(_buf, buffer_u16);
            _channels  = buffer_read(_buf, buffer_u16);
            _rate      = buffer_read(_buf, buffer_u32);
            buffer_read(_buf, buffer_u32);
            buffer_read(_buf, buffer_u16);
            _bits      = buffer_read(_buf, buffer_u16);
            _fmt_found = true;
        } else if (_id == 0x61746164) {
            _data_off = _body;
            _data_len = _csz;
        }
        if (_next <= _body - 8 || _next > _size) break;
        buffer_seek(_buf, buffer_seek_start, _next);
    }
    if (!_fmt_found || _data_off == -1) return noone;
    if (_audio_fmt != 1) return noone;
    if (_bits != 8 && _bits != 16) return noone;
    if (_channels != 1 && _channels != 2) return noone;
    if (_data_off + _data_len > _size) _data_len = _size - _data_off;

    return {
        format: (_bits == 8) ? buffer_u8 : buffer_s16,
        rate: _rate,
        offset: _data_off,
        length: _data_len,
        channels: (_channels == 1) ? audio_mono : audio_stereo,
    };
}

function audio_import(_path, _silent = false) {
    var _ext = string_lower(filename_ext(_path));
    if (_ext != ".wav" && _ext != ".ogg" && _ext != ".mp3") {
        if (!_silent) editor_toast("Use .wav, .ogg or .mp3");
        return;
    }

    audio_clear();

    var _load_path = _path;
    var _is_temp = false;
    if (_ext == ".mp3") {
        _load_path = game_save_id + "audio_import_tmp.wav";
        if (mp3_decode_to_wav(_path, _load_path) == 0) {
            if (!_silent) editor_toast("Could not decode MP3");
            return;
        }
        _ext = ".wav";
        _is_temp = true;
    }

    if (_ext == ".ogg") {
        var _snd = audio_create_stream(_load_path);
        if (_snd < 0) { if (!_silent) editor_toast("Could not load audio"); return; }
        audio_sound = _snd;
        audio_kind = "ogg";
    } else {
        var _raw = buffer_load(_load_path);
        if (_is_temp) file_delete(_load_path);
        if (_raw == -1) { if (!_silent) editor_toast("Could not load audio"); return; }
        var _info = wav_parse(_raw);
        if (_info == noone) {
            buffer_delete(_raw);
            if (!_silent) editor_toast("Unsupported WAV (need 8/16-bit PCM)");
            return;
        }
        // buffer_load() returns buffer_grow; audio_create_buffer_sound needs buffer_fixed.
        var _buf = buffer_create(_info.length, buffer_fixed, 1);
        buffer_copy(_raw, _info.offset, _info.length, _buf, 0);
        buffer_delete(_raw);
        audio_file_buf = _buf;
        audio_sound = audio_create_buffer_sound(_buf, _info.format, _info.rate, 0, _info.length, _info.channels);
        audio_kind = "wav";
    }

    audio_path = _path;
    audio_duration = audio_sound_length(audio_sound);
    audio_trim_start = 0;
    audio_trim_end = audio_duration;
    audio_offset_fr = 0;
    if (!_silent) {
        is_dirty = true;
        editor_toast("Imported audio: " + filename_name(_path));
    }
}

function audio_restore(_path, _offset_fr, _trim_start, _trim_end) {
    if (_path == "" || !file_exists(_path)) {
        if (_path != "") editor_toast("Audio file missing: " + filename_name(_path));
        return;
    }
    audio_import(_path, true);
    if (audio_sound == -1) return;
    audio_offset_fr = max(0, _offset_fr);
    audio_trim_start = clamp(_trim_start, 0, audio_duration);
    audio_trim_end = clamp(_trim_end, audio_trim_start + 1 / anim_fps, audio_duration);
}

function audio_sync(_playing, _jumped) {
    var _rel = (current_frame - audio_offset_fr) / anim_fps;
    var _t = audio_trim_start + _rel;
    var _within = (audio_sound != -1) && _rel >= 0 && _rel < (audio_trim_end - audio_trim_start);

    if (!_playing || !_within) {
        if (audio_instance != -1) { audio_stop_sound(audio_instance); audio_instance = -1; }
        return;
    }

    if (audio_instance == -1 || !audio_is_playing(audio_instance)) {
        audio_instance = audio_play_sound(audio_sound, 1, false);
        audio_sound_set_track_position(audio_instance, _t);
        return;
    }

    if (_jumped) {
        audio_sound_set_track_position(audio_instance, _t);
    } else {
        var _pos = audio_sound_get_track_position(audio_instance);
        if (abs(_pos - _t) > 0.12) audio_sound_set_track_position(audio_instance, _t);
    }
}

function audio_context_open(_x, _y) {
    ctx_kind = "audio";
    ctx_items = [
        ["Delete Audio", spr_ic_trash_2, "", true],
    ];
    var _mw = 210;
    var _mh = 8; for (var _i = 0; _i < array_length(ctx_items); _i++) _mh += (ctx_items[_i][0] == "-") ? 9 : 30;
    ctx_x = clamp(_x, 0, gw - _mw);
    ctx_y = clamp(_y, mbar_h, gh - _mh);
    ctx_open = true;
}

function audio_context_action(_label) {
    switch (_label) {
        case "Delete Audio": audio_clear(); is_dirty = true; break;
    }
    ctx_open = false;
}
