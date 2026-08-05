gw = display_get_gui_width();
gh = display_get_gui_height();
cv_x = tb_w;
cv_y = title_h + mbar_h;                 
cv_w = gw - tb_w - pp_w;
cv_h = gh - cv_y - tl_h;
tl_y = gh - tl_h;

ui_click_used = false;

var _mgx = device_mouse_x_to_gui(0);
var _mgy = device_mouse_y_to_gui(0);

win_anim_update(delta_time / 1000000);

while (dnd_count() > 0) {
    var _drop = dnd_poll();
    if (_drop == "") break;
    var _dext = string_lower(filename_ext(_drop));
    if (_dext == ".anst") {
        if (screen == "editor") { pending_open_path = _drop; editor_guard_action(editor_do_open_pending); }
        else if (project_load(_drop)) { recent_projects = project_load_recent(); screen = "editor"; editor_fit_canvas(); }
    } else if (screen == "editor") {
        editor_place_image(_drop, true);
    }
}

var _tb_close_x = gw - 50;
var _tb_max_x   = gw - 100;
var _tb_min_x   = gw - 150;
if (mouse_check_button_pressed(mb_left)) {
    if (pt_in(_mgx, _mgy, _tb_close_x, 0, 50, title_h)) {
        editor_request_quit();
        exit;
    } else if (pt_in(_mgx, _mgy, _tb_max_x, 0, 50, title_h)) {
        if (win_anim <= 0) win_toggle_maximize();
    } else if (pt_in(_mgx, _mgy, _tb_min_x, 0, 50, title_h)) {
        window_minimize();
    } else if (pt_in(_mgx, _mgy, 0, 0, gw - 150, title_h)) {
        win_drag = true;
        win_drag_mx = display_mouse_get_x();
        win_drag_my = display_mouse_get_y();
    }
}
if (win_drag) {
    if (mouse_check_button(mb_left)) {
        if (win_maximized) {
            win_anim = 0;
            window_set_size(win_rest_w, win_rest_h);
            win_maximized = false;
        }
        var _dmx = display_mouse_get_x();
        var _dmy = display_mouse_get_y();
        window_set_position(window_get_x() + (_dmx - win_drag_mx),
                            window_get_y() + (_dmy - win_drag_my));
        win_drag_mx = display_mouse_get_x();
        win_drag_my = display_mouse_get_y();
    } else {
        win_drag = false;
    }
}

if (keyboard_check_pressed(vk_f11) && win_anim <= 0) win_toggle_maximize();

if (screen == "manager") {
    pm_step();
    exit;
}

if (!is_drawing && !erasing && !shape_drag) editor_evict_surfaces();
kf_epoch++;

var _pressed  = mouse_check_button_pressed(mb_left);
var _down     = mouse_check_button(mb_left);
var _released = mouse_check_button_released(mb_left);
var _dt = delta_time / 1000000;

if (toast_timer > 0) toast_timer -= _dt;

if (unsaved_open) {
    var _uw = 450, _uh = 210;
    var _ux = (gw - _uw) * 0.5, _uy = (gh - _uh) * 0.5;
    var _by = _uy + _uh - 24 - 36;
    var _bw = 90, _gap = 8;
    var _yes_x    = _ux + _uw - 24 - _bw;
    var _no_x     = _yes_x - _gap - _bw;
    var _cancel_x = _no_x  - _gap - _bw;
    var _close_x  = _ux + _uw - 24 - 28;
    if (_pressed) {
        if (pt_in(_mgx, _mgy, _yes_x, _by, _bw, 36))          unsaved_save_and_quit();
        else if (pt_in(_mgx, _mgy, _no_x, _by, _bw, 36))      unsaved_discard_and_quit();
        else if (pt_in(_mgx, _mgy, _cancel_x, _by, _bw, 36))  unsaved_cancel();
        else if (pt_in(_mgx, _mgy, _close_x, _uy + 20, 28, 28)) unsaved_cancel();
    }
    if (keyboard_check_pressed(vk_escape)) unsaved_cancel();
    if (keyboard_check_pressed(vk_enter))  unsaved_save_and_quit();
    exit;
}

if (screen == "editor" && keyboard_check_pressed(vk_escape)
    && !ctx_open && !rename_open && !picker_open && open_menu == -1
    && !shape_picker_open && !editing_frames && !sel_active) {
    editor_request_quit();
    exit;
}

if (sel_active && !tween_active && current_frame != sel_last_frame) {
    var _now = current_frame;
    current_frame = sel_last_frame;
    sel_clear();
    current_frame = _now;
}
sel_last_frame = current_frame;

