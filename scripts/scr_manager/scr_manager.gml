function pm_open_editor() {
    screen = "editor";
    tb_scroll = 0; tl_scroll = 0; tl_vscroll = 0; tl_follow_frame = -1;
    editor_fit_canvas();
}

function pm_browse_open() {
    var _path = get_open_filename("animgm Project|*.anst", "");
    if (_path == "") return;
    if (project_load(_path)) {
        recent_projects = project_load_recent();
        pm_open_editor();
    } else {
        editor_toast("Failed to open project");
    }
}

function pm_step() {
    var _mgx = device_mouse_x_to_gui(0);
    var _mgy = device_mouse_y_to_gui(0);
    var _pressed = mouse_check_button_pressed(mb_left);
    var _down    = mouse_check_button(mb_left);

    if (newproj_open) {
        if (np_dragging) {
            if (_down && np_field != -1) {
                np_sel_b = pm_field_char_at(np_field, _mgx);
            } else {
                np_dragging = false;
            }
        }
        if (np_field != -1) {
            var _txt = pm_field_get(np_field);
            var _len = string_length(_txt);
            var _numeric = (np_field != 0);
            var _ctrl = keyboard_check(vk_control);
            var _a = clamp(np_sel_a, 0, _len);
            var _b = clamp(np_sel_b, 0, _len);
            var _lo = min(_a, _b), _hi = max(_a, _b);
            var _has_sel = (_lo != _hi);

            if (_ctrl && keyboard_check_pressed(ord("A"))) {
                np_sel_a = 0; np_sel_b = _len;
            }
            else if (_ctrl && keyboard_check_pressed(ord("C"))) {
                if (_has_sel) clipboard_set_text(string_copy(_txt, _lo + 1, _hi - _lo));
            }
            else if (_ctrl && keyboard_check_pressed(ord("X"))) {
                if (_has_sel) {
                    clipboard_set_text(string_copy(_txt, _lo + 1, _hi - _lo));
                    _txt = string_copy(_txt, 1, _lo) + string_copy(_txt, _hi + 1, _len - _hi);
                    np_sel_a = _lo; np_sel_b = _lo;
                    pm_field_set(np_field, _txt);
                }
            }
            else if (_ctrl && keyboard_check_pressed(ord("V"))) {
                var _paste = clipboard_has_text() ? clipboard_get_text() : "";
                if (_numeric) {
                    var _clean = "";
                    for (var _i = 1; _i <= string_length(_paste); _i++) {
                        var _c = string_char_at(_paste, _i);
                        if (_c >= "0" && _c <= "9") _clean += _c;
                    }
                    _paste = _clean;
                }
                _txt = string_copy(_txt, 1, _lo) + _paste + string_copy(_txt, _hi + 1, _len - _hi);
                if (_numeric) _txt = string_copy(_txt, 1, 5);
                var _np = _lo + string_length(_paste);
                np_sel_a = _np; np_sel_b = _np;
                pm_field_set(np_field, _txt);
            }
            else {
                var _kb = keyboard_string;
                keyboard_string = "";
                if (_kb != "") {
                    if (_numeric) {
                        var _clean2 = "";
                        for (var _i = 1; _i <= string_length(_kb); _i++) {
                            var _c2 = string_char_at(_kb, _i);
                            if (_c2 >= "0" && _c2 <= "9") _clean2 += _c2;
                        }
                        _kb = _clean2;
                    }
                    _txt = string_copy(_txt, 1, _lo) + _kb + string_copy(_txt, _hi + 1, _len - _hi);
                    if (_numeric) _txt = string_copy(_txt, 1, 5);
                    var _cp = min(_lo + string_length(_kb), string_length(_txt));
                    np_sel_a = _cp; np_sel_b = _cp;
                    pm_field_set(np_field, _txt);
                }
                if (keyboard_check_pressed(vk_backspace)) {
                    if (_has_sel) {
                        _txt = string_copy(_txt, 1, _lo) + string_copy(_txt, _hi + 1, _len - _hi);
                        np_sel_a = _lo; np_sel_b = _lo;
                    } else if (_lo > 0) {
                        _txt = string_copy(_txt, 1, _lo - 1) + string_copy(_txt, _lo + 1, _len - _lo);
                        np_sel_a = _lo - 1; np_sel_b = _lo - 1;
                    }
                    pm_field_set(np_field, _txt);
                }
                if (keyboard_check_pressed(vk_delete)) {
                    if (_has_sel) {
                        _txt = string_copy(_txt, 1, _lo) + string_copy(_txt, _hi + 1, _len - _hi);
                        np_sel_a = _lo; np_sel_b = _lo;
                    } else if (_lo < _len) {
                        _txt = string_copy(_txt, 1, _lo) + string_copy(_txt, _lo + 2, _len - _lo - 1);
                    }
                    pm_field_set(np_field, _txt);
                }
                if (keyboard_check_pressed(vk_left)) {
                    var _nc = max(0, (_has_sel && !keyboard_check(vk_shift)) ? _lo : min(_a, _b) - (_has_sel ? 0 : 1));
                    if (!_has_sel) _nc = max(0, _b - 1);
                    np_sel_b = _nc;
                    if (!keyboard_check(vk_shift)) np_sel_a = _nc;
                }
                if (keyboard_check_pressed(vk_right)) {
                    var _nc2 = min(string_length(pm_field_get(np_field)), (_has_sel && !keyboard_check(vk_shift)) ? _hi : _b + (_has_sel ? 0 : 1));
                    if (!_has_sel) _nc2 = min(string_length(pm_field_get(np_field)), _b + 1);
                    np_sel_b = _nc2;
                    if (!keyboard_check(vk_shift)) np_sel_a = _nc2;
                }
            }

            if (keyboard_check_pressed(vk_tab))    { np_field = (np_field + 1) mod 5; pm_field_select_all(); }
            if (keyboard_check_pressed(vk_enter))  np_field = -1;
            if (keyboard_check_pressed(vk_escape)) np_field = -1;
        }
        var _mw = 520, _mh = 470;
        var _mx = (gw - _mw) * 0.5, _my = (gh - _mh) * 0.5;
        if (keyboard_check_pressed(vk_escape) && np_preset_open) np_preset_open = false;
        if (_pressed) {
            if (np_preset_open) {
                var _preset_hit = -1;
                for (var _pi = 0; _pi < array_length(np_preset_rect); _pi++) {
                    var _prc = np_preset_rect[_pi];
                    if (pt_in(_mgx, _mgy, _prc[0], _prc[1], _prc[2], _prc[3])) _preset_hit = _pi;
                }
                if (_preset_hit != -1) {
                    np_w = np_presets[_preset_hit][2];
                    np_h = np_presets[_preset_hit][3];
                }
                np_preset_open = false;
                np_field = -1;
                return;
            }
            if (pt_in(_mgx, _mgy, np_preset_box[0], np_preset_box[1], np_preset_box[2], np_preset_box[3])) {
                np_preset_open = true;
                np_field = -1;
                return;
            }
            var _hit = -1;
            for (var _f = 0; _f < 5; _f++) {
                var _rc = np_field_rect[_f];
                if (pt_in(_mgx, _mgy, _rc[0], _rc[1], _rc[2], _rc[3])) _hit = _f;
            }
            if (_hit != -1) {
                np_field = _hit;
                var _ci = pm_field_char_at(_hit, _mgx);
                np_sel_a = _ci; np_sel_b = _ci;
                np_dragging = true;
            }
            else if (pt_in(_mgx, _mgy, np_close_rect[0], np_close_rect[1], np_close_rect[2], np_close_rect[3])) {
                newproj_open = false; np_field = -1;
            }
            else if (pt_in(_mgx, _mgy, np_cancel_rect[0], np_cancel_rect[1], np_cancel_rect[2], np_cancel_rect[3])) {
                newproj_open = false; np_field = -1;
            }
            else if (pt_in(_mgx, _mgy, np_create_rect[0], np_create_rect[1], np_create_rect[2], np_create_rect[3])) {
                if (string_length(string_trim(np_name)) > 0) {
                    project_new(np_name,
                        max(1, real(np_w == "" ? "1" : string(np_w))),
                        max(1, real(np_h == "" ? "1" : string(np_h))),
                        max(1, real(np_fps == "" ? "1" : string(np_fps))),
                        max(1, real(np_frames == "" ? "1" : string(np_frames))));
                    newproj_open = false; np_field = -1;
                    pm_open_editor();
                }
            }
            else if (!pt_in(_mgx, _mgy, _mx, _my, _mw, _mh)) {
                np_field = -1;
            }
        }
        return;
    }

    if (_pressed) {
        if (pt_in(_mgx, _mgy, pm_new_rect[0], pm_new_rect[1], pm_new_rect[2], pm_new_rect[3])) {
            newproj_open = true;
            np_name = "Untitled Animation"; np_w = 1920; np_h = 1080; np_fps = 24; np_frames = 30;
            np_field = -1; np_preset_open = false;
            return;
        }
        if (pt_in(_mgx, _mgy, pm_open_rect[0], pm_open_rect[1], pm_open_rect[2], pm_open_rect[3])) {
            pm_browse_open();
            return;
        }
        for (var _i = 0; _i < array_length(pm_card_rect); _i++) {
            var _rc = pm_card_rect[_i];
            var _xr = pm_cardx_rect[_i];
            if (pt_in(_mgx, _mgy, _xr[0], _xr[1], _xr[2], _xr[3])) {
                project_remove_recent(recent_projects[_i].path);
                recent_projects = project_load_recent();
                return;
            }
            if (pt_in(_mgx, _mgy, _rc[0], _rc[1], _rc[2], _rc[3])) {
                var _path = recent_projects[_i].path;
                if (project_load(_path)) {
                    recent_projects = project_load_recent();
                    pm_open_editor();
                } else if (!file_exists(_path)) {
                    project_remove_recent(_path);
                    recent_projects = project_load_recent();
                    editor_toast("Missing file removed");
                } else {
                    editor_toast("Could not open project (unsupported or corrupt)");
                }
                return;
            }
        }
    }
}

