// animgm — brush / shape / flood-fill rendering

/// Draw a solid round-capped polyline (hard-edged) at the given scale/offset.
/// Used both for the live preview and, at 2x, as the source for supersampling.
function draw_polyline_solid(_pts, _w, _col, _ox, _oy, _mul) {
    var _n = array_length(_pts);
    if (_n == 0) return;
    var _r = max(_w * _mul * 0.5, 0.5);
    draw_set_colour(_col);
    var _x0 = (_pts[0][0] - _ox) * _mul, _y0 = (_pts[0][1] - _oy) * _mul;
    draw_circle(_x0, _y0, _r, false);
    for (var _i = 1; _i < _n; _i++) {
        var _px = (_pts[_i-1][0] - _ox) * _mul, _py = (_pts[_i-1][1] - _oy) * _mul;
        var _cx = (_pts[_i][0]   - _ox) * _mul, _cy = (_pts[_i][1]   - _oy) * _mul;
        draw_line_width(_px, _py, _cx, _cy, _w * _mul);
        draw_circle(_cx, _cy, _r, false);
    }
}

/// Round-capped polyline for LIVE PREVIEW (drawn straight to screen at 1x).
function draw_polyline_round(_pts, _w, _col) {
    draw_polyline_solid(_pts, _w, _col, 0, 0, 1);
}

/// Commit an ANTIALIASED brush stroke onto _target via 2x supersampling:
/// render the stroke solid on a 2x scratch surface, then draw it back at 0.5x
/// with linear filtering so the edges get smooth, Photoshop-like coverage.
function commit_stroke_aa(_target, _pts, _w, _col) {
    var _n = array_length(_pts);
    if (_n == 0) return;
    var _pad = _w * 0.5 + 2;
    var _minx = _pts[0][0], _miny = _pts[0][1], _maxx = _pts[0][0], _maxy = _pts[0][1];
    for (var _i = 1; _i < _n; _i++) {
        _minx = min(_minx, _pts[_i][0]); _maxx = max(_maxx, _pts[_i][0]);
        _miny = min(_miny, _pts[_i][1]); _maxy = max(_maxy, _pts[_i][1]);
    }
    var _sw = surface_get_width(_target), _sh = surface_get_height(_target);
    var _bx = clamp(floor(_minx - _pad), 0, _sw);
    var _by = clamp(floor(_miny - _pad), 0, _sh);
    var _bw = clamp(ceil(_maxx + _pad), 0, _sw) - _bx;
    var _bh = clamp(ceil(_maxy + _pad), 0, _sh) - _by;
    if (_bw <= 0 || _bh <= 0) return;

    var _ss = 2;   // supersample factor
    var _scratch = surface_create(_bw * _ss, _bh * _ss);
    surface_set_target(_scratch);
    draw_clear_alpha(c_black, 0);
    draw_polyline_solid(_pts, _w, _col, _bx, _by, _ss);
    surface_reset_target();

    surface_set_target(_target);
    gpu_set_tex_filter(true);
    draw_surface_ext(_scratch, _bx, _by, 1 / _ss, 1 / _ss, 0, c_white, 1);
    gpu_set_tex_filter(false);
    surface_reset_target();
    surface_free(_scratch);
}

/// Simple neighbour-average smoothing (approximates brushSmoothing)
function stroke_smooth(_pts, _amount) {
    var _passes = floor(_amount / 25);
    for (var _p = 0; _p < _passes; _p++) {
        var _n = array_length(_pts);
        if (_n < 3) return _pts;
        var _out = array_create(_n);
        _out[0] = _pts[0];
        _out[_n - 1] = _pts[_n - 1];
        for (var _i = 1; _i < _n - 1; _i++) {
            _out[_i] = [
                (_pts[_i - 1][0] + _pts[_i][0] * 2 + _pts[_i + 1][0]) * 0.25,
                (_pts[_i - 1][1] + _pts[_i][1] * 2 + _pts[_i + 1][1]) * 0.25,
            ];
        }
        _pts = _out;
    }
    return _pts;
}

