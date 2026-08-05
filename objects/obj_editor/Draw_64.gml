
var _mgx = device_mouse_x_to_gui(0);
var _mgy = device_mouse_y_to_gui(0);
var _ox = cv_x + (cv_w - canvas_w * zoom) * 0.5 + pan_x;
var _oy = cv_y + (cv_h - canvas_h * zoom) * 0.5 + pan_y;

draw_set_halign(fa_left);
draw_set_valign(fa_top);

if (screen == "manager") {
    pm_draw();
    exit;
}

ui_rect(cv_x, cv_y, cv_w, cv_h, COL_BG_CANVAS);

draw_set_alpha(0.3);
draw_set_colour(COL_GRID);
for (var _gx = cv_x; _gx < cv_x + cv_w; _gx += 20) draw_line(_gx, cv_y, _gx, cv_y + cv_h);
for (var _gy = cv_y; _gy < cv_y + cv_h; _gy += 20) draw_line(cv_x, _gy, cv_x + cv_w, _gy);
draw_set_alpha(1);

var _cw = canvas_w * zoom, _ch = canvas_h * zoom;
ui_rect(_ox, _oy, _cw, _ch, c_white);

if (onion_skin && !is_playing && array_length(layers) > 0) {
    var _lay = layers[selected_layer];
    var _cur_ri = frame_resolve(_lay, current_frame);
    if (current_frame > 0) {
        var _ri = frame_resolve(_lay, current_frame - 1);
        if (_ri != -1 && _ri != _cur_ri) {
            draw_surface_ext(kf_surface(_lay.frames[_ri]), _ox, _oy, zoom, zoom, 0, c_white, 0.3);
        }
    }
    if (current_frame < total_frames - 1) {
        var _ri2 = frame_resolve(_lay, current_frame + 1);
        if (_ri2 != -1 && _ri2 != _cur_ri) {
            draw_surface_ext(kf_surface(_lay.frames[_ri2]), _ox, _oy, zoom, zoom, 0, c_white, 0.18);
        }
    }
}

for (var _li = array_length(layers) - 1; _li >= 0; _li--) {
    var _lay = layers[_li];
    if (!_lay.visible) continue;
    var _ri = frame_resolve(_lay, current_frame);
    if (_ri == -1) continue;
    var _op = variable_struct_exists(_lay, "opacity") ? _lay.opacity : 1;
    draw_surface_ext(kf_surface(_lay.frames[_ri]), _ox, _oy, zoom, zoom, 0, c_white, _op);
}

if (is_drawing && array_length(stroke_pts) > 0) {
    var _n = array_length(stroke_pts);
    var _tp = array_create(_n + 1);
    for (var _i = 0; _i < _n; _i++) {
        _tp[_i] = [_ox + stroke_pts[_i][0] * zoom, _oy + stroke_pts[_i][1] * zoom];
    }
    _tp[_n] = [_ox + pen_x * zoom, _oy + pen_y * zoom];
    var _pw = stroke_width * zoom;
    draw_polyline_round(_tp, max(_pw, 1), stroke_color);
}
if (shape_drag) {
    var _sx0 = _ox + drag_x0 * zoom, _sy0 = _oy + drag_y0 * zoom;
    var _sx1 = _ox + drag_x1 * zoom, _sy1 = _oy + drag_y1 * zoom;
    if (tool == "line") {
        draw_polyline_round([[_sx0, _sy0], [_sx1, _sy1]], max(stroke_width * zoom, 1), stroke_color);
    } else {
        draw_shape(selected_shape, _sx0, _sy0, _sx1, _sy1, fill_color, stroke_color, max(stroke_width * zoom, 1));
    }
}

if (sel_active && sel_lifted && sel_float != -1 && surface_exists(sel_float)) {
    gpu_set_tex_filter(true);
    sel_draw_float(sel_float, _ox, _oy, zoom, 1);
    gpu_set_tex_filter(false);
}

if ((sel_active || sel_marquee) && sel_w >= 1 && sel_h >= 1) {
    var _dirs = sel_handle_dirs();
    var _corn = array_create(4);
    for (var _ci = 0; _ci < 4; _ci++) {
        var _cp = sel_handle_pos(_dirs[_ci][0], _dirs[_ci][1]);
        _corn[_ci] = [_ox + _cp[0] * zoom, _oy + _cp[1] * zoom];
    }
    draw_set_alpha(0.08);
    draw_set_colour(COL_PRIMARY);
    draw_primitive_begin(pr_trianglefan);
    for (var _ci = 0; _ci < 4; _ci++) draw_vertex(_corn[_ci][0], _corn[_ci][1]);
    draw_primitive_end();
    draw_set_alpha(1);
    var _dash = 6;
    var _ph = (sel_ants * _dash) mod (_dash * 2);
    for (var _s = 0; _s < 4; _s++) {
        var _a = _corn[_s], _b = _corn[(_s + 1) mod 4];
        var _len = point_distance(_a[0], _a[1], _b[0], _b[1]);
        var _dx = (_b[0] - _a[0]) / max(_len, 1), _dy = (_b[1] - _a[1]) / max(_len, 1);
        var _t = -_ph;
        while (_t < _len) {
            var _s0 = max(_t, 0), _s1 = min(_t + _dash, _len);
            if (_s1 > _s0) {
                draw_set_colour(((floor((_t + _ph) / _dash) mod 2) == 0) ? c_white : c_black);
                draw_line(_a[0] + _dx * _s0, _a[1] + _dy * _s0, _a[0] + _dx * _s1, _a[1] + _dy * _s1);
            }
            _t += _dash;
        }
    }
    if (sel_active && !sel_marquee) {
        var _hs = 6;
        var _tc = sel_handle_pos(0, -1);
        var _tcx = _ox + _tc[0] * zoom, _tcy = _oy + _tc[1] * zoom;
        var _up = sel_handle_pos(0, -1 - 30 / max(sel_h * 0.5 * zoom, 1));
        var _rx = _ox + _up[0] * zoom, _ry = _oy + _up[1] * zoom;
        draw_set_colour(COL_PRIMARY);
        draw_line(_tcx, _tcy, _rx, _ry);
        draw_circle_colour(_rx, _ry, _hs - 1, c_white, c_white, false);
        draw_circle_colour(_rx, _ry, _hs - 1, COL_PRIMARY, COL_PRIMARY, true);
        for (var _hi = 0; _hi < 8; _hi++) {
            var _hp = sel_handle_pos(_dirs[_hi][0], _dirs[_hi][1]);
            var _hx = _ox + _hp[0] * zoom, _hy = _oy + _hp[1] * zoom;
            ui_rect(_hx - _hs, _hy - _hs, _hs * 2, _hs * 2, c_white);
            ui_rect_outline(_hx - _hs, _hy - _hs, _hs * 2, _hs * 2, COL_PRIMARY);
        }
    }
    draw_set_colour(c_white);
    draw_set_alpha(1);
}

