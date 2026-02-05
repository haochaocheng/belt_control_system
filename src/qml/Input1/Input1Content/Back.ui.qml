import QtQuick

Image {
    id: back2
    width: 1920
    height: 1080
    source: "images/back2.svg"
    fillMode: Image.PreserveAspectFit

    Image {
        id: back3
        x: 0
        y: 0
        source: "images/back3.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: back_Rrigt
        x: 1520
        y: 0
        source: "images/back_Rrigt.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: back_Lift
        x: 0
        y: 0
        source: "images/back_Lift.svg"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: back1
        x: 0
        y: 0
        source: "images/back1.svg"
        fillMode: Image.PreserveAspectFit
    }
}
