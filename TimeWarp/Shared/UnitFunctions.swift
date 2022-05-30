//
//  UnitFunctions.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 4/29/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import Foundation
import Accelerate
import AVFoundation

/*
 Functions defined on unit interval [0,1].
*/

// unitmap and mapunit are inverses
// map [x0,y0] to [0,1]
func unitmap(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return (x - x0)/(x1 - x0)
}

func unitmap(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return unitmap(r.lowerBound, r.upperBound, x)
}

// map [0,1] to [x0,x1] 
func mapunit(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return mapunit(r.lowerBound, r.upperBound, x)
}

func mapunit(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return (x1 - x0) * x + x0
}

// flips function on [0,1]
func unitflip(_ x:Double) -> Double {
    return 1 - x
}

// MARK: Unit Functions

func constant(_ k:Double) -> Double {
    return k
}

func line(_ x1:Double, _ y1:Double, _ x2:Double, _ y2:Double, x:Double) -> Double {
    return y1 + (x - x1) * (y2 - y1) / (x2 - x1)
}

func smoothstep(_ x:Double) -> Double {
    return -2 * pow(x, 3) + 3 * pow(x, 2)
}

func smoothstep_flip(_ x:Double) -> Double {
    return smoothstep(unitflip(x)) 
}

func smoothstep_on(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return smoothstep(unitmap(x0, x1, x)) 
}

func smoothstep_on(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return smoothstep(unitmap(r, x)) 
}

func smoothstep_flip_on(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return smoothstep(unitflip(unitmap(x0, x1, x)))
}

func smoothstep_flip_on(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return smoothstep(unitflip(unitmap(r, x)))
}

func smoothstep_centered_on(_ c:Double, _ w:Double, _ x:Double) -> Double {
    return smoothstep(unitmap(c-w, c+w, x)) 
}

func smoothstep_flip_centered_on(_ c:Double, _ w:Double, _ x:Double) -> Double {
    return smoothstep(unitflip(unitmap(c-w, c+w, x)))
}

// MARK: Scaling functions to integrate and plot
    
func double_smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.4) -> Double {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 0.5 else {
        return 0
    }
    
    var value:Double = 0
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0-range.upperBound
    let r4 = 1.0-range.upperBound...1.0-range.lowerBound
    let r5 = 1.0-range.lowerBound...1.0
    
    if r1.contains(t) {
        value = constant(from)
    }
    else if r2.contains(t) {
        value = mapunit(from, to, smoothstep_on(r2, t))
    }
    else if r3.contains(t) {
        value = constant(to)
    }
    else if r4.contains(t) {
        value = mapunit(from, to, smoothstep_flip_on(r4, t))
    }
    else if r5.contains(t) {
        value = constant(from)
    }
    
    return value
}

func triangle(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.8) -> Double {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return 0
    }
    
    var value:Double = 0
    
    let center = (range.lowerBound + range.upperBound) / 2.0
    
    let r1 = 0...range.lowerBound
    let r2 = range.lowerBound...center
    let r3 = center...range.upperBound
    let r4 = range.upperBound...1.0
    
    if r1.contains(t) {
        value = constant(from)
    }
    else if r2.contains(t) {
        value = line(range.lowerBound, from, center, to, x: t)
    }
    else if r3.contains(t) {
        value = line(range.upperBound, from, center, to, x: t)
    }
    else if r4.contains(t) {
        value = constant(from)
    }
    
    return value
}

func cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    factor * (cos(12 * modifier * .pi * t) + 1) + (factor / 2)
}

func tapered_cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    1 + (cosine(t, factor:factor, modifier:modifier) - 1) * smoothstep_on(0, 1, t)
}

func constant(_ t:Double, factor:Double) -> Double {
    return factor
}

func power(_ t:Double, factor:Double, modifier:Double) -> Double {
    return 2 * modifier * pow(t, factor) + (modifier / 2)
}

// MARK: Integration

let quadrature = Quadrature(integrator: Quadrature.Integrator.nonAdaptive, absoluteTolerance: 1.0e-8, relativeTolerance: 1.0e-2)

func integrate(_ t:Double, integrand:(Double)->Double) -> Double? {
    
    var resultValue:Double?
    
    let result = quadrature.integrate(over: 0...t, integrand: { t in
        integrand(t)
    })
    
    do {
        try resultValue =  result.get().integralResult
    }
    catch {
        print("integrate error")
    }
    
    return resultValue
}

func integrate(_ r:ClosedRange<Double>, integrand:(Double)->Double) -> Double? {
    
    var resultValue:Double?
    
    let result = quadrature.integrate(over: r, integrand: { t in
        integrand(t)
    })
    
    do {
        try resultValue =  result.get().integralResult
    }
    catch {
        print("integrate error")
    }
    
    return resultValue
}