draw_set_font(fnt_mono_sm);
var _ztxt = string(round(zoom * 100)) + "%";
var _zdw = string_width(_ztxt) + 16;
var _zp_w = 8 + 28 + 8 + _zdw + 8 + 28 + 8 + 28 + 8;
var _zp_h = 44;
var _zp_x = cv_x + cv_w - 16 - _zp_w;
var _zp_y = cv_y + cv_h - 16 - _zp_h;
ui_roundrect(_zp_x, _zp_y, _zp_w, _zp_h, 8, COL_BG_PANEL);
ui_roundrect_outline(_zp_x, _zp_y, _zp_w, _zp_h, 8, COL_BORDER);
var _zb_y = _zp_y + 8;
var _bx = _zp_x + 8;
if (ui_hover(_bx, _zb_y, 28, 28)) ui_roundrect(_bx, _zb_y, 28, 28, 4, COL_HOVER);
ui_icon(spr_ic_zoom_out, _bx + 14, _zb_y + 14, 16, COL_TEXT);
if (ui_clicked(_bx, _zb_y, 28, 28)) editor_zoom_at(cv_x + cv_w * 0.5, cv_y + cv_h * 0.5, 1 / 1.2);
_bx += 28 + 8;
draw_set_colour(COL_TEXT_2);
draw_set_valign(fa_middle);
draw_text(_bx + 8, _zb_y + 14, _ztxt);
draw_set_valign(fa_top);
_bx += _zdw + 8;
if (ui_hover(_bx, _zb_y, 28, 28)) ui_roundrect(_bx, _zb_y, 28, 28, 4, COL_HOVER);
ui_icon(spr_ic_zoom_in, _bx + 14, _zb_y + 14, 16, COL_TEXT);
if (ui_clicked(_bx, _zb_y, 28, 28)) editor_zoom_at(cv_x + cv_w * 0.5, cv_y + cv_h * 0.5, 1.2);
_bx += 28 + 8;
if (ui_hover(_bx, _zb_y, 28, 28)) ui_roundrect(_bx, _zb_y, 28, 28, 4, COL_HOVER);
ui_icon(spr_ic_maximize_2, _bx + 14, _zb_y + 14, 16, COL_TEXT);
if (ui_clicked(_bx, _zb_y, 28, 28)) editor_fit_canvas();

ui_rect(0, cv_y, tb_w, cv_h, COL_BG_PANEL);
ui_rect(tb_w - 1, cv_y, 1, cv_h, COL_BORDER);

var _tb_vis = pt_in(_mgx, _mgy, 0, cv_y, tb_w, cv_h);

var _ty = cv_y + 8 - tb_scroll;
for (var _t = 0; _t < array_length(tool_ids); _t++) {
    var _active = (tool == tool_ids[_t]);
    var _icon = tool_icons[_t];
    if (tool_ids[_t] == "shape") {
        for (var _s = 0; _s < array_length(shape_ids); _s++) {
            if (shape_ids[_s] == selected_shape) { _icon = shape_icons[_s]; break; }
        }
    }
    if (_active) ui_rect(0, _ty, tb_w, 44, COL_PRIMARY);
    else if (_tb_vis && ui_hover(0, _ty, tb_w, 44)) ui_rect(0, _ty, tb_w, 44, COL_HOVER);
    ui_icon(_icon, tb_w * 0.5, _ty + 22, 20, COL_TEXT);
    if (_tb_vis && ui_clicked(0, _ty, tb_w, 44)) tool = tool_ids[_t];
    _ty += 46;
}

ui_rect(4, _ty + 8, tb_w - 8, 1, COL_BORDER);
_ty += 8 + 1 + 8;

var _sw_x = (tb_w - 32) * 0.5;
var _sw_y = _ty;
ui_rect(_sw_x + 12, _sw_y + 12, 20, 20, COL_BORDER);
ui_rect(_sw_x + 14, _sw_y + 14, 16, 16, fill_color);
if (_tb_vis && ui_clicked(_sw_x + 12, _sw_y + 12, 20, 20)) editor_pick_colour("fill");
ui_rect(_sw_x, _sw_y, 24, 24, COL_BORDER);
ui_rect(_sw_x + 2, _sw_y + 2, 20, 20, stroke_color);
if (_tb_vis && ui_clicked(_sw_x, _sw_y, 24, 24)) editor_pick_colour("stroke");
var _sb_y2 = _sw_y + 32 + 4;
ui_roundrect(_sw_x, _sb_y2, 32, 24, 4, ui_hover(_sw_x, _sb_y2, 32, 24) ? COL_HOVER : COL_BG_CANVAS);
ui_roundrect_outline(_sw_x, _sb_y2, 32, 24, 4, COL_BORDER);
ui_icon(spr_ic_arrow_left_right, _sw_x + 16, _sb_y2 + 12, 14, COL_TEXT);
if (_tb_vis && ui_clicked(_sw_x, _sb_y2, 32, 24)) {
    var _tmp = stroke_color; stroke_color = fill_color; fill_color = _tmp;
}

var _pp_x = gw - pp_w;
ui_rect(_pp_x, cv_y, pp_w, cv_h, COL_BG_PANEL);
ui_rect(_pp_x, cv_y, 1, cv_h, COL_BORDER);

var _is_eraser = (tool == "eraser");
var _is_brush  = (tool == "brush");
var _is_bucket = (tool == "paint-bucket");
var _uses_stroke = (tool == "brush" || tool == "line" || tool == "shape");
var _uses_fill   = (tool == "shape" || _is_bucket);

var _py = cv_y;
ui_rect(_pp_x + 1, _py, pp_w - 1, 33, ui_hover(_pp_x, _py, pp_w, 33) ? COL_HOVER : COL_BG_PANEL);
draw_set_font(fnt_ui_bold);
draw_set_colour(COL_TEXT);
draw_set_valign(fa_middle);
draw_text(_pp_x + 16, _py + 17, _is_bucket ? "Fill Settings" : "Brush Settings");
ui_icon(spr_ic_chevron_down, _pp_x + pp_w - 16 - 8, _py + 17, 16, COL_TEXT);
draw_set_valign(fa_top);
_py += 33;

var _cx0 = _pp_x + 16;
var _cw0 = pp_w - 32;
_py += 16;

if (_uses_stroke) {
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, "Stroke Color");
    _py += 16 + 4;
    ui_roundrect(_cx0, _py, 56, 28, 4, COL_BG_CANVAS);
    ui_roundrect_outline(_cx0, _py, 56, 28, 4, COL_BORDER);
    ui_rect(_cx0 + 5, _py + 5, 46, 18, stroke_color);
    if (ui_clicked(_cx0, _py, 56, 28)) editor_pick_colour("stroke");
    _py += 28 + 16;
}

if (_is_eraser || _uses_stroke) {
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, _is_eraser ? "Eraser Size" : "Stroke Width");
    _py += 16 + 4;
    var _val = _is_eraser ? eraser_width : stroke_width;
    var _tt = (_val - 1) / 49;
    ui_roundrect(_cx0, _py + 8, _cw0, 4, 2, COL_BORDER_LT);
    ui_roundrect(_cx0, _py + 8, _cw0 * _tt, 4, 2, COL_PRIMARY);
    draw_circle_colour(_cx0 + _cw0 * _tt, _py + 10, 6, COL_PRIMARY, COL_PRIMARY, false);
    if (ui_clicked(_cx0, _py, _cw0, 20)) drag_slider = 0;
    _py += 20 + 4;
    draw_set_font(fnt_mono_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, string(_val) + "px");
    _py += 16 + 16;
}

