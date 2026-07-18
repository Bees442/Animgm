function editor_toast(_msg) {
    toast_text  = _msg;
    toast_timer = 2.2;
}

function editor_set_total_frames(_n) {
    _n = clamp(_n, 1, 9999);
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _layer = layers[_li];
        var _old = _layer.frames;
        var _cnt = array_length(_old);
        var _nf = array_create(_n, -1);
        for (var _i = 0; _i < min(_cnt, _n); _i++) _nf[_i] = _old[_i];
        for (var _i = _n; _i < _cnt; _i++) kf_free(_old[_i]);
        _layer.frames = _nf;
    }
    total_frames  = _n;
    current_frame = min(current_frame, total_frames - 1);
}

function editor_zoom_at(_gx, _gy, _factor) {
    var _nz = clamp(zoom * _factor, 0.1, 8);
    if (_nz == zoom) return;
    var _ox = cv_x + (cv_w - canvas_w * zoom) * 0.5 + pan_x;
    var _oy = cv_y + (cv_h - canvas_h * zoom) * 0.5 + pan_y;
    var _px = (_gx - _ox) / zoom;
    var _py = (_gy - _oy) / zoom;
    zoom = _nz;
    var _nox = cv_x + (cv_w - canvas_w * zoom) * 0.5;
    var _noy = cv_y + (cv_h - canvas_h * zoom) * 0.5;
    pan_x = _gx - _px * zoom - _nox;
    pan_y = _gy - _py * zoom - _noy;
}

function editor_fit_canvas() {
    zoom  = min(cv_w / canvas_w, cv_h / canvas_h) * 0.9;
    zoom  = clamp(zoom, 0.1, 8);
    pan_x = 0;
    pan_y = 0;
}

function editor_new_project() {
    for (var _li = 0; _li < array_length(layers); _li++) {
        var _fr = layers[_li].frames;
        for (var _i = 0; _i < array_length(_fr); _i++) kf_free(_fr[_i]);
    }
    layers = [layer_make("Layer 1", 30)];
    layers[0].frames[0] = keyframe_make();
    selected_layer = 0;
    total_frames   = 30;
    current_frame  = 0;
    is_playing     = false;
    project_name   = "Untitled";
    zoom = 1; pan_x = 0; pan_y = 0;
    undo_stack = [];
    redo_stack = [];
    tl_scroll  = 0;
}