if (picker_open) {
    var _pw2 = 260, _ph2 = 300;
    var _px2 = clamp((gw - _pw2) * 0.5, 8, gw - _pw2 - 8);
    var _py2 = clamp((gh - _ph2) * 0.5, mbar_h + 8, gh - _ph2 - 8);
    var _sv_x = _px2 + 16, _sv_y = _py2 + 16, _sv_w = _pw2 - 32, _sv_h = 160;
    var _hue_y = _sv_y + _sv_h + 12, _hue_h = 18;
    var _ok_y  = _py2 + _ph2 - 44;

    if (_pressed) {
        if (pt_in(_mgx, _mgy, _sv_x, _sv_y, _sv_w, _sv_h)) picker_drag = 0;
        else if (pt_in(_mgx, _mgy, _sv_x, _hue_y, _sv_w, _hue_h)) picker_drag = 1;
        else if (pt_in(_mgx, _mgy, _px2 + _pw2 - 16 - 90, _ok_y, 90, 30)) {
            editor_apply_picker(); picker_open = false;
        } else if (pt_in(_mgx, _mgy, _px2 + 16, _ok_y, 90, 30)) {
            picker_open = false;
        } else if (!pt_in(_mgx, _mgy, _px2, _py2, _pw2, _ph2)) {
            picker_open = false;
        }
    }
    if (picker_drag == 0) {
        pick_s = clamp((_mgx - _sv_x) / _sv_w, 0, 1);
        pick_v = clamp(1 - (_mgy - _sv_y) / _sv_h, 0, 1);
    } else if (picker_drag == 1) {
        pick_h = clamp((_mgx - _sv_x) / _sv_w, 0, 1) * 360;
    }
    if (picker_drag != -1) editor_apply_picker();
    if (!_down) picker_drag = -1;
    if (keyboard_check_pressed(vk_enter))  { editor_apply_picker(); picker_open = false; }
    if (keyboard_check_pressed(vk_escape)) picker_open = false;
    exit;
}

if (rename_open) {
    rename_text = keyboard_string;
    if (keyboard_check_pressed(vk_enter)) {
        var _nm = string_trim(rename_text);
        if (_nm != "" && rename_layer >= 0 && rename_layer < array_length(layers)) {
            layers[rename_layer].name = _nm;
            is_dirty = true;
        }
        rename_open = false;
    } else if (keyboard_check_pressed(vk_escape)) {
        rename_open = false;
    }
    exit;
}

if (ctx_open) {
    var _mw = 210;
    var _yy = ctx_y + 4;
    if (_pressed || mouse_check_button_pressed(mb_right)) {
        var _inside = false;
        for (var _r = 0; _r < array_length(ctx_items); _r++) {
            var _rh = (ctx_items[_r][0] == "-") ? 9 : 30;
            if (ctx_items[_r][0] != "-" && pt_in(_mgx, _mgy, ctx_x, _yy, _mw, _rh)) {
                switch (ctx_kind) {
                    case "layer": layer_context_action(ctx_items[_r][0]); break;
                    case "frame": frame_context_action(ctx_items[_r][0]); break;
                    case "audio": audio_context_action(ctx_items[_r][0]); break;
                }
                _inside = true;
                break;
            }
            _yy += _rh;
        }
        if (!_inside) ctx_open = false;
        ui_click_used = true;
    }
    if (keyboard_check_pressed(vk_escape)) ctx_open = false;
    exit;
}

if (mouse_check_button_pressed(mb_right)) {
    var _lp_y = tl_y + tlh_h;
    var _rows_area = tl_h - tlh_h - audio_h;
    var _rc_au_y = tl_y + tl_h - audio_h;
    if (pt_in(_mgx, _mgy, 0, _lp_y, lay_w, _rows_area)) {
        var _l = floor((_mgy - _lp_y + tl_vscroll) / row_h);
        if (_l >= 0 && _l < array_length(layers)) {
            layer_context_open(_mgx, _mgy, _l);
            exit;
        }
    } else if (pt_in(_mgx, _mgy, lay_w, _lp_y + ruler_h, gw - lay_w, tl_h - tlh_h - ruler_h - audio_h)) {
        var _fc = floor((_mgx - lay_w + tl_scroll) / cell_w);
        var _fl = floor((_mgy - _lp_y - ruler_h + tl_vscroll) / row_h);
        if (_fc >= 0 && _fc < total_frames && _fl >= 0 && _fl < array_length(layers)) {
            frame_context_open(_mgx, _mgy, _fl, _fc);
            exit;
        }
    } else if (audio_sound != -1 && pt_in(_mgx, _mgy, lay_w, _rc_au_y, gw - lay_w, audio_h)) {
        var _rc_au_w = (audio_trim_end - audio_trim_start) * anim_fps * cell_w;
        var _rc_au_x = lay_w + audio_offset_fr * cell_w - tl_scroll;
        if (pt_in(_mgx, _mgy, _rc_au_x, _rc_au_y, _rc_au_w, audio_h)) {
            audio_context_open(_mgx, _mgy);
            exit;
        }
    }
}

