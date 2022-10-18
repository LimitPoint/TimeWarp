//
//  PlotView.swift
//  ScaleVideo
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp/
//
//  Created by Joseph Pagliaro on 5/1/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct CurrentSizeReader: ViewModifier {
    @Binding var currentSize: CGSize
    @State var lastSize:CGSize = .zero // prevents too much view updating if value is stored in a published property of a View's observable object. 
    
    var geometryReader: some View {
        GeometryReader { proxy in
            Color.clear
                .execute {
                    if lastSize != proxy.size {
                        currentSize = proxy.size
                        lastSize = currentSize
                    }
                }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(geometryReader)
    }
}

struct CurrentFrameReader: ViewModifier {
    @Binding var currentFrame: CGRect
    
    var coordinateSpace:CoordinateSpace
    
    var geometryReader: some View {
        GeometryReader { proxy in
            Color.clear
                .execute {
                    currentFrame = proxy.frame(in: coordinateSpace)
                    print("currentFrame = \(currentFrame)")
                }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(geometryReader)
    }
}

extension View {
    func execute(_ closure: @escaping () -> Void) -> Self {
        DispatchQueue.main.async {
            closure()
        }
        return self
    }
    
    func currentSizeReader(currentSize: Binding<CGSize>) -> some View {
        modifier(CurrentSizeReader(currentSize: currentSize))
    }
    
    func currentFrameReader(currentFrame: Binding<CGRect>, coordinateSpace:CoordinateSpace) -> some View {
        modifier(CurrentFrameReader(currentFrame: currentFrame, coordinateSpace: coordinateSpace))
    }
}

struct PlotView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
        
    var body: some View {
        
        VStack {
            ZStack {
                scaleVideoObservable.scalingPath
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .scaleEffect(CGSize(width: 0.9, height: 0.9))
            }
            .currentSizeReader(currentSize: $scaleVideoObservable.scalingPathViewFrameSize)
            
            Text("Time Scale on [0,1] to [\(String(format: "%.2f", scaleVideoObservable.minimum_y)), \(String(format: "%.2f", scaleVideoObservable.maximum_y))]\nExpected Scaled Duration: \(scaleVideoObservable.expectedScaledDuration)")
                .font(.caption)
                .padding()
            
            if scaleVideoObservable.fps.rawValue == 0 {
                Text("\(scaleVideoObservable.scalingType.rawValue) @ Any FPS")
            }
            else {
                Text("\(scaleVideoObservable.scalingType.rawValue) @ \(scaleVideoObservable.fps.rawValue) FPS")
            }
             
        }
        
    }
}

struct PlotView_Previews: PreviewProvider {
    static var previews: some View {
        PlotView(scaleVideoObservable: ScaleVideoObservable())
    }
}
