function editor_snapshot(_li, _fi) {
    var _kf = layers[_li].frames[_fi];
    var _snap = { li: _li, fi: _fi, existed: (_kf != -1), cbuf: -1, bx: 0, by: 0, bw: 0, bh: 0 };
    if (_kf != -1) {
        kf_backup(_kf);
        _snap.bx = _kf.bx; _snap.by = _kf.by; _snap.bw = _kf.bw; _snap.bh = _kf.bh;
        if (_kf.cbuf != -1) {
            var _sz = buffer_get_size(_kf.cbuf);
            _snap.cbuf = buffer_create(_sz, buffer_fixed, 1);
            buffer_copy(_kf.cbuf, 0, _sz, _snap.cbuf, 0);
        }
    }
    return _snap;
}

function editor_push_undo(_li, _fi) {
    if (_fi == -1) _fi = current_frame;
    is_dirty = true;
    array_push(undo_stack, editor_snapshot(_li, _fi));
    if (array_length(undo_stack) > 30) {
        var _old = undo_stack[0];
        if (_old.cbuf != -1) buffer_delete(_old.cbuf);
        array_delete(undo_stack, 0, 1);
    }
    for (var _i = 0; _i < array_length(redo_stack); _i++) {
        if (redo_stack[_i].cbuf != -1) buffer_delete(redo_stack[_i].cbuf);
    }
    redo_stack = [];
}

function editor_apply_snapshot(_snap) {
    if (_snap.li >= array_length(layers)) return;
    var _layer = layers[_snap.li];
    if (_snap.fi >= array_length(_layer.frames)) return;
    var _cur = _layer.frames[_snap.fi];
    if (!_snap.existed) {
        kf_free(_cur);
        _layer.frames[_snap.fi] = -1;
    } else {
        var _kf = (_cur != -1) ? _cur : keyframe_make();
        if (surface_exists(_kf.surf)) { surface_free(_kf.surf); _kf.surf = -1; }
        if (_kf.cbuf != -1) { buffer_delete(_kf.cbuf); _kf.cbuf = -1; }
        _kf.bx = _snap.bx; _kf.by = _snap.by; _kf.bw = _snap.bw; _kf.bh = _snap.bh;
        kf_seed_used(_kf);
        _kf.dirty = false;
        if (_snap.cbuf != -1) {
            var _sz = buffer_get_size(_snap.cbuf);
            _kf.cbuf = buffer_create(_sz, buffer_fixed, 1);
            buffer_copy(_snap.cbuf, 0, _sz, _kf.cbuf, 0);
        }
        _layer.frames[_snap.fi] = _kf;
    }
}

function editor_undo() {
    if (array_length(undo_stack) == 0) return;
    var _snap = array_pop(undo_stack);
    array_push(redo_stack, editor_snapshot(_snap.li, _snap.fi));
    editor_apply_snapshot(_snap);
    if (_snap.cbuf != -1) buffer_delete(_snap.cbuf);
}

function editor_redo() {
    if (array_length(redo_stack) == 0) return;
    var _snap = array_pop(redo_stack);
    array_push(undo_stack, editor_snapshot(_snap.li, _snap.fi));
    editor_apply_snapshot(_snap);
    if (_snap.cbuf != -1) buffer_delete(_snap.cbuf);
}
