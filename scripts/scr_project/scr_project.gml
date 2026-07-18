#macro ANST_MAGIC   0x32534E41
#macro ANST_MAGIC_V1 0x31534E41
#macro ANST_VERSION 3
#macro ANRC_MAGIC   0x31524E41

function buf_write_str(_buf, _s) {
    var _len = string_byte_length(_s);
    buffer_write(_buf, buffer_u32, _len);
    if (_len > 0) {
        var _tmp = buffer_create(_len + 1, buffer_fixed, 1);
        buffer_write(_tmp, buffer_text, _s);
        buffer_copy(_tmp, 0, _len, _buf, buffer_tell(_buf));
        buffer_seek(_buf, buffer_seek_relative, _len);
        buffer_delete(_tmp);
    }
}

function buf_can_read(_buf, _n) {
    return buffer_tell(_buf) + _n <= buffer_get_size(_buf);
}

function buf_read_str(_buf) {
    if (!buf_can_read(_buf, 4)) return "";
    var _len = buffer_read(_buf, buffer_u32);
    if (_len <= 0) return "";
    if (!buf_can_read(_buf, _len)) {
        buffer_seek(_buf, buffer_seek_end, 0);
        return "";
    }
    var _tmp = buffer_create(_len + 1, buffer_fixed, 1);
    buffer_copy(_buf, buffer_tell(_buf), _len, _tmp, 0);
    buffer_poke(_tmp, _len, buffer_u8, 0);
    buffer_seek(_buf, buffer_seek_relative, _len);
    var _s = buffer_read(_tmp, buffer_text);
    buffer_delete(_tmp);
    return _s;
}

function project_recent_path() {
    return game_save_id + "recent_projects.dat";
}

function project_make_thumbnail(_path) {
    var _tw = 320, _th = 180;
    var _surf = surface_create(_tw, _th);
    surface_set_target(_surf);
    draw_clear(c_white);
    var _sc = min(_tw / canvas_w, _th / canvas_h);
    var _dw = canvas_w * _sc, _dh = canvas_h * _sc;
    var _dx = (_tw - _dw) * 0.5, _dy = (_th - _dh) * 0.5;
    for (var _li = array_length(layers) - 1; _li >= 0; _li--) {
        if (!layers[_li].visible) continue;
        var _ri = frame_resolve(layers[_li], 0);
        if (_ri == -1) continue;
        draw_surface_ext(kf_surface(layers[_li].frames[_ri]), _dx, _dy, _sc, _sc, 0, c_white, 1);
    }
    surface_reset_target();
    var _tp = filename_change_ext(_path, "") + ".thumb.png";
    surface_save(_surf, _tp);
    surface_free(_surf);
    return file_exists(_tp) ? _tp : "";
}

function project_save(_path) {
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) {
            if (_fr[_i] != -1) kf_backup(_fr[_i], true);
        }
    }

    var _buf = buffer_create(1024, buffer_grow, 1);
    buffer_write(_buf, buffer_u32, ANST_MAGIC);
    buffer_write(_buf, buffer_u32, ANST_VERSION);

    buf_write_str(_buf, project_name);
    buffer_write(_buf, buffer_u32, canvas_w);
    buffer_write(_buf, buffer_u32, canvas_h);
    buffer_write(_buf, buffer_u32, anim_fps);
    buffer_write(_buf, buffer_u32, total_frames);

    buffer_write(_buf, buffer_u32, array_length(layers));
    for (var _li = 0; _li < array_length(layers); _li++) {
        buf_write_str(_buf, layers[_li].name);
        buffer_write(_buf, buffer_u8, layers[_li].visible ? 1 : 0);
        buffer_write(_buf, buffer_u8, layers[_li].locked  ? 1 : 0);
        var _op = variable_struct_exists(layers[_li], "opacity") ? layers[_li].opacity : 1;
        buffer_write(_buf, buffer_u8, round(clamp(_op, 0, 1) * 255));   // v2: opacity
    }

    var _kf_count = 0;
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) if (_fr[_i] != -1) _kf_count++;
    }
    buffer_write(_buf, buffer_u32, _kf_count);

    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) {
            var _kf = _fr[_i];
            if (_kf == -1) continue;
            buffer_write(_buf, buffer_u32, _li);
            buffer_write(_buf, buffer_u32, _i);
            buffer_write(_buf, buffer_u32, _kf.bx);
            buffer_write(_buf, buffer_u32, _kf.by);
            buffer_write(_buf, buffer_u32, _kf.bw);
            buffer_write(_buf, buffer_u32, _kf.bh);
            if (_kf.cbuf != -1 && _kf.bw > 0) {
                var _raw_sz = buffer_get_size(_kf.cbuf);
                var _comp = buffer_compress(_kf.cbuf, 0, _raw_sz);
                var _csz = buffer_get_size(_comp);
                buffer_write(_buf, buffer_u32, _raw_sz);
                buffer_write(_buf, buffer_u32, _csz);
                buffer_copy(_comp, 0, _csz, _buf, buffer_tell(_buf));
                buffer_seek(_buf, buffer_seek_relative, _csz);
                buffer_delete(_comp);
            } else {
                buffer_write(_buf, buffer_u32, 0);
                buffer_write(_buf, buffer_u32, 0);
            }
        }
    }

    buffer_save(_buf, _path);
    buffer_delete(_buf);

    project_path = _path;
    project_name = filename_change_ext(filename_name(_path), "");
    is_dirty = false;
    var _thumb = project_make_thumbnail(_path);
    project_add_recent(_path, _thumb);
    return true;
}

