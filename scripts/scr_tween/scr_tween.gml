function tween_can_start() {
    return sel_active && sel_w >= 1 && sel_h >= 1 && !tween_active;
}

function tween_start() {
    if (!tween_can_start()) return;
    editor_push_undo(selected_layer, frame_resolve(layers[selected_layer], current_frame));
    sel_lift();

    tween_active   = true;
    tween_li       = selected_layer;
    tween_start_fr = current_frame;
    tween_fw = sel_fw; tween_fh = sel_fh;
    tween_start_x = sel_x; tween_start_y = sel_y;
    tween_start_w = sel_w; tween_start_h = sel_h;
    tween_start_rot = sel_rot;

    if (tween_buf != -1) buffer_delete(tween_buf);
    tween_buf = buffer_create(tween_fw * tween_fh * 4, buffer_fixed, 1);
    buffer_get_surface(tween_buf, sel_float, 0);

    editor_toast("Tween start set — move the playhead, pose the end, then Finish Tween");
}

function tween_wrap180(_d) {
    _d = _d mod 360;
    if (_d > 180) _d -= 360;
    if (_d <= -180) _d += 360;
    return _d;
}

// Reuses sel_draw_float's rotation math by momentarily driving it with the
// interpolated pose instead of the live selection state.
function tween_stamp(_x, _y, _w, _h, _rot) {
    var _tsurf = surface_create(tween_fw, tween_fh);
    buffer_set_surface(tween_buf, _tsurf, 0);
    var _sx = sel_x, _sy = sel_y, _sw = sel_w, _sh = sel_h, _sr = sel_rot, _sfw = sel_fw, _sfh = sel_fh;
    sel_x = _x; sel_y = _y; sel_w = _w; sel_h = _h; sel_rot = _rot; sel_fw = tween_fw; sel_fh = tween_fh;
    gpu_set_tex_filter(true);
    sel_draw_float(_tsurf, 0, 0, 1, 1);
    gpu_set_tex_filter(false);
    sel_x = _sx; sel_y = _sy; sel_w = _sw; sel_h = _sh; sel_rot = _sr; sel_fw = _sfw; sel_fh = _sfh;
    surface_free(_tsurf);
}

function tween_finish() {
    if (!tween_active) return;
    tween_end_fr = current_frame;
    if (tween_end_fr == tween_start_fr) {
        editor_toast("Move the playhead to a different frame for the tween end");
        return;
    }

    var _end_x = sel_x, _end_y = sel_y, _end_w = sel_w, _end_h = sel_h, _end_rot = sel_rot;
    var _rot_delta = tween_wrap180(_end_rot - tween_start_rot);
    var _f0 = min(tween_start_fr, tween_end_fr);
    var _f1 = max(tween_start_fr, tween_end_fr);
    var _span = tween_end_fr - tween_start_fr;

    for (var _f = _f0; _f <= _f1; _f++) {
        var _t = (_f - tween_start_fr) / _span;
        var _te = _t * _t * (3 - 2 * _t);   // ease-in/out, not raw linear
        var _x = lerp(tween_start_x, _end_x, _te);
        var _y = lerp(tween_start_y, _end_y, _te);
        var _w = lerp(tween_start_w, _end_w, _te);
        var _h = lerp(tween_start_h, _end_h, _te);
        var _rot = tween_start_rot + _rot_delta * _te;

        editor_push_undo(tween_li, frame_resolve(layers[tween_li], _f));
        var _kf = layers[tween_li].frames[_f];
        if (_kf == -1) { _kf = keyframe_make(); layers[tween_li].frames[_f] = _kf; }
        surface_set_target(kf_surface(_kf));
        tween_stamp(_x, _y, _w, _h, _rot);
        surface_reset_target();
        var _r = ceil(max(_w, _h) * 0.75) + 2;
        var _cx = _x + _w * 0.5, _cy = _y + _h * 0.5;
        kf_mark_used(_kf, _cx - _r, _cy - _r, _cx + _r, _cy + _r, 0);
        _kf.dirty = true; kf_backup(_kf);
    }

    array_push(layers[tween_li].tweens, [_f0, _f1]);

    is_dirty = true;
    editor_toast("Tween generated: frames " + string(_f0 + 1) + "-" + string(_f1 + 1));
    tween_cancel();
}

function tween_cancel() {
    if (sel_float != -1 && surface_exists(sel_float)) surface_free(sel_float);
    sel_float = -1;
    sel_active = false;
    sel_lifted = false;
    sel_rot = 0;
    if (tween_buf != -1) { buffer_delete(tween_buf); tween_buf = -1; }
    tween_active = false;
    tween_li = -1;
}
