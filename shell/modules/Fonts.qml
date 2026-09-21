import QtQuick
import Quickshell
import Caelestia.Models
import qs.utils

// Loads every font found under assets/fonts - both the bundled ones
// (google-sans-flex) and anything the user drops in (e.g. SF-Pro/, SF-Mono/,
// or their own folders) - recursively. Adding a font never requires touching
// this file.
//
// Two directories, not one. A package ships the small assets and leaves the fonts
// to the install, which downloads them into the user's own asset directory
// (scripts/12-fetch-assets.sh); a checkout has them in its tree. The shell cannot
// put them in its own tree when a package owns it, and a download there would
// outlive the package.
Item {
    FileSystemModel {
        id: bundledFontsModel

        recursive: true
        path: Quickshell.shellPath("assets/fonts")
        filter: FileSystemModel.Files
        nameFilters: ["*.ttf", "*.otf"]
    }

    FileSystemModel {
        id: userFontsModel

        recursive: true
        path: `${Paths.data}/assets/fonts`
        filter: FileSystemModel.Files
        nameFilters: ["*.ttf", "*.otf"]
    }

    Repeater {
        model: bundledFontsModel

        delegate: Item {
            FontLoader {
                source: "file://" + modelData.path
            }
        }
    }

    Repeater {
        model: userFontsModel

        delegate: Item {
            FontLoader {
                source: "file://" + modelData.path
            }
        }
    }
}