if (_is_brush) {
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, "Brush Smoothing");
    _py += 16 + 4;
    var _tt2 = brush_smoothing / 100;
    ui_roundrect(_cx0, _py + 8, _cw0, 4, 2, COL_BORDER_LT);
    ui_roundrect(_cx0, _py + 8, _cw0 * _tt2, 4, 2, COL_PRIMARY);
    draw_circle_colour(_cx0 + _cw0 * _tt2, _py + 10, 6, COL_PRIMARY, COL_PRIMARY, false);
    if (ui_clicked(_cx0, _py, _cw0, 20)) drag_slider = 1;
    _py += 20 + 4;
    draw_set_font(fnt_mono_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, string(brush_smoothing) + "%");
    _py += 16 + 16;
}

if (_uses_fill) {
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, "Fill Color");
    _py += 16 + 4;
    ui_roundrect(_cx0, _py, 56, 28, 4, COL_BG_CANVAS);
    ui_roundrect_outline(_cx0, _py, 56, 28, 4, COL_BORDER);
    ui_rect(_cx0 + 5, _py + 5, 46, 18, fill_color);
    if (ui_clicked(_cx0, _py, 56, 28)) editor_pick_colour("fill");
    _py += 28 + 16;
}

if (_is_bucket) {
    draw_set_font(fnt_mono_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text_ext(_cx0, _py, "Bucket uses only fill color and click area.", 16, _cw0);
    _py += 36;
}

ui_rect(_pp_x + 1, _py, pp_w - 1, 1, COL_BORDER);
_py += 1;

ui_rect(_pp_x + 1, _py, pp_w - 1, 33, ui_hover(_pp_x, _py, pp_w, 33) ? COL_HOVER : COL_BG_PANEL);
draw_set_font(fnt_ui_bold);
draw_set_colour(COL_TEXT);
draw_set_valign(fa_middle);
draw_text(_pp_x + 16, _py + 17, "Transform");
ui_icon(spr_ic_chevron_down, _pp_x + pp_w - 16 - 8, _py + 17, 16, COL_TEXT);
draw_set_valign(fa_top);
_py += 33 + 16;

var _tf_on = sel_active;
var _tf_labels = ["Position", "Size", "Rotation"];
var _tf_str = _tf_on
    ? [[string(round(sel_x)), string(round(sel_y))],
       [string(round(sel_w)), string(round(sel_h))],
       [string(round(sel_rot))]]
    : [["—","—"],["—","—"],["—"]];
var _tf_fieldidx = [[0,1],[2,3],[4]];
for (var _g = 0; _g < 3; _g++) {
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, _tf_labels[_g]);
    _py += 16 + 4;
    var _vals = _tf_str[_g];
    var _nv = array_length(_vals);
    var _iw = (_nv == 2) ? (_cw0 - 8) * 0.5 : _cw0;
    for (var _v2 = 0; _v2 < _nv; _v2++) {
        var _ix = _cx0 + _v2 * (_iw + 8);
        var _fi = _tf_fieldidx[_g][_v2];
        tf_rects[_fi] = [_ix, _py, _iw, 28];
        var _editing = (tf_edit == _fi);
        ui_roundrect(_ix, _py, _iw, 28, 4, COL_BG_CANVAS);
        ui_roundrect_outline(_ix, _py, _iw, 28, 4, _editing ? COL_PRIMARY : COL_BORDER);
        draw_set_font(fnt_mono);
        draw_set_colour(_tf_on ? COL_TEXT : COL_TEXT_MUTED);
        draw_set_valign(fa_middle);
        var _show = _editing ? tf_text : _vals[_v2];
        if (_editing && (current_time mod 1000 < 500)) _show += "|";
        draw_text(_ix + 8, _py + 14, _show);
        draw_set_valign(fa_top);
    }
    _py += 28 + 16;
}

if (tween_active) {
    var _tw_hint = "Tween: pose the end on another frame";
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_MUTED);
    draw_text_ext(_cx0, _py, _tw_hint, 14, _cw0);
    _py += 32;
    var _tw_bw = (_cw0 - 8) * 0.5;
    var tw_finish_rect = [_cx0, _py, _tw_bw, 28];
    var tw_cancel_rect = [_cx0 + _tw_bw + 8, _py, _tw_bw, 28];
    var _tw_fin_hover = pt_in(_mgx, _mgy, tw_finish_rect[0], tw_finish_rect[1], tw_finish_rect[2], tw_finish_rect[3]);
    var _tw_can_hover = pt_in(_mgx, _mgy, tw_cancel_rect[0], tw_cancel_rect[1], tw_cancel_rect[2], tw_cancel_rect[3]);
    ui_roundrect(tw_finish_rect[0], tw_finish_rect[1], tw_finish_rect[2], tw_finish_rect[3], 4, _tw_fin_hover ? COL_SECONDARY : COL_PRIMARY);
    ui_roundrect(tw_cancel_rect[0], tw_cancel_rect[1], tw_cancel_rect[2], tw_cancel_rect[3], 4, _tw_can_hover ? COL_HOVER : COL_BORDER_LT);
    draw_set_halign(fa_center); draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_sm);
    draw_set_colour(c_white);
    draw_text(tw_finish_rect[0] + _tw_bw * 0.5, _py + 14, "Finish Tween");
    draw_set_colour(COL_TEXT);
    draw_text(tw_cancel_rect[0] + _tw_bw * 0.5, _py + 14, "Cancel");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    if (ui_clicked(tw_finish_rect[0], tw_finish_rect[1], tw_finish_rect[2], tw_finish_rect[3])) tween_finish();
    else if (ui_clicked(tw_cancel_rect[0], tw_cancel_rect[1], tw_cancel_rect[2], tw_cancel_rect[3])) tween_cancel();
    _py += 28 + 16;
} else {
    var tw_start_rect = [_cx0, _py, _cw0, 28];
    var _tw_can_start = tween_can_start();
    var _tw_start_hover = _tw_can_start && pt_in(_mgx, _mgy, tw_start_rect[0], tw_start_rect[1], tw_start_rect[2], tw_start_rect[3]);
    ui_roundrect(tw_start_rect[0], tw_start_rect[1], tw_start_rect[2], tw_start_rect[3], 4,
        !_tw_can_start ? COL_BORDER_LT : (_tw_start_hover ? COL_SECONDARY : COL_PRIMARY));
    draw_set_halign(fa_center); draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_sm);
    draw_set_colour(_tw_can_start ? c_white : COL_TEXT_MUTED);
    draw_text(tw_start_rect[0] + _cw0 * 0.5, _py + 14, "Start Tween");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    if (_tw_can_start && ui_clicked(tw_start_rect[0], tw_start_rect[1], tw_start_rect[2], tw_start_rect[3])) tween_start();
    _py += 28 + 16;
}

ui_rect(_pp_x + 1, _py, pp_w - 1, 1, COL_BORDER);
_py += 1;
ui_rect(_pp_x + 1, _py, pp_w - 1, 33, ui_hover(_pp_x, _py, pp_w, 33) ? COL_HOVER : COL_BG_PANEL);
draw_set_font(fnt_ui_bold);
draw_set_colour(COL_TEXT);
draw_set_valign(fa_middle);
draw_text(_pp_x + 16, _py + 17, "Layer");
ui_icon(spr_ic_chevron_down, _pp_x + pp_w - 16 - 8, _py + 17, 16, COL_TEXT);
draw_set_valign(fa_top);
_py += 33 + 16;