function pm_thumb_sprite(_rp) {
    var _tp = variable_struct_exists(_rp, "thumb") ? _rp.thumb : "";
    if (_tp == "" || !file_exists(_tp)) return -1;
    if (ds_map_exists(pm_thumb_cache, _tp)) return pm_thumb_cache[? _tp];
    var _spr = sprite_add(_tp, 1, false, false, 0, 0);
    pm_thumb_cache[? _tp] = _spr;   // sprite_add returns -1 on failure; cache it
    return _spr;
}

function pm_field_get(_f) {
    switch (_f) {
        case 0: return np_name;
        case 1: return string(np_w);
        case 2: return string(np_h);
        case 3: return string(np_fps);
        case 4: return string(np_frames);
    }
    return "";
}
function pm_field_select_all() {
    if (np_field == -1) return;
    np_sel_a = 0;
    np_sel_b = string_length(pm_field_get(np_field));
}

function pm_field_char_at(_f, _mx) {
    var _rc = np_field_rect[_f];
    var _tx = _rc[0] + 10;
    var _val = pm_field_get(_f);
    var _len = string_length(_val);
    draw_set_font(fnt_ui);
    var _best = 0, _bestd = abs(_mx - _tx);
    for (var _i = 1; _i <= _len; _i++) {
        var _cx = _tx + string_width(string_copy(_val, 1, _i));
        var _d = abs(_mx - _cx);
        if (_d < _bestd) { _bestd = _d; _best = _i; }
    }
    return _best;
}
function pm_field_set(_f, _v) {
    switch (_f) {
        case 0: np_name = _v; break;
        case 1: np_w = _v; break;
        case 2: np_h = _v; break;
        case 3: np_fps = _v; break;
        case 4: np_frames = _v; break;
    }
}

