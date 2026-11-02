.pragma library

// Colour choices beyond DMS' Theme.roleColor: DMS' surface levels (set in
// DMS › Wallpaper & colours › Surfaces, so they follow the user's choice)
// and black/white with 85 % transparency. Everything else goes to DMS.
// theme = the Theme singleton (passed in, a library has no imports).
function resolve(theme, mode, customColor, fallback) {
    switch (mode ?? "default") {
    case "host":
        return theme.hostSurface;
    case "card":
        return theme.cardSurface;
    case "chip":
        return theme.chipSurface;
    case "chipNested":
        return theme.chipSurfaceNested;
    case "black85":
        return Qt.rgba(0, 0, 0, 0.15);
    case "white85":
        return Qt.rgba(1, 1, 1, 0.15);
    default:
        return theme.surfaceRoleColor(mode, customColor, fallback);
    }
}