if (array_length(layers) > 0) {
    var _lay_sel = layers[selected_layer];
    var _lop = variable_struct_exists(_lay_sel, "opacity") ? _lay_sel.opacity : 1;
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, "Opacity");
    _py += 16 + 4;
    ui_roundrect(_cx0, _py + 8, _cw0, 4, 2, COL_BORDER_LT);
    ui_roundrect(_cx0, _py + 8, _cw0 * _lop, 4, 2, COL_PRIMARY);
    draw_circle_colour(_cx0 + _cw0 * _lop, _py + 10, 6, COL_PRIMARY, COL_PRIMARY, false);
    if (ui_clicked(_cx0, _py, _cw0, 20)) drag_slider = 2;
    _py += 20 + 4;
    draw_set_font(fnt_mono_sm);
    draw_set_colour(COL_TEXT_2);
    draw_text(_cx0, _py, string(round(_lop * 100)) + "%");
    _py += 16 + 16;
}

ui_rect(0, tl_y, gw, tl_h, COL_BG_PANEL_DK);
ui_rect(0, tl_y, gw, 1, COL_BORDER);

ui_rect(0, tl_y, gw, tlh_h, COL_BG_TOOLBAR);
ui_rect(0, tl_y + tlh_h - 1, gw, 1, COL_BORDER);

var _hb_x = 8;
var _hb_y = tl_y + 4;
if (ui_hover(_hb_x, _hb_y, 24, 24)) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_HOVER);
ui_icon(spr_ic_skip_back, _hb_x + 12, _hb_y + 12, 16, ui_hover(_hb_x, _hb_y, 24, 24) ? COL_TEXT : COL_TEXT_2);
if (ui_clicked(_hb_x, _hb_y, 24, 24)) current_frame = max(0, current_frame - 1);
_hb_x += 28;
if (is_playing) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_PRIMARY, 0.1);
else if (ui_hover(_hb_x, _hb_y, 24, 24)) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_HOVER);
ui_icon(is_playing ? spr_ic_pause : spr_ic_play, _hb_x + 12, _hb_y + 12, 20,
        is_playing ? COL_PRIMARY : (ui_hover(_hb_x, _hb_y, 24, 24) ? COL_TEXT : COL_TEXT_2));
if (ui_clicked(_hb_x, _hb_y, 24, 24)) { is_playing = !is_playing; play_timer = 0; audio_sync(is_playing, true); }
_hb_x += 28;
if (ui_hover(_hb_x, _hb_y, 24, 24)) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_HOVER);
ui_icon(spr_ic_skip_forward, _hb_x + 12, _hb_y + 12, 16, ui_hover(_hb_x, _hb_y, 24, 24) ? COL_TEXT : COL_TEXT_2);
if (ui_clicked(_hb_x, _hb_y, 24, 24)) current_frame = min(total_frames - 1, current_frame + 1);
_hb_x += 28;
if (ui_hover(_hb_x, _hb_y, 24, 24)) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_HOVER);
ui_icon(spr_ic_plus, _hb_x + 12, _hb_y + 12, 16, ui_hover(_hb_x, _hb_y, 24, 24) ? COL_TEXT : COL_TEXT_2);
if (ui_clicked(_hb_x, _hb_y, 24, 24)) layer_add();
_hb_x += 28;
if (onion_skin) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_PRIMARY, 0.1);
else if (ui_hover(_hb_x, _hb_y, 24, 24)) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_HOVER);
ui_icon(spr_ic_eye, _hb_x + 12, _hb_y + 12, 16,
        onion_skin ? COL_PRIMARY : (ui_hover(_hb_x, _hb_y, 24, 24) ? COL_TEXT : COL_TEXT_2));
if (ui_clicked(_hb_x, _hb_y, 24, 24)) onion_skin = !onion_skin;
_hb_x += 28;
if (ui_hover(_hb_x, _hb_y, 24, 24)) ui_roundrect(_hb_x, _hb_y, 24, 24, 2, COL_HOVER);
ui_icon(spr_ic_film, _hb_x + 12, _hb_y + 12, 16, ui_hover(_hb_x, _hb_y, 24, 24) ? COL_TEXT : COL_TEXT_2);
if (ui_clicked(_hb_x, _hb_y, 24, 24)) { editing_frames = true; keyboard_string = string(total_frames); }

if (editing_frames) {
    var _inp_x = gw - 8 - 80;
    ui_roundrect(_inp_x, tl_y + 4, 80, 24, 4, COL_BG_PANEL);
    ui_roundrect_outline(_inp_x, tl_y + 4, 80, 24, 4, COL_PRIMARY);
    draw_set_font(fnt_mono);
    draw_set_colour(COL_TEXT);
    draw_set_valign(fa_middle);
    var _cursor = (current_time mod 1000 < 500) ? "|" : "";
    draw_text(_inp_x + 8, tl_y + 16, keyboard_string + _cursor);
    draw_set_valign(fa_top);
} else {
    draw_set_font(fnt_mono);
    var _ftxt = "Frame: " + string(current_frame + 1) + " / " + string(total_frames) + " (" + string(anim_fps) + " fps)";
    var _ft_w = string_width(_ftxt) + 16;
    var _ft_x = gw - 8 - _ft_w;
    if (ui_hover(_ft_x, tl_y + 4, _ft_w, 24)) ui_roundrect(_ft_x, tl_y + 4, _ft_w, 24, 4, COL_HOVER);
    draw_set_colour(COL_TEXT_2);
    draw_set_valign(fa_middle);
    draw_text(_ft_x + 8, tl_y + 16, _ftxt);
    draw_set_valign(fa_top);
    if (ui_clicked(_ft_x, tl_y + 4, _ft_w, 24)) { editing_frames = true; keyboard_string = string(total_frames); }
}

var _fr_x = lay_w;
var _fr_y = tl_y + tlh_h;
var _fr_w = gw - lay_w;
var _grid_y = _fr_y + ruler_h;
var _rows_h = tl_h - tlh_h - ruler_h - audio_h;

var _c0 = max(0, floor(tl_scroll / cell_w));
var _c1 = min(total_frames - 1, floor((tl_scroll + _fr_w) / cell_w));
var _l0 = max(0, floor(tl_vscroll / row_h));
var _l1 = min(array_length(layers) - 1, floor((tl_vscroll + _rows_h) / row_h));

