// animgm — document model: layers, keyframes, surfaces

function layer_make(_name, _nframes) {
    return {
        name: _name,
        visible: true,
        locked: false,
        opacity: 1.0,                          // 0..1 layer transparency
        frames: array_create(_nframes, -1),   // -1 = no keyframe; struct = keyframe
    };
}

function keyframe_make() {
    // surf : live surface (VRAM), created on demand, freed when off-screen.
    // cbuf : raw ARGB backing store (RAM) of just the used sub-rect [bx,by,bw,bh].
    //        Uncompressed on purpose — GameMaker's buffer_compress/decompress
    //        (zlib) costs ~550 ms on a full-canvas buffer and caused the stutters.
    //        Cropping to the drawn bounding box keeps RAM small instead.
    // touched : last epoch at which this surface was used (LRU eviction).
    // dirty : surface has unsaved edits vs cbuf.
    // used_* : accumulated bounding box of everything ever drawn on this frame,
    //          grown incrementally so kf_backup never scans the whole canvas.
    return {
        surf: -1, cbuf: -1, bx: 0, by: 0, bw: 0, bh: 0,
        used_x0: 999999, used_y0: 999999, used_x1: -1, used_y1: -1,
        touched: 0, dirty: false,
    };
}

/// Seed a keyframe's used-rect from its stored [bx,by,bw,bh] (after load/undo).
function kf_seed_used(_kf) {
    if (_kf.bw > 0 && _kf.bh > 0) {
        _kf.used_x0 = _kf.bx;
        _kf.used_y0 = _kf.by;
        _kf.used_x1 = _kf.bx + _kf.bw;
        _kf.used_y1 = _kf.by + _kf.bh;
    } else {
        _kf.used_x0 = 999999; _kf.used_y0 = 999999;
        _kf.used_x1 = -1;     _kf.used_y1 = -1;
    }
}

/// Grow a keyframe's accumulated used-rect to include [_x0,_y0,_x1,_y1]
/// (canvas coords), clamped to the canvas and padded by _pad px.
function kf_mark_used(_kf, _x0, _y0, _x1, _y1, _pad) {
    var _ax0 = clamp(floor(min(_x0, _x1) - _pad), 0, canvas_w);
    var _ay0 = clamp(floor(min(_y0, _y1) - _pad), 0, canvas_h);
    var _ax1 = clamp(ceil(max(_x0, _x1) + _pad), 0, canvas_w);
    var _ay1 = clamp(ceil(max(_y0, _y1) + _pad), 0, canvas_h);
    if (_ax0 < _kf.used_x0) _kf.used_x0 = _ax0;
    if (_ay0 < _kf.used_y0) _kf.used_y0 = _ay0;
    if (_ax1 > _kf.used_x1) _kf.used_x1 = _ax1;
    if (_ay1 > _kf.used_y1) _kf.used_y1 = _ay1;
}

/// Index of the keyframe that is shown at frame _f (Flash-style span), or -1.
function frame_resolve(_layer, _f) {
    for (var _i = min(_f, array_length(_layer.frames) - 1); _i >= 0; _i--) {
        if (_layer.frames[_i] != -1) return _i;
    }
    return -1;
}

/// Make sure the keyframe's surface exists (restores from the compressed
/// backing store after a surface loss or eviction).
function kf_surface(_kf) {
    if (!surface_exists(_kf.surf)) {
        _kf.surf = surface_create(canvas_w, canvas_h);
        if (_kf.cbuf != -1) {
            // Uploading only the used sub-rect keeps this fast even at 1080p.
            if (_kf.bw > 0 && _kf.bh > 0) {
                surface_set_target(_kf.surf);
                draw_clear_alpha(c_black, 0);
                surface_reset_target();
                var _tmp = surface_create(_kf.bw, _kf.bh);
                buffer_set_surface(_kf.cbuf, _tmp, 0);
                surface_copy(_kf.surf, _kf.bx, _kf.by, _tmp);
                surface_free(_tmp);
            } else {
                surface_set_target(_kf.surf);
                draw_clear_alpha(c_black, 0);
                surface_reset_target();
            }
        } else {
            surface_set_target(_kf.surf);
            draw_clear_alpha(c_black, 0);
            surface_reset_target();
        }
    }
    _kf.touched = kf_epoch;
    return _kf.surf;
}

