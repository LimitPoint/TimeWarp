![TimeWarp](http://www.limit-point.com/assets/images/TimeWarp.jpg)
# ScaleVideo.swift
## Variably scales video in time domain

Learn more about *uniformly* scaling video files from our [in-depth blog post](https://www.limit-point.com/blog/2022/scale-video) from which this project is derived.

The associated Xcode project implements a [SwiftUI] app for macOS and iOS that variably scales video files stored on your device or iCloud. 

A default video file is provided to set the initial state of the app. 

After a video is imported it is displayed in the [VideoPlayer] where it can be viewed, along with its variably scaled counterpart.

Select the scaling type and its parameters using sliders and popup menu.

## Classes

The project is comprised of the same classes but modified for variably scaling with [definite integration](https://developer.apple.com/documentation/accelerate/quadrature):

1. `ScaleVideoApp` - The [App] for import, scale and export.
2. `ScaleVideoObservable` - An [ObservableObject] that manages the user interaction to scale and play video files.
3. `ScaleVideo` - The [AVFoundation], [vDSP] and [Quadrature] code that reads, scales and writes video files.

### ScaleVideoApp

Videos to scale are imported from Files using [fileImporter] and exported to Files using [fileExporter]. 

The scaling is monitored with a [ProgressView].

The video and scaled video can be played with a [VideoPlayer].

### ScaleVideoObservable

Creates the `ScaleAudio` object to perform the scaling operation and send progress back to the app.

The `URL` of the video to scale is received from the file import operation and, if needed, downloaded with [startDownloadingUbiquitousItem] or security accessed with [startAccessingSecurityScopedResource].

To facilitate exporting using `fileExporter` a [FileDocument] named `VideoDocument` is prepared with a [FileWrapper] created from the [URL] of the scaled video.

### ScaleVideo

Scaling video is performed using [AVFoundation], [vDSP] and [Quadrature].

The ScaleVideo initializer `init`:

```swift
init?(path : String, frameRate: Int32, destination: String, integrator:@escaping (Double) -> Double, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void)
```

Arguments:

1. **path: String** - The path of the video file to be scaled.

2. **frameRate: Int32** - The desired frame rate of the scaled video. 

3. **destination: String** - The path of the scaled video file.

4. **integrator: Closure** - A time scaling function defined on the unit interval [0,1], whose derivitive is the instantaneous time scale factor. 

5. **progress: Closures** - A handler that is periodically executed to send progress images and values.

6. **completion: Closure** - A handler that is executed when the operation has completed to send a message of success or not.

Example usage is provided in the code. 

In ScaleVideoApp.swift try uncommenting the code in `init()`:

```swift
// iterate all tests:
let _ = ScaleFunctionTestType.allCases .map({ testScaleVideo(scaleType: $0) })
```

Run the app on the Mac and navigate to the apps Documents folder using 'Go to Folder...' from the 'Go' menu in the Finder. There you will find the generated video samples. 

Here is another example with the scaling function s(t) = t/2, and kDefaultURL pointing to a video bundle resource. 

The derivitive of s(t) is s'(t) = 1/2 so time is scaled locally halved uniformly, and the resulting video plays uniformly at 2x the normal rate:

```swift
let kDefaultURL = Bundle.main.url(forResource: "DefaultVideo", withExtension: "mov")!
let fm = FileManager.default
let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

let destinationPath = docsurl.appendingPathComponent("2x.mov").path
let scaleVideo = ScaleVideo(path: kDefaultURL.path, frameRate: 30, destination: destinationPath, integrator: {t in t/2}, progress: { p, _ in
    print("p = \(p)")
}, completion: { result, error in
    print("result = \(String(describing: result))")
})

scaleVideo?.start()
```
Other examples include:

s(t) = 2 * t, then s'(t) = 2, time is locally doubled uniformly, and then the rate of play of the scaled video is 1/2 the original rate of play. 

s(t) = t * t/2, then s'(t) = t, time is locally scaled at a variable rate from 0 to 1, and the video rate varies from fast to normal play.


[App]: https://developer.apple.com/documentation/swiftui/app
[ObservableObject]: https://developer.apple.com/documentation/combine/observableobject
[AVFoundation]: https://developer.apple.com/documentation/avfoundation/
[vDSP]: https://developer.apple.com/documentation/accelerate/vdsp
[SwiftUI]: https://developer.apple.com/tutorials/swiftui
[fileImporter]: https://developer.apple.com/documentation/swiftui/form/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)
[fileExporter]: https://developer.apple.com/documentation/swiftui/form/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:)-1srj
[FileDocument]: https://developer.apple.com/documentation/swiftui/filedocument
[FileWrapper]: https://developer.apple.com/documentation/foundation/filewrapper
[URL]: https://developer.apple.com/documentation/foundation/url
[VideoPlayer]: https://developer.apple.com/documentation/avkit/videoplayer
[ProgressView]: https://developer.apple.com/documentation/swiftui/progressview
[startDownloadingUbiquitousItem]: https://developer.apple.com/documentation/foundation/filemanager/1410377-startdownloadingubiquitousitem
[startAccessingSecurityScopedResource]: https://developer.apple.com/documentation/foundation/nsurl/1417051-startaccessingsecurityscopedreso
[Quadrature]: https://developer.apple.com/documentation/accelerate/quadrature