var _ox = cv_x + (cv_w - canvas_w * zoom) * 0.5 + pan_x;
var _oy = cv_y + (cv_h - canvas_h * zoom) * 0.5 + pan_y;
var _cmx = (_mgx - _ox) / zoom;
var _cmy = (_mgy - _oy) / zoom;

if (is_playing) {
    play_timer += _dt;
    var _spf = 1 / anim_fps;
    while (play_timer >= _spf) {
        play_timer -= _spf;
        current_frame = (current_frame + 1) mod total_frames;
    }
}
audio_sync(is_playing, false);

var _frames_w = gw - lay_w;
if (current_frame != tl_follow_frame) {
    var _fx = current_frame * cell_w;
    if (_fx < tl_scroll) tl_scroll = max(0, _fx - 40);
    else if (_fx > tl_scroll + _frames_w - cell_w) tl_scroll = _fx - _frames_w + cell_w + 40;
}
tl_follow_frame = current_frame;
tl_scroll = clamp(tl_scroll, 0, max(0, total_frames * cell_w - _frames_w));

if (editing_frames) {
    var _clean = "";
    for (var _i = 1; _i <= string_length(keyboard_string); _i++) {
        var _ch = string_char_at(keyboard_string, _i);
        if (_ch >= "0" && _ch <= "9") _clean += _ch;
    }
    keyboard_string = string_copy(_clean, 1, 5);
    if (keyboard_check_pressed(vk_enter)) {
        var _v = real(keyboard_string == "" ? "0" : keyboard_string);
        if (_v > 0) editor_set_total_frames(_v);
        editing_frames = false;
    } else if (keyboard_check_pressed(vk_escape)) {
        editing_frames = false;
    } else if (_pressed) {
        var _inp_x = gw - 8 - 80;
        if (!pt_in(_mgx, _mgy, _inp_x, tl_y + 4, 80, 24)) {
            var _v = real(keyboard_string == "" ? "0" : keyboard_string);
            if (_v > 0) editor_set_total_frames(_v);
            editing_frames = false;
        }
    }
}

if (tf_edit != -1) {
    for (var _i = 1; _i <= string_length(keyboard_string); _i++) {
        var _ch = string_char_at(keyboard_string, _i);
        if (_ch >= "0" && _ch <= "9") tf_text += _ch;
        else if (_ch == "-" && string_length(tf_text) == 0) tf_text += _ch;
        else if (_ch == "." && string_pos(".", tf_text) == 0) tf_text += _ch;
    }
    keyboard_string = "";
    if (keyboard_check_pressed(vk_backspace) && string_length(tf_text) > 0)
        tf_text = string_copy(tf_text, 1, string_length(tf_text) - 1);

    var _commit = keyboard_check_pressed(vk_enter);
    var _cancel = keyboard_check_pressed(vk_escape);
    var _blur = false;
    if (_pressed) {
        var _rc = tf_rects[tf_edit];
        if (!pt_in(_mgx, _mgy, _rc[0], _rc[1], _rc[2], _rc[3])) _blur = true;
    }
    if (_commit || _blur) {
        tf_apply_field(tf_edit, tf_text);
        tf_edit = (_commit && keyboard_check(vk_tab)) ? (tf_edit + 1) mod 5 : -1;
    } else if (_cancel) {
        tf_edit = -1;
    }
}

if (!editing_frames && tf_edit == -1) {
    var _ctrl = keyboard_check(vk_control);
    if (_ctrl) {
        if (keyboard_check_pressed(ord("Z"))) { editor_undo(); }
        if (keyboard_check_pressed(ord("Y"))) { editor_redo(); }
        if (keyboard_check_pressed(ord("N"))) { editor_menu_action(0, "New Project"); }
        if (keyboard_check_pressed(ord("S"))) { editor_save(keyboard_check(vk_shift)); }
        if (keyboard_check_pressed(ord("O"))) { editor_open_dialog(); }
        if (keyboard_check_pressed(ord("D"))) { layer_duplicate(selected_layer); }
        if (keyboard_check_pressed(ord("E"))) { editor_toast("Export: not implemented yet"); }
    } else {
        for (var _t = 0; _t < array_length(tool_ids); _t++) {
            if (keyboard_check_pressed(ord(tool_keys[_t]))) tool = tool_ids[_t];
        }
        if (keyboard_check_pressed(ord("X"))) {
            var _tmp = stroke_color; stroke_color = fill_color; fill_color = _tmp;
        }
        if (keyboard_check_pressed(vk_space)) { is_playing = !is_playing; play_timer = 0; audio_sync(is_playing, true); }
        if (keyboard_check_pressed(188)) current_frame = max(0, current_frame - 1);              // ,
        if (keyboard_check_pressed(190)) current_frame = min(total_frames - 1, current_frame + 1); // .
    }
}

