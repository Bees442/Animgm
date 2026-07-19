function tf_apply_field(_field, _txt) {
    if (!sel_active) return;
    if (_txt == "" || _txt == "-" || _txt == ".") return;
    var _v = real(_txt);
    editor_push_undo(selected_layer, frame_resolve(layers[selected_layer], current_frame));
    sel_lift();
    switch (_field) {
        case 0: sel_x = _v; break;
        case 1: sel_y = _v; break;
        case 2: sel_w = max(4, _v); break;
        case 3: sel_h = max(4, _v); break;
        case 4: sel_rot = _v; break;
    }
    is_dirty = true;
}

function sel_cx() { return sel_x + sel_w * 0.5; }
function sel_cy() { return sel_y + sel_h * 0.5; }

function sel_handle_pos(_hx, _hy) {
    var _lx = _hx * sel_w * 0.5;
    var _ly = _hy * sel_h * 0.5;
    var _c = dcos(-sel_rot), _s = dsin(-sel_rot);
    return [sel_cx() + _lx * _c - _ly * _s,
            sel_cy() + _lx * _s + _ly * _c];
}

function sel_handle_dirs() {
    return [[-1,-1],[1,-1],[1,1],[-1,1],
            [0,-1],[1,0],[0,1],[-1,0]];
}

function sel_to_local(_px, _py) {
    var _dx = _px - sel_cx(), _dy = _py - sel_cy();
    var _c = dcos(sel_rot), _s = dsin(sel_rot);
    return [_dx * _c - _dy * _s, _dx * _s + _dy * _c];
}

function sel_contains(_px, _py) {
    var _l = sel_to_local(_px, _py);
    return abs(_l[0]) <= sel_w * 0.5 && abs(_l[1]) <= sel_h * 0.5;
}

function sel_draw_float(_surf, _ox, _oy, _zoom, _alpha) {
    if (_surf == -1 || !surface_exists(_surf)) return;
    var _cx = _ox + sel_cx() * _zoom;
    var _cy = _oy + sel_cy() * _zoom;
    var _sx = (sel_w / max(sel_fw, 1)) * _zoom;
    var _sy = (sel_h / max(sel_fh, 1)) * _zoom;
    // draw_surface_ext rotates around its top-left, so the rotated top-left
    // offset has to be computed to land the surface's centre on (_cx,_cy).
    var _hw = sel_fw * 0.5 * _sx, _hh = sel_fh * 0.5 * _sy;
    var _c = dcos(-sel_rot), _s = dsin(-sel_rot);
    var _tlx = _cx + (-_hw) * _c - (-_hh) * _s;
    var _tly = _cy + (-_hw) * _s + (-_hh) * _c;
    draw_surface_ext(_surf, _tlx, _tly, _sx, _sy, sel_rot, c_white, _alpha);
}

function sel_normalize() {
    var _x0 = clamp(min(sel_x, sel_x + sel_w), 0, canvas_w);
    var _y0 = clamp(min(sel_y, sel_y + sel_h), 0, canvas_h);
    var _x1 = clamp(max(sel_x, sel_x + sel_w), 0, canvas_w);
    var _y1 = clamp(max(sel_y, sel_y + sel_h), 0, canvas_h);
    sel_x = _x0; sel_y = _y0; sel_w = _x1 - _x0; sel_h = _y1 - _y0;
    if (sel_w < 1 || sel_h < 1) sel_clear();
}

function sel_clear() {
    if (sel_lifted && sel_float != -1) sel_stamp();
    if (sel_float != -1 && surface_exists(sel_float)) surface_free(sel_float);
    sel_float = -1;
    sel_active = false;
    sel_lifted = false;
    sel_moving = false;
    sel_marquee = false;
    sel_xform = -1;
    sel_rot = 0;
}

