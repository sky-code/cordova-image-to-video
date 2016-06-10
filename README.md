# cordova-images-to-video plugin

iOS Cordova plugin for converting images (frames) to video written in Swift.

## Usage

```javascript
var options = {
    filePath: filePath,
    width: 320,
    height: 150,
    fps: 30
};
frames = ["data:image/gif;base64,R0lGODlhMgAyA...", "data:image/gif;base64,R0lGODlhMgAyA..."];
MediaKit.convert(function (fileUrl) {

            videoPreviewElement.src = fileUrl;
            videoPreviewElement.play();

            MediaKit.saveVideoToPhotoLibrary(function(videoLocalIdentifier) {
                                             alert(videoLocalIdentifier);
            }, function(error) {
                console.log(error);
            }, fileUrl);
        }, function () {
            console.log(error);
        }, options, frames);
```

## Useful links 

https://gist.github.com/acj/6ae90aa1ebb8cad6b47b
https://gist.github.com/yangyi/99f347fb1616342569cf

Good implementation of **pixelBufferFromImage** can be found here https://github.com/kiomega/horrorgram-ios/blob/master/Horrorgram/HorrorgramVideoMaker.swift

Also interested links
https://github.com/davidisaaclee/ViewRecorder/blob/c2422158b93c6615959f8f1d7df4d76a14d05746/ViewRecorder/ImageSequenceToVideoConverter.swift
https://github.com/nakajijapan/teiten/blob/de25b7431ee668ef7457837819bddbd5e270ace8/teiten/Classes/MovieMakerWithImages.swift
https://github.com/MingleChang/camera_swift/blob/778e16e79f700cba970ba899d3e16fc9b8cad3ad/camera_swift/Common/MingleChang/MCImagesToVideo.swift

https://github.com/apple/swift-evolution/blob/master/proposals/0022-objc-selectors.md

## UISaveVideoAtPathToSavedPhotosAlbum

how to add UISaveVideoAtPathToSavedPhotosAlbum feature 
[https://github.com/deege/deegeu-ios-swift-video-camera/blob/master/deegeu-ios-swift-video-camera/ViewController.swift](github)
maybe in future releases will be added or use this plugin [https://gitlab.com/romanvolkov/VideoToGalleryPlugin](VideoToGalleryPlugin)

## License

MIT