/// Load a project from _path into the live document.
function project_load(_path) {
    if (!file_exists(_path)) return false;
    var _buf = buffer_load(_path);
    if (_buf == -1) return false;

    var _m = buffer_read(_buf, buffer_u32);
    if (_m == ANST_MAGIC_V1) { return project_load_v1(_buf, _path); }
    if (_m != ANST_MAGIC) { buffer_delete(_buf); return false; }
    var _ver = buffer_read(_buf, buffer_u32);
    if (_ver < 1 || _ver > 3) { buffer_delete(_buf); return false; }
    var _compressed = (_ver >= 2);
    var _has_opacity = (_ver >= 3);

    var _name  = buf_read_str(_buf);
    if (!buf_can_read(_buf, 16)) { buffer_delete(_buf); return false; }
    var _w     = buffer_read(_buf, buffer_u32);
    var _h     = buffer_read(_buf, buffer_u32);
    var _fps   = buffer_read(_buf, buffer_u32);
    var _tf    = buffer_read(_buf, buffer_u32);
    if (_w <= 0 || _w > 16384 || _h <= 0 || _h > 16384 || _fps <= 0 || _tf <= 0) {
        buffer_delete(_buf); return false;
    }

    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) kf_free(_fr[_i]);
    }

    canvas_w = _w; canvas_h = _h; anim_fps = _fps;
    total_frames = _tf; project_name = _name;

    var _lc = buf_can_read(_buf, 4) ? buffer_read(_buf, buffer_u32) : 0;
    layers = [];
    for (var _li = 0; _li < _lc; _li++) {
        var _ln = buf_read_str(_buf);
        if (!buf_can_read(_buf, 2)) break;
        var _lv = buffer_read(_buf, buffer_u8);
        var _ll = buffer_read(_buf, buffer_u8);
        var _layer = layer_make(_ln, total_frames);
        _layer.visible = (_lv != 0);
        _layer.locked  = (_ll != 0);
        if (_has_opacity && buf_can_read(_buf, 1)) {
            _layer.opacity = buffer_read(_buf, buffer_u8) / 255;
        }
        array_push(layers, _layer);
    }
    if (array_length(layers) == 0) layers = [layer_make("Layer 1", total_frames)];

    var _kfc = buf_can_read(_buf, 4) ? buffer_read(_buf, buffer_u32) : 0;
    for (var _k = 0; _k < _kfc; _k++) {
        if (!buf_can_read(_buf, 24)) break;
        var _li = buffer_read(_buf, buffer_u32);
        var _fi = buffer_read(_buf, buffer_u32);
        var _bx = buffer_read(_buf, buffer_u32);
        var _by = buffer_read(_buf, buffer_u32);
        var _bw = buffer_read(_buf, buffer_u32);
        var _bh = buffer_read(_buf, buffer_u32);
        if (!buf_can_read(_buf, 4)) break;
        var _rawlen = buffer_read(_buf, buffer_u32);
        var _blob_len = _rawlen;
        if (_compressed) {
            if (!buf_can_read(_buf, 4)) break;
            _blob_len = buffer_read(_buf, buffer_u32);
        }
        if (!buf_can_read(_buf, _blob_len)) break;   // truncated blob
        if (_li >= array_length(layers) || _fi >= array_length(layers[_li].frames)) {
            buffer_seek(_buf, buffer_seek_relative, _blob_len);
            continue;
        }
        var _kf = keyframe_make();
        _kf.bx = _bx; _kf.by = _by; _kf.bw = _bw; _kf.bh = _bh;
        kf_seed_used(_kf);
        if (_blob_len > 0) {
            if (_compressed) {
                var _cbin = buffer_create(_blob_len, buffer_fixed, 1);
                buffer_copy(_buf, buffer_tell(_buf), _blob_len, _cbin, 0);
                _kf.cbuf = buffer_decompress(_cbin);
                buffer_delete(_cbin);
            } else {
                _kf.cbuf = buffer_create(_blob_len, buffer_fixed, 1);
                buffer_copy(_buf, buffer_tell(_buf), _blob_len, _kf.cbuf, 0);
            }
            buffer_seek(_buf, buffer_seek_relative, _blob_len);
        }
        layers[_li].frames[_fi] = _kf;
    }
    buffer_delete(_buf);

    selected_layer = 0;
    current_frame  = 0;
    is_playing     = false;
    zoom = 1; pan_x = 0; pan_y = 0;
    undo_stack = []; redo_stack = [];
    project_path = _path;
    is_dirty = false;
    project_add_recent(_path);
    return true;
}

