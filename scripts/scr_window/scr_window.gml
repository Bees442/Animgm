// animgm — custom title bar, window controls, unsaved-changes guard

/// Draw the custom title bar (TitleBar.css): 40px, bg #1E1E1E, centred project
/// title (+ "*" when dirty), and minimize / maximize / close buttons at right.
function draw_titlebar() {
    var _mgx = device_mouse_x_to_gui(0);
    var _mgy = device_mouse_y_to_gui(0);
    ui_rect(0, 0, gw, title_h, COL_INPUT_BG);          // #1E1E1E
    ui_rect(0, title_h - 1, gw, 1, $0F0F0F);           // bottom border

    draw_set_font(fnt_ui);
    draw_set_colour(COL_TEXT_2);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    var _t = (project_name == "" ? "Untitled" : project_name) + (is_dirty ? "*" : "");
    draw_text(gw * 0.5, title_h * 0.5, _t);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _min_x = gw - 150, _max_x = gw - 100, _close_x = gw - 50;
    if (pt_in(_mgx, _mgy, _min_x, 0, 50, title_h)) ui_rect(_min_x, 0, 50, title_h, c_white, 0.08);
    ui_icon(spr_ic_minus, _min_x + 25, title_h * 0.5, 16, COL_TEXT_2);
    if (pt_in(_mgx, _mgy, _max_x, 0, 50, title_h)) ui_rect(_max_x, 0, 50, title_h, c_white, 0.08);
    ui_icon(spr_ic_square, _max_x + 25, title_h * 0.5, 13, COL_TEXT_2);
    if (pt_in(_mgx, _mgy, _close_x, 0, 50, title_h)) {
        ui_rect(_close_x, 0, 50, title_h, $2311E8);    // #E81123 (BGR)
        ui_icon(spr_ic_x, _close_x + 25, title_h * 0.5, 16, c_white);
    } else {
        ui_icon(spr_ic_x, _close_x + 25, title_h * 0.5, 16, COL_TEXT_2);
    }
    draw_set_colour(c_white);
    draw_set_alpha(1);
}

/// Toggle a pseudo-maximize that fills the desktop work area.
function win_toggle_maximize() {
    win_from_x = window_get_x();
    win_from_y = window_get_y();
    win_from_w = window_get_width();
    win_from_h = window_get_height();
    if (win_maximized) {
        win_to_x = win_rest_x; win_to_y = win_rest_y;
        win_to_w = win_rest_w; win_to_h = win_rest_h;
        win_maximized = false;
    } else {
        win_rest_x = win_from_x; win_rest_y = win_from_y;
        win_rest_w = win_from_w; win_rest_h = win_from_h;
        win_to_x = 0; win_to_y = 0;
        win_to_w = display_get_width();
        win_to_h = display_get_height();
        win_maximized = true;
    }
    win_anim = win_anim_dur;   // Step drives the interpolation
}

/// Per-frame smooth maximize/restore. Eases the window rect from from→to.
function win_anim_update(_dt) {
    if (win_anim <= 0) return;
    win_anim = max(0, win_anim - _dt);
    var _t = 1 - (win_anim / win_anim_dur);       // 0..1
    _t = 1 - power(1 - _t, 3);
    var _x = lerp(win_from_x, win_to_x, _t);
    var _y = lerp(win_from_y, win_to_y, _t);
    var _w = lerp(win_from_w, win_to_w, _t);
    var _h = lerp(win_from_h, win_to_h, _t);
    window_set_rectangle(round(_x), round(_y), round(_w), round(_h));
}

/// Route a discarding action (quit, open another project, new project) through
/// the unsaved-changes guard. If the current project has unsaved edits, show the
/// "Save changes?" dialog and defer _action until the user answers; otherwise
/// run _action immediately. _action is a function (method) with no arguments.
function editor_guard_action(_action) {
    if (screen == "editor" && is_dirty) {
        unsaved_action = _action;
        unsaved_open = true;
    } else {
        _action();
    }
}

/// Called when the user tries to close the app (window X, Escape, menu Quit).
function editor_request_quit() {
    editor_guard_action(function() { game_end(); });
}

/// "Yes" — save, then run the pending action (stay open if the save was
/// cancelled or failed).
function unsaved_save_and_quit() {
    var _path = project_path;
    if (_path == "") {
        _path = get_save_filename("animgm Project|*.anst", project_name + ".anst");
        if (_path == "") return;                 // cancelled save -> keep dialog
        if (filename_ext(_path) == "") _path += ".anst";
    }
    if (project_save(_path)) {
        unsaved_open = false;
        var _a = unsaved_action; unsaved_action = undefined;
        if (_a != undefined) _a();
    } else editor_toast("Save failed");
}

/// "No" — discard changes and run the pending action.
function unsaved_discard_and_quit() {
    is_dirty = false;
    unsaved_open = false;
    var _a = unsaved_action; unsaved_action = undefined;
    if (_a != undefined) _a();
}

/// "Cancel" — dismiss the dialog and keep working (drop the pending action).
function unsaved_cancel() {
    unsaved_open = false;
    unsaved_action = undefined;
}
