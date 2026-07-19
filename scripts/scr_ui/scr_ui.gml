function pt_in(_px, _py, _x, _y, _w, _h) {
    return _px >= _x && _px < _x + _w && _py >= _y && _py < _y + _h;
}

function ui_rect(_x, _y, _w, _h, _col, _alpha = 1) {
    draw_set_alpha(_alpha);
    draw_rectangle_colour(_x, _y, _x + _w - 1, _y + _h - 1, _col, _col, _col, _col, false);
    draw_set_alpha(1);
}

function ui_rect_outline(_x, _y, _w, _h, _col, _alpha = 1) {
    draw_set_alpha(_alpha);
    draw_rectangle_colour(_x, _y, _x + _w - 1, _y + _h - 1, _col, _col, _col, _col, true);
    draw_set_alpha(1);
}

function ui_roundrect(_x, _y, _w, _h, _r, _col, _alpha = 1) {
    draw_set_alpha(_alpha);
    draw_roundrect_colour_ext(_x, _y, _x + _w - 1, _y + _h - 1, _r, _r, _col, _col, false);
    draw_set_alpha(1);
}

function ui_roundrect_outline(_x, _y, _w, _h, _r, _col, _alpha = 1) {
    draw_set_alpha(_alpha);
    draw_roundrect_colour_ext(_x, _y, _x + _w - 1, _y + _h - 1, _r, _r, _col, _col, true);
    draw_set_alpha(1);
}

function ui_icon(_spr, _cx, _cy, _size, _col, _alpha = 1) {
    var _s = _size / 48;
    draw_sprite_ext(_spr, 0, _cx - _size * 0.5, _cy - _size * 0.5, _s, _s, 0, _col, _alpha);
}

function ui_hover(_x, _y, _w, _h) {
    return pt_in(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _x, _y, _w, _h);
}

function ui_clicked(_x, _y, _w, _h) {
    if (ui_click_used) return false;
    if (open_menu != -1 || shape_picker_open) return false;
    if (!mouse_check_button_pressed(mb_left)) return false;
    if (!ui_hover(_x, _y, _w, _h)) return false;
    ui_click_used = true;
    return true;
}

function editor_hex2(_v) {
    var _d = "0123456789ABCDEF";
    _v = clamp(round(_v), 0, 255);
    return string_char_at(_d, (_v div 16) + 1) + string_char_at(_d, (_v mod 16) + 1);
}

function ui_text_fit(_s, _w) {
    if (string_width(_s) <= _w) return _s;
    while (string_length(_s) > 1 && string_width(_s + "…") > _w) {
        _s = string_copy(_s, 1, string_length(_s) - 1);
    }
    return _s + "…";
}
