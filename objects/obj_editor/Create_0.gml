window_set_caption("animgm");
window_set_min_width(1024);
window_set_min_height(640);
draw_set_font(fnt_ui);

dnd_enable(window_handle());

screen = "manager";

project_name  = "Untitled";
project_path  = "";
is_dirty      = false;
canvas_w      = 1920;
canvas_h      = 1080;
anim_fps      = 24;
total_frames  = 30;
current_frame = 0;
is_playing    = false;
play_timer    = 0;
onion_skin    = false;

recent_projects = [];
newproj_open    = false;
np_name = "Untitled Animation";
np_w = 1920; np_h = 1080; np_fps = 24; np_frames = 30;
np_field = -1;
np_presets = [
    ["1080p (Full HD)",  "16:9",  1920, 1080],
    ["4K UHD",           "16:9",  3840, 2160],
    ["720p (HD)",        "16:9",  1280,  720],
    ["Square",           "1:1",   1080, 1080],
    ["Story / Reels",    "9:16",  1080, 1920],
    ["Portrait",         "4:5",   1080, 1350],
    ["Landscape",        "4:3",   1440, 1080],
    ["Cinema",           "21:9",  2560, 1080],
];
np_preset_open = false;
np_preset_rect = [];
np_preset_box  = [0,0,0,0];
np_sel_a = 0;
np_sel_b = 0;
np_dragging = false;
pm_hover_remove = -1;
pm_thumb_cache = ds_map_create();
pm_new_rect = [0,0,0,0]; pm_open_rect = [0,0,0,0];
pm_card_rect = []; pm_cardx_rect = [];
np_field_rect = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];
np_close_rect = [0,0,0,0]; np_cancel_rect = [0,0,0,0]; np_create_rect = [0,0,0,0];

tool            = "select";
selected_shape  = "rectangle";
stroke_color    = make_colour_rgb(0, 0, 0);
fill_color      = make_colour_rgb(255, 255, 255);
stroke_width    = 2;
eraser_width    = 10;
brush_smoothing = 35;

tool_ids   = ["select","subselect","brush","line","shape","eraser","paint-bucket","eyedropper","hand","zoom"];
tool_icons = [spr_ic_move, spr_ic_mouse_pointer_2, spr_ic_paintbrush, spr_ic_minus,
              spr_ic_square, spr_ic_eraser, spr_ic_paint_bucket, spr_ic_pipette, spr_ic_hand, spr_ic_zoom_in];
tool_labels = ["Select","Subselect","Brush","Line","Shape","Eraser","Paint Bucket","Eyedropper","Hand","Zoom"];
tool_keys   = ["V","A","B","N","R","E","K","I","H","Z"];

shape_ids   = ["rectangle","circle","ellipse","triangle","diamond","pentagon","hexagon","star"];
shape_icons = [spr_ic_square, spr_ic_circle, spr_ic_circle, spr_ic_triangle,
               spr_ic_diamond, spr_ic_pentagon, spr_ic_hexagon, spr_ic_star];

zoom  = 1.0;
pan_x = 0;
pan_y = 0;

layers = [layer_make("Layer 1", total_frames)];
layers[0].frames[0] = keyframe_make();
selected_layer = 0;

menu_names        = ["File", "Edit", "Window"];
menubar_x = array_create(array_length(menu_names), 0);
menubar_w = array_create(array_length(menu_names), 0);
open_menu         = -1;
shape_picker_open = false;
shape_btn_lastclick = -1000;
ui_click_used     = false;

is_drawing  = false;
stroke_pts  = [];
pen_x = 0; pen_y = 0;
shape_drag  = false;
drag_x0 = 0; drag_y0 = 0;
drag_x1 = 0; drag_y1 = 0;
erasing     = false;
erase_px = 0; erase_py = 0;

panning = false;
pan_mx = 0; pan_my = 0; pan_ox = 0; pan_oy = 0;

scrubbing      = false;
drag_slider    = -1;
editing_frames = false;
tf_edit = -1;
tf_text = "";
tf_rects = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];