/// Polygon vertices for the shape tool, inside the drag box (x0,y0)-(x1,y1)
function shape_points(_kind, _x0, _y0, _x1, _y1) {
    var _cx = (_x0 + _x1) * 0.5, _cy = (_y0 + _y1) * 0.5;
    var _rx = abs(_x1 - _x0) * 0.5, _ry = abs(_y1 - _y0) * 0.5;
    var _pts = [];
    switch (_kind) {
        case "rectangle":
            return [[min(_x0,_x1), min(_y0,_y1)], [max(_x0,_x1), min(_y0,_y1)],
                    [max(_x0,_x1), max(_y0,_y1)], [min(_x0,_x1), max(_y0,_y1)]];
        case "triangle":
            return [[_cx, _cy - _ry], [_cx + _rx, _cy + _ry], [_cx - _rx, _cy + _ry]];
        case "diamond":
            return [[_cx, _cy - _ry], [_cx + _rx, _cy], [_cx, _cy + _ry], [_cx - _rx, _cy]];
        case "pentagon":
        case "hexagon": {
            var _sides = (_kind == "pentagon") ? 5 : 6;
            for (var _i = 0; _i < _sides; _i++) {
                var _a = -90 + _i * 360 / _sides;
                array_push(_pts, [_cx + _rx * dcos(_a), _cy + _ry * dsin(_a)]);
            }
            return _pts;
        }
        case "star": {
            for (var _i = 0; _i < 10; _i++) {
                var _a = -90 + _i * 36;
                var _k = (_i % 2 == 0) ? 1 : 0.45;
                array_push(_pts, [_cx + _rx * _k * dcos(_a), _cy + _ry * _k * dsin(_a)]);
            }
            return _pts;
        }
    }
    return _pts;
}

/// Draw the shape preview / commit (fill + stroke) with current colours
function draw_shape(_kind, _x0, _y0, _x1, _y1, _fill, _stroke, _sw) {
    if (_kind == "circle" || _kind == "ellipse") {
        var _cx = (_x0 + _x1) * 0.5, _cy = (_y0 + _y1) * 0.5;
        var _rx = abs(_x1 - _x0) * 0.5, _ry = abs(_y1 - _y0) * 0.5;
        if (_kind == "circle") { _rx = min(_rx, _ry); _ry = _rx; }
        draw_set_colour(_fill);
        draw_ellipse(_cx - _rx, _cy - _ry, _cx + _rx, _cy + _ry, false);
        var _pts = [];
        for (var _i = 0; _i <= 48; _i++) {
            var _a = _i * 360 / 48;
            array_push(_pts, [_cx + _rx * dcos(_a), _cy + _ry * dsin(_a)]);
        }
        draw_polyline_round(_pts, _sw, _stroke);
        return;
    }
    var _pts = shape_points(_kind, _x0, _y0, _x1, _y1);
    var _n = array_length(_pts);
    if (_n < 3) return;
    draw_set_colour(_fill);
    draw_primitive_begin(pr_trianglefan);
    for (var _i = 0; _i < _n; _i++) draw_vertex(_pts[_i][0], _pts[_i][1]);
    draw_primitive_end();
    var _closed = _pts;
    array_push(_closed, _pts[0]);
    draw_polyline_round(_closed, _sw, _stroke);
}

/// True if the pixel at buffer offset _off matches the seed within tolerance
/// and hasn't already been set to the fill colour.
function flood_match(_buf, _off, _sr, _sg, _sb, _sa, _tol, _fill) {
    var _p = buffer_peek(_buf, _off, buffer_u32);
    if (_p == _fill) return false;                    // already filled
    var _r = _p & $FF, _g = (_p >> 8) & $FF, _b = (_p >> 16) & $FF, _a = (_p >> 24) & $FF;
    return abs(_r - _sr) <= _tol && abs(_g - _sg) <= _tol
        && abs(_b - _sb) <= _tol && abs(_a - _sa) <= _tol;
}