function pm_draw() {
    var _mgx = device_mouse_x_to_gui(0);
    var _mgy = device_mouse_y_to_gui(0);

    ui_rect(0, 0, gw, gh, COL_INPUT_BG);

    var _cw = min(1200, gw - 80);
    var _cx = (gw - _cw) * 0.5;
    var _y = max(title_h + 24, (gh - 620) * 0.5);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    var _title_scale = 340 / sprite_get_width(spr_title);
    draw_sprite_ext(spr_title, 0, gw * 0.5, _y + 24, _title_scale, _title_scale, 0, c_white, 1);
    _y += 56;
    draw_set_font(fnt_ui);
    draw_set_colour(COL_TEXT_2);
    draw_text(gw * 0.5, _y, "Create stunning 2D animations");
    draw_set_halign(fa_left);
    _y += 44;

    var _gap = 16;
    var _card_w = (_cw - _gap) * 0.5;
    var _card_h = 150;
    pm_new_rect = [_cx, _y, _card_w, _card_h];
    var _new_hover = pt_in(_mgx, _mgy, _cx, _y, _card_w, _card_h);
    ui_roundrect(_cx, _y, _card_w, _card_h, 8, _new_hover ? COL_SECONDARY : COL_PRIMARY);
    pm_action_card_content(_cx, _y, _card_w, spr_ic_plus, "New Project", "Start a new animation project", true);
    var _ox2 = _cx + _card_w + _gap;
    pm_open_rect = [_ox2, _y, _card_w, _card_h];
    var _open_hover = pt_in(_mgx, _mgy, _ox2, _y, _card_w, _card_h);
    ui_roundrect(_ox2, _y, _card_w, _card_h, 8, _open_hover ? COL_BG_TOOLBAR : COL_BG_PANEL);
    ui_roundrect_outline(_ox2, _y, _card_w, _card_h, 8, _open_hover ? COL_PRIMARY : COL_BORDER_LT);
    pm_action_card_content(_ox2, _y, _card_w, spr_ic_folder_open, "Open Project", "Open an existing project file", false);
    _y += _card_h + 48;

    var _sec_h = max(220, gh - _y - 40);
    ui_roundrect(_cx, _y, _cw, _sec_h, 8, COL_BG_PANEL);
    ui_roundrect_outline(_cx, _y, _cw, _sec_h, 8, COL_BORDER_LT);
    ui_icon(spr_ic_clock, _cx + 24 + 10, _y + 24 + 10, 20, COL_TEXT);
    draw_set_font(fnt_ui_bold);
    draw_set_colour(COL_TEXT);
    draw_set_valign(fa_middle);
    draw_text(_cx + 24 + 32, _y + 24 + 10, "Recent Projects");
    draw_set_valign(fa_top);
    ui_rect(_cx + 24, _y + 56, _cw - 48, 1, COL_BORDER_LT);

    pm_card_rect = [];
    pm_cardx_rect = [];

    if (array_length(recent_projects) == 0) {
        draw_set_halign(fa_center);
        ui_icon(spr_ic_file_text, gw * 0.5, _y + _sec_h * 0.5 - 20, 48, COL_BORDER_LT);
        draw_set_font(fnt_ui);
        draw_set_colour(COL_TEXT_2);
        draw_text(gw * 0.5, _y + _sec_h * 0.5 + 16, "No recent projects");
        draw_set_font(fnt_ui_sm);
        draw_set_colour(COL_TEXT_MUTED);
        draw_text(gw * 0.5, _y + _sec_h * 0.5 + 38, "Create a new project to get started");
        draw_set_halign(fa_left);
    } else {
        var _grid_x = _cx + 24;
        var _grid_w = _cw - 48;
        var _min_cw = 220, _cgap = 16;
        var _cols = max(1, floor((_grid_w + _cgap) / (_min_cw + _cgap)));
        var _cardw = (_grid_w - (_cols - 1) * _cgap) / _cols;
        var _cardh = 150;   // thumbnail (16:9 of card) + info
        var _thumb_h = _cardw * 9 / 16;
        for (var _i = 0; _i < array_length(recent_projects); _i++) {
            var _rp = recent_projects[_i];
            var _col = _i mod _cols;
            var _row = _i div _cols;
            var _rx = _grid_x + _col * (_cardw + _cgap);
            var _ry = _y + 72 + _row * (_cardh + _thumb_h - 60 + _cgap);
            var _rh = _thumb_h + 74;
            if (_ry + _rh > _y + _sec_h - 12) break;
            array_push(pm_card_rect, [_rx, _ry, _cardw, _rh]);
            var _hover = pt_in(_mgx, _mgy, _rx, _ry, _cardw, _rh);
            ui_roundrect(_rx, _ry, _cardw, _rh, 6, COL_BG_PANEL_DK);
            ui_roundrect_outline(_rx, _ry, _cardw, _rh, 6, _hover ? COL_PRIMARY : COL_BORDER_LT);
            ui_rect(_rx + 1, _ry + 1, _cardw - 2, _thumb_h, COL_BORDER);
            var _spr = pm_thumb_sprite(_rp);
            if (_spr != -1) {
                var _tsx = (_cardw - 2) / sprite_get_width(_spr);
                var _tsy = _thumb_h / sprite_get_height(_spr);
                draw_sprite_ext(_spr, 0, _rx + 1, _ry + 1, _tsx, _tsy, 0, c_white, 1);
            } else {
                ui_icon(spr_ic_file_text, _rx + _cardw * 0.5, _ry + _thumb_h * 0.5, 40, $5A5A5A);
            }
            var _xw = 24;
            var _xr = [_rx + _cardw - _xw - 8, _ry + 8, _xw, _xw];
            array_push(pm_cardx_rect, _xr);
            if (_hover) {
                var _xhover = pt_in(_mgx, _mgy, _xr[0], _xr[1], _xr[2], _xr[3]);
                ui_roundrect(_xr[0], _xr[1], _xw, _xw, 4, _xhover ? COL_PLAYHEAD : $B2000000);
                ui_icon(spr_ic_x, _xr[0] + _xw*0.5, _xr[1] + _xw*0.5, 16, c_white);
            }
            var _iy = _ry + _thumb_h + 10;
            draw_set_font(fnt_ui_bold);
            draw_set_colour(COL_TEXT);
            draw_text(_rx + 12, _iy, ui_text_fit(_rp.name, _cardw - 24));
            draw_set_font(fnt_ui_sm);
            draw_set_colour(COL_TEXT_MUTED);
            draw_text(_rx + 12, _iy + 20, string(_rp.width) + "×" + string(_rp.height) + "  •  " + string(_rp.fps) + " fps");
            draw_set_colour($5A5A5A);
            draw_text(_rx + 12, _iy + 38, string(_rp.modified));
        }
    }
    draw_set_valign(fa_top);

    if (newproj_open) pm_draw_newproject();

    draw_titlebar();

    draw_sprite_ext(spr_cursor, 0, _mgx, _mgy, 0.5, 0.5, 0, c_white, 1);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
}