/// Persist surface pixels into the keyframe's backing store, cropped to the
/// incrementally-tracked used-rect. No full-canvas scan (that cost ~360 ms and
/// caused the draw/undo stutters) and no zlib — just a small ARGB sub-rect copy.
/// No-op when the surface has no unsaved edits.
function kf_backup(_kf, _force = false) {
    if (!surface_exists(_kf.surf)) return;
    if (!_kf.dirty && !_force && _kf.cbuf != -1) return;   // already up to date

    var _t0 = dbg_perf ? get_timer() : 0;
    if (_kf.cbuf != -1) { buffer_delete(_kf.cbuf); _kf.cbuf = -1; }

    if (_kf.used_x1 < 0) {
        _kf.bx = 0; _kf.by = 0; _kf.bw = 0; _kf.bh = 0;
    } else {
        _kf.bx = _kf.used_x0;
        _kf.by = _kf.used_y0;
        _kf.bw = _kf.used_x1 - _kf.used_x0;
        _kf.bh = _kf.used_y1 - _kf.used_y0;
        if (_kf.bw <= 0 || _kf.bh <= 0) {
            _kf.bx = 0; _kf.by = 0; _kf.bw = 0; _kf.bh = 0;
        } else {
            var _tmp = surface_create(_kf.bw, _kf.bh);
            surface_copy_part(_tmp, 0, 0, _kf.surf, _kf.bx, _kf.by, _kf.bw, _kf.bh);
            _kf.cbuf = buffer_create(_kf.bw * _kf.bh * 4, buffer_fixed, 1);
            buffer_get_surface(_kf.cbuf, _tmp, 0);
            surface_free(_tmp);
        }
    }
    _kf.dirty = false;
    if (dbg_perf) show_debug_message("kf_backup: " + string((get_timer() - _t0) / 1000) + " ms  (" + string(_kf.bw) + "x" + string(_kf.bh) + ")");
}

/// Drop the live surface but keep the pixels (compressed) in RAM.
/// Only re-compresses if the surface was edited since the last backup.
function kf_evict_surface(_kf) {
    if (_kf == -1 || !surface_exists(_kf.surf)) return;
    if (_kf.dirty || _kf.cbuf == -1) kf_backup(_kf);
    surface_free(_kf.surf);
    _kf.surf = -1;
}

function kf_free(_kf) {
    if (_kf == -1) return;
    if (surface_exists(_kf.surf)) surface_free(_kf.surf);
    if (_kf.cbuf != -1) buffer_delete(_kf.cbuf);
}

/// Keyframe drawing goes to: resolved keyframe, or a new one on the current
/// frame when the layer has none yet.
function active_keyframe() {
    var _layer = layers[selected_layer];
    var _ri = frame_resolve(_layer, current_frame);
    if (_ri == -1) {
        _layer.frames[current_frame] = keyframe_make();
        _ri = current_frame;
    }
    return _layer.frames[_ri];
}

/// Keep VRAM bounded without thrashing. A surface is only freed once it has
/// gone unused for KF_SURFACE_GRACE epochs — so scrubbing / looping playback
/// reuses cached surfaces instead of decompressing 8 MB every tick. If the
/// live-surface count exceeds KF_SURFACE_BUDGET, the least-recently-used ones
/// are evicted immediately to hold the ceiling.
function editor_evict_surfaces() {
    // gather live surfaces (skip current-frame / onion neighbours implicitly:
    // those are touched this epoch and never past the grace window)
    var _live = [];
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) {
            var _kf = _fr[_i];
            if (_kf == -1 || !surface_exists(_kf.surf)) continue;
            var _age = kf_epoch - _kf.touched;
            if (_age >= KF_SURFACE_GRACE) kf_evict_surface(_kf);
            else array_push(_live, _kf);
        }
    }
    // budget cap: if still too many, evict the oldest first
    var _n = array_length(_live);
    if (_n > KF_SURFACE_BUDGET) {
        array_sort(_live, function(_a, _b) { return _a.touched - _b.touched; });
        var _drop = _n - KF_SURFACE_BUDGET;
        for (var _i = 0; _i < _drop; _i++) kf_evict_surface(_live[_i]);
    }
}

/// Total bytes held by compressed keyframe backing stores + undo/redo.
function editor_mem_bytes() {
    var _b = 0;
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) {
            if (_fr[_i] != -1 && _fr[_i].cbuf != -1) _b += buffer_get_size(_fr[_i].cbuf);
        }
    }
    for (var _i = 0; _i < array_length(undo_stack); _i++) if (undo_stack[_i].cbuf != -1) _b += buffer_get_size(undo_stack[_i].cbuf);
    for (var _i = 0; _i < array_length(redo_stack); _i++) if (redo_stack[_i].cbuf != -1) _b += buffer_get_size(redo_stack[_i].cbuf);
    return _b;
}

function editor_count_keyframes() {
    var _n = 0;
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) {
            if (_fr[_i] != -1) _n++;
        }
    }
    return _n;
}
