#include <dlfcn.h>
#include <darling-boundary-diagnostics.h>

int main(void) {
    void *handle = dlopen("/System/Library/Frameworks/Foundation.framework/Foundation",
                          RTLD_LAZY | RTLD_LOCAL | RTLD_FIRST);
    if (!handle)
        return 95;
    void *bridge = dlsym(handle, "$sSS10FoundationE19_bridgeToObjectiveCSo8NSStringCyF");
    dlclose(handle);
    if (!bridge)
        return 96;
    darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_OVERLAY_LOOKUP_SUCCESS);
    return 0;
}
