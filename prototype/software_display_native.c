/* The Windows callback must reside in an image-backed module. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef struct {
    ULONG size;
    const WCHAR *instance, *hardware, *compatible;
    const GUID *container;
    ULONG capabilities;
    const WCHAR *description, *location;
    const void *security;
} CreateInfo;
typedef void (WINAPI *CreateCallback)(HANDLE, HRESULT, void *, const WCHAR *);
typedef HRESULT (WINAPI *CreateFunction)(const WCHAR *, const WCHAR *, const CreateInfo *, ULONG, const void *, CreateCallback, void *, HANDLE *);
typedef void (WINAPI *CloseFunction)(HANDLE);
typedef struct {
    HMODULE api;
    HANDLE device, completed;
    CloseFunction close;
    HRESULT result;
    WCHAR instance[512];
} DisplayContext;

static void WINAPI OnCreated(HANDLE device, HRESULT result, void *opaque, const WCHAR *instance) {
    DisplayContext *context = (DisplayContext *)opaque;
    (void)device;
    context->result = result;
    if (instance) lstrcpynW(context->instance, instance, 512);
    SetEvent(context->completed);
}
static void Release(DisplayContext *context) {
    if (!context) return;
    if (context->device && context->close) context->close(context->device);
    /* SwDeviceClose guarantees the creation callback can no longer run. */
    if (context->completed) CloseHandle(context->completed);
    if (context->api) FreeLibrary(context->api);
    HeapFree(GetProcessHeap(), 0, context);
}
__declspec(dllexport) void WINAPI CastAggregatorClose(void *opaque) {
    Release((DisplayContext *)opaque);
}
__declspec(dllexport) HRESULT WINAPI CastAggregatorCreate(const WCHAR *instance, WCHAR *out_id, ULONG chars, void **out_context, ULONG *stage) {
    if (!instance || !out_id || chars < 512 || !out_context || !stage) return E_INVALIDARG;
    *stage = 1;
    *out_context = NULL; out_id[0] = 0;
    DisplayContext *context = (DisplayContext *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(DisplayContext));
    if (!context) return E_OUTOFMEMORY;
    context->api = LoadLibraryExW(L"cfgmgr32.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!context->api) { HRESULT hr = HRESULT_FROM_WIN32(GetLastError()); Release(context); return hr; }
    CreateFunction create = (CreateFunction)(void *)GetProcAddress(context->api, "SwDeviceCreate");
    context->close = (CloseFunction)(void *)GetProcAddress(context->api, "SwDeviceClose");
    if (!create || !context->close) { Release(context); return HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND); }
    context->completed = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!context->completed) { HRESULT hr = HRESULT_FROM_WIN32(GetLastError()); Release(context); return hr; }
    CreateInfo info = {0};
    info.size = sizeof(info); info.instance = instance; info.hardware = L"MttVDD\0";
    info.capabilities = 9; info.description = L"CastAggregator temporary virtual display";
    *stage = 2;
    HRESULT hr = create(L"CastAggregator", L"HTREE\\ROOT\\0", &info, 0, NULL, OnCreated, context, &context->device);
    if (FAILED(hr)) { Release(context); return hr; }
    /* Creation already defaults to handle lifetime. No lifetime change needed. */
    *stage = 3;
    DWORD wait = WaitForSingleObject(context->completed, 20000);
    if (wait != WAIT_OBJECT_0) {
        hr = HRESULT_FROM_WIN32(wait == WAIT_TIMEOUT ? ERROR_TIMEOUT : GetLastError()); Release(context); return hr;
    }
    *stage = 4;
    if (FAILED(context->result)) { hr = context->result; Release(context); return hr; }
    if (!context->instance[0]) { Release(context); return E_UNEXPECTED; }
    lstrcpynW(out_id, context->instance, (int)chars);
    *out_context = context;
    *stage = 0;
    return S_OK;
}
