// animgm — editor controller

window_set_caption("animgm");
window_set_min_width(1024);
window_set_min_height(640);
draw_set_font(fnt_ui);

dnd_enable(window_handle());

screen = "manager";

project_name  = "Untitled";
project_path  = "";          // "" until saved / loaded
is_dirty      = false;
canvas_w      = 1920;
canvas_h      = 1080;
anim_fps      = 24;
total_frames  = 30;
current_frame = 0;
is_playing    = false;
play_timer    = 0;
onion_skin    = false;

recent_projects = [];        // loaded lazily on Create (below)
newproj_open    = false;     // New Project modal visible
np_name = "Untitled Animation";
np_w = 1920; np_h = 1080; np_fps = 24; np_frames = 30;
np_field = -1;               // which text field is being edited (see Draw)
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
np_preset_open = false;      // preset dropdown expanded
np_preset_rect = [];         // per-item hit-rects (when open)
np_preset_box  = [0,0,0,0];  // the collapsed dropdown box rect
np_sel_a = 0;                // selection anchor
np_sel_b = 0;                // selection caret; a==b means no selection
np_dragging = false;         // dragging out a selection with the mouse
pm_hover_remove = -1;        // recent card whose remove-X is hovered
pm_thumb_cache = ds_map_create();   // path -> loaded thumbnail sprite (or -1)
pm_new_rect = [0,0,0,0]; pm_open_rect = [0,0,0,0];
pm_card_rect = []; pm_cardx_rect = [];
np_field_rect = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];
np_close_rect = [0,0,0,0]; np_cancel_rect = [0,0,0,0]; np_create_rect = [0,0,0,0];

tool            = "select";
selected_shape  = "rectangle";
stroke_color    = make_colour_rgb(0, 0, 0);       // #000000
fill_color      = make_colour_rgb(255, 255, 255); // #FFFFFF
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

zoom  = 1.0;   // 1.0 == 100%
pan_x = 0;
pan_y = 0;

layers = [layer_make("Layer 1", total_frames)];
layers[0].frames[0] = keyframe_make();
selected_layer = 0;

menu_names        = ["File", "Edit", "Window"];
// menubar hit-rects are recomputed in Step; seed them so Draw never reads unset
menubar_x = array_create(array_length(menu_names), 0);
menubar_w = array_create(array_length(menu_names), 0);
open_menu         = -1;      // index into menu_names, -1 = closed
shape_picker_open = false;
shape_btn_lastclick = -1000; // for double-click detection
ui_click_used     = false;

is_drawing  = false;         // freehand stroke in progress
stroke_pts  = [];
// brush stabilizer: the "pen" trails the cursor so shaky input smooths into
// a clean line (like Photoshop/Krita/Lazy Nezumi)
pen_x = 0; pen_y = 0;         // stabilized pen position (canvas coords)
shape_drag  = false;         // line/shape drag in progress
drag_x0 = 0; drag_y0 = 0;
drag_x1 = 0; drag_y1 = 0;
erasing     = false;
erase_px = 0; erase_py = 0;

panning = false;
pan_mx = 0; pan_my = 0; pan_ox = 0; pan_oy = 0;

scrubbing      = false;
drag_slider    = -1;         // 0 = stroke width / eraser size, 1 = smoothing
editing_frames = false;      // frame-count text input active
tf_edit = -1;                // which transform field is being edited (-1 none)
tf_text = "";               // current text buffer for the edited field
tf_rects = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];  // field hit-rects

sel_active   = false;        // a committed marquee rectangle exists
sel_x = 0; sel_y = 0; sel_w = 0; sel_h = 0;   // selection rect in canvas coords
sel_rot      = 0;            // selection rotation (degrees, around its centre)
sel_marquee  = false;        // currently dragging out a new rectangle
sel_mx0 = 0; sel_my0 = 0;    // marquee anchor
sel_moving   = false;        // dragging the selection contents
sel_float    = -1;           // lifted pixels (surface) while moving/pasted
sel_fw = 0; sel_fh = 0;      // floating surface size (original pixel dimensions)
sel_grab_dx = 0; sel_grab_dy = 0;  // cursor offset within the selection
sel_lifted   = false;        // contents lifted from the keyframe (vs. just marquee)
sel_xform    = -1;           // -1 none, 0..7 resize handles, 8 rotate
sel_grab_rot = 0;            // rotation at drag-start
sel_grab_ang = 0;           // pointer angle at drag-start (for rotate)
sel_grab_x = 0; sel_grab_y = 0; sel_grab_w = 0; sel_grab_h = 0;  // rect at grab
clip_buf = -1;               // clipboard: raw ARGB buffer
clip_w = 0; clip_h = 0;      // clipboard dimensions
sel_ants = 0;                // marching-ants animation phase
sel_last_frame = 0;          // frame the current selection belongs to

window_set_cursor(cr_none);
cursor_mode = "arrow";       // arrow | brush | eraser | cross | move

ctx_open   = false;
ctx_x = 0; ctx_y = 0;        // menu top-left (gui)
ctx_layer  = -1;             // layer the menu acts on
ctx_items  = [];             // [label, icon, shortcut, danger] rows, "-" = divider
rename_open = false;         // inline layer-name editor active
rename_text = "";
rename_layer = -1;

unsaved_open = false;        // "Save changes?" dialog visible
unsaved_action = undefined;  // deferred action to run after the dialog resolves
pending_open_path = "";      // .anst path awaiting the guard (File > Open)

export_progress = 0;
export_total = 0;

title_h    = 40;             // titlebar height (px)
win_drag   = false;          // dragging the window by the titlebar
win_drag_mx = 0; win_drag_my = 0;   // cursor offset within the window at grab
win_maximized = false;       // pseudo-maximize (fills the work area)
win_rest_x = 0; win_rest_y = 0; win_rest_w = 0; win_rest_h = 0;  // restore rect
win_anim   = 0;              // 0 = idle, else remaining time (s)
win_anim_dur = 0.18;
win_from_x = 0; win_from_y = 0; win_from_w = 0; win_from_h = 0;
win_to_x = 0; win_to_y = 0; win_to_w = 0; win_to_h = 0;

tl_scroll  = 0;              // timeline horizontal scroll (px)
tl_vscroll = 0;              // timeline layers vertical scroll (px)
tb_scroll  = 0;              // left toolbar vertical scroll (px)
tb_content_h = 8 + array_length(tool_ids) * 46 + 17 + 60 + 8;

undo_stack = [];
redo_stack = [];

kf_epoch = 0;                // increments each step; used for surface LRU eviction
dbg_perf = false;            // log surface-restore timings to the debug console

toast_text  = "";
toast_timer = 0;

color_target = "";           // "stroke" / "fill" — which swatch the picker edits
picker_open  = false;
picker_drag  = -1;           // 0 = SV square, 1 = hue bar
pick_h = 0; pick_s = 0; pick_v = 0;

gw = 0; gh = 0;
mbar_h = 32; tb_w = 48; pp_w = 280; tl_h = 200; tlh_h = 32;
lay_w = 180; ruler_h = 24; cell_w = 20; row_h = 24;
cv_x = 0; cv_y = 0; cv_w = 0; cv_h = 0; tl_y = 0;

recent_projects = project_load_recent();