function pm_action_card_content(_x, _y, _w, _spr, _title, _sub, _primary) {
    var _icon_col = _primary ? c_white : COL_PRIMARY;
    var _chip = 56;
    var _chx = _x + _w * 0.5;
    ui_roundrect(_chx - _chip*0.5, _y + 20, _chip, _chip, 8,
        _primary ? c_white : COL_PRIMARY, _primary ? 0.2 : 0.15);
    ui_icon(_spr, _chx, _y + 20 + _chip*0.5, 32, _icon_col);
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_bold);
    draw_set_colour(_primary ? c_white : COL_TEXT);
    draw_text_transformed(_chx, _y + 88, _title, 1.35, 1.35, 0);
    draw_set_font(fnt_ui_sm);
    draw_set_colour(_primary ? c_white : COL_TEXT_2);
    draw_set_alpha(_primary ? 0.9 : 1);
    draw_text(_chx, _y + 116, _sub);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
}

function pm_draw_newproject() {
    var _mgx = device_mouse_x_to_gui(0);
    var _mgy = device_mouse_y_to_gui(0);
    ui_rect(0, 0, gw, gh, c_black, 0.8);

    var _mw = 520, _mh = 470;
    var _mx = (gw - _mw) * 0.5, _my = (gh - _mh) * 0.5;
    ui_roundrect(_mx, _my, _mw, _mh, 8, COL_BG_PANEL);
    ui_roundrect_outline(_mx, _my, _mw, _mh, 8, COL_BORDER_LT);

    draw_set_font(fnt_ui_bold);
    draw_set_colour(COL_TEXT);
    draw_text(_mx + 24, _my + 22, "New Project");
    np_close_rect = [_mx + _mw - 24 - 28, _my + 16, 28, 28];
    var _ch = pt_in(_mgx, _mgy, np_close_rect[0], np_close_rect[1], 28, 28);
    if (_ch) ui_roundrect(np_close_rect[0], np_close_rect[1], 28, 28, 4, COL_HOVER);
    ui_icon(spr_ic_x, np_close_rect[0]+14, np_close_rect[1]+14, 20, COL_TEXT_2);
    ui_rect(_mx + 24, _my + 56, _mw - 48, 1, COL_BORDER_LT);

    var _fx = _mx + 24;
    var _fw = _mw - 48;
    var _fy = _my + 74;

    np_field_rect[0] = pm_field(_fx, _fy, _fw, "Project Name", np_name, 0, "");
    _fy += 62;

    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_text(_fx, _fy, "Preset");
    _fy += 18;
    var _dbh = 34;
    np_preset_box = [_fx, _fy, _fw, _dbh];
    var _cur_w = real(np_w == "" ? "0" : string(np_w));
    var _cur_h = real(np_h == "" ? "0" : string(np_h));
    var _cur_label = "Custom";
    for (var _i = 0; _i < array_length(np_presets); _i++) {
        if (np_presets[_i][2] == _cur_w && np_presets[_i][3] == _cur_h) {
            _cur_label = np_presets[_i][0] + "   " + np_presets[_i][1];
            break;
        }
    }
    var _box_hover = pt_in(_mgx, _mgy, _fx, _fy, _fw, _dbh);
    ui_roundrect(_fx, _fy, _fw, _dbh, 4, _box_hover ? COL_HOVER : COL_INPUT_BG);
    ui_roundrect_outline(_fx, _fy, _fw, _dbh, 4, np_preset_open ? COL_PRIMARY : COL_BORDER_LT);
    draw_set_font(fnt_ui);
    draw_set_colour(COL_TEXT);
    draw_set_valign(fa_middle);
    draw_text(_fx + 12, _fy + _dbh * 0.5, _cur_label);
    draw_set_valign(fa_top);
    ui_icon(spr_ic_chevron_down, _fx + _fw - 20, _fy + _dbh * 0.5, 16, COL_TEXT_2);
    _fy += _dbh + 16;

    var _hw = (_fw - 12) * 0.5;
    np_field_rect[1] = pm_field(_fx, _fy, _hw, "Width (px)", string(np_w), 1, "");
    np_field_rect[2] = pm_field(_fx + _hw + 12, _fy, _hw, "Height (px)", string(np_h), 2, "");
    _fy += 62;
    var _fps_dur = "";
    np_field_rect[3] = pm_field(_fx, _fy, _hw, "Frame Rate (FPS)", string(np_fps), 3, "Common: 24, 30, 60");
    var _dur = (real(np_fps == "" ? "1" : string(np_fps)) > 0)
        ? string_format(real(np_frames == "" ? "0" : string(np_frames)) / real(np_fps == "" ? "1" : string(np_fps)), 1, 1) + "s duration" : "";
    np_field_rect[4] = pm_field(_fx + _hw + 12, _fy, _hw, "Total Frames", string(np_frames), 4, _dur);
    _fy += 70;

    var _by = _my + _mh - 24 - 34;
    ui_rect(_mx + 24, _by - 16, _mw - 48, 1, COL_BORDER_LT);
    var _cw2 = 90;
    np_cancel_rect = [_mx + _mw - 24 - 130 - _cw2, _by, _cw2, 34];
    var _cah = pt_in(_mgx, _mgy, np_cancel_rect[0], np_cancel_rect[1], _cw2, 34);
    ui_roundrect(np_cancel_rect[0], np_cancel_rect[1], _cw2, 34, 4, _cah ? COL_BTN_SEC_H : COL_BORDER_LT);
    draw_set_halign(fa_center); draw_set_valign(fa_middle);
    draw_set_font(fnt_ui); draw_set_colour(COL_TEXT);
    draw_text(np_cancel_rect[0] + _cw2*0.5, _by + 17, "Cancel");
    var _crw = 130;
    np_create_rect = [_mx + _mw - 24 - _crw, _by, _crw, 34];
    var _enabled = string_length(string_trim(np_name)) > 0;
    var _crh = pt_in(_mgx, _mgy, np_create_rect[0], np_create_rect[1], _crw, 34);
    ui_roundrect(np_create_rect[0], np_create_rect[1], _crw, 34, 4, _enabled ? (_crh ? COL_SECONDARY : COL_PRIMARY) : COL_BORDER_LT);
    draw_set_alpha(_enabled ? 1 : 0.5);
    draw_set_colour(c_white);
    draw_text(np_create_rect[0] + _crw*0.5, _by + 17, "Create Project");
    draw_set_alpha(1);
    draw_set_halign(fa_left); draw_set_valign(fa_top);

    np_preset_rect = [];
    if (np_preset_open) {
        var _lx = np_preset_box[0], _lw = np_preset_box[2];
        var _ly = np_preset_box[1] + np_preset_box[3] + 2;
        var _ih = 34;
        var _lh = array_length(np_presets) * _ih + 8;
        ui_roundrect(_lx + 2, _ly + 3, _lw, _lh, 6, c_black, 0.4);
        ui_roundrect(_lx, _ly, _lw, _lh, 6, COL_BG_PANEL);
        ui_roundrect_outline(_lx, _ly, _lw, _lh, 6, COL_BORDER_LT);
        var _iy = _ly + 4;
        for (var _i = 0; _i < array_length(np_presets); _i++) {
            var _pr = np_presets[_i];
            array_push(np_preset_rect, [_lx, _iy, _lw, _ih]);
            var _active = (_pr[2] == _cur_w && _pr[3] == _cur_h);
            var _hover = pt_in(_mgx, _mgy, _lx, _iy, _lw, _ih);
            if (_active || _hover) ui_roundrect(_lx + 4, _iy, _lw - 8, _ih, 4, _active ? COL_PRIMARY : COL_HOVER);
            draw_set_font(fnt_ui);
            draw_set_colour(_active ? c_white : COL_TEXT);
            draw_set_valign(fa_middle);
            draw_text(_lx + 12, _iy + _ih * 0.5, _pr[0]);
            draw_set_font(fnt_ui_sm);
            draw_set_colour(_active ? c_white : COL_TEXT_MUTED);
            draw_set_halign(fa_right);
            draw_text(_lx + _lw - 12, _iy + _ih * 0.5, _pr[1] + "  " + string(_pr[2]) + "×" + string(_pr[3]));
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            _iy += _ih;
        }
    }
}

