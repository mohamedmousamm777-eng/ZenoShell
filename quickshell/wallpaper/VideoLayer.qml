import QtQuick
import QtMultimedia
import qs.services

// The video player. It is its own file on purpose: LiveWallpaper.qml loads it with a Loader, so if the
// Qt Multimedia module is not installed only this fails (the shell and the GIFs keep working).
Item {
    id: layer

    property url source: ""
    property bool paused: false

    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // Play or pause, but only once the player really has the file (otherwise play() does nothing
    // and nothing would start it later)
    function sync() {
        if (player.source.toString() === "") return
        if (paused) player.pause(); else player.play()
    }

    onPausedChanged: sync()

    // no AudioOutput: always silent
    MediaPlayer {
        id: player
        source: layer.source
        loops: MediaPlayer.Infinite
        videoOutput: out
        onErrorOccurred: (error, text) => { LiveWall.playerError = text !== "" ? text : "player error" }
        onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) layer.opacity = 1
        onSourceChanged: layer.sync()
        // the file is ready: start (also covers a source set before the player was ready)
        onMediaStatusChanged: {
            if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)
                    && !layer.paused && playbackState !== MediaPlayer.PlayingState)
                play()
        }
        Component.onCompleted: layer.sync()
    }

    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