function project_load_v1(_buf, _path) {
    if (!buf_can_read(_buf, 4)) { buffer_delete(_buf); return false; }
    var _jlen = buffer_read(_buf, buffer_u32);
    if (!buf_can_read(_buf, _jlen)) { buffer_delete(_buf); return false; }
    var _jbuf = buffer_create(_jlen + 1, buffer_fixed, 1);
    buffer_copy(_buf, buffer_tell(_buf), _jlen, _jbuf, 0);
    buffer_poke(_jbuf, _jlen, buffer_u8, 0);
    var _json = buffer_read(_jbuf, buffer_text);
    buffer_delete(_jbuf);
    buffer_seek(_buf, buffer_seek_relative, _jlen);

    var _header;
    try { _header = json_parse(_json); }
    catch (_e) { buffer_delete(_buf); return false; }

    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) kf_free(_fr[_i]);
    }

    canvas_w = _header.width; canvas_h = _header.height;
    anim_fps = _header.fps;   total_frames = _header.total_frames;
    project_name = _header.name;

    layers = [];
    var _hl = _header.layers;
    for (var _li = 0; _li < array_length(_hl); _li++) {
        var _l = _hl[_li];
        var _layer = layer_make(_l.name, total_frames);
        _layer.visible = _l.visible;
        _layer.locked  = _l.locked;
        array_push(layers, _layer);
    }
    if (array_length(layers) == 0) layers = [layer_make("Layer 1", total_frames)];

    while (buf_can_read(_buf, 4)) {
        var _li2 = buffer_read(_buf, buffer_u32);
        if (_li2 == 0xFFFFFFFF) break;
        if (!buf_can_read(_buf, 24)) break;
        var _fi = buffer_read(_buf, buffer_u32);
        var _bx = buffer_read(_buf, buffer_u32);
        var _by = buffer_read(_buf, buffer_u32);
        var _bw = buffer_read(_buf, buffer_u32);
        var _bh = buffer_read(_buf, buffer_u32);
        var _rlen = buffer_read(_buf, buffer_u32);
        if (!buf_can_read(_buf, _rlen)) break;
        if (_li2 >= array_length(layers) || _fi >= array_length(layers[_li2].frames)) {
            buffer_seek(_buf, buffer_seek_relative, _rlen);
            continue;
        }
        var _kf = keyframe_make();
        _kf.bx = _bx; _kf.by = _by; _kf.bw = _bw; _kf.bh = _bh;
        kf_seed_used(_kf);
        if (_rlen > 0) {
            _kf.cbuf = buffer_create(_rlen, buffer_fixed, 1);
            buffer_copy(_buf, buffer_tell(_buf), _rlen, _kf.cbuf, 0);
            buffer_seek(_buf, buffer_seek_relative, _rlen);
        }
        layers[_li2].frames[_fi] = _kf;
    }
    buffer_delete(_buf);

    selected_layer = 0; current_frame = 0; is_playing = false;
    zoom = 1; pan_x = 0; pan_y = 0;
    undo_stack = []; redo_stack = [];
    project_path = _path; is_dirty = false;
    project_add_recent(_path);
    return true;
}