sel_active   = false;
sel_x = 0; sel_y = 0; sel_w = 0; sel_h = 0;
sel_rot      = 0;
sel_marquee  = false;
sel_mx0 = 0; sel_my0 = 0;
sel_moving   = false;
sel_float    = -1;
sel_fw = 0; sel_fh = 0;
sel_grab_dx = 0; sel_grab_dy = 0;
sel_lifted   = false;
sel_xform    = -1;           // -1 none, 0..7 resize handles, 8 rotate
sel_grab_rot = 0;
sel_grab_ang = 0;
sel_grab_x = 0; sel_grab_y = 0; sel_grab_w = 0; sel_grab_h = 0;
clip_buf = -1;
clip_w = 0; clip_h = 0;
sel_ants = 0;
sel_last_frame = 0;

tween_active    = false;
tween_li        = -1;
tween_start_fr  = 0;
tween_end_fr    = 0;
tween_buf       = -1;          // persistent ARGB copy of the lifted pixels
tween_fw = 0; tween_fh = 0;    // original pixel dimensions of tween_buf
tween_start_x = 0; tween_start_y = 0; tween_start_w = 0; tween_start_h = 0; tween_start_rot = 0;

window_set_cursor(cr_none);
cursor_mode = "arrow";

ctx_open   = false;
ctx_x = 0; ctx_y = 0;
ctx_kind   = "layer";         // "layer" | "frame" | "audio" — which menu ctx_items belongs to
ctx_layer  = -1;
ctx_fr_li  = -1; ctx_fr_fi = -1;
ctx_items  = [];              // [label, icon, shortcut, danger] rows, "-" = divider
rename_open = false;
rename_text = "";
rename_layer = -1;

unsaved_open = false;
unsaved_action = undefined;
pending_open_path = "";

export_progress = 0;
export_total = 0;

title_h    = 40;
win_drag   = false;
win_drag_mx = 0; win_drag_my = 0;
win_maximized = false;
win_rest_x = 0; win_rest_y = 0; win_rest_w = 0; win_rest_h = 0;
win_anim   = 0;
win_anim_dur = 0.18;
win_from_x = 0; win_from_y = 0; win_from_w = 0; win_from_h = 0;
win_to_x = 0; win_to_y = 0; win_to_w = 0; win_to_h = 0;

tl_scroll  = 0;
tl_follow_frame = current_frame;
tl_vscroll = 0;
tb_scroll  = 0;
tb_content_h = 8 + array_length(tool_ids) * 46 + 17 + 60 + 8;

undo_stack = [];
redo_stack = [];

kf_epoch = 0;
dbg_perf = false;

toast_text  = "";
toast_timer = 0;

color_target = "";
picker_open  = false;
picker_drag  = -1;
pick_h = 0; pick_s = 0; pick_v = 0;

gw = 0; gh = 0;
audio_h = 28;
mbar_h = 32; tb_w = 48; pp_w = 280; tl_h = 200 + audio_h; tlh_h = 32;
lay_w = 180; ruler_h = 24; cell_w = 20; row_h = 24;
cv_x = 0; cv_y = 0; cv_w = 0; cv_h = 0; tl_y = 0;

audio_path      = "";
audio_kind      = "";
audio_sound     = -1;
audio_file_buf  = -1;
audio_instance  = -1;
audio_duration  = 0;
audio_trim_start = 0;         // seconds into the source file where the clip begins
audio_trim_end   = 0;         // seconds into the source file where the clip ends
audio_offset_fr = 0;
audio_drag      = false;
audio_drag_mx0  = 0;
audio_drag_off0 = 0;
audio_resize       = false;
audio_resize_side  = 0;       // 1 = left handle (trim start), 2 = right handle (trim end)
audio_resize_mx0   = 0;
audio_resize_start0 = 0;
audio_resize_end0   = 0;
audio_resize_off0   = 0;

recent_projects = project_load_recent();
