# Distributed notification transport

Provenance: the vendored Foundation declarations (rung 2), Apple's public
DistributedNotificationCenter posting and SuspensionBehavior documentation
(rung 3), and authored two-process API tests (rung 4). No guest internals used.

- https://developer.apple.com/documentation/foundation/distributednotificationcenter
- https://developer.apple.com/documentation/foundation/distributednotificationcenter/postnotificationname(_:object:userinfo:deliverimmediately:)
- https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspensionbehavior
- https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspensionbehavior/deliverimmediately

The original implementation returns nil from defaultCenter and logs rather than
sending notifications. `distributed-notifications.m receive READY_PATH` fails
immediately on that baseline. Build the test as a Mach-O against Foundation,
objc and libSystem with the configured SDK/reexport mappings. Run a receiver
and an independent `distributed-notifications.m send` process in the same private
Darling prefix. Start the sender only after READY_PATH exists. They exchange
binary property-list values and an acknowledgement through the public APIs.
The receiver checks main-thread delivery, name/object filters, observer removal,
a nested dictionary, data values and a different sender PID. Both must exit 0.
A local-only nonnil center fails this test.

The transport uses nonblocking UNIX datagrams and owner-only directories/sockets,
inside the prefix, scoped by UID. A desktop-session hash uses XDG_SESSION_ID,
then WAYLAND_DISPLAY, then one session for the prefix. This mapping is explicitly
a compatibility approximation (GUESS/rung 6), not a Darwin audit-session
implementation. Unix getsid is unsuitable: separate Darling launches create
separate Unix sessions. PostToAllSessions sends to all desktop-session peers of
the same UID in this prefix; no cross-user transport is provided.

Messages are property lists limited to 64 KiB; malformed protocol packets are
ignored. A stalled peer cannot block a sender. Notifications remain best effort;
full receive buffers can drop messages. Suspended queues have 256 entries per
registration and may flush when full, as allowed for Hold by the public contract.
The private namespace lives under /var/run, because /tmp may map to the host
and be shared by otherwise independent prefixes. Unclean process exits can
leave stale socket files; send errors are ignored and
peers never unlink another process's path. Foundation-after-fork use is not
validated; independent test processes must exec their test image.

This work does not repair CFNotificationCenter's independent distributed-center
implementation or provide App Sandbox policy enforcement.

Additional session check: run the receiver with XDG_SESSION_ID=receiver and
`send-all` with XDG_SESSION_ID=sender (set inside the guest shell). The sender
first posts an intentionally invalid payload to its own session; delivery to
the other session would fail the receiver. It then uses PostToAllSessions for
the valid payload and completion; acknowledgement also crosses sessions.
Run the ordinary receive/send pair with a matching session as a control.
