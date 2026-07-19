function editor_export_mp4() {
    if (array_length(layers) == 0) { editor_toast("Nothing to export"); return; }
    var _out = get_save_filename("MP4 Video|*.mp4", project_name + ".mp4");
    if (_out == "") return;
    if (filename_ext(_out) == "") _out += ".mp4";
    export_run(_out);
}

// Render every frame straight to a surface and hand its pixels to the
// in-process OpenH264/minimp4 encoder (mp4enc_*, see export_ext.cpp) — no PNG
// round-trip through disk and no external ffmpeg.exe process.
function export_run(_out) {
    show_debug_message("[export] start -> " + string(_out));
    var _cur = current_frame;
    var _w = canvas_w, _h = canvas_h;

    export_progress = 0;
    export_total = total_frames;

    var _opened = mp4enc_open(_out, _w, _h, anim_fps);
    show_debug_message("[export] mp4enc_open=" + string(_opened) + " err=" + string(mp4enc_last_error()));
    if (_opened == 0) {
        editor_toast("Export failed: " + string(mp4enc_last_error()));
        return;
    }

    var _surf = surface_create(_w, _h);
    var _buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
    var _ok = true;
    for (var _f = 0; _f < total_frames; _f++) {
        surface_set_target(_surf);
        draw_clear(c_white);
        for (var _li = array_length(layers) - 1; _li >= 0; _li--) {
            var _lay = layers[_li];
            if (!_lay.visible) continue;
            var _ri = frame_resolve(_lay, _f);
            if (_ri == -1) continue;
            var _op = variable_struct_exists(_lay, "opacity") ? _lay.opacity : 1;
            draw_surface_ext(kf_surface(_lay.frames[_ri]), 0, 0, 1, 1, 0, c_white, _op);
        }
        surface_reset_target();
        buffer_get_surface(_buf, _surf, 0);
        var _addr = buffer_get_address(_buf);
        if (_f == 0) show_debug_message("[export] frame0 addr=" + string(_addr) + " w=" + string(_w) + " h=" + string(_h));
        var _added = mp4enc_add_frame(_addr, _w, _h);
        if (_added == 0) {
            show_debug_message("[export] add_frame failed at " + string(_f) + " err=" + string(mp4enc_last_error()));
            _ok = false;
            break;
        }
        export_progress = _f + 1;
    }
    buffer_delete(_buf);
    surface_free(_surf);

    var _closed = mp4enc_close();
    show_debug_message("[export] done ok=" + string(_ok) + " closed=" + string(_closed) + " exists=" + string(file_exists(_out)));
    current_frame = _cur;

    if (_ok && _closed) editor_toast("Exported " + filename_name(_out));
    else editor_toast("Export failed: " + string(mp4enc_last_error()));
}
