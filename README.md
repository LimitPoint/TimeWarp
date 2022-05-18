---
modified: 2022-05-18
title: TimeWarp
subtitle: Create an app to variably time scale video
github: LimitPoint/TimeWarp
tags: iOS macOS swiftui accelerate quadrature vdsp avfoundation
---
Variably speed up or slow down the rate of play of video across its timeline.
<!--more-->
# TimeWarp

*(This document is a draft!)*

This project implements a method that variably scales video and audio in the time domain. This means that the time intervals between video and audio samples are variably scaled along the timeline of the video.

A discussion about *uniformly* scaling video files is in the [ScaleVideo] blog post from which this project is derived. 

Variable time scaling is interpreted as a function on the unit interval [0,1] that specifies the instantaneous time scale factor at each time in the video, with video time mapped to the unit interval with division by its duration. It will be referred to as the instantaneous time scale function. The values `v` of the instantaneous time scale function will contract or expand [infinitesimal] time intervals variably across the duration of the video.

In this way the absolute time scale at any particular time `t` is the sum of all infinitesimal time scaling up to that time, or the [definite integral] of the instantaneous scaling function from `0` to `t`.

The associated Xcode project implements a [SwiftUI] app for macOS and iOS that variably scales video files stored on your device or iCloud. 

A default video file is provided to set the initial state of the app. 

After a video is imported it is displayed in the [VideoPlayer] where it can be viewed, along with its variably scaled counterpart.

Select the scaling type and its parameters using sliders and popup menu.

<a name='classes'></a>
# Classes

The project is comprised of:

1. [ScaleVideoApp](#scale-video-app) - The [App] for import, scale and export.
2. [ScaleVideoObservable](#scale-video-observable) - An [ObservableObject] that manages the user interaction to scale and play video files.
3. [ScaleVideo](#scale-video) - The [AVFoundation], [vDSP] and [Quadrature] code that reads, scales and writes video files.

<a name='scale-video-app'></a>
## 1. ScaleVideoApp 
[Back to Classes](#classes)

The user interface of this app is very similar to [ScaleVideo] with three new user interface items:

<a name='new-UI'></a>
### New UI
1. [Scale Function:](#choose-scaling-function) Popup menu for choosing an instantaneous time scale function.
2. [Modifier:](#choose-modifer) Additional slider to pick a *modifier* parameter for that function, if applicable.
3. [Plot:](#animated-plot) PlotView for visualizing the current time scaling function.

More specifically:

<a name='choose-scaling-function'></a>
#### 1. Popup menu for choosing an instantaneous time scale function.
[Back to New UI](#new-UI)

Variable scaling is defined by a function on the unit interval, called the instantaneous time scale function, that specifies the local scaling factor at each point in the video.

The app provides several [built-in time scale functions] defined by an enumeration: 

```swift
enum ScaleFunctionType: String, CaseIterable, Identifiable {
    case doubleSmoothstep = "Double Smooth Step"
    case triangle = "Triangle"
    case cosine = "Cosine"
    case taperedCosine = "Tapered Cosine"
    case constant = "Constant"
    case power = "Power"
    var id: Self { self }
}
```
The current scaling function is stored in the property of observable object `ScaleVideoObservable`:

```swift
@Published var scalingType:ScaleFunctionType = .doubleSmoothstep
```

And selected from a popup menu:

```swift
Picker("Scaling", selection: $scaleVideoObservable.scalingType) {
    ForEach(ScaleFunctionType.allCases) { scalingType in
        Text(scalingType.rawValue.capitalized)
    }
}
```

The [built-in time scale functions] are defined in a new file named *UnitFunctions.swift* along with other mathematical functions for plotting and integration.

The time scale functions have two associated parameters called `factor` and `modifier`. 

The `factor` [Slider] sets the same `ScaleVideoObservable` property as in [ScaleVideo]:

```swift
@Published var factor:Double = 1.5 // 0.1 to 2
```

And is set by the same slider control:

```swift
Slider(
    value: $scaleVideoObservable.factor,
    in: 0.1...2
) {
    Text("Factor")
} minimumValueLabel: {
    Text("0.1")
} maximumValueLabel: {
    Text("2")
} onEditingChanged: { editing in
    isEditing = editing
}
Text(String(format: "%.2f", scaleVideoObservable.factor))
    .foregroundColor(isEditing ? .red : .blue)
```

In [ScaleVideo] the `factor` is the uniform scaling factor across the whole video. In this project `factor` has an interpretation that depends on the scaling function chosen. 


<a name='choose-modifer'></a>
#### 2. Additional slider to pick a *modifier* parameter for that function, if applicable.


A general parameter named `modifier` is also provided as a slider and whose usage depends on the time scale function. 

One of the [built-in time scale functions], the `constant` function, do not use the `modifier` so it is defined to be invisible using the [SwiftUI] `opacity` modifier when the current time scale function is set to the `constant` function:

```swift
Group {
    Slider(
        value: $scaleVideoObservable.modifier,
        in: 0.1...1
    ) {
        Text("Modifier")
    } minimumValueLabel: {
        Text("0.1")
    } maximumValueLabel: {
        Text("1")
    } onEditingChanged: { editing in
        isEditing = editing
    }
    Text(String(format: "%.2f", scaleVideoObservable.modifier))
        .foregroundColor(isEditing ? .red : .blue) 
}
.opacity((scaleVideoObservable.scalingType != .constant ? 1 : 0))
.animation(.easeIn)
```

<a name='built-in-time-scale-functions'></a>
### Instantaneous Time Scaling Functions

Here are the built-in time scaling functions defined in the file *UnitFunctions.swift*. Use the scaling type popup menu to switch among them and see the effects of changing the `factor` and `modifier` parameters.

**Constant Function:** 

![Constant](http://www.limit-point.com/assets/images/TimeWarp_Constant.jpg)

In the `constant` function the `factor` takes on its previous meaning in [ScaleVideo] as a uniform time scale factor across the video:

```swift
func constant(_ t:Double, factor:Double) -> Double {
    return factor
}
```

In use the `factor` is the constant value:

```swift
scalingFunction = {t in constant(t, factor: self.factor)}
```

**Triangle Function:** 

![Triangle](http://www.limit-point.com/assets/images/TimeWarp_Triangle.jpg)

The `triangle` function, a piecewise function of lines:

```swift
func triangle(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.8) -> Double
```

The plot of this function is a triangle with a *peak* specified by the `to` argument, and a *base* specified by the `from` argument. 

When it is used :

```swift
scalingFunction = {t in triangle(t, from: 1, to: self.factor, range: c-w...c+w) }
```

In the case of the `triangle` function the `to` argument is set to the value of the `factor` slider and the `modifier` is used define the width of the base of the triangle, defined by a [ClosedRange] `range`:

```swift
let c = 1/2.0
let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
scalingFunction = {t in triangle(t, from: 1, to: self.factor, range: c-w...c+w) }
```

**Cosine Function:** 

![Cosine](http://www.limit-point.com/assets/images/TimeWarp_Cosine.jpg)

In the `cosine` function the `factor` is its amplitude:

```swift
func cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    factor * cos(12 * modifier * .pi * t) + 1
}
```

In use:

```swift
scalingFunction = {t in cosine(t, factor: self.factor, modifier: self.modifier) }
```

**Tapered Cosine Function:** 

![TaperedCosine](http://www.limit-point.com/assets/images/TimeWarp_TaperedCosine.jpg)

This is a function that uses a [smoothstep] function to transition between a `constant` functions and a `cosine` function.

```swift
func tapered_cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    1 + (cosine(t, factor:factor, modifier:modifier) - 1) * smoothstep_on(0, 1, t)
}
```

In use:

```swift
scalingFunction = {t in tapered_cosine(t, factor: self.factor, modifier: self.modifier) }
```

**Power Function** 

![Power](http://www.limit-point.com/assets/images/TimeWarp_Power.jpg)

The `factor` is the exponent of the variable:

```swift
func power(_ t:Double, factor:Double, modifier:Double) -> Double {
    return 2 * modifier * pow(t, factor)
}
```

In use:

```swift
scalingFunction = {t in power(t, factor: self.factor, modifier: self.modifier) }
```

**Double Smoothstep Function** 

![DoubleSmoothStep](http://www.limit-point.com/assets/images/TimeWarp_DoubleSmoothStep.jpg)

This is also a piecewise function made with constant and [smoothstep] functions:

```swift
func double_smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.4) -> Double
```

As in the `triangle` function when it is used the `to` argument is set to the value of the `factor` slider:

```swift
scalingFunction = {t in double_smoothstep(t, from: 1, to: self.factor, range: c-w...c+w) }
```

<a name='animated-plot'></a>
#### 3. PlotView for visualizing the current time scaling function.
[Back to New UI](#new-UI)

The new `PlotView` provides a graphical plot of the curve illustrating the current time scale function, animates the effect of changes to the parameters `factor` and `modifier` on its shape, and includes an animated timeline position indicator that is synced to the video player time.

The `ScaleVideoObservable` handles generating the [Path] using various functions defined in the `UnitFunctions` file.

The path is stored in the published property for updates:

```swift
@Published var scalingPath
```

And drawn in the view with `stroke`:

```swift
scaleVideoObservable.scalingPath
    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
    .scaleEffect(CGSize(width: 0.9, height: 0.9))
```

The plot is updated in response to changes such as:

```swift
$factor.sink { _ in
    DispatchQueue.main.async {
        self.updatePath()
    }
    
}
.store(in: &cancelBag)

$modifier.sink { _ in
    DispatchQueue.main.async {
        self.updatePath()
    }
    
}
.store(in: &cancelBag)
```

The plot has a caption that lists the maximum and minimum values plotted for the instantaneous time scaling function (which are not necessarily the maximum and minimum of the function itself since the plot is a sampling). 

The caption also displays the expected duration of the time warped video. 

```swift
Text("Time Scale on [0,1] to [\(String(format: "%.2f", scaleVideoObservable.minimum_y)), \(String(format: "%.2f", scaleVideoObservable.maximum_y))]\nExpected Scaled Duration: \(scaleVideoObservable.expectedScaledDuration)")
    .font(.caption)
    .padding()
```

The time scaling function may take on negative values as long as the cumulative scale factor, computed as a definite integral, is not negative.

<a name='scale-video-observable'></a>
## 2. ScaleVideoObservable
[Back to Classes](#classes)

The observable object of this app is very similar to [ScaleVideo] with two new features:

<a name='new-features'></a>
#### New Features
1. [Integrator:](#integrator) Define the definite integral of the instantaneous time scale function currently chosen.
2. [Plotter:](#plotter) Manage the plot of the current time scaling function.

Both of these features make use of a new enumeration identifying the [built-in time scale functions]:

```swift
enum ScaleFunctionType: String, CaseIterable, Identifiable {
    case doubleSmoothstep = "Double Smooth Step"
    case triangle = "Triangle"
    case cosine = "Cosine"
    case taperedCosine = "Tapered Cosine"
    case constant = "Constant"
    case power = "Power"
    var id: Self { self }
}
```

More specifically:

<a name='integrator'></a>
### 1. Define the definite integral of the instantaneous time scale function currently chosen.
[Back to New Features](#new-features)

As in [ScaleVideo] scaling is performed by the `scale` method that creates and runs a `ScaleVideo` object.

The `ScaleVideo` initializer `init`:

```swift
init?(path : String, frameRate: Int32, destination: String, integrator:@escaping (Double) -> Double, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void)
```

Arguments:

1. **path: String** - The path of the video file to be scaled.

2. **frameRate: Int32** - The desired frame rate of the scaled video. 

3. **destination: String** - The path of the scaled video file.

4. **integrator: Closure** - A function that is the definite integral of the instantaneous time scale function on the unit interval [0,1].

5. **progress: Closure** - A handler that is periodically executed to send progress images and values.

6. **completion: Closure** - A handler that is executed when the operation has completed to send a message of success or not.

The integrator can be defined as definite integrals or, equivalently, using antiderivatives. That's due to the [Fundamental Theorem of Calculus] which states:

![Fundamental Theorem of Calculus](http://www.limit-point.com/assets/images/TimeWarp_FundamentalTheoremOfCalculus_2nd_Form.jpg)

Example usage is provided in the code defining the integrator as definite integrals or, equivalently, using antiderivatives.

Read the discussion in the [mathematical justification](#mathematical-justification) below for more about how integration for time scaling works.

<a name='scale-video-differences'></a>
#### Differences with [ScaleVideo]:

1. The `desiredDuration` named argument was removed.
2. A new argument named `integrator` has been added.

Previously the desired duration of the scaled video was determined by the selected scale factor, multiplying the video duration in seconds by the factor:

```swift
let desiredDuration:Float64 = asset.duration.seconds * self.factor
```

Variable scaling is performed using the instantaneous time scale function instead. 

As noted in the introduction this is achieved by considering the values of the scaling function as the instantaneous scaling factor at every time of the video. And that leads to the interpretation of scale factors as integration.

The `integrator` is defined in the `ScaleVideoObservable` in terms of the [built-in time scale functions] as follows:

```swift
func integrator(_ t:Double) -> Double {
    
    var value:Double?
    
    switch scalingType {
        case .doubleSmoothstep:
            let c = 1/4.0
            let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
            value = integrate_double_smoothstep(t, from: 1, to: self.factor, range: c-w...c+w)
        case .triangle:
            let c = 1/2.0
            let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
            value = integrate_triangle(t, from: 1, to: self.factor, range: c-w...c+w)
        case .cosine:
            value = integrate(t, integrand: { t in 
                cosine(t, factor: self.factor, modifier: self.modifier)
            })
        case .taperedCosine:
            value = integrate(t, integrand: { t in 
                tapered_cosine(t, factor: self.factor, modifier: self.modifier)
            })
        case .constant:
            value = integrate(t, integrand: { t in 
                constant(t, factor: self.factor)
            })
        case .power:
            value = integrate(t, integrand: { t in 
                power(t, factor: self.factor, modifier: self.modifier)
            })
    } 
    
    return value ?? 1
}
```

The `integrator` is then used by the `ScaleVideo` class to perform time scaling with the new method `timeScale`:

```swift
func timeScale(_ t:Double) -> Double?
{     
    var resultValue:Double?
    
    resultValue = integrator(t/videoDuration)
    
    if let r = resultValue {
        resultValue = r * videoDuration
    }
    
    return resultValue
}
```

In particular this is how the expected duration of the scaled video can always be obtained:

```swift
func updateExpectedScaledDuration() {
    
    let assetDurationSeconds = AVAsset(url: videoURL).duration.seconds
    
    let scaleFactor = integrator(1)
    
    expectedScaledDuration = secondsToString(secondsIn: scaleFactor * assetDurationSeconds)
}
```

The time scale factor for the whole video is the integration of the time scale function over the whole interval [0,1]. Then we multiply the original video duration by that factor to get the expected duration. 

<a name='mathematical-justification'></a>
#### Mathematical Justification:

The scaling function `s(t)` is defined on the unit interval [0,1] and used as a scale factor on the video using a linear mapping that divides time by the duration of the video `D`: The scale factor at video time `t` is `s(t/D)`.

Recall that integration of a function `f(x)` on an interval `[a,b]` can be imagined as a limit of a series of summations, each called a [Riemann sum], by dividing the interval into a partition of smaller sub-intervals that cover `[a,b]` and multiplying the width of each sub-interval `dx` by a value of the function `f(x)` in that interval:

![Riemann_sum](http://www.limit-point.com/assets/images/TimeWarp_Riemann_sum.jpg)

So that when the size of the partition is iteratively increased the limit is symbolically written using the integration symbol:

![Integration](http://www.limit-point.com/assets/images/TimeWarp_Integration.jpg)

We apply that idea to the scaling function for video and audio samples: 

The scaled time `T` for a sample at time `t` is then the integral of the scaling function on the interval `[0,t]`: 

Partition the interval [0,t] and for each interval in the partition we scale it by multiplying its duration by a value of the time scaling function in that interval and sum them all up. In the limit as the partition size increases the sum approaches the integral of the time scaling function over that interval. 

The `integrator` closure `(Double)->Double` is that [definite integral].

From the [Fundamental Theorem of Calculus] we know that the value of a definite integral can be determined by the [antiderivative] of the integrand. That is why the `integrator` may be expressed using the antiderivative, as some of the code examples illustrate.

![FundamentalTheoremOfCalculus](http://www.limit-point.com/assets/images/TimeWarp_FundamentalTheoremOfCalculus_2nd_Form.jpg)

However, in this app the `integrator` is calculated using numerical integration provided using [Quadrature] in the [Accelerate] framework. 

Moreover, the integration is not performed in the video time domain, but rather in the unit interval domain where the scaling functions are defined using [Change of Variables] for integration:

![ChangeOfVariables](http://www.limit-point.com/assets/images/TimeWarp_ChangeOfVariables.jpg)

The domain mapping is given by:

![DomainMapping](http://www.limit-point.com/assets/images/TimeWarp_DomainMapping.jpg)

So the integral can be written in the domain of the unit interval, with the left side in the video domain and the right side in the unit interval domain:

![ChangeOfVariablesForDomainMapping](http://www.limit-point.com/assets/images/TimeWarp_ChangeOfVariablesForDomainMapping.jpg)

This explains the calculation in the `timeScale` method previously mentioned:

```swift
func timeScale(_ t:Double) -> Double?
{     
    var resultValue:Double?
    
    resultValue = integrator(t/videoDuration)
    
    if let r = resultValue {
        resultValue = r * videoDuration
    }
    
    return resultValue
}
```

We pass time `t/videoDuration` to the integrator as the upper limit on the integral, and then multiply the result by the `videoDuration`.

<a name='plotter'></a>
### 2. Manage the plot of the current time scaling function.
[Back to New Features](#new-features)

A new property has been added to update the plots of the [built-in time scale functions]:

```swift
@Published var scalingPath = Path()
```

The plot contains an circle indicator overlay whose position on the plot is synchronized with the current play time. This aids in seeing the current value of the time scale function as the scaled video is playing. 

The plot is updated with the following method in response to certain state changes, such as the `factor` or `modifier`, or the video time via a periodic time observer installed on the player:

```swift
func updatePath() {
    
    var scalingFunction:(Double)->Double
    
    switch scalingType {
        case .doubleSmoothstep:
            let c = 1/4.0
            let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
            scalingFunction = {t in double_smoothstep(t, from: 1, to: self.factor, range: c-w...c+w) }
        case .triangle:
            let c = 1/2.0
            let w = (self.modifier == 1 ? c * 0.99 : c * self.modifier)  
            scalingFunction = {t in triangle(t, from: 1, to: self.factor, range: c-w...c+w) }
        case .cosine:
            scalingFunction = {t in cosine(t, factor: self.factor, modifier: self.modifier) }
        case .taperedCosine:
            scalingFunction = {t in tapered_cosine(t, factor: self.factor, modifier: self.modifier) }
        case .constant:
            scalingFunction = {t in constant(t, factor: self.factor)}
        case .power:
            scalingFunction = {t in power(t, factor: self.factor, modifier: self.modifier) }
    }
    
    var currentTime:Double = 0
    if let time = self.currentPlayerTime, let duration = self.currentPlayerDuration {
        currentTime = time / duration
    }
    
    (scalingPath, minimum_y, maximum_y) = path(a: 0, b: 1, time:currentTime, subdivisions: Int(scalingPathViewFrameSize.width), frameSize: scalingPathViewFrameSize, function:scalingFunction)
    
    updateExpectedScaledDuration()
}
```

A [periodic time observer] is added to the player whenever a new one is created for a new URL to play:

```swift
func play(_ url:URL) {
    
    if let periodicTimeObserver = periodicTimeObserver {
        self.player.removeTimeObserver(periodicTimeObserver)
    }
    
    self.player.pause()
    self.player = AVPlayer(url: url)
    
    self.currentPlayerDuration = AVAsset(url: url).duration.seconds
    periodicTimeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: nil) { [weak self] cmTime in
        self?.currentPlayerTime = cmTime.seconds
    }
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) { () -> Void in
        self.player.play()
    }
    
}
```

The updates from the periodic time observer are handled using `sink` publisher:

```swift
$currentPlayerTime.sink { _ in
    DispatchQueue.main.async {
        self.updatePath()
    }
    
}
.store(in: &cancelBag)
```

<a name='scale-video'></a>
## 3. ScaleVideo
[Back to Classes](#classes)

Time scaling is performed by the `ScaleVideo` class on both the video frames and audio samples simultaneously. This class is largely the same as in [ScaleVideo] and this discussion focuses on the differences. 

The changes to the initializer for `ScaleVideo` was discussed [previously here](#scale-video-differences). 

<a name='scale-video-writers'></a>
#### ScaleVideo Writers

#### 1. [Video writer `writeVideoOnQueue`](#write-video-on-queue)

Writes time scaled video frames:

This resampling method implements *upsampling* by repeating frames and *downsampling* by skipping frames of the video to stretch or contract it in time respectively.

#### 2. [Audio writer `writeAudioOnQueue`](#write-audio-on-queue)

Writes time scaled audio samples:

This method is based on the technique developed in the blog [ScaleAudio]. But rather than scale the whole audio file at once, as is done in [ScaleAudio], we implement scaling in a progressive manner where audio is scaled, when it can be, as it is read from the file being scaled. 

<a name='write-video-on-queue'></a>
### 1. Video writer `writeVideoOnQueue`
[Back to ScaleVideo Writers](#scale-video-writers)

The discussion here focuses on how `ScaleVideo` has been altered to support variable time scaling.

The only adjustments for time scaling video frames is made in the method `copyNextSampleBufferForResampling`. 

Recall that previously in this method the presentation times of sample buffers were scaled using the time scale property `timeScaleFactor` as follows:

```swift
presentationTimeStamp = CMTimeMultiplyByFloat64(presentationTimeStamp, multiplier: self.timeScaleFactor)
```

The `timeScaleFactor` was set from the `desiredDuration`:

```swift
self.timeScaleFactor = self.desiredDuration / CMTimeGetSeconds(videoAsset.duration)
```

Now `timeScaleFactor` has been removed from `ScaleVideo` and we use instead the `timeScale` method for scaling time: 

```swift
if let presentationTimeStampScaled = self.timeScale(presentationTimeStamp.seconds) {

   presentationTimeStamp = CMTimeMakeWithSeconds(presentationTimeStampScaled, preferredTimescale: 64000)

...
```

A very important thing to note is that when we convert seconds to a `CMTime` value with `CMTimeMakeWithSeconds` the `preferredTimescale` is set to a high value of `64000`. 

This is important to ensure a rational number with `preferredTimescale` as its denominator is fine grained enough to represent the value with high accuracy. In the case it does not the Xcode log may present a warning of the kind:

<pre>2022-04-12 23:37:58.287225-0400 ScaleVideo[68292:3560687] CMTimeMakeWithSeconds(0.082 seconds, timescale 24): warning: error of -0.040 introduced due to very low timescale</pre>

But more importantly the video may be defective. 

Recall the `timeScale` method uses the `integrator` to scale time:

```swift
func timeScale(_ t:Double) -> Double?
{     
    var resultValue:Double?
    
    resultValue = integrator(t/videoDuration)
    
    if let r = resultValue {
        resultValue = r * videoDuration
    }
    
    return resultValue
}
```

The `timeScale` argument is the presentation time of the current sample buffer.

The method `copyNextSampleBufferForResampling` with these adjustments completes time scaling the video frames:

```swift
func copyNextSampleBufferForResampling(lastPercent:CGFloat) -> CGFloat {
    
    self.sampleBuffer = nil
    
    guard let sampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() else {
        return lastPercent
    }
    
    self.sampleBuffer = sampleBuffer
    
    if self.videoReaderOutput.outputSettings != nil {
        var presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let presentationTimeStampScaled = self.timeScale(presentationTimeStamp.seconds) {
            presentationTimeStamp = CMTimeMakeWithSeconds(presentationTimeStampScaled, preferredTimescale: 64000)
            if let adjustedSampleBuffer = sampleBuffer.setTimeStamp(time: presentationTimeStamp) {
                self.sampleBufferPresentationTime = presentationTimeStamp
                self.sampleBuffer = adjustedSampleBuffer
            }
            else {
                self.sampleBuffer = nil
            }
        }
        else {
            self.sampleBuffer = nil
        }
    }
    
    ...
}
```

Variably scaling the audio samples is a bit more work as we will see next.

<a name='write-audio-on-queue'></a>
### 2. Audio writer `writeAudioOnQueue`
[Back to ScaleVideo Writers](#scale-video-writers)

The discussion here focuses on how it has been altered to support variable scaling.

See [ScaleAudio] for basic information on processing audio.

The `ScaleVideo` class has a new property `sampelRate` which stores the sample rate of the video audio, the value is set in the initializer using the AudioStreamBasicDescription:

```swift
var sampleRate:Float64
```

The sample rate is essential to the time scaling method described here.


# Conclusion

Building upon previous work in [ScaleVideo] we have an app that can variably scale video and audio in an innumerable number of ways by providing various `integrator` functions.

The ScaleVideo initializer `init`:

```swift
init?(path : String, frameRate: Int32, destination: String, integrator:@escaping (Double) -> Double, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void)
```

Arguments:

1. **path: String** - The path of the video file to be scaled.

2. **frameRate: Int32** - The desired frame rate of the scaled video. 

3. **destination: String** - The path of the scaled video file.

4. **integrator: Closure** - A function that is the definite integral of the instantaneous time scale function on the unit interval [0,1].

5. **progress: Closure** - A handler that is periodically executed to send progress images and values.

6. **completion: Closure** - A handler that is executed when the operation has completed to send a message of success or not.

Example usage is provided in the code defining the integrator as definite integrals or, equivalently, using antiderivatives.

In *ScaleVideoApp.swift* try uncommenting the code below in `init()`. Run the app on the Mac and navigate to the apps Documents folder using the 'Go to Documents' button in the Mac app, or 'Go to Folder...' from the 'Go' menu in the Finder (The path to the generated videos appear in the Xcode log view). There you will find the generated video samples. 

This `integralTests` series of examples uses integration of instantaneous scaling functions for the integrator:

```swift
// iterate all tests:
let _ = IntegralType.allCases.map({ integralTests(integralType: $0) })
```

This `antiDerivativeTests` series of examples uses the antiderivative of instantaneous scaling functions for the integrator:

```swift
let _ = AntiDerivativeType.allCases.map({ antiDerivativeTests(antiDerivativeType: $0) })
```

In the first example the integrator is the antiderivative s(t) = t/2. The derivative of s(t) = t/2 is the instantaneous scaling function s'(t) = 1/2 so time is locally scaled by 1/2 uniformly, and the resulting video plays uniformly at 2x the normal rate.

For s(t) = 2 * t, with instantaneous scaling function s'(t) = 2, time is locally doubled uniformly, and then the rate of play of the scaled video is 1/2 the original rate of play. 

For s(t) = t * t/2, with instantaneous scaling function s'(t) = t, time is locally scaled at a variable rate `t` from 0 to 1, and the video rate varies from fast to normal play.

[App]: https://developer.apple.com/documentation/swiftui/app
[ScaleVideo]: http://www.limit-point.com/blog/2022/scale-video/
[ObservableObject]: https://developer.apple.com/documentation/combine/observableobject
[Button]: https://developer.apple.com/documentation/swiftui/button
[Slider]: https://developer.apple.com/documentation/swiftui/slider
[Picker]: https://developer.apple.com/documentation/swiftui/picker
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
[ClosedRange]: https://developer.apple.com/documentation/swift/closedrange
[Path]: https://developer.apple.com/documentation/swiftui/path
[built-in time scale functions]: #built-in-time-scale-functions
[smoothstep]: https://en.wikipedia.org/wiki/Smoothstep
[Riemann sum]: https://en.wikipedia.org/wiki/Riemann_sum
[Fundamental Theorem of Calculus]: https://en.wikipedia.org/wiki/Fundamental_theorem_of_calculus
[Accelerate]: https://developer.apple.com/accelerate/
[Change of Variables]: https://en.wikipedia.org/wiki/Integration_by_substitution
[periodic time observer]:https://developer.apple.com/documentation/avfoundation/avplayer/1385829-addperiodictimeobserver