function pm_field(_x, _y, _w, _label, _val, _idx, _hint) {
    draw_set_font(fnt_ui_sm);
    draw_set_colour(COL_TEXT_2);
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_text(_x, _y, _label);
    var _iy = _y + 18;
    var _ih = 30;
    var _focused = (np_field == _idx);
    ui_roundrect(_x, _iy, _w, _ih, 4, COL_INPUT_BG);
    ui_roundrect_outline(_x, _iy, _w, _ih, 4, _focused ? COL_PRIMARY : COL_BORDER_LT);

    var _tx = _x + 10;
    var _cy = _iy + _ih * 0.5;
    draw_set_font(fnt_ui);
    draw_set_valign(fa_middle);

    if (_focused) {
        var _len = string_length(_val);
        var _a = clamp(np_sel_a, 0, _len), _b = clamp(np_sel_b, 0, _len);
        var _lo = min(_a, _b), _hi = max(_a, _b);
        if (_lo != _hi) {
            var _sx0 = _tx + string_width(string_copy(_val, 1, _lo));
            var _sx1 = _tx + string_width(string_copy(_val, 1, _hi));
            ui_rect(_sx0, _iy + 4, _sx1 - _sx0, _ih - 8, COL_PRIMARY, 0.35);
        }
        draw_set_colour(COL_TEXT);
        draw_text(_tx, _cy, _val);
        if (current_time mod 1000 < 500) {
            var _cx = _tx + string_width(string_copy(_val, 1, _b));
            ui_rect(_cx, _iy + 5, 1, _ih - 10, COL_TEXT);
        }
    } else {
        draw_set_colour(COL_TEXT);
        draw_text(_tx, _cy, _val);
    }
    draw_set_valign(fa_top);

    if (_hint != "") {
        draw_set_font(fnt_ui_sm);
        draw_set_colour(COL_TEXT_MUTED);
        draw_text(_x, _iy + _ih + 4, _hint);
    }
    return [_x, _iy, _w, _ih];
}