draw_set_font(fnt_ui);
var _menu_x = array_create(array_length(menu_names));
var _menu_w = array_create(array_length(menu_names));
var _mx_acc = 12;
for (var _i = 0; _i < array_length(menu_names); _i++) {
    _menu_x[_i] = _mx_acc;
    _menu_w[_i] = string_width(menu_names[_i]) + 24;
    _mx_acc += _menu_w[_i] + 4;
}
menubar_x = _menu_x;
menubar_w = _menu_w;

if (_pressed && !ui_click_used) {
    var _hit_item = -1;
    for (var _i = 0; _i < array_length(menu_names); _i++) {
        if (pt_in(_mgx, _mgy, _menu_x[_i], title_h + 4, _menu_w[_i], 24)) _hit_item = _i;
    }
    if (_hit_item != -1) {
        open_menu = (open_menu == _hit_item) ? -1 : _hit_item;
        shape_picker_open = false;
        ui_click_used = true;
    } else if (open_menu != -1) {
        var _rows = editor_menu_rows(open_menu);
        var _mrx = _menu_x[open_menu];
        var _mry = title_h + mbar_h;
        var _mrw = 200;
        var _mrh = 8;
        for (var _r = 0; _r < array_length(_rows); _r++) _mrh += (_rows[_r][0] == "-") ? 9 : 26;
        if (pt_in(_mgx, _mgy, _mrx, _mry, _mrw, _mrh)) {
            var _yy = _mry + 4;
            for (var _r = 0; _r < array_length(_rows); _r++) {
                var _rh = (_rows[_r][0] == "-") ? 9 : 26;
                if (_rows[_r][0] != "-" && pt_in(_mgx, _mgy, _mrx, _yy, _mrw, _rh)) {
                    editor_menu_action(open_menu, _rows[_r][0]);
                    open_menu = -1;
                }
                _yy += _rh;
            }
        } else {
            open_menu = -1;
        }
        ui_click_used = true;
    }
}

var _shape_slot = tool_slot("shape");
var _sb_y = cv_y + 8 + _shape_slot * 46 - tb_scroll;
if (_pressed && !ui_click_used && shape_picker_open) {
    var _spx = tb_w + 6, _spy = _sb_y, _spw = 6 + 4 * 38 - 4 + 6, _sph = 6 + 2 * 38 - 4 + 6;
    if (pt_in(_mgx, _mgy, _spx, _spy, _spw, _sph)) {
        for (var _s = 0; _s < array_length(shape_ids); _s++) {
            var _bx = _spx + 6 + (_s mod 4) * 38;
            var _by = _spy + 6 + (_s div 4) * 38;
            if (pt_in(_mgx, _mgy, _bx, _by, 34, 34)) {
                selected_shape = shape_ids[_s];
                tool = "shape";
                shape_picker_open = false;
            }
        }
    } else {
        shape_picker_open = false;
    }
    ui_click_used = true;
}

if (_pressed && !ui_click_used && pt_in(_mgx, _mgy, 0, _sb_y, tb_w, 44)) {
    if (current_time - shape_btn_lastclick < 350) {
        tool = "shape";
        shape_picker_open = !shape_picker_open;
        ui_click_used = true;
    }
    shape_btn_lastclick = current_time;
}

if (drag_slider != -1) {
    if (!_down) {
        drag_slider = -1;
    } else {
        var _sx = gw - pp_w + 16;
        var _sw2 = pp_w - 32;
        var _t = clamp((_mgx - _sx) / _sw2, 0, 1);
        if (drag_slider == 0) {
            if (tool == "eraser") eraser_width = round(1 + _t * 49);
            else                  stroke_width = round(1 + _t * 49);
        } else if (drag_slider == 1) {
            brush_smoothing = round(_t * 100);
        } else if (drag_slider == 2) {
            if (array_length(layers) > 0) { layers[selected_layer].opacity = _t; is_dirty = true; }
        }
    }
}

if (_pressed && sel_active && tf_edit == -1 && !ui_click_used) {
    for (var _fi = 0; _fi < 5; _fi++) {
        var _rc = tf_rects[_fi];
        if (pt_in(_mgx, _mgy, _rc[0], _rc[1], _rc[2], _rc[3])) {
            tf_edit = _fi;
            tf_text = "";
            keyboard_string = "";
            ui_click_used = true;
            break;
        }
    }
}

var _fr_x = lay_w;
var _fr_y = tl_y + tlh_h;
var _au_y = tl_y + tl_h - audio_h;
var _over_ruler  = pt_in(_mgx, _mgy, _fr_x, _fr_y, gw - lay_w, ruler_h);
var _over_frames = pt_in(_mgx, _mgy, _fr_x, _fr_y + ruler_h, gw - lay_w, tl_h - tlh_h - ruler_h - audio_h);
var _over_audio  = pt_in(_mgx, _mgy, _fr_x, _au_y, gw - _fr_x, audio_h);

