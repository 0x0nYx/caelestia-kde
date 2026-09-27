# Fonts

The shell loads every `.ttf`/`.otf` found here at startup. This directory ships the
Google Sans Flex subset the shell uses by default; the full variable font lives in
`assets/google-sans-flex/`.

A font this repository does not ship - SF Pro, for example - goes into the user's own
directory instead, `~/.local/share/caelestia/assets/fonts`, which the shell reads the
same way.