import QtQuick
import Quickshell
import Caelestia.Models
import qs.utils

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