function sel_lift() {
    if (sel_lifted || !sel_active || sel_w < 1 || sel_h < 1) return;
    var _kf = active_keyframe();
    var _src = kf_surface(_kf);
    sel_fw = sel_w; sel_fh = sel_h;
    sel_rot = 0;
    sel_float = surface_create(sel_fw, sel_fh);
    surface_set_target(sel_float);
    draw_clear_alpha(c_black, 0);
    surface_reset_target();
    surface_copy_part(sel_float, 0, 0, _src, sel_x, sel_y, sel_w, sel_h);
    surface_set_target(_src);
    gpu_set_blendmode_ext(bm_zero, bm_zero);
    draw_rectangle(sel_x, sel_y, sel_x + sel_w, sel_y + sel_h, false);
    gpu_set_blendmode(bm_normal);
    surface_reset_target();
    kf_mark_used(_kf, sel_x, sel_y, sel_x + sel_w, sel_y + sel_h, 0);
    _kf.dirty = true; kf_backup(_kf);
    sel_lifted = true;
}

function sel_stamp(_drop = false) {
    if (sel_float == -1 || !surface_exists(sel_float)) return;
    var _kf = active_keyframe();
    surface_set_target(kf_surface(_kf));
    gpu_set_tex_filter(true);
    sel_draw_float(sel_float, 0, 0, 1, 1);
    gpu_set_tex_filter(false);
    surface_reset_target();
    var _r = ceil(max(sel_w, sel_h) * 0.75) + 2;
    kf_mark_used(_kf, sel_cx() - _r, sel_cy() - _r, sel_cx() + _r, sel_cy() + _r, 0);
    _kf.dirty = true; kf_backup(_kf);
    sel_lifted = false;
    if (_drop) {
        if (surface_exists(sel_float)) surface_free(sel_float);
        sel_float = -1;
    }
}

function sel_copy() {
    if (!sel_active || sel_w < 1 || sel_h < 1) { editor_toast("Nothing selected"); return; }
    var _src;
    if (sel_lifted && sel_float != -1) _src = sel_float;
    else _src = kf_surface(active_keyframe());
    var _tmp = surface_create(sel_w, sel_h);
    if (sel_lifted) { surface_set_target(_tmp); draw_clear_alpha(c_black,0); surface_reset_target(); surface_copy(_tmp, 0, 0, _src); }
    else surface_copy_part(_tmp, 0, 0, _src, sel_x, sel_y, sel_w, sel_h);
    if (clip_buf != -1) buffer_delete(clip_buf);
    clip_w = sel_w; clip_h = sel_h;
    clip_buf = buffer_create(clip_w * clip_h * 4, buffer_fixed, 1);
    buffer_get_surface(clip_buf, _tmp, 0);
    surface_free(_tmp);
    editor_toast("Copied " + string(clip_w) + "×" + string(clip_h));
}

function sel_cut() {
    if (!sel_active) { editor_toast("Nothing selected"); return; }
    sel_copy();
    sel_delete();
}

function sel_delete() {
    if (!sel_active || sel_w < 1 || sel_h < 1) return;
    var _li = selected_layer;
    editor_push_undo(_li, frame_resolve(layers[_li], current_frame));
    if (sel_lifted) {
        if (sel_float != -1 && surface_exists(sel_float)) surface_free(sel_float);
        sel_float = -1; sel_lifted = false;
    } else {
        var _kf = active_keyframe();
        surface_set_target(kf_surface(_kf));
        gpu_set_blendmode_ext(bm_zero, bm_zero);
        draw_rectangle(sel_x, sel_y, sel_x + sel_w, sel_y + sel_h, false);
        gpu_set_blendmode(bm_normal);
        surface_reset_target();
        _kf.dirty = true; kf_backup(_kf);
    }
}

function sel_paste() {
    if (clip_buf == -1) { editor_toast("Clipboard empty"); return; }
    sel_clear();
    var _li = selected_layer;
    editor_push_undo(_li, frame_resolve(layers[_li], current_frame));
    sel_w = clip_w; sel_h = clip_h;
    sel_x = clamp(floor((canvas_w - sel_w) * 0.5), 0, max(0, canvas_w - sel_w));
    sel_y = clamp(floor((canvas_h - sel_h) * 0.5), 0, max(0, canvas_h - sel_h));
    sel_fw = clip_w; sel_fh = clip_h;
    sel_rot = 0;
    sel_float = surface_create(sel_fw, sel_fh);
    surface_set_target(sel_float);
    draw_clear_alpha(c_black, 0);
    buffer_set_surface(clip_buf, sel_float, 0);
    surface_reset_target();
    sel_active = true;
    sel_lifted = true;
    tool = "select";
    editor_toast("Pasted");
}
