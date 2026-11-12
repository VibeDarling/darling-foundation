#include <darling-boundary-diagnostics.h>

extern int authored_foundation_bridge(void);
int main(void) {
    int status = authored_foundation_bridge();
    if (status == 0)
        darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_OVERLAY_BRIDGE_SUCCESS);
    return status;
}
