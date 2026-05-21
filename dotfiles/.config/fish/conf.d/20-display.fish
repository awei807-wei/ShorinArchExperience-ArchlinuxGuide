# Auto-fix DISPLAY for X11 apps under Wayland (niri + Xwayland/xwayland-satellite)
# This runs for interactive fish sessions.
if not set -q DISPLAY
    set -l found_display ""

    # Prefer /tmp/.X11-unix (common for Xwayland); fallback to $XDG_RUNTIME_DIR if present.
    for i in (seq 0 9)
        if test -S "/tmp/.X11-unix/X$i"
            set found_display ":$i"
            break
        end
    end

    if test -z "$found_display"; and set -q XDG_RUNTIME_DIR
        for i in (seq 0 9)
            if test -S "$XDG_RUNTIME_DIR/X11-unix/X$i"
                set found_display ":$i"
                break
            end
        end
    end

    if test -n "$found_display"
        set -gx DISPLAY $found_display

        # Best-effort: propagate to desktop-activated apps (dbus/systemd user).
        if command -q dbus-update-activation-environment
            dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR >/dev/null 2>&1
        end
        if command -q systemctl
            systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR >/dev/null 2>&1
        end
    end
end