function project_load_recent() {
    var _p = project_recent_path();
    if (!file_exists(_p)) return [];
    var _buf = buffer_load(_p);
    if (_buf == -1) return [];
    if (buffer_get_size(_buf) < 8 || buffer_read(_buf, buffer_u32) != ANRC_MAGIC) {
        buffer_delete(_buf);
        return [];
    }
    var _count = buffer_read(_buf, buffer_u32);
    var _list = [];
    for (var _i = 0; _i < _count; _i++) {
        var _path = buf_read_str(_buf);
        var _name = buf_read_str(_buf);
        if (!buf_can_read(_buf, 12)) break;
        var _w = buffer_read(_buf, buffer_u32);
        var _h = buffer_read(_buf, buffer_u32);
        var _f = buffer_read(_buf, buffer_u32);
        var _mod = buf_read_str(_buf);
        var _thumb = buf_read_str(_buf);
        if (_path == "") continue;
        array_push(_list, { path: _path, name: _name, width: _w, height: _h, fps: _f, modified: _mod, thumb: _thumb });
    }
    buffer_delete(_buf);
    return _list;
}

function project_save_recent(_list) {
    var _buf = buffer_create(256, buffer_grow, 1);
    buffer_write(_buf, buffer_u32, ANRC_MAGIC);
    buffer_write(_buf, buffer_u32, array_length(_list));
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        buf_write_str(_buf, _e.path);
        buf_write_str(_buf, _e.name);
        buffer_write(_buf, buffer_u32, _e.width);
        buffer_write(_buf, buffer_u32, _e.height);
        buffer_write(_buf, buffer_u32, _e.fps);
        buf_write_str(_buf, _e.modified);
        buf_write_str(_buf, variable_struct_exists(_e, "thumb") ? _e.thumb : "");
    }
    buffer_save(_buf, project_recent_path());
    buffer_delete(_buf);
}

function project_add_recent(_path, _thumb = undefined) {
    var _list = project_load_recent();
    for (var _i = array_length(_list) - 1; _i >= 0; _i--) {
        if (_list[_i].path == _path) {
            if (_thumb == undefined) _thumb = _list[_i].thumb;
            array_delete(_list, _i, 1);
        }
    }
    array_insert(_list, 0, {
        path: _path,
        name: filename_change_ext(filename_name(_path), ""),
        width: canvas_w,
        height: canvas_h,
        fps: anim_fps,
        modified: date_datetime_string(date_current_datetime()),
        thumb: (_thumb == undefined) ? "" : _thumb,
    });
    while (array_length(_list) > 12) array_delete(_list, array_length(_list) - 1, 1);
    project_save_recent(_list);
    recent_projects = _list;
}

function project_remove_recent(_path) {
    var _list = project_load_recent();
    for (var _i = array_length(_list) - 1; _i >= 0; _i--) {
        if (_list[_i].path == _path) array_delete(_list, _i, 1);
    }
    project_save_recent(_list);
    recent_projects = _list;
}

function project_new(_name, _w, _h, _fps, _frames) {
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) kf_free(_fr[_i]);
    }
    project_name  = _name;
    canvas_w      = _w;
    canvas_h      = _h;
    anim_fps      = _fps;
    total_frames  = _frames;
    layers = [layer_make("Layer 1", total_frames)];
    selected_layer = 0;
    current_frame  = 0;
    is_playing     = false;
    zoom = 1; pan_x = 0; pan_y = 0;
    undo_stack = []; redo_stack = [];
    project_path = "";
    is_dirty = false;
}
