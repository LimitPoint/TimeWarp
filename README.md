![TimeWarp](https://www.limit-point.com/assets/images/TimeWarp.jpg)
# TimeWarp
## Variably scales video in time domain

This project implements a method that variably scales video and audio in the time domain. This means that the time intervals between video and audio samples are variably scaled along the timeline of the video.

Learn more about *variably* scaling video files from our [in-depth blog post](https://www.limit-point.com/blog/2022/time-warp).

Variable time scaling is interpreted as a function on the unit interval [0,1] that specifies the instantaneous time scale factor at each time in the video, with video time mapped to the unit interval with division by its duration. It will be referred to as the instantaneous time scale function. The values `v` of the instantaneous time scale function will contract or expand [infinitesimal] time intervals `dt` variably across the duration of the video as `v` * `dt`.

In this way the absolute time scale at any particular time `t` is the sum of all infinitesimal time scaling up to that time, or the [definite integral] of the instantaneous scaling function from `0` to `t`.

The associated Xcode project implements a [SwiftUI] app for macOS and iOS that variably scales video files stored on your device or iCloud. 

A default video file is provided to set the initial state of the app. 

After a video is imported it is displayed in the [VideoPlayer] where it can be viewed, along with its variably scaled counterpart.

Select the scaling type and its parameters using sliders and popup menu.

## Classes

The project is comprised of the same classes as [ScaleVideo] but modified for variably scaling with [definite integration]:

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

2. **frameRate: Int32** - The desired frame rate of the scaled video. Specify 0 for variable rate.

3. **destination: String** - The path of the scaled video file.

4. **integrator: Closure** - A function that is the definite integral of the instantaneous time scale function on the unit interval [0,1].

5. **progress: Closure** - A handler that is periodically executed to send progress images and values.

6. **completion: Closure** - A handler that is executed when the operation has completed to send a message of success or not.

The *ScaleVideoApp.swift* file contains sample code can be run in the `init()` method to exercise the method. 

The samples generate files into the *Documents* folder.

Run the app on the Mac and navigate to the Documents folder using the *Go to Documents* button, or use *Go to Folder...* from the *Go* menu in the Finder using the paths to the generated videos that will be printed in the Xcode log view. 

The `integralTests` series of examples uses numerical integration of various instantaneous time scaling functions for the integrator:

```swift
// iterate all tests:
let _ = IntegralType.allCases.map({ integralTests(integralType: $0) })
```

The `antiDerivativeTests` series of examples uses the antiderivative of various instantaneous time scaling functions for the integrator:

```swift
let _ = AntiDerivativeType.allCases.map({ antiDerivativeTests(antiDerivativeType: $0) })
```

#### Antiderivative Examples

Since the app code described in our [in-depth blog post](https://www.limit-point.com/blog/2022/time-warp) is itself an example of using numerical integration to compute time scaling only antiderivative examples are given here.

Three different time scaling functions are defined by their antiderivatives:

```swift
enum AntiDerivativeType: CaseIterable {
    case constantDoubleRate
    case constantHalfRate
    case variableRate
}

func antiDerivativeTests(antiDerivativeType:AntiDerivativeType) {
    
    var filename:String
    
    switch antiDerivativeType {
        case .constantDoubleRate:
            filename = "constantDoubleRate.mov"
        case .constantHalfRate:
            filename = "constantHalfRate.mov"
        case .variableRate:
            filename = "variableRate.mov"
    }
    
    func antiDerivative(_ t:Double) -> Double {
        
        var value:Double
        
        switch antiDerivativeType {
            case .constantDoubleRate:
                value = t / 2
            case .constantHalfRate:
                value = 2 * t
            case .variableRate:
                value = t * t / 2
        }
        
        return value
    }
    
    let fm = FileManager.default
    let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    let destinationPath = docsurl.appendingPathComponent(filename).path
    let scaleVideo = ScaleVideo(path: kDefaultURL.path, frameRate: 30, destination: destinationPath, integrator: antiDerivative, progress: { p, _ in
        print("p = \(p)")
    }, completion: { result, error in
        print("result = \(String(describing: result))")
    })
    
    scaleVideo?.start()
}
```

Run with:

```swift
let _ = AntiDerivativeType.allCases.map({ antiDerivativeTests(antiDerivativeType: $0) })
```

#### Example 1

The integrator is the antiderivative: 

s(t) = t/2

The instantaneous time scaling function is: 

s`(t) = 1/2

In terms of integrals:

 ∫ s'(t) dt = ∫ 1/2 dt = t/2

So time is locally scaled by 1/2 uniformly and the resulting video **constantDoubleRate.mov** plays uniformly at double the original rate.

#### Example 2

The integrator is the antiderivative: 

s(t) = 2 t

The instantaneous time scaling function is: 

s`(t) = 2

In terms of integrals:

 ∫ s'(t) dt = ∫ 2 dt = 2 t

So time is locally scaled by 2 uniformly and the resulting scaled video **constantHalfRate.mov** plays uniformly at half the original rate.


#### Example 3

The integrator is the antiderivative: 

s(t) = s(t) = t^2/2

The instantaneous time scaling function is: 

s'(t) = t

In terms of integrals:

 ∫ s'(t) dt = ∫ t dt = t^2/2

So time is locally scaled at a variable rate `t` and the resulting scaled video **variableRate.mov** plays at a variable rate that starts fast and slows to end at normal speed.

[App]: https://developer.apple.com/documentation/swiftui/app
[ScaleVideo]: https://www.limit-point.com/blog/2022/scale-video/
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
[infinitesimal]: https://en.wikipedia.org/wiki/Infinitesimal
[definite integral]: https://en.wikipedia.org/wiki/Integral
[antiderivative]: https://en.wikipedia.org/wiki/Antiderivative
[derivative]: https://en.wikipedia.org/wiki/Derivative
[definite integration]: https://developer.apple.com/documentation/accelerate/quadrature
[quadrature]: https://developer.apple.com/documentation/accelerate/quadrature