for (var _l = _l0; _l <= _l1; _l++) {
    var _ry = _grid_y + _l * row_h - tl_vscroll;
    var _lay2 = layers[_l];

    for (var _twi = 0; _twi < array_length(_lay2.tweens); _twi++) {
        var _tw = _lay2.tweens[_twi];
        var _tf0 = _tw[0], _tf1 = _tw[1];
        if (_lay2.frames[_tf0] == -1 || _lay2.frames[_tf1] == -1) continue;
        if (_tf1 < _c0 || _tf0 > _c1) continue;
        var _tx0 = _fr_x + _tf0 * cell_w - tl_scroll;
        var _tx1 = _fr_x + (_tf1 + 1) * cell_w - tl_scroll;
        ui_rect(_tx0, _ry + 1, _tx1 - _tx0, row_h - 2, COL_TWEEN, 0.18);
    }

    for (var _c = _c0; _c <= _c1; _c++) {
        var _cx = _fr_x + _c * cell_w - tl_scroll;
        if (_c == current_frame) ui_rect(_cx, _ry, cell_w, row_h, COL_FRAME_HL, 0.15);
        var _cell_hover = pt_in(_mgx, _mgy, _cx, _ry, cell_w, row_h);
        if (_cell_hover && _c != current_frame) ui_rect(_cx, _ry, cell_w, row_h, c_white, 0.05);
        var _is5b = ((_c + 1) mod 5 == 0);
        ui_rect(_cx + cell_w - 1, _ry, 1, row_h, _is5b ? COL_TEXT_MUTED : COL_BORDER);
        var _ccx = _cx + cell_w * 0.5;
        var _ccy = _ry + row_h * 0.5;
        if (_lay2.frames[_c] != -1) {
            draw_circle_colour(_ccx, _ccy, 6, COL_BG_PANEL, COL_BG_PANEL, false);
            draw_circle_colour(_ccx, _ccy, 4, COL_KEYFRAME, COL_KEYFRAME, false);
        } else if (_cell_hover) {
            draw_set_alpha(0.3);
            draw_circle_colour(_ccx, _ccy, 6, COL_FRAME_HL, COL_FRAME_HL, false);
            draw_set_alpha(0.6);
            draw_circle_colour(_ccx, _ccy, 6, COL_PRIMARY, COL_PRIMARY, true);
            draw_set_alpha(1);
            ui_icon(spr_ic_plus, _ccx, _ccy, 8, COL_TEXT);
        }
    }

    for (var _twj = 0; _twj < array_length(_lay2.tweens); _twj++) {
        var _tw2 = _lay2.tweens[_twj];
        var _tf0b = _tw2[0], _tf1b = _tw2[1];
        if (_lay2.frames[_tf0b] == -1 || _lay2.frames[_tf1b] == -1) continue;
        if (_tf1b < _c0 || _tf0b > _c1) continue;
        var _ax0 = _fr_x + _tf0b * cell_w - tl_scroll + cell_w * 0.5;
        var _ax1 = _fr_x + _tf1b * cell_w - tl_scroll + cell_w * 0.5;
        var _acy = _ry + row_h * 0.5;
        if (abs(_ax1 - _ax0) > 10) {
            draw_set_colour(COL_TWEEN);
            draw_line_width(_ax0, _acy, _ax1, _acy, 2);
            var _adir = sign(_ax1 - _ax0);
            draw_triangle_colour(_ax1 - _adir * 7, _acy - 4, _ax1 - _adir * 7, _acy + 4, _ax1, _acy,
                COL_TWEEN, COL_TWEEN, COL_TWEEN, false);
            draw_set_colour(c_white);
        }
    }
    ui_rect(_fr_x, _ry + row_h - 1, _fr_w, 1, COL_BORDER);
}

ui_rect(_fr_x, _fr_y, _fr_w, ruler_h, COL_BG_PANEL);
ui_rect(_fr_x, _fr_y + ruler_h - 1, _fr_w, 1, COL_BORDER);
draw_set_font(fnt_mono_sm);
draw_set_halign(fa_center);
for (var _c = _c0; _c <= _c1; _c++) {
    var _cx = _fr_x + _c * cell_w - tl_scroll;
    var _is5 = ((_c + 1) mod 5 == 0);
    ui_rect(_cx + cell_w - 1, _fr_y, 1, ruler_h, _is5 ? COL_TEXT_MUTED : COL_BORDER);
    if (_is5) {
        draw_set_colour(COL_TEXT_2);
        draw_set_valign(fa_middle);
        draw_text(_cx + cell_w * 0.5, _fr_y + ruler_h * 0.5, string(_c + 1));
        draw_set_valign(fa_top);
    }
}
draw_set_halign(fa_left);

var _ph_x = _fr_x + current_frame * cell_w - tl_scroll;
if (_ph_x >= _fr_x - 8 && _ph_x <= gw + 8) {
    ui_rect(_ph_x, _grid_y, 2, _rows_h, COL_PLAYHEAD);
    draw_triangle_colour(_ph_x - 6, _grid_y, _ph_x + 8, _grid_y, _ph_x + 1, _grid_y + 8,
                         COL_PLAYHEAD, COL_PLAYHEAD, COL_PLAYHEAD, false);
}

ui_rect(0, _fr_y, lay_w, tl_h - tlh_h, COL_BG_PANEL);
ui_rect(lay_w - 1, _fr_y, 1, tl_h - tlh_h, COL_BORDER);
for (var _l = _l0; _l <= _l1; _l++) {
    var _ry = _fr_y + _l * row_h - tl_vscroll;
    var _lay3 = layers[_l];
    var _sel = (_l == selected_layer);
    var _row_hover = pt_in(_mgx, _mgy, 0, _ry, lay_w, row_h);
    if (_sel || _row_hover) ui_rect(0, _ry, lay_w - 1, row_h, COL_HOVER);
    if (_sel) ui_rect(0, _ry, 2, row_h, COL_PRIMARY);
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT);
    draw_set_valign(fa_middle);
    draw_text(8, _ry + row_h * 0.5, ui_text_fit(_lay3.name, lay_w - 8 - 52));
    draw_set_valign(fa_top);
    var _ic_x = lay_w - 8 - 44;
    var _eye_hover = pt_in(_mgx, _mgy, _ic_x, _ry + 2, 20, 20);
    if (_eye_hover) ui_roundrect(_ic_x, _ry + 2, 20, 20, 3, COL_BORDER);
    ui_icon(_lay3.visible ? spr_ic_eye : spr_ic_eye_off, _ic_x + 10, _ry + 12, 14, COL_TEXT, _lay3.visible ? 1 : 0.3);
    var _lk_x = _ic_x + 24;
    var _lk_hover = pt_in(_mgx, _mgy, _lk_x, _ry + 2, 20, 20);
    if (_lk_hover) ui_roundrect(_lk_x, _ry + 2, 20, 20, 3, COL_BORDER);
    ui_icon(_lay3.locked ? spr_ic_lock : spr_ic_unlock, _lk_x + 10, _ry + 12, 14, COL_TEXT, _lay3.locked ? 0.3 : 1);
    if (ui_clicked(_ic_x, _ry + 2, 20, 20)) _lay3.visible = !_lay3.visible;
    else if (ui_clicked(_lk_x, _ry + 2, 20, 20)) _lay3.locked = !_lay3.locked;
    else if (ui_clicked(0, _ry, lay_w, row_h)) selected_layer = _l;
    ui_rect(0, _ry + row_h - 1, lay_w, 1, COL_BORDER);
}