if (_pressed && !ui_click_used && open_menu == -1 && !shape_picker_open) {
    if (_over_ruler) {
        scrubbing = true;
        ui_click_used = true;
    } else if (_over_frames) {
        var _c = floor((_mgx - _fr_x + tl_scroll) / cell_w);
        var _l = floor((_mgy - _fr_y - ruler_h + tl_vscroll) / row_h);
        if (_c >= 0 && _c < total_frames && _l >= 0 && _l < array_length(layers)) {
            current_frame  = _c;
            selected_layer = _l;
            audio_sync(is_playing, true);
            var _ccx = _fr_x + _c * cell_w - tl_scroll + cell_w * 0.5;
            var _ccy = _fr_y + ruler_h + _l * row_h - tl_vscroll + row_h * 0.5;
            if (layers[_l].frames[_c] == -1 && point_distance(_mgx, _mgy, _ccx, _ccy) <= 7) {
                editor_push_undo(_l, _c);
                layers[_l].frames[_c] = keyframe_make();
            }
        }
        ui_click_used = true;
    } else if (_over_audio && audio_sound != -1) {
        var _au_clip_w = (audio_trim_end - audio_trim_start) * anim_fps * cell_w;
        var _au_clip_x = _fr_x + audio_offset_fr * cell_w - tl_scroll;
        var _au_handle_w = 8;
        if (pt_in(_mgx, _mgy, _au_clip_x, _au_y, _au_handle_w, audio_h)) {
            audio_resize = true;
            audio_resize_side = 1;
            audio_resize_mx0 = _mgx + tl_scroll;
            audio_resize_start0 = audio_trim_start;
            audio_resize_off0 = audio_offset_fr;
            ui_click_used = true;
        } else if (pt_in(_mgx, _mgy, _au_clip_x + _au_clip_w - _au_handle_w, _au_y, _au_handle_w, audio_h)) {
            audio_resize = true;
            audio_resize_side = 2;
            audio_resize_mx0 = _mgx + tl_scroll;
            audio_resize_end0 = audio_trim_end;
            ui_click_used = true;
        } else if (pt_in(_mgx, _mgy, _au_clip_x, _au_y, _au_clip_w, audio_h)) {
            audio_drag = true;
            audio_drag_mx0 = _mgx + tl_scroll;
            audio_drag_off0 = audio_offset_fr;
            ui_click_used = true;
        }
    }
}
if (scrubbing) {
    current_frame = clamp(floor((_mgx - _fr_x + tl_scroll) / cell_w), 0, total_frames - 1);
    audio_sync(is_playing, true);
    if (!_down) scrubbing = false;
}
if (audio_drag || audio_resize) {
    var _au_edge = 24, _au_pan_spd = 14;
    var _au_scroll_max = max(0, total_frames * cell_w - _frames_w);
    if (_mgx < _fr_x + _au_edge) tl_scroll = max(0, tl_scroll - _au_pan_spd);
    else if (_mgx > gw - _au_edge) tl_scroll = min(_au_scroll_max, tl_scroll + _au_pan_spd);
}
if (audio_drag) {
    var _au_delta_fr = round(((_mgx + tl_scroll) - audio_drag_mx0) / cell_w);
    audio_offset_fr = max(0, audio_drag_off0 + _au_delta_fr);
    is_dirty = true;
    if (!_down) audio_drag = false;
}
if (audio_resize) {
    if (audio_resize_side == 1) {
        var _delta_fr_l = round(((_mgx + tl_scroll) - audio_resize_mx0) / cell_w);
        var _new_start = clamp(audio_resize_start0 + _delta_fr_l / anim_fps, 0, audio_trim_end - 1 / anim_fps);
        var _actual_delta_fr = round((_new_start - audio_resize_start0) * anim_fps);
        audio_trim_start = _new_start;
        audio_offset_fr = max(0, audio_resize_off0 + _actual_delta_fr);
    } else if (audio_resize_side == 2) {
        var _delta_fr_r = round(((_mgx + tl_scroll) - audio_resize_mx0) / cell_w);
        audio_trim_end = clamp(audio_resize_end0 + _delta_fr_r / anim_fps, audio_trim_start + 1 / anim_fps, audio_duration);
    }
    is_dirty = true;
    if (!_down) { audio_resize = false; audio_resize_side = 0; }
}

