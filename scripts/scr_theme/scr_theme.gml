// animgm — theme colours + tuning constants
// Theme colours mirror animator/src/styles/global.css (GM colours are $BBGGRR)
#macro COL_PRIMARY      $EFA400   // #00A4EF
#macro COL_SECONDARY    $D47800   // #0078D4
#macro COL_KEYFRAME     $FF4A90D9  // Blue color for keyframes
#macro COL_ACCENT       $FFD400   // #00D4FF
#macro COL_BG_CANVAS    $191919
#macro COL_BG_PANEL     $2B2B2B
#macro COL_BG_PANEL_DK  $232323
#macro COL_BG_TOOLBAR   $323232
#macro COL_BORDER       $1A1A1A
#macro COL_BORDER_LT    $3E3E3E
#macro COL_HOVER        $3A3A3A
#macro COL_ACTIVE       $404040
#macro COL_GRID         $2A2A2A
#macro COL_PLAYHEAD     $303BFF   // #FF3B30
#macro COL_TEXT         $E8E8E8
#macro COL_TEXT_2       $B0B0B0
#macro COL_TEXT_MUTED   $7A7A7A
#macro COL_FRAME_HL     $F6823B   // rgba(59,130,246,*) frame cell highlight
#macro COL_INPUT_BG     $1E1E1E
#macro COL_BTN_SEC_H    $4A4A4A   // btn-secondary hover

// ---- keyframe surface-eviction tuning (see scr_keyframe) ----
#macro KF_SURFACE_GRACE  90   // keep an unused surface alive this many epochs
#macro KF_SURFACE_BUDGET 64   // hard cap on simultaneously live surfaces