var _au_y = tl_y + tl_h - audio_h;
ui_rect(0, _au_y, gw, audio_h, COL_BG_PANEL_DK);
ui_rect(0, _au_y, gw, 1, COL_BORDER);
draw_set_font(fnt_ui_sm);
draw_set_colour(COL_TEXT_2);
draw_set_valign(fa_middle);
draw_text(8, _au_y + audio_h * 0.5, "Audio");
draw_set_valign(fa_top);
if (audio_sound != -1) {
    var _au_clip_w = (audio_trim_end - audio_trim_start) * anim_fps * cell_w;
    var _au_clip_x = _fr_x + audio_offset_fr * cell_w - tl_scroll;
    var _au_x0 = max(_au_clip_x, _fr_x);
    var _au_x1 = min(_au_clip_x + _au_clip_w, gw);
    if (_au_x1 > _au_x0) {
        var _au_hover = pt_in(_mgx, _mgy, _au_x0, _au_y + 2, _au_x1 - _au_x0, audio_h - 4);
        ui_roundrect(_au_x0, _au_y + 2, _au_x1 - _au_x0, audio_h - 4, 4, (audio_drag || _au_hover) ? COL_SECONDARY : COL_PRIMARY);
        draw_set_font(fnt_ui_sm);
        draw_set_colour(c_white);
        draw_set_valign(fa_middle);
        draw_text(_au_x0 + 8, _au_y + audio_h * 0.5, ui_text_fit(filename_name(audio_path), (_au_x1 - _au_x0) - 16));
        draw_set_valign(fa_top);

        var _au_handle_w = 8;
        var _au_hx_l = _au_clip_x;
        var _au_hx_r = _au_clip_x + _au_clip_w - _au_handle_w;
        if (_au_hx_l + _au_handle_w > _fr_x && _au_hx_l < gw) {
            var _au_hover_l = pt_in(_mgx, _mgy, _au_hx_l, _au_y, _au_handle_w, audio_h);
            ui_rect(max(_au_hx_l, _fr_x), _au_y + 2, min(_au_hx_l + _au_handle_w, gw) - max(_au_hx_l, _fr_x), audio_h - 4,
                    ((audio_resize && audio_resize_side == 1) || _au_hover_l) ? c_white : COL_BORDER_LT);
        }
        if (_au_hx_r + _au_handle_w > _fr_x && _au_hx_r < gw) {
            var _au_hover_r = pt_in(_mgx, _mgy, _au_hx_r, _au_y, _au_handle_w, audio_h);
            ui_rect(max(_au_hx_r, _fr_x), _au_y + 2, min(_au_hx_r + _au_handle_w, gw) - max(_au_hx_r, _fr_x), audio_h - 4,
                    ((audio_resize && audio_resize_side == 2) || _au_hover_r) ? c_white : COL_BORDER_LT);
        }
    }
} else {
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_MUTED);
    draw_set_valign(fa_middle);
    draw_text(_fr_x + 8, _au_y + audio_h * 0.5, "No audio (File > Import Audio...)");
    draw_set_valign(fa_top);
}

if (shape_picker_open) {
    var _shape_slot = tool_slot("shape");
    var _sp_y = cv_y + 8 + _shape_slot * 46 - tb_scroll;
    var _sp_x = tb_w + 6;
    var _sp_w = 6 + 4 * 38 - 4 + 6;
    var _sp_h = 6 + 2 * 38 - 4 + 6;
    ui_roundrect(_sp_x + 2, _sp_y + 6, _sp_w, _sp_h, 6, c_black, 0.32);
    ui_roundrect(_sp_x, _sp_y, _sp_w, _sp_h, 6, COL_BG_PANEL);
    ui_roundrect_outline(_sp_x, _sp_y, _sp_w, _sp_h, 6, COL_BORDER);
    for (var _s = 0; _s < array_length(shape_ids); _s++) {
        var _bx2 = _sp_x + 6 + (_s mod 4) * 38;
        var _by2 = _sp_y + 6 + (_s div 4) * 38;
        var _sactive = (shape_ids[_s] == selected_shape);
        if (_sactive) ui_roundrect(_bx2, _by2, 34, 34, 4, COL_PRIMARY);
        else if (pt_in(_mgx, _mgy, _bx2, _by2, 34, 34)) {
            ui_roundrect(_bx2, _by2, 34, 34, 4, COL_HOVER);
            ui_roundrect_outline(_bx2, _by2, 34, 34, 4, COL_BORDER);
        }
        ui_icon(shape_icons[_s], _bx2 + 17, _by2 + 17, 18, COL_TEXT);
    }
}

var _mb = title_h;
ui_rect(0, _mb, gw, mbar_h, COL_BG_TOOLBAR);
ui_rect(0, _mb + mbar_h - 1, gw, 1, COL_BORDER);

draw_set_font(fnt_ui);
draw_set_valign(fa_middle);
for (var _i = 0; _i < array_length(menu_names); _i++) {
    var _ix2 = menubar_x[_i];
    var _iw2 = menubar_w[_i];
    if (open_menu == _i || ui_hover(_ix2, _mb + 4, _iw2, 24)) ui_roundrect(_ix2, _mb + 4, _iw2, 24, 4, COL_HOVER);
    draw_set_colour(COL_TEXT);
    draw_text(_ix2 + 12, _mb + mbar_h * 0.5, menu_names[_i]);
}
draw_set_font(fnt_ui_sm);
draw_set_colour(COL_TEXT_MUTED);
draw_set_halign(fa_right);
draw_text(gw - 12, _mb + mbar_h * 0.5, "animgm");
draw_set_halign(fa_left);
draw_set_valign(fa_top);

if (open_menu != -1) {
    var _rows = editor_menu_rows(open_menu);
    var _mrx = menubar_x[open_menu];
    var _mry = _mb + mbar_h;
    var _mrw = 200;
    if (menu_names[open_menu] == "Window") {
        var _mrh2 = 8 + 22 + 26 * 3;
        ui_roundrect(_mrx + 3, _mry + 5, _mrw, _mrh2, 4, c_black, 0.5);
        ui_roundrect(_mrx, _mry, _mrw, _mrh2, 4, COL_BG_PANEL);
        ui_roundrect_outline(_mrx, _mry, _mrw, _mrh2, 4, COL_BORDER_LT);
        var _wy = _mry + 8;
        draw_set_font(fnt_ui_xs);
        draw_set_colour(COL_TEXT_MUTED);
        draw_text(_mrx + 12, _wy + 2, "SYSTEM PERFORMANCE");
        _wy += 22;
        var _perf_icons = [spr_ic_activity, spr_ic_cpu, spr_ic_hard_drive];
        var _perf_txt = [
            "FPS: " + string(fps),
            "Frame time: " + string(round(1000000 / max(fps_real, 1)) / 1000) + " ms",
            "Keyframes: " + string(editor_count_keyframes()) + "  (" + string(round(editor_mem_bytes() / 104857.6) / 10) + " MB)",
        ];
        draw_set_font(fnt_ui);
        draw_set_valign(fa_middle);
        for (var _r = 0; _r < 3; _r++) {
            ui_icon(_perf_icons[_r], _mrx + 12 + 7, _wy + 13, 14, COL_TEXT_2);
            draw_set_colour(COL_TEXT);
            draw_text(_mrx + 12 + 22, _wy + 13, _perf_txt[_r]);
            _wy += 26;
        }
        draw_set_valign(fa_top);
    } else if (array_length(_rows) > 0) {
        var _mrh = 8;
        for (var _r = 0; _r < array_length(_rows); _r++) _mrh += (_rows[_r][0] == "-") ? 9 : 26;
        ui_roundrect(_mrx + 3, _mry + 5, _mrw, _mrh, 4, c_black, 0.5);
        ui_roundrect(_mrx, _mry, _mrw, _mrh, 4, COL_BG_PANEL);
        ui_roundrect_outline(_mrx, _mry, _mrw, _mrh, 4, COL_BORDER_LT);
        var _yy = _mry + 4;
        for (var _r = 0; _r < array_length(_rows); _r++) {
            if (_rows[_r][0] == "-") {
                ui_rect(_mrx, _yy + 4, _mrw, 1, COL_BORDER_LT);
                _yy += 9;
                continue;
            }
            var _dim = (menu_names[open_menu] == "Edit")
                       && ((_rows[_r][0] == "Undo" && array_length(undo_stack) == 0)
                       ||  (_rows[_r][0] == "Redo" && array_length(redo_stack) == 0));
            if (pt_in(_mgx, _mgy, _mrx, _yy, _mrw, 26)) ui_rect(_mrx + 1, _yy, _mrw - 2, 26, COL_HOVER);
            draw_set_valign(fa_middle);
            draw_set_font(fnt_ui);
            draw_set_colour(COL_TEXT);
            draw_set_alpha(_dim ? 0.5 : 1);
            draw_text(_mrx + 12, _yy + 13, _rows[_r][0]);
            draw_set_font(fnt_mono_sm);
            draw_set_colour(COL_TEXT_MUTED);
            draw_set_halign(fa_right);
            draw_text(_mrx + _mrw - 12, _yy + 13, _rows[_r][1]);
            draw_set_halign(fa_left);
            draw_set_alpha(1);
            draw_set_valign(fa_top);
            _yy += 26;
        }
    }
}