var _wheel = mouse_wheel_down() - mouse_wheel_up();
if (_wheel != 0 && open_menu == -1 && !shape_picker_open) {
    var _rows_h2 = tl_h - tlh_h - ruler_h - audio_h;
    if (pt_in(_mgx, _mgy, 0, cv_y, tb_w, cv_h)) {
        tb_scroll = clamp(tb_scroll + _wheel * 46, 0, max(0, tb_content_h - cv_h));
        _wheel = 0;
    } else if (pt_in(_mgx, _mgy, 0, tl_y + tlh_h + ruler_h, lay_w, _rows_h2)) {
        tl_vscroll = clamp(tl_vscroll + _wheel * row_h, 0, max(0, array_length(layers) * row_h - _rows_h2));
        _wheel = 0;
    } else if (pt_in(_mgx, _mgy, 0, tl_y, gw, tl_h)) {
        tl_scroll = clamp(tl_scroll + _wheel * 60, 0, max(0, total_frames * cell_w - _frames_w));
        _wheel = 0;
    } else if (pt_in(_mgx, _mgy, cv_x, cv_y, cv_w, cv_h)) {
        editor_zoom_at(_mgx, _mgy, _wheel < 0 ? 1.1 : 1 / 1.1);
        _wheel = 0;
    }
}

var _zoom_panel_w = 28 * 3 + string_width("8000%") + 16 + 8 * 2 + 8 * 3;
var _over_zoomctl = pt_in(_mgx, _mgy, cv_x + cv_w - 16 - _zoom_panel_w, cv_y + cv_h - 16 - 44, _zoom_panel_w, 44);
var _over_canvas  = pt_in(_mgx, _mgy, cv_x, cv_y, cv_w, cv_h) && !_over_zoomctl
                    && open_menu == -1 && !shape_picker_open && !ui_click_used;

var _pan_start = _over_canvas && (mouse_check_button_pressed(mb_middle)
                 || (_pressed && tool == "hand"));
if (_pan_start) {
    panning = true;
    pan_mx = _mgx; pan_my = _mgy; pan_ox = pan_x; pan_oy = pan_y;
    ui_click_used = ui_click_used || _pressed;
}
if (panning) {
    pan_x = pan_ox + (_mgx - pan_mx);
    pan_y = pan_oy + (_mgy - pan_my);
    if (!_down && !mouse_check_button(mb_middle)) panning = false;
}

var _layer_ok = array_length(layers) > 0 && !layers[selected_layer].locked && layers[selected_layer].visible;

if (_over_canvas && _pressed && !panning && !ui_click_used) {
    switch (tool) {
        case "select": case "subselect":
            if (_layer_ok) {
                var _hit = -1;
                if (sel_active) {
                    var _hs = 6;
                    var _dirs = sel_handle_dirs();
                    for (var _hi = 0; _hi < 8; _hi++) {
                        var _hp = sel_handle_pos(_dirs[_hi][0], _dirs[_hi][1]);
                        var _hsx = _ox + _hp[0] * zoom, _hsy = _oy + _hp[1] * zoom;
                        if (point_distance(_mgx, _mgy, _hsx, _hsy) <= _hs + 3) { _hit = _hi; break; }
                    }
                    if (_hit == -1) {
                        var _tc = sel_handle_pos(0, -1);
                        var _up = sel_handle_pos(0, -1 - 30 / max(sel_h * 0.5 * zoom, 1));
                        var _rsx = _ox + _up[0] * zoom, _rsy = _oy + _up[1] * zoom;
                        if (point_distance(_mgx, _mgy, _rsx, _rsy) <= _hs + 4) _hit = 8;
                    }
                }
                if (_hit != -1) {
                    editor_push_undo(selected_layer, frame_resolve(layers[selected_layer], current_frame));
                    sel_lift();
                    sel_xform = _hit;
                    sel_grab_rot = sel_rot;
                    sel_grab_x = sel_x; sel_grab_y = sel_y; sel_grab_w = sel_w; sel_grab_h = sel_h;
                    sel_grab_ang = point_direction(sel_cx(), sel_cy(), _cmx, _cmy);
                } else if (sel_active && sel_contains(_cmx, _cmy)) {
                    editor_push_undo(selected_layer, frame_resolve(layers[selected_layer], current_frame));
                    sel_lift();
                    sel_moving = true;
                    sel_grab_dx = _cmx - sel_x;
                    sel_grab_dy = _cmy - sel_y;
                } else if (tween_active) {
                    editor_toast("Finish or cancel the tween first");
                } else {
                    sel_clear();
                    sel_marquee = true;
                    sel_mx0 = clamp(_cmx, 0, canvas_w);
                    sel_my0 = clamp(_cmy, 0, canvas_h);
                    sel_x = sel_mx0; sel_y = sel_my0; sel_w = 0; sel_h = 0; sel_rot = 0;
                }
                ui_click_used = true;
            }
            break;
        case "brush":
            if (_layer_ok) {
                is_drawing = true;
                pen_x = _cmx; pen_y = _cmy;
                stroke_pts = [[_cmx, _cmy]];
                ui_click_used = true;
            }
            break;
        case "eraser":
            if (_layer_ok) {
                var _kf = active_keyframe();
                var _li = selected_layer;
                var _fi = frame_resolve(layers[_li], current_frame);
                editor_push_undo(_li, _fi);
                erasing = true;
                erase_px = _cmx; erase_py = _cmy;
                ui_click_used = true;
            }
            break;
        case "line": case "shape":
            if (_layer_ok) {
                shape_drag = true;
                drag_x0 = _cmx; drag_y0 = _cmy;
                drag_x1 = _cmx; drag_y1 = _cmy;
                ui_click_used = true;
            }
            break;
        case "zoom":
            editor_zoom_at(_mgx, _mgy, keyboard_check(vk_alt) ? 1 / 1.25 : 1.25);
            ui_click_used = true;
            break;
        case "eyedropper": {
            var _col = make_colour_rgb(255, 255, 255);
            if (_cmx >= 0 && _cmy >= 0 && _cmx < canvas_w && _cmy < canvas_h) {
                for (var _li = 0; _li < array_length(layers); _li++) {
                    if (!layers[_li].visible) continue;
                    var _ri = frame_resolve(layers[_li], current_frame);
                    if (_ri == -1) continue;
                    var _kf2 = layers[_li].frames[_ri];
                    if (!surface_exists(_kf2.surf)) kf_surface(_kf2);
                    var _v = surface_getpixel_ext(_kf2.surf, _cmx, _cmy);
                    if (((_v >> 24) & 255) > 10) { _col = _v & $FFFFFF; break; }
                }
            }
            stroke_color = _col;
            ui_click_used = true;
            break;
        }
        case "paint-bucket":
            if (_layer_ok && _cmx >= 0 && _cmy >= 0 && _cmx < canvas_w && _cmy < canvas_h) {
                var _kf3 = active_keyframe();
                var _li3 = selected_layer;
                editor_push_undo(_li3, frame_resolve(layers[_li3], current_frame));
                editor_flood_fill(_kf3, _cmx, _cmy, fill_color);
                ui_click_used = true;
            }
            break;
    }
}

