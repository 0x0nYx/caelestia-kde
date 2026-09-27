import QtQuick
import Caelestia.Models
import qs.utils

Item {
    FileSystemModel {
        id: userFontsModel

        recursive: true
        path: `${Paths.data}/assets/fonts`
        filter: FileSystemModel.Files
        nameFilters: ["*.ttf", "*.otf"]
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
