function editor_pick_colour(_which) {
    color_target = _which;
    var _cur = (_which == "fill") ? fill_color : stroke_color;
    var _r = colour_get_red(_cur)   / 255;
    var _g = colour_get_green(_cur) / 255;
    var _b = colour_get_blue(_cur)  / 255;
    var _mx = max(_r, _g, _b), _mn = min(_r, _g, _b), _d = _mx - _mn;
    pick_v = _mx;
    pick_s = (_mx <= 0) ? 0 : _d / _mx;
    if (_d <= 0) pick_h = 0;
    else if (_mx == _r) pick_h = 60 * (((_g - _b) / _d) mod 6);
    else if (_mx == _g) pick_h = 60 * (((_b - _r) / _d) + 2);
    else                pick_h = 60 * (((_r - _g) / _d) + 4);
    if (pick_h < 0) pick_h += 360;
    picker_open = true;
    picker_drag = -1;
}

function hsv_to_col(_h, _s, _v) {
    var _c = _v * _s;
    var _x = _c * (1 - abs(((_h / 60) mod 2) - 1));
    var _m = _v - _c;
    var _r = 0, _g = 0, _b = 0;
    if (_h < 60)       { _r = _c; _g = _x; }
    else if (_h < 120) { _r = _x; _g = _c; }
    else if (_h < 180) { _g = _c; _b = _x; }
    else if (_h < 240) { _g = _x; _b = _c; }
    else if (_h < 300) { _r = _x; _b = _c; }
    else               { _r = _c; _b = _x; }
    return make_colour_rgb((_r + _m) * 255, (_g + _m) * 255, (_b + _m) * 255);
}

function editor_apply_picker() {
    var _col = hsv_to_col(pick_h, pick_s, pick_v);
    if (color_target == "fill") fill_color = _col;
    else                        stroke_color = _col;
}
