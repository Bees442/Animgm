function editor_menu_rows(_idx) {
    switch (menu_names[_idx]) {
        case "File": return [
            ["New Project", "Ctrl+N"], ["Open...", "Ctrl+O"], ["-"],
            ["Save", "Ctrl+S"], ["Save As...", "Ctrl+Shift+S"], ["-"],
            ["Import Image...", ""], ["Export...", "Ctrl+E"],
        ];
        case "Edit": return [
            ["Undo", "Ctrl+Z"], ["Redo", "Ctrl+Y"], ["-"],
            ["Cut", "Ctrl+X"], ["Copy", "Ctrl+C"], ["Paste", "Ctrl+V"], ["-"],
            ["Delete", "Del"],
        ];
    }
    return [];
}

function editor_menu_action(_idx, _label) {
    switch (_label) {
        case "New Project":
            editor_guard_action(editor_do_new_project);
            break;
        case "Open...":  editor_open_dialog(); break;
        case "Save":     editor_save(false);  break;
        case "Save As...": editor_save(true); break;
        case "Undo": editor_undo(); break;
        case "Redo": editor_redo(); break;
        case "Cut":    sel_cut();    break;
        case "Copy":   sel_copy();   break;
        case "Paste":  sel_paste();  break;
        case "Delete": sel_delete(); break;
        case "Import Image...": editor_import_image(); break;
        case "Export...": editor_export_mp4(); break;
    }
}

function editor_save(_as) {
    var _path = project_path;
    if (_as || _path == "") {
        _path = get_save_filename("animgm Project|*.anst", project_name + ".anst");
        if (_path == "") return;
        if (filename_ext(_path) == "") _path += ".anst";
    }
    if (project_save(_path)) editor_toast("Saved: " + filename_name(_path));
    else editor_toast("Save failed");
}

function editor_import_image() {
    var _path = get_open_filename("Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif", "");
    if (_path == "") return;
    editor_place_image(_path, true);
}

function editor_place_image(_path, _new_layer) {
    if (!file_exists(_path)) { editor_toast("File not found"); return; }
    var _ext = string_lower(filename_ext(_path));
    if (_ext != ".png" && _ext != ".jpg" && _ext != ".jpeg" && _ext != ".bmp" && _ext != ".gif") {
        editor_toast("Not an image: " + filename_name(_path));
        return;
    }
    var _spr = sprite_add(_path, 1, false, false, 0, 0);
    if (_spr == -1) { editor_toast("Could not load image"); return; }

    var _iw = sprite_get_width(_spr);
    var _ih = sprite_get_height(_spr);
    var _sc = min(canvas_w / _iw, canvas_h / _ih, 1);
    var _dw = _iw * _sc, _dh = _ih * _sc;
    var _dx = (canvas_w - _dw) * 0.5;
    var _dy = (canvas_h - _dh) * 0.5;

    if (_new_layer) {
        var _lname = filename_change_ext(filename_name(_path), "");
        layer_add(_lname);
    } else if (array_length(layers) == 0 || layers[selected_layer].locked) {
        editor_toast("Layer is locked");
        sprite_delete(_spr);
        return;
    }

    var _li = selected_layer;
    editor_push_undo(_li, frame_resolve(layers[_li], current_frame));
    var _kf = active_keyframe();
    surface_set_target(kf_surface(_kf));
    draw_sprite_ext(_spr, 0, _dx, _dy, _sc, _sc, 0, c_white, 1);
    surface_reset_target();
    kf_mark_used(_kf, _dx, _dy, _dx + _dw, _dy + _dh, 1);
    _kf.dirty = true; kf_backup(_kf);
    sprite_delete(_spr);
    editor_toast("Imported " + filename_name(_path));
}

function editor_open_dialog() {
    var _path = get_open_filename("animgm Project|*.anst", "");
    if (_path == "") return;
    pending_open_path = _path;
    editor_guard_action(editor_do_open_pending);
}

function editor_do_new_project() {
    screen = "manager";
    recent_projects = project_load_recent();
    newproj_open = true;
    np_name = "Untitled Animation"; np_w = 1920; np_h = 1080; np_fps = 24; np_frames = 30;
    np_field = -1; np_preset_open = false;
}

function editor_do_open_pending() {
    var _p = pending_open_path;
    pending_open_path = "";
    if (_p == "") return;
    if (project_load(_p)) { recent_projects = project_load_recent(); editor_toast("Opened: " + filename_name(_p)); }
    else editor_toast("Open failed");
}