if (toast_timer > 0) {
    draw_set_font(fnt_ui);
    var _tw = string_width(toast_text) + 32;
    var _tx = cv_x + (cv_w - _tw) * 0.5;
    var _tyy = cv_y + cv_h - 72;
    var _ta = min(1, toast_timer / 0.4);
    ui_roundrect(_tx, _tyy, _tw, 36, 6, COL_BG_TOOLBAR, 0.95 * _ta);
    ui_roundrect_outline(_tx, _tyy, _tw, 36, 6, COL_BORDER_LT, _ta);
    draw_set_colour(COL_TEXT);
    draw_set_alpha(_ta);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(_tx + _tw * 0.5, _tyy + 18, toast_text);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

if (picker_open) {
    ui_rect(0, 0, gw, gh, c_black, 0.45);

    var _pw2 = 260, _ph2 = 300;
    var _px2 = clamp((gw - _pw2) * 0.5, 8, gw - _pw2 - 8);
    var _py2 = clamp((gh - _ph2) * 0.5, mbar_h + 8, gh - _ph2 - 8);
    ui_roundrect(_px2 + 3, _py2 + 6, _pw2, _ph2, 6, c_black, 0.5);
    ui_roundrect(_px2, _py2, _pw2, _ph2, 6, COL_BG_PANEL);
    ui_roundrect_outline(_px2, _py2, _pw2, _ph2, 6, COL_BORDER_LT);

    draw_set_font(fnt_ui_bold);
    draw_set_colour(COL_TEXT);
    draw_text(_px2 + 16, _py2 + 8, (color_target == "fill" ? "Fill" : "Stroke") + " Color");

    var _sv_x = _px2 + 16, _sv_y = _py2 + 30, _sv_w = _pw2 - 32, _sv_h = 150;
    var _hue_col = hsv_to_col(pick_h, 1, 1);
    var _svr = _sv_x + _sv_w, _svb = _sv_y + _sv_h;
    draw_primitive_begin(pr_trianglestrip);
    draw_vertex_colour(_sv_x, _sv_y, c_white,   1);
    draw_vertex_colour(_svr,   _sv_y, _hue_col, 1);
    draw_vertex_colour(_sv_x, _svb,   c_white,   1);
    draw_vertex_colour(_svr,   _svb,   _hue_col, 1);
    draw_primitive_end();
    draw_primitive_begin(pr_trianglestrip);
    draw_vertex_colour(_sv_x, _sv_y, c_black, 0);
    draw_vertex_colour(_svr,   _sv_y, c_black, 0);
    draw_vertex_colour(_sv_x, _svb,   c_black, 1);
    draw_vertex_colour(_svr,   _svb,   c_black, 1);
    draw_primitive_end();
    ui_rect_outline(_sv_x, _sv_y, _sv_w, _sv_h, COL_BORDER);
    var _cur_sx = _sv_x + pick_s * _sv_w;
    var _cur_sy = _sv_y + (1 - pick_v) * _sv_h;
    draw_circle_colour(_cur_sx, _cur_sy, 6, c_black, c_black, true);
    draw_circle_colour(_cur_sx, _cur_sy, 5, c_white, c_white, true);

    var _hue_y = _sv_y + _sv_h + 12, _hue_h = 18;
    var _seg = 6;
    var _hcols = [c_red, c_yellow, c_lime, c_aqua, c_blue, c_fuchsia, c_red];
    for (var _hh = 0; _hh < _seg; _hh++) {
        var _hx0 = _sv_x + _sv_w * _hh / _seg;
        var _hx1 = _sv_x + _sv_w * (_hh + 1) / _seg;
        draw_rectangle_colour(_hx0, _hue_y, _hx1, _hue_y + _hue_h,
            _hcols[_hh], _hcols[_hh + 1], _hcols[_hh + 1], _hcols[_hh], false);
    }
    ui_rect_outline(_sv_x, _hue_y, _sv_w, _hue_h, COL_BORDER);
    var _hcx = _sv_x + (pick_h / 360) * _sv_w;
    ui_rect(_hcx - 2, _hue_y - 2, 4, _hue_h + 4, c_white);
    ui_rect_outline(_hcx - 2, _hue_y - 2, 4, _hue_h + 4, c_black);

    var _prev = hsv_to_col(pick_h, pick_s, pick_v);
    var _prev_y = _hue_y + _hue_h + 12;
    ui_rect(_sv_x, _prev_y, 40, 28, _prev);
    ui_rect_outline(_sv_x, _prev_y, 40, 28, COL_BORDER);
    draw_set_font(fnt_mono);
    draw_set_colour(COL_TEXT);
    var _hex = "#" + editor_hex2(colour_get_red(_prev)) + editor_hex2(colour_get_green(_prev)) + editor_hex2(colour_get_blue(_prev));
    draw_set_valign(fa_middle);
    draw_text(_sv_x + 50, _prev_y + 14, _hex);
    draw_set_valign(fa_top);

    var _ok_y = _py2 + _ph2 - 44;
    var _cancel_hover = pt_in(_mgx, _mgy, _px2 + 16, _ok_y, 90, 30);
    ui_roundrect(_px2 + 16, _ok_y, 90, 30, 4, _cancel_hover ? COL_HOVER : COL_BG_CANVAS);
    ui_roundrect_outline(_px2 + 16, _ok_y, 90, 30, 4, COL_BORDER);
    draw_set_colour(COL_TEXT);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(_px2 + 16 + 45, _ok_y + 15, "Cancel");
    var _ok_x = _px2 + _pw2 - 16 - 90;
    var _ok_hover = pt_in(_mgx, _mgy, _ok_x, _ok_y, 90, 30);
    ui_roundrect(_ok_x, _ok_y, 90, 30, 4, _ok_hover ? COL_PRIMARY : COL_SECONDARY);
    draw_set_colour(c_white);
    draw_text(_ok_x + 45, _ok_y + 15, "OK");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

if (rename_open && rename_layer >= 0 && rename_layer < array_length(layers)) {
    var _rr_y = tl_y + tlh_h + rename_layer * row_h - tl_vscroll;
    ui_rect(0, _rr_y, lay_w - 1, row_h, COL_INPUT_BG);
    ui_rect_outline(0, _rr_y, lay_w - 1, row_h, COL_PRIMARY);
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT);
    draw_set_valign(fa_middle);
    var _caret = (current_time mod 1000 < 500) ? "|" : "";
    draw_text(8, _rr_y + row_h * 0.5, ui_text_fit(rename_text + _caret, lay_w - 16));
    draw_set_valign(fa_top);
}

if (ctx_open) {
    var _cmw = 210;
    var _cmh = 8;
    for (var _r = 0; _r < array_length(ctx_items); _r++) _cmh += (ctx_items[_r][0] == "-") ? 9 : 30;
    ui_roundrect(ctx_x + 3, ctx_y + 5, _cmw, _cmh, 8, c_black, 0.4);
    ui_roundrect(ctx_x, ctx_y, _cmw, _cmh, 8, COL_BG_PANEL);
    ui_roundrect_outline(ctx_x, ctx_y, _cmw, _cmh, 8, COL_BORDER);
    var _cy2 = ctx_y + 4;
    for (var _r = 0; _r < array_length(ctx_items); _r++) {
        var _it = ctx_items[_r];
        if (_it[0] == "-") {
            ui_rect(ctx_x + 8, _cy2 + 4, _cmw - 16, 1, COL_BORDER);
            _cy2 += 9;
            continue;
        }
        var _danger = _it[3];
        var _hover = pt_in(_mgx, _mgy, ctx_x, _cy2, _cmw, 30);
        if (_hover) {
            if (_danger) ui_roundrect(ctx_x + 4, _cy2, _cmw - 8, 30, 4, $4444EF, 0.12);
            else         ui_roundrect(ctx_x + 4, _cy2, _cmw - 8, 30, 4, COL_HOVER);
        }
        var _col = _danger ? $4444EF : COL_TEXT;
        ui_icon(_it[1], ctx_x + 12 + 8, _cy2 + 15, 16, _danger ? $4444EF : COL_TEXT_2);
        draw_set_font(fnt_ui);
        draw_set_colour(_col);
        draw_set_valign(fa_middle);
        draw_text(ctx_x + 12 + 24, _cy2 + 15, _it[0]);
        if (_it[2] != "") {
            draw_set_font(fnt_mono_sm);
            draw_set_colour(COL_TEXT_MUTED);
            draw_set_halign(fa_right);
            draw_text(ctx_x + _cmw - 12, _cy2 + 15, _it[2]);
            draw_set_halign(fa_left);
        }
        draw_set_valign(fa_top);
        _cy2 += 30;
    }
}

if (unsaved_open) {
    ui_rect(0, 0, gw, gh, c_black, 0.8);
    var _uw = 450, _uh = 210;
    var _ux = (gw - _uw) * 0.5, _uy = (gh - _uh) * 0.5;
    ui_roundrect(_ux + 3, _uy + 6, _uw, _uh, 8, c_black, 0.5);
    ui_roundrect(_ux, _uy, _uw, _uh, 8, COL_BG_PANEL);
    ui_roundrect_outline(_ux, _uy, _uw, _uh, 8, COL_BORDER_LT);

    ui_roundrect(_ux + 24, _uy + 20, 48, 48, 8, $07C1FF, 0.15);
    ui_icon(spr_ic_alert_triangle, _ux + 24 + 24, _uy + 20 + 24, 24, $07C1FF);
    var _uclose_x = _ux + _uw - 24 - 28;
    var _uch = pt_in(_mgx, _mgy, _uclose_x, _uy + 20, 28, 28);
    if (_uch) ui_roundrect(_uclose_x, _uy + 20, 28, 28, 4, COL_HOVER);
    ui_icon(spr_ic_x, _uclose_x + 14, _uy + 20 + 14, 20, COL_TEXT_2);

    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(fnt_ui_bold);
    draw_set_colour(COL_TEXT);
    draw_text_transformed(_ux + 24, _uy + 82, "Save changes?", 1.3, 1.3, 0);
    draw_set_font(fnt_ui);
    draw_set_colour(COL_TEXT_2);
    draw_text_ext(_ux + 24, _uy + 112, "This project has unsaved changes. Do you want to save them?", 20, _uw - 48);

    var _uby = _uy + _uh - 24 - 36;
    var _ubw = 90, _ugap = 8;
    var _yes_x    = _ux + _uw - 24 - _ubw;
    var _no_x     = _yes_x - _ugap - _ubw;
    var _cancel_x = _no_x  - _ugap - _ubw;
    draw_set_halign(fa_center); draw_set_valign(fa_middle);
    draw_set_font(fnt_ui);
    var _cah = pt_in(_mgx, _mgy, _cancel_x, _uby, _ubw, 36);
    ui_roundrect(_cancel_x, _uby, _ubw, 36, 4, _cah ? COL_BTN_SEC_H : COL_BORDER_LT);
    draw_set_colour(COL_TEXT);
    draw_text(_cancel_x + _ubw*0.5, _uby + 18, "Cancel");
    var _nh = pt_in(_mgx, _mgy, _no_x, _uby, _ubw, 36);
    if (_nh) ui_roundrect(_no_x, _uby, _ubw, 36, 4, $303BFF, 0.1);
    ui_roundrect_outline(_no_x, _uby, _ubw, 36, 4, $303BFF);
    draw_set_colour($303BFF);
    draw_text(_no_x + _ubw*0.5, _uby + 18, "No");
    var _yh = pt_in(_mgx, _mgy, _yes_x, _uby, _ubw, 36);
    ui_roundrect(_yes_x, _uby, _ubw, 36, 4, _yh ? COL_SECONDARY : COL_PRIMARY);
    draw_set_colour(c_white);
    draw_text(_yes_x + _ubw*0.5, _uby + 18, "Yes");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
}

draw_titlebar();


draw_set_alpha(1);
draw_set_colour(c_white);
var _cm = (picker_open || open_menu != -1 || shape_picker_open || ctx_open || rename_open || unsaved_open) ? "arrow" : cursor_mode;
switch (_cm) {
    case "brush": {
        var _cr = max(stroke_width * zoom * 0.5, 2);
        draw_set_alpha(0.35);
        draw_circle_colour(_mgx, _mgy, _cr, c_black, c_black, false);
        draw_set_alpha(1);
        draw_circle_colour(_mgx, _mgy, _cr + 1, c_black, c_black, true);
        draw_circle_colour(_mgx, _mgy, _cr,     c_white, c_white, true);
        draw_set_colour(c_black);
        draw_line(_mgx + 1, _mgy - 4, _mgx + 1, _mgy + 4);
        draw_line(_mgx - 4, _mgy + 1, _mgx + 4, _mgy + 1);
        draw_set_colour(c_white);
        draw_line(_mgx, _mgy - 4, _mgx, _mgy + 4);
        draw_line(_mgx - 4, _mgy, _mgx + 4, _mgy);
        break;
    }
    case "eraser": {
        var _er = max(eraser_width * zoom * 0.5, 2);
        draw_set_alpha(0.25);
        draw_circle_colour(_mgx, _mgy, _er, c_white, c_white, false);
        draw_set_alpha(1);
        draw_circle_colour(_mgx, _mgy, _er + 1, c_black, c_black, true);
        draw_circle_colour(_mgx, _mgy, _er,     c_white, c_white, true);
        break;
    }
    case "cross":
        draw_set_colour(c_white);
        draw_line(_mgx - 7, _mgy, _mgx + 7, _mgy);
        draw_line(_mgx, _mgy - 7, _mgx, _mgy + 7);
        draw_set_colour(c_black);
        draw_line(_mgx - 7, _mgy + 1, _mgx + 7, _mgy + 1);
        draw_line(_mgx + 1, _mgy - 7, _mgx + 1, _mgy + 7);
        break;
    default:
        draw_sprite_ext(spr_cursor, 0, _mgx, _mgy, 0.5, 0.5, 0, c_white, 1);
        break;
}

draw_set_colour(c_white);
draw_set_alpha(1);
