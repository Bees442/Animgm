function tool_slot(_id) {
    for (var _i = 0; _i < array_length(tool_ids); _i++) {
        if (tool_ids[_i] == _id) return _i;
    }
    return -1;
}

function kf_clone(_kf) {
    if (_kf == -1) return -1;
    kf_backup(_kf, true);
    var _n = keyframe_make();
    _n.bx = _kf.bx; _n.by = _kf.by; _n.bw = _kf.bw; _n.bh = _kf.bh;
    kf_seed_used(_n);
    if (_kf.cbuf != -1) {
        var _sz = buffer_get_size(_kf.cbuf);
        _n.cbuf = buffer_create(_sz, buffer_fixed, 1);
        buffer_copy(_kf.cbuf, 0, _sz, _n.cbuf, 0);
    }
    return _n;
}

function layer_add(_name = "") {
    if (_name == "") _name = "Layer " + string(array_length(layers) + 1);
    array_insert(layers, 0, layer_make(_name, total_frames));
    selected_layer = 0;
    is_dirty = true;
}

function layer_duplicate(_li) {
    if (_li < 0 || _li >= array_length(layers)) return;
    var _src = layers[_li];
    var _copy = layer_make(_src.name + " Copy", total_frames);
    _copy.visible = _src.visible;
    _copy.locked  = _src.locked;
    for (var _i = 0; _i < array_length(_src.frames); _i++) {
        _copy.frames[_i] = kf_clone(_src.frames[_i]);
    }
    for (var _ti = 0; _ti < array_length(_src.tweens); _ti++) {
        array_push(_copy.tweens, [_src.tweens[_ti][0], _src.tweens[_ti][1]]);
    }
    array_insert(layers, _li, _copy);
    selected_layer = _li;
    is_dirty = true;
}

function layer_delete(_li) {
    if (_li < 0 || _li >= array_length(layers)) return;
    if (array_length(layers) <= 1) { editor_toast("Can't delete the last layer"); return; }
    var _fr = layers[_li].frames;
    for (var _i = 0; _i < array_length(_fr); _i++) kf_free(_fr[_i]);
    array_delete(layers, _li, 1);
    selected_layer = clamp(selected_layer, 0, array_length(layers) - 1);
    is_dirty = true;
}

function layer_move(_li, _dir) {
    var _to = _li + _dir;
    if (_li < 0 || _li >= array_length(layers) || _to < 0 || _to >= array_length(layers)) return;
    var _tmp = layers[_li];
    layers[_li] = layers[_to];
    layers[_to] = _tmp;
    selected_layer = _to;
    is_dirty = true;
}

function layer_context_open(_x, _y, _li) {
    ctx_kind = "layer";
    ctx_layer = _li;
    selected_layer = _li;
    ctx_items = [
        ["Duplicate", spr_ic_copy, "Ctrl+D", false],
        ["-", -1, "", false],
        ["Move to Layer Above", spr_ic_move_up, "", false],
        ["Move to Layer Below", spr_ic_move_down, "", false],
        ["-", -1, "", false],
        ["Rename", spr_ic_edit_3, "", false],
        ["-", -1, "", false],
        ["Delete", spr_ic_trash_2, "Del", true],
    ];
    var _mw = 210;
    var _mh = 8; for (var _i = 0; _i < array_length(ctx_items); _i++) _mh += (ctx_items[_i][0] == "-") ? 9 : 30;
    ctx_x = clamp(_x, 0, gw - _mw);
    ctx_y = clamp(_y, mbar_h, gh - _mh);
    ctx_open = true;
}

function layer_context_action(_label) {
    switch (_label) {
        case "Duplicate": layer_duplicate(ctx_layer); break;
        case "Move to Layer Above": layer_move(ctx_layer, -1); break;
        case "Move to Layer Below": layer_move(ctx_layer, 1); break;
        case "Rename":
            rename_open = true; rename_layer = ctx_layer;
            rename_text = layers[ctx_layer].name;
            keyboard_string = rename_text;
            break;
        case "Delete": layer_delete(ctx_layer); break;
    }
    ctx_open = false;
}
