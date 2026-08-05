// Native GameMaker extension: drag-and-drop + in-process MP4 export.
#include <windows.h>
#include <shellapi.h>
#include <string>
#include <deque>
#include <mutex>

#pragma comment(lib, "shell32.lib")

#define GMEXPORT extern "C" __declspec(dllexport)

static std::deque<std::string> g_dropped;
static std::mutex g_dropMutex;

struct Hook { HWND hwnd; WNDPROC prev; };
static Hook g_hooks[8];
static int g_hookCount = 0;

static WNDPROC prevProcFor(HWND hwnd) {
    for (int i = 0; i < g_hookCount; i++) if (g_hooks[i].hwnd == hwnd) return g_hooks[i].prev;
    return DefWindowProc ? nullptr : nullptr;
}

static LRESULT CALLBACK DropWndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_DROPFILES) {
        HDROP hDrop = (HDROP)wp;
        UINT n = DragQueryFileA(hDrop, 0xFFFFFFFF, NULL, 0);
        for (UINT i = 0; i < n; i++) {
            char path[MAX_PATH];
            if (DragQueryFileA(hDrop, i, path, MAX_PATH)) {
                std::lock_guard<std::mutex> lk(g_dropMutex);
                g_dropped.push_back(path);
            }
        }
        DragFinish(hDrop);
        return 0;
    }
    WNDPROC prev = prevProcFor(hwnd);
    if (prev) return CallWindowProc(prev, hwnd, msg, wp, lp);
    return DefWindowProc(hwnd, msg, wp, lp);
}

// Let WM_DROPFILES through the UAC message filter (elevated processes).
static void AllowDropMessages(HWND hwnd) {
    typedef BOOL (WINAPI *PCWMFEX)(HWND, UINT, DWORD, void*);
    HMODULE u = GetModuleHandleA("user32.dll");
    if (!u) return;
    PCWMFEX f = (PCWMFEX)GetProcAddress(u, "ChangeWindowMessageFilterEx");
    if (!f) return;
    f(hwnd, WM_DROPFILES,                 1, NULL);
    f(hwnd, 0x0049 /*WM_COPYDATA*/,       1, NULL);
    f(hwnd, 0x0313 /*WM_COPYGLOBALDATA*/, 1, NULL);
}

static void hookWindow(HWND hwnd) {
    if (!hwnd || g_hookCount >= 8) return;
    for (int i = 0; i < g_hookCount; i++) if (g_hooks[i].hwnd == hwnd) return;
    AllowDropMessages(hwnd);
    DragAcceptFiles(hwnd, TRUE);
    WNDPROC prev = (WNDPROC)SetWindowLongPtr(hwnd, GWLP_WNDPROC, (LONG_PTR)DropWndProc);
    g_hooks[g_hookCount].hwnd = hwnd;
    g_hooks[g_hookCount].prev = prev;
    g_hookCount++;
}

static BOOL CALLBACK enumChildProc(HWND child, LPARAM) {
    hookWindow(child);
    return TRUE;
}

// Hooks the top-level window and its child render window. Returns windows hooked.
GMEXPORT double dnd_enable(double hwndValue) {
    HWND h = (HWND)(intptr_t)hwndValue;
    if (!h) return 0.0;
    HWND top = h;
    while (HWND p = GetParent(top)) top = p;
    g_hookCount = 0;
    hookWindow(top);
    EnumChildWindows(top, enumChildProc, 0);
    return (double)g_hookCount;
}

GMEXPORT double dnd_count() {
    std::lock_guard<std::mutex> lk(g_dropMutex);
    return (double)g_dropped.size();
}

GMEXPORT const char* dnd_poll() {
    static std::string s;
    std::lock_guard<std::mutex> lk(g_dropMutex);
    if (g_dropped.empty()) { s.clear(); return s.c_str(); }
    s = g_dropped.front();
    g_dropped.pop_front();
    return s.c_str();
}

