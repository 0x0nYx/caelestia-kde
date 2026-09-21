# Put an intensity knob on a generated palette, and only on a generated one

Matugen's vibrant variant is flatter than the one the old color engine produced. The newer
specification balances tonal elevation, and that took chroma out of exactly the variant people
pick when they want a loud desktop, which is what the reports say (#790, #763, #791). On
2026-09-12 the port decided to accept matugen's palette rather than compensate for it. That
decision still holds for a default, and it has nothing to say to a user who chose vibrant and
wants it louder, so the render now takes an intensity. This revises
0002-matugen-owns-the-palette.md, which recorded dropping the hue and chroma knobs that lived on
the Advanced Colors page as one of the costs it accepted.

The intensity is a saturation multiplier from 0 to 2. One is what matugen produced, byte for
byte, and is what every path defaults to; zero leaves a grey palette at the tones it already had;
two saturates the accents. Scaling saturation is scaling chroma with the tone left alone, which is
the nearest the standard library gets to the specification's own chroma, and it is why the palette
keeps its shape instead of drifting to a different one.

The factor is stored in `scheme.json` beside the variant rather than in the CLI's own config, and
that is the decision that kept the rest of this small. Every path that re-derives the palette - a
wallpaper change, the reseed at login, the login screen syncing itself - starts by reading the
scheme in effect, so a value kept there survives all of them with no flag threaded through any of
their calls, and it is the same file `Colours.qml` already reads, so the slider has a source of
truth that updates itself. A value in `cli.json` would have needed a second write path and left a
knob that a wallpaper change silently reset, which is the shape of bug the variant itself had
(#763). It travels from one scheme to the next for the same reason the variant does: the knob is
a standing preference about how saturated the palette should be, not a property of one wallpaper.

Three alternatives were rejected. Reproducing the old engine's post-processing automatically is
still what the earlier decision ruled out: it means maintaining a transform reverse-engineered
from somebody else's output and applying it to users who never asked. Keeping the old engine
alongside the new one behind a setting, which the reporter suggested, means two color engines,
two dependency trees and two sets of bugs for a preference the specification has moved past. And
scaling every palette, named schemes included, would make catppuccin no longer catppuccin: those
files are curated, so they record the factor and are not scaled by it.

What this costs is a palette that can be pushed past what the specification would produce. The
surfaces follow the accents, so at 2 the background is tinted too, which is what more vibrant
means but is no longer a Material palette. Saturation in HSL is not chroma in HCT, so the hues
wander a little at the top of the range as the accents clamp. Two is where the range ends, not a
reproduction of the 2.4.2 palette the reports came from: that engine is gone from the tree, so
nothing here can be measured against it, and the top of the range is set where the accents still
hold the hue they were given instead.

The render costs more at any intensity but the default. matugen cannot be asked for a palette it
would not have produced by itself, so it is run once to produce one, the command scales that, and
the fan out - the terminals, GTK, Qt, the scheme Plasma is applied - is rendered from the scaled
palette in a second run. Without that second run the desktop would be themed at matugen's
intensity while the shell was themed at the user's, which is worse than the extra run. A change at
the default intensity still renders everything in one pass, so no existing install pays for this.

And the slider commits when it is let go rather than as it is dragged, because every step of a
drag would otherwise be a run of the color engine, the whole theme fan out and a re-apply of the
Plasma scheme. For the same reason it does not follow the wheel, which is the one way this
control behaves unlike the other sliders in Nexus: those write a config value that is visible
immediately, while this one waits for a render to come back through `scheme.json`.