func integrate_double_smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.4) -> Double? {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 0.5 else {
        return nil
    }
    
    var value:Double?
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0-range.upperBound
    let r4 = 1.0-range.upperBound...1.0-range.lowerBound
    let r5 = 1.0-range.lowerBound...1.0
    
    guard let value1 = integrate(r1, integrand: { t in
        constant(from)
    }) else {
        return nil
    }
    
    guard let value2 = integrate(r2, integrand: { t in
        mapunit(from, to, smoothstep_on(r2, t))
    }) else {
        return nil
    }
    
    guard let value3 = integrate(r3, integrand: { t in
        constant(to)
    }) else {
        return nil
    }
    
    guard let value4 = integrate(r4, integrand: { t in
        mapunit(from, to, smoothstep_flip_on(r4, t))
    }) else {
        return nil
    }
    
    if r1.contains(t) {
        value = integrate(r1.lowerBound...t, integrand: { t in
            constant(from)
        })
    }
    else if r2.contains(t) {
        if let value2 = integrate(r2.lowerBound...t, integrand: { t in
            mapunit(from, to, smoothstep_on(r2, t))
        }) {
            value = value1 + value2
        }
    }
    else if r3.contains(t) {
        if let value3 = integrate(r3.lowerBound...t, integrand: { t in
            constant(to)
        }) {
            value = value1 + value2 + value3
        }
    }
    else if r4.contains(t) {
        if let value4 = integrate(r4.lowerBound...t, integrand: { t in
            mapunit(from, to, smoothstep_flip_on(r4, t))
        }) {
            value = value1 + value2 + value3 + value4
        }
    }
    else if r5.contains(t) {
        if let value5 = integrate(r5.lowerBound...t, integrand: { t in
            constant(from)
        }) {
            value = value1 + value2 + value3 + value4 + value5
        }
    }
    
    return value
}

func integrate_triangle(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.8) -> Double? {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return 0
    }
    
    var value:Double?
    
    let center = (range.lowerBound + range.upperBound) / 2.0
    
    let r1 = 0...range.lowerBound
    let r2 = range.lowerBound...center
    let r3 = center...range.upperBound
    let r4 = range.upperBound...1.0
    
    guard let value1 = integrate(r1, integrand: { t in
        constant(from)
    }) else {
        return nil
    }
    
    guard let value2 = integrate(r2, integrand: { t in
        line(range.lowerBound, from, center, to, x: t)
    }) else {
        return nil
    }
    
    guard let value3 = integrate(r3, integrand: { t in
        line(range.upperBound, from, center, to, x: t)
    }) else {
        return nil
    }
    
    if r1.contains(t) {
        value = integrate(r1.lowerBound...t, integrand: { t in
            constant(from)
        })
    }
    else if r2.contains(t) {
        if let value2 = integrate(r2.lowerBound...t, integrand: { t in
            line(range.lowerBound, from, center, to, x: t)
        }) {
            value = value1 + value2
        }
    }
    else if r3.contains(t) {
        if let value3 = integrate(r3.lowerBound...t, integrand: { t in
            line(range.upperBound, from, center, to, x: t)
        }) {
            value = value1 + value2 + value3
        }
    }
    else if r4.contains(t) {
        if let value4 = integrate(r4.lowerBound...t, integrand: { t in
            constant(from)
        }) {
            value = value1 + value2 + value3 + value4
        }
    }
    
    return value
}

// MARK: Plotting
func plot_on(_ N:Int, _ x0:Double, _ x1:Double, function:(Double) -> Double) -> [Double] {
    var result:[Double] = []
    let delta = 1.0 / Double(N)
    let lower = Int((x0 / delta).rounded(FloatingPointRoundingRule.up))
    let upper = Int((x1 / delta).rounded(FloatingPointRoundingRule.down))
    if upper >= lower {
        result = (lower...upper).map { i in
            function(Double(i)/Double(N))
        }
    }
    return result
}

func plot_centered_on(_ N:Int, _ c:Double, _ w:Double, function:(Double) -> Double) -> [Double] {
    return plot_on(N, c-w, c+w, function: function)
}

func path(a:Double, b:Double, time:Double, subdivisions:Int, frameSize:CGSize, function:((Double) -> Double) = smoothstep(_:)) -> (Path, Double, Double) {
    
    guard subdivisions > 0 else {
        return (Path(), 0, 0)
    }
    
    var plot_x:[Double] = []
    var plot_y:[Double] = []
    
    let values = plot_on(subdivisions, a, b, function: function)
    
    var minimum_y:Double = values[0]
    var maximum_y:Double = values[0]
    
    let minimum_x:Double = a
    let maximum_x:Double = b
    
    let N = values.count-1
    
    for i in 0...N {
        
        let x = a + (Double(i) * ((b - a) / Double(N)))
        let y = values[i]
        
        let value = y
        if value < minimum_y {
            minimum_y = value
        }
        if value > maximum_y {
            maximum_y = value
        }
        
        plot_x.append(x)
        plot_y.append(value)
    }
    
    let frameRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
    
    // center a rectangle for plotting in the view frame rectangle
    let plotRect = AVMakeRect(aspectRatio: CGSize(width: (maximum_x - minimum_x), height: (maximum_y - minimum_y)), insideRect: frameRect)
    
    let x0 = plotRect.origin.x
    let y0 = plotRect.origin.y
    let W = plotRect.width
    let H = plotRect.height
    
    func tx(_ x:Double) -> Double {
        if maximum_x == minimum_x {
            return x0 + W
        }
        return (x0 + W * ((x - minimum_x) / (maximum_x - minimum_x)))
    }
    
    func ty(_ y:Double) -> Double {
        if maximum_y == minimum_y {
            return frameSize.height - (y0 + H)
        }
        return frameSize.height - (y0 + H * ((y - minimum_y) / (maximum_y - minimum_y))) // subtract from frameSize.height to flip coordinates
    }
    
    // map points into plotRect using linear interpolation
    plot_x = plot_x.map( { x in
        tx(x)
    })
        
    plot_y = plot_y.map( { y in
        ty(y)
    })
    
    let path = Path { path in
        
        path.move(to: CGPoint(x: plot_x[0], y: plot_y[0]))
        
        for i in 1...N {
            let x = plot_x[i]
            let y = plot_y[i]
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        let t = a + time * (b - a)
        let xTime = tx(t)
        let yTime = ty(function(t))
        path.addEllipse(in: CGRect(x: xTime-3, y: yTime-3, width: 6, height: 6))
        
    }
    
    return (path, minimum_y, maximum_y)
}