// Run a command line, wait, return its exit code (-1 if it couldn't start).
GMEXPORT double ffmpeg_run(const char* cmdline) {
    std::string cmd = cmdline ? cmdline : "";
    // Extra outer quotes keep quoted paths intact through cmd /C (see "cmd /?").
    std::string full = "cmd.exe /S /C \"" + cmd + "\"";

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    ZeroMemory(&pi, sizeof(pi));

    std::string buf = full;
    if (!CreateProcessA(NULL, &buf[0], NULL, NULL, FALSE,
                        CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
        return -1.0;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (double)code;
}

GMEXPORT double ffmpeg_file_exists(const char* path) {
    DWORD a = GetFileAttributesA(path ? path : "");
    return (a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY)) ? 1.0 : 0.0;
}

// ---------------------------------------------------------------------------
// In-process MP4 export: OpenH264 (loaded dynamically at runtime) + minimp4.
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>

#define MINIMP4_IMPLEMENTATION
#include "thirdparty/minimp4/minimp4.h"
#include "thirdparty/openh264/codec_api.h"

typedef int  (*WelsCreateSVCEncoder_t)(ISVCEncoder**);
typedef void (*WelsDestroySVCEncoder_t)(ISVCEncoder*);

struct Mp4Session {
    HMODULE      openh264Lib = NULL;
    ISVCEncoder* encoder     = nullptr;
    FILE*        file        = nullptr;
    MP4E_mux_t*  mux         = nullptr;
    mp4_h26x_writer_t writer;
    int          width = 0, height = 0, fps = 0;
    std::vector<unsigned char> i420;
    bool         open = false;
};

static Mp4Session g_mp4;
static std::string g_mp4LastError;

// GameMaker runs the game from a temp dir that isn't on the DLL search path, so
// load openh264 by full path from next to this dll (where GameMaker copied it).
static HMODULE LoadOpenH264() {
    char self[MAX_PATH] = {0};
    HMODULE hSelf = NULL;
    if (GetModuleHandleExA(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            (LPCSTR)&LoadOpenH264, &hSelf)
        && GetModuleFileNameA(hSelf, self, MAX_PATH) > 0) {
        std::string p(self);
        size_t slash = p.find_last_of("\\/");
        if (slash != std::string::npos) {
            std::string cand = p.substr(0, slash + 1) + "openh264-2.6.0-win64.dll";
            HMODULE h = LoadLibraryA(cand.c_str());
            if (h) return h;
        }
    }
    return LoadLibraryA("openh264-2.6.0-win64.dll");
}

static int Mp4WriteCallback(int64_t offset, const void* buffer, size_t size, void* token) {
    FILE* f = (FILE*)token;
    if (fseek(f, (long)offset, SEEK_SET) != 0) return 1;
    return fwrite(buffer, 1, size, f) != size;
}

static void Mp4CloseInternal() {
    if (g_mp4.mux) {
        mp4_h26x_write_close(&g_mp4.writer);
        MP4E_close(g_mp4.mux);
        g_mp4.mux = nullptr;
    }
    if (g_mp4.file) { fclose(g_mp4.file); g_mp4.file = nullptr; }
    if (g_mp4.encoder) {
        g_mp4.encoder->Uninitialize();
        if (g_mp4.openh264Lib) {
            auto destroy = (WelsDestroySVCEncoder_t)GetProcAddress(g_mp4.openh264Lib, "WelsDestroySVCEncoder");
            if (destroy) destroy(g_mp4.encoder);
        }
        g_mp4.encoder = nullptr;
    }
    if (g_mp4.openh264Lib) { FreeLibrary(g_mp4.openh264Lib); g_mp4.openh264Lib = NULL; }
    g_mp4.i420.clear();
    g_mp4.open = false;
}

// RGBA8 (byte0=R,1=G,2=B,3=A) -> planar I420, 2x2-averaged chroma.
static void RgbaToI420(const unsigned char* rgba, int srcStride, int w, int h,
                       unsigned char* y, unsigned char* u, unsigned char* v) {
    int cw = w / 2;
    for (int yy = 0; yy < h; yy++) {
        const unsigned char* row = rgba + (size_t)yy * srcStride;
        unsigned char* yrow = y + (size_t)yy * w;
        for (int xx = 0; xx < w; xx++) {
            int r = row[xx * 4 + 0], g = row[xx * 4 + 1], b = row[xx * 4 + 2];
            yrow[xx] = (unsigned char)(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16);
        }
    }
    int ch = h / 2;
    for (int cy = 0; cy < ch; cy++) {
        unsigned char* urow = u + (size_t)cy * cw;
        unsigned char* vrow = v + (size_t)cy * cw;
        const unsigned char* r0 = rgba + (size_t)(cy * 2) * srcStride;
        const unsigned char* r1 = rgba + (size_t)(cy * 2 + 1) * srcStride;
        for (int cx = 0; cx < cw; cx++) {
            int x0 = cx * 2 * 4, x1 = x0 + 4;
            int r = (r0[x0 + 0] + r0[x1 + 0] + r1[x0 + 0] + r1[x1 + 0]) >> 2;
            int g = (r0[x0 + 1] + r0[x1 + 1] + r1[x0 + 1] + r1[x1 + 1]) >> 2;
            int b = (r0[x0 + 2] + r0[x1 + 2] + r1[x0 + 2] + r1[x1 + 2]) >> 2;
            urow[cx] = (unsigned char)((( -38 * r -  74 * g + 112 * b + 128) >> 8) + 128);
            vrow[cx] = (unsigned char)((( 112 * r -  94 * g -  18 * b + 128) >> 8) + 128);
        }
    }
}

// Open an MP4 session. width/height are cropped to even (4:2:0). Bitrate is
// derived here rather than passed — an extension function with >4 args must
// have them all the same type, and this already mixes string + doubles.
GMEXPORT double mp4enc_open(const char* path, double width, double height, double fps) {
    Mp4CloseInternal();
    g_mp4LastError.clear();

    int w = ((int)width) & ~1;
    int h = ((int)height) & ~1;
    int f = (int)fps;
    if (w <= 0 || h <= 0 || f <= 0) { g_mp4LastError = "bad dimensions/fps"; return 0.0; }

    double bitrate = (double)w * h * f * 0.07;
    if (bitrate < 1000000.0) bitrate = 1000000.0;
    if (bitrate > 40000000.0) bitrate = 40000000.0;

    g_mp4.openh264Lib = LoadOpenH264();
    if (!g_mp4.openh264Lib) { g_mp4LastError = "openh264-2.6.0-win64.dll could not be loaded"; return 0.0; }
    auto create = (WelsCreateSVCEncoder_t)GetProcAddress(g_mp4.openh264Lib, "WelsCreateSVCEncoder");
    if (!create) { g_mp4LastError = "WelsCreateSVCEncoder missing from dll"; Mp4CloseInternal(); return 0.0; }
    if (create(&g_mp4.encoder) != 0 || !g_mp4.encoder) { g_mp4LastError = "encoder create failed"; Mp4CloseInternal(); return 0.0; }

    SEncParamBase param;
    memset(&param, 0, sizeof(param));
    param.iUsageType = CAMERA_VIDEO_REAL_TIME;
    param.iPicWidth = w;
    param.iPicHeight = h;
    param.iTargetBitrate = (int)bitrate;
    param.iRCMode = RC_BITRATE_MODE;
    param.fMaxFrameRate = (float)f;
    if (g_mp4.encoder->Initialize(&param) != 0) { g_mp4LastError = "encoder init failed"; Mp4CloseInternal(); return 0.0; }
    int videoFormat = videoFormatI420;
    g_mp4.encoder->SetOption(ENCODER_OPTION_DATAFORMAT, &videoFormat);

    g_mp4.file = fopen(path, "wb");
    if (!g_mp4.file) { g_mp4LastError = "could not create output file"; Mp4CloseInternal(); return 0.0; }
    g_mp4.mux = MP4E_open(0, 0, g_mp4.file, Mp4WriteCallback);
    if (!g_mp4.mux) { g_mp4LastError = "MP4E_open failed"; Mp4CloseInternal(); return 0.0; }
    if (mp4_h26x_write_init(&g_mp4.writer, g_mp4.mux, w, h, 0) != MP4E_STATUS_OK) {
        g_mp4LastError = "mp4_h26x_write_init failed"; Mp4CloseInternal(); return 0.0;
    }

    g_mp4.width = w; g_mp4.height = h; g_mp4.fps = f;
    g_mp4.i420.resize((size_t)w * h + 2 * (size_t)(w / 2) * (size_t)(h / 2));
    g_mp4.open = true;
    return 1.0;
}

// SEH wrappers turn an access violation into a reportable error instead of a
// silent process crash. POD-only locals so MSVC allows __try. 0 = AV caught.
static int SafeConvert(const unsigned char* rgba, int srcStride, int w, int h,
                       unsigned char* y, unsigned char* u, unsigned char* v) {
    __try { RgbaToI420(rgba, srcStride, w, h, y, u, v); return 1; }
    __except (EXCEPTION_EXECUTE_HANDLER) { return 0; }
}

static int SafeEncode(ISVCEncoder* enc, SSourcePicture* pic, SFrameBSInfo* info, int* rv) {
    __try { *rv = enc->EncodeFrame(pic, info); return 1; }
    __except (EXCEPTION_EXECUTE_HANDLER) { return 0; }
}

static int SafeWriteNals(mp4_h26x_writer_t* wr, SFrameBSInfo* info, int fps, int* status) {
    __try {
        for (int li = 0; li < info->iLayerNum; li++) {
            SLayerBSInfo& layer = info->sLayerInfo[li];
            int size = 0;
            for (int n = 0; n < layer.iNalCount; n++) size += layer.pNalLengthInByte[n];
            if (size <= 0) continue;
            int s = mp4_h26x_write_nal(wr, layer.pBsBuf, size, 90000 / fps);
            if (s != MP4E_STATUS_OK) { *status = s; return 1; }
        }
        *status = MP4E_STATUS_OK;
        return 1;
    } __except (EXCEPTION_EXECUTE_HANDLER) { return 0; }
}

// The frame pointer (GML buffer_get_address) MUST be received as char* / a
// string arg — GameMaker then passes it through untouched. A double arg would
// reinterpret the pointer bits as a float and corrupt the address.
GMEXPORT double mp4enc_add_frame(const char* bufData, double width, double height) {
    if (!g_mp4.open) { g_mp4LastError = "encoder not open"; return 0.0; }
    const unsigned char* rgba = (const unsigned char*)bufData;
    int srcStride = (int)width * 4;

    unsigned char* y = g_mp4.i420.data();
    unsigned char* u = y + (size_t)g_mp4.width * g_mp4.height;
    unsigned char* v = u + (size_t)(g_mp4.width / 2) * (size_t)(g_mp4.height / 2);
    if (!SafeConvert(rgba, srcStride, g_mp4.width, g_mp4.height, y, u, v)) {
        g_mp4LastError = "crash in RGBA->I420 (bad frame pointer?)";
        return 0.0;
    }

    SSourcePicture pic;
    memset(&pic, 0, sizeof(pic));
    pic.iColorFormat = videoFormatI420;
    pic.iPicWidth = g_mp4.width;
    pic.iPicHeight = g_mp4.height;
    pic.iStride[0] = g_mp4.width;
    pic.iStride[1] = pic.iStride[2] = g_mp4.width / 2;
    pic.pData[0] = y; pic.pData[1] = u; pic.pData[2] = v;

    SFrameBSInfo info;
    memset(&info, 0, sizeof(info));
    int encRv = 0;
    if (!SafeEncode(g_mp4.encoder, &pic, &info, &encRv)) {
        g_mp4LastError = "crash inside OpenH264 EncodeFrame";
        return 0.0;
    }
    if (encRv != cmResultSuccess) { g_mp4LastError = "EncodeFrame failed"; return 0.0; }
    if (info.eFrameType == videoFrameTypeSkip) return 1.0;

    int status = MP4E_STATUS_OK;
    if (!SafeWriteNals(&g_mp4.writer, &info, g_mp4.fps, &status)) {
        g_mp4LastError = "crash inside mp4_h26x_write_nal";
        return 0.0;
    }
    if (status != MP4E_STATUS_OK) { g_mp4LastError = "mp4_h26x_write_nal failed"; return 0.0; }
    return 1.0;
}

GMEXPORT double mp4enc_close() {
    bool wasOpen = g_mp4.open;
    Mp4CloseInternal();
    return wasOpen ? 1.0 : 0.0;
}

GMEXPORT const char* mp4enc_last_error() {
    return g_mp4LastError.c_str();
}

// Decodes an MP3 to PCM and writes it as a WAV so GML's existing WAV import
// path handles it unchanged.
#define DR_MP3_IMPLEMENTATION
#include "thirdparty/dr_mp3/dr_mp3.h"

GMEXPORT double mp3_decode_to_wav(const char* mp3_path, const char* wav_path) {
    drmp3_config cfg;
    drmp3_uint64 frameCount = 0;
    drmp3_int16* pcm = drmp3_open_file_and_read_pcm_frames_s16(mp3_path, &cfg, &frameCount, NULL);
    if (!pcm || frameCount == 0 || cfg.channels == 0) {
        if (pcm) drmp3_free(pcm, NULL);
        return 0.0;
    }

    uint32_t channels = cfg.channels;
    uint32_t rate = cfg.sampleRate;
    uint64_t dataBytes = frameCount * channels * sizeof(drmp3_int16);

    FILE* f = fopen(wav_path, "wb");
    if (!f) { drmp3_free(pcm, NULL); return 0.0; }

    uint32_t byteRate = rate * channels * 2;
    uint16_t blockAlign = (uint16_t)(channels * 2);
    uint32_t riffSize = (uint32_t)(36 + dataBytes);
    uint32_t fmtSize = 16;
    uint16_t audioFormat = 1;
    uint16_t ch16 = (uint16_t)channels;
    uint16_t bits = 16;
    uint32_t dataSize32 = (uint32_t)dataBytes;

    fwrite("RIFF", 1, 4, f);
    fwrite(&riffSize, 4, 1, f);
    fwrite("WAVE", 1, 4, f);
    fwrite("fmt ", 1, 4, f);
    fwrite(&fmtSize, 4, 1, f);
    fwrite(&audioFormat, 2, 1, f);
    fwrite(&ch16, 2, 1, f);
    fwrite(&rate, 4, 1, f);
    fwrite(&byteRate, 4, 1, f);
    fwrite(&blockAlign, 2, 1, f);
    fwrite(&bits, 2, 1, f);
    fwrite("data", 1, 4, f);
    fwrite(&dataSize32, 4, 1, f);
    fwrite(pcm, 1, (size_t)dataBytes, f);
    fclose(f);

    drmp3_free(pcm, NULL);
    return 1.0;
}