if (is_drawing) {
    var _follow = lerp(1.0, 0.12, brush_smoothing / 100);
    pen_x += (_cmx - pen_x) * _follow;
    pen_y += (_cmy - pen_y) * _follow;

    var _n = array_length(stroke_pts);
    var _last = stroke_pts[_n - 1];
    if (point_distance(pen_x, pen_y, _last[0], _last[1]) > 1.0 / max(zoom, 0.01)) {
        array_push(stroke_pts, [pen_x, pen_y]);
    }
    if (!_down) {
        array_push(stroke_pts, [_cmx, _cmy]);
        var _li = selected_layer;
        var _kf = active_keyframe();
        editor_push_undo(_li, frame_resolve(layers[_li], current_frame));
        var _pts = stroke_pts;
        if (brush_smoothing > 0) _pts = stroke_smooth(_pts, brush_smoothing);
        var _pw = stroke_width;
        commit_stroke_aa(kf_surface(_kf), _pts, _pw, stroke_color);
        var _pad = _pw * 0.5 + 1;
        for (var _pi = 0; _pi < array_length(_pts); _pi++) {
            kf_mark_used(_kf, _pts[_pi][0], _pts[_pi][1], _pts[_pi][0], _pts[_pi][1], _pad);
        }
        _kf.dirty = true; kf_backup(_kf);
        is_drawing = false;
        stroke_pts = [];
    }
}

if (erasing) {
    var _kf = active_keyframe();
    surface_set_target(kf_surface(_kf));
    gpu_set_blendmode_ext(bm_zero, bm_inv_src_alpha);
    draw_set_colour(c_white);
    var _r = eraser_width * 0.5;
    draw_circle(erase_px, erase_py, _r, false);
    draw_line_width(erase_px, erase_py, _cmx, _cmy, eraser_width);
    draw_circle(_cmx, _cmy, _r, false);
    gpu_set_blendmode(bm_normal);
    surface_reset_target();
    erase_px = _cmx; erase_py = _cmy;
    if (!_down) {
        _kf.dirty = true; kf_backup(_kf);
        erasing = false;
    }
}