/// Flood-fill the keyframe surface starting at (_sx,_sy) with _col, replacing
/// the connected region of pixels that match the seed colour (within a small
/// tolerance). Works on a CPU copy of the surface, then uploads the sub-rect.
function editor_flood_fill(_kf, _sx, _sy, _col) {
    var _w = canvas_w, _h = canvas_h;
    _sx = floor(_sx); _sy = floor(_sy);
    if (_sx < 0 || _sy < 0 || _sx >= _w || _sy >= _h) return;

    var _surf = kf_surface(_kf);
    var _buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
    buffer_get_surface(_buf, _surf, 0);

    // surface buffer is RGBA little-endian => byte0=R,1=G,2=B,3=A
    var _seed = buffer_peek(_buf, (_sy * _w + _sx) * 4, buffer_u32);
    var _fill = colour_get_red(_col) | (colour_get_green(_col) << 8)
              | (colour_get_blue(_col) << 16) | (255 << 24);
    if (_seed == _fill) { buffer_delete(_buf); return; }

    var _sr = _seed & $FF, _sg = (_seed >> 8) & $FF, _sb = (_seed >> 16) & $FF, _sa = (_seed >> 24) & $FF;
    var _tol = 24;   // per-channel tolerance so anti-aliased edges fill too

    var _stack = ds_stack_create();
    ds_stack_push(_stack, _sx, _sy);
    var _minx = _sx, _miny = _sy, _maxx = _sx, _maxy = _sy;

    while (!ds_stack_empty(_stack)) {
        var _y = ds_stack_pop(_stack);
        var _x = ds_stack_pop(_stack);
        var _lx = _x;
        while (_lx >= 0 && flood_match(_buf, (_y * _w + _lx) * 4, _sr, _sg, _sb, _sa, _tol, _fill)) _lx--;
        _lx++;
        var _spanUp = false, _spanDown = false;
        var _rx = _lx;
        while (_rx < _w && flood_match(_buf, (_y * _w + _rx) * 4, _sr, _sg, _sb, _sa, _tol, _fill)) {
            buffer_poke(_buf, (_y * _w + _rx) * 4, buffer_u32, _fill);
            if (_rx < _minx) _minx = _rx;
            if (_rx > _maxx) _maxx = _rx;
            if (_y > 0) {
                var _up = flood_match(_buf, ((_y - 1) * _w + _rx) * 4, _sr, _sg, _sb, _sa, _tol, _fill);
                if (_up && !_spanUp) { ds_stack_push(_stack, _rx, _y - 1); _spanUp = true; }
                else if (!_up) _spanUp = false;
            }
            if (_y < _h - 1) {
                var _dn = flood_match(_buf, ((_y + 1) * _w + _rx) * 4, _sr, _sg, _sb, _sa, _tol, _fill);
                if (_dn && !_spanDown) { ds_stack_push(_stack, _rx, _y + 1); _spanDown = true; }
                else if (!_dn) _spanDown = false;
            }
            _rx++;
        }
        if (_y < _miny) _miny = _y;
        if (_y > _maxy) _maxy = _y;
    }
    ds_stack_destroy(_stack);

    // upload only the affected sub-rect back to the surface
    var _bw = _maxx - _minx + 1, _bh = _maxy - _miny + 1;
    var _sub = buffer_create(_bw * _bh * 4, buffer_fixed, 1);
    for (var _row = 0; _row < _bh; _row++) {
        buffer_copy(_buf, ((_miny + _row) * _w + _minx) * 4, _bw * 4, _sub, _row * _bw * 4);
    }
    var _tmp = surface_create(_bw, _bh);
    buffer_set_surface(_sub, _tmp, 0);
    surface_set_target(_surf);
    // overwrite the sub-rect exactly (no alpha blend) so filled pixels replace
    gpu_set_blendmode_ext(bm_one, bm_zero);
    draw_surface(_tmp, _minx, _miny);
    gpu_set_blendmode(bm_normal);
    surface_reset_target();
    surface_free(_tmp);
    buffer_delete(_sub);
    buffer_delete(_buf);

    kf_mark_used(_kf, _minx, _miny, _maxx + 1, _maxy + 1, 0);
    _kf.dirty = true; kf_backup(_kf);
}