if (shape_drag) {
    drag_x1 = _cmx; drag_y1 = _cmy;
    if (keyboard_check(vk_shift) && tool == "shape") {
        var _dx = drag_x1 - drag_x0, _dy = drag_y1 - drag_y0;
        var _m = max(abs(_dx), abs(_dy));
        drag_x1 = drag_x0 + sign(_dx) * _m;
        drag_y1 = drag_y0 + sign(_dy) * _m;
    }
    if (!_down) {
        var _li = selected_layer;
        var _kf = active_keyframe();
        editor_push_undo(_li, frame_resolve(layers[_li], current_frame));
        surface_set_target(kf_surface(_kf));
        if (tool == "line") {
            draw_polyline_round([[drag_x0, drag_y0], [drag_x1, drag_y1]], stroke_width, stroke_color);
        } else {
            draw_shape(selected_shape, drag_x0, drag_y0, drag_x1, drag_y1, fill_color, stroke_color, stroke_width);
        }
        surface_reset_target();
        kf_mark_used(_kf, drag_x0, drag_y0, drag_x1, drag_y1, stroke_width * 0.5 + 1);
        _kf.dirty = true; kf_backup(_kf);
        shape_drag = false;
    }
}

sel_ants += _dt * 8;

if (sel_marquee) {
    var _mx = clamp(_cmx, 0, canvas_w);
    var _my = clamp(_cmy, 0, canvas_h);
    sel_x = min(sel_mx0, _mx);
    sel_y = min(sel_my0, _my);
    sel_w = abs(_mx - sel_mx0);
    sel_h = abs(_my - sel_my0);
    if (!_down) {
        sel_marquee = false;
        if (sel_w >= 2 && sel_h >= 2) sel_active = true;
        else sel_clear();
    }
}

if (sel_moving) {
    sel_x = clamp(_cmx - sel_grab_dx, -sel_w + 1, canvas_w - 1);
    sel_y = clamp(_cmy - sel_grab_dy, -sel_h + 1, canvas_h - 1);
    if (!_down) sel_moving = false;
}

if (sel_xform != -1) {
    if (sel_xform == 8) {
        var _ang = point_direction(sel_cx(), sel_cy(), _cmx, _cmy);
        sel_rot = sel_grab_rot + (_ang - sel_grab_ang);
        if (keyboard_check(vk_shift)) sel_rot = round(sel_rot / 15) * 15;
    } else {
        var _dirs = sel_handle_dirs();
        var _hx = _dirs[sel_xform][0], _hy = _dirs[sel_xform][1];
        var _gcx = sel_grab_x + sel_grab_w * 0.5;
        var _gcy = sel_grab_y + sel_grab_h * 0.5;
        var _ddx = _cmx - _gcx, _ddy = _cmy - _gcy;
        var _c = dcos(sel_rot), _s = dsin(sel_rot);
        var _lx = _ddx * _c - _ddy * _s;
        var _ly = _ddx * _s + _ddy * _c;
        var _neww = sel_grab_w, _newh = sel_grab_h;
        if (_hx != 0) _neww = max(4, abs(_lx - (-_hx * sel_grab_w * 0.5)));
        if (_hy != 0) _newh = max(4, abs(_ly - (-_hy * sel_grab_h * 0.5)));
        var _dw = (_hx != 0) ? (_neww - sel_grab_w) : 0;
        var _dh = (_hy != 0) ? (_newh - sel_grab_h) : 0;
        var _lcx = _hx * _dw * 0.5;
        var _lcy = _hy * _dh * 0.5;
        var _rc = dcos(-sel_rot), _rs = dsin(-sel_rot);
        var _wcx = _gcx + _lcx * _rc - _lcy * _rs;
        var _wcy = _gcy + _lcx * _rs + _lcy * _rc;
        sel_w = _neww; sel_h = _newh;
        sel_x = _wcx - sel_w * 0.5;
        sel_y = _wcy - sel_h * 0.5;
    }
    if (!_down) sel_xform = -1;
}

if (!editing_frames && tf_edit == -1) {
    if (sel_active && !tween_active && keyboard_check_pressed(vk_delete)) {
        sel_delete();
    }
    if (keyboard_check(vk_control)) {
        if (keyboard_check_pressed(ord("C"))) sel_copy();
        if (!tween_active && keyboard_check_pressed(ord("X"))) sel_cut();
        if (!tween_active && keyboard_check_pressed(ord("V"))) sel_paste();
    }
    if (keyboard_check_pressed(vk_escape) && sel_active) {
        if (tween_active) tween_cancel(); else sel_clear();
    }
}

if (tool != "select" && tool != "subselect" && sel_active && !tween_active) sel_clear();

window_set_cursor(cr_none);
if (_over_canvas && tool == "brush") {
    cursor_mode = "brush";
} else if (_over_canvas && tool == "eraser") {
    cursor_mode = "eraser";
} else if (_over_canvas && (tool == "shape" || tool == "line")) {
    cursor_mode = "cross";
} else if (_over_canvas && (tool == "select" || tool == "subselect")) {
    cursor_mode = (sel_active && _cmx >= sel_x && _cmx < sel_x + sel_w
                   && _cmy >= sel_y && _cmy < sel_y + sel_h) ? "move" : "cross";
} else {
    cursor_mode = "arrow";
}
