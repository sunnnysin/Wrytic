import CoreGraphics

extension ShapeClassifier {
    struct CurvedArrowFit {
        let tail: CGPoint
        let head: CGPoint
        let control: CGPoint
    }

    /// Finds an arrow shaft + arrowhead in an open stroke: the two
    /// farthest-apart points in the stroke are taken as the shaft's ends
    /// (robust to a pencil doubling back to draw the head without lifting),
    /// then every point is checked against the line between them. A shape
    /// only counts as an arrow if most points sit close to that line (a
    /// real shaft) while a cluster of outliers sits near just one end (the
    /// arrowhead) — outliers scattered across both ends or through the
    /// middle mean it's a scribble, not an arrow.
    static func detectArrow(points: [CGPoint]) -> (tail: CGPoint, head: CGPoint)? {
        guard points.count >= 6, let (endA, endB) = farthestPair(in: points) else { return nil }

        let flare = flareCounts(points: points, endA: endA, endB: endB)
        guard flare.nearA + flare.nearB >= arrowMinimumFlaredPoints, flare.nearLine >= points.count / 3 else {
            return nil
        }
        return flareEnds(flare, endA: endA, endB: endB)
    }

    /// Like `detectArrow`, but for a shaft that bows in one smooth
    /// direction instead of running straight. `detectArrow`'s flare check
    /// projects points onto the straight tail-head chord, which a curved
    /// shaft's own ink deviates from throughout — not just at the
    /// arrowhead — so it can no longer tell "this is the flare" from
    /// "this is just the curve" apart. Detecting the flare by proximity to
    /// the two candidate endpoints instead sidesteps the chord entirely:
    /// an arrowhead is drawn with extra ink packed into a small area near
    /// one end (the flanks), which shows up as a point-density spike near
    /// that endpoint regardless of how the shaft bends to get there.
    static func detectCurvedArrow(points: [CGPoint]) -> CurvedArrowFit? {
        guard points.count >= 8, let (endA, endB) = farthestPair(in: points) else { return nil }
        let span = distance(endA, endB)
        guard span > 0, let (tail, head) = flareEndsByDensity(points: points, endA: endA, endB: endB, span: span) else {
            return nil
        }

        let flareRadius = span * flareProximityRatio
        guard let bend = shaftBend(points: points, tail: tail, head: head, excluding: flareRadius) else { return nil }
        let diagonal = distance(tail, head)
        guard bend.maxDeviation >= diagonal * lineDeviationThresholdRatio else { return nil }
        let minCount = min(bend.positiveCount, bend.negativeCount)
        let maxCount = max(bend.positiveCount, bend.negativeCount)
        guard minCount == 0 || maxCount >= 3 * minCount else { return nil }

        return CurvedArrowFit(tail: tail, head: head, control: bendControlPoint(tail: tail, head: head, bend: bend))
    }

    private static func flareEndsByDensity(
        points: [CGPoint],
        endA: CGPoint,
        endB: CGPoint,
        span: CGFloat
    ) -> (tail: CGPoint, head: CGPoint)? {
        let radius = span * flareProximityRatio
        let densityA = points.filter { distance($0, endA) <= radius }.count
        let densityB = points.filter { distance($0, endB) <= radius }.count
        let minimumFlareDensity = arrowMinimumFlaredPoints + 2
        if densityA >= densityB * Int(arrowFlareDominanceRatio), densityA >= minimumFlareDensity {
            return (tail: endB, head: endA)
        }
        if densityB >= densityA * Int(arrowFlareDominanceRatio), densityB >= minimumFlareDensity {
            return (tail: endA, head: endB)
        }
        return nil
    }

    private static func flareEnds(
        _ flare: FlareCounts,
        endA: CGPoint,
        endB: CGPoint
    ) -> (tail: CGPoint, head: CGPoint)? {
        if flare.nearA > flare.nearB * Int(arrowFlareDominanceRatio), flare.nearA >= arrowMinimumFlaredPoints {
            return (tail: endB, head: endA)
        }
        if flare.nearB > flare.nearA * Int(arrowFlareDominanceRatio), flare.nearB >= arrowMinimumFlaredPoints {
            return (tail: endA, head: endB)
        }
        return nil
    }

    private struct ShaftBend {
        let maxDeviation: CGFloat
        /// The actual point of greatest deviation from the tail-head
        /// chord, and its own fractional position (0=tail, 1=head) along
        /// that chord — not a reconstructed value forced to the chord's
        /// midpoint. A curved arrow's bend is very often *not* centered
        /// (a quick gesture typically hooks sharply near one end rather
        /// than bowing symmetrically through the middle), so the control
        /// point derived from this must reproduce the bend at its real
        /// position, not always at t=0.5 — otherwise every curved arrow
        /// gets reshaped into the same generic symmetric bow regardless
        /// of where it actually bent.
        let point: CGPoint
        let fraction: CGFloat
        let positiveCount: Int
        let negativeCount: Int
    }

    /// Points within `excluding` of either `tail` or `head` are skipped —
    /// that's the arrowhead's own flare ink (see `flareEndsByDensity`),
    /// which would otherwise pollute the curve's own bend measurement.
    private static func shaftBend(points: [CGPoint], tail: CGPoint, head: CGPoint, excluding: CGFloat) -> ShaftBend? {
        let dx = head.x - tail.x
        let dy = head.y - tail.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return nil }

        var maxDeviation: CGFloat = 0
        var pointAtMax = tail
        var fractionAtMax: CGFloat = 0.5
        var positiveCount = 0
        var negativeCount = 0
        for point in points {
            guard distance(point, tail) > excluding, distance(point, head) > excluding else { continue }
            let fraction = ((point.x - tail.x) * dx + (point.y - tail.y) * dy) / lengthSquared
            let projected = CGPoint(x: tail.x + fraction * dx, y: tail.y + fraction * dy)
            let cross = (point.x - tail.x) * dy - (point.y - tail.y) * dx
            let deviation = distance(point, projected)
            if cross > 0 { positiveCount += 1 } else if cross < 0 { negativeCount += 1 }
            if deviation > maxDeviation {
                maxDeviation = deviation
                pointAtMax = point
                fractionAtMax = fraction
            }
        }
        return ShaftBend(
            maxDeviation: maxDeviation,
            point: pointAtMax,
            fraction: fractionAtMax,
            positiveCount: positiveCount,
            negativeCount: negativeCount
        )
    }

    /// Solves for the quadratic Bézier control point that makes the curve
    /// pass through `bend.point` at `bend.fraction`, rather than always
    /// assuming the bend sits at t=0.5 — see `ShaftBend.point`'s doc
    /// comment for why that assumption was the actual bug.
    private static func bendControlPoint(tail: CGPoint, head: CGPoint, bend: ShaftBend) -> CGPoint {
        let fraction = min(max(bend.fraction, 0.12), 0.88)
        let inverse = 1 - fraction
        let weight = 2 * fraction * inverse
        guard weight > 0 else { return CGPoint(x: (tail.x + head.x) / 2, y: (tail.y + head.y) / 2) }
        return CGPoint(
            x: (bend.point.x - inverse * inverse * tail.x - fraction * fraction * head.x) / weight,
            y: (bend.point.y - inverse * inverse * tail.y - fraction * fraction * head.y) / weight
        )
    }

    /// An open stroke made of a handful of overwhelmingly horizontal or
    /// vertical segments — Notes' "continuous line with 90-degree turns".
    /// Simplifying first (rather than checking raw point-to-point
    /// direction) is what makes this tolerant of natural hand wobble along
    /// each intended-straight segment.
    static func detectOrthogonalPolyline(points: [CGPoint], diagonal: CGFloat) -> [CGPoint]? {
        guard diagonal > 0 else { return nil }
        let simplified = douglasPeucker(points: points, epsilon: diagonal * cornerSimplificationRatio)
        guard simplified.count >= 4 else { return nil }

        for index in 0..<(simplified.count - 1) {
            let start = simplified[index]
            let end = simplified[index + 1]
            let dx = abs(end.x - start.x)
            let dy = abs(end.y - start.y)
            let minDimension = min(dx, dy)
            let maxDimension = max(dx, dy)
            guard maxDimension > 0, minDimension / maxDimension <= orthogonalAlignmentTolerance else { return nil }
        }
        return simplified
    }

    private static func farthestPair(in points: [CGPoint]) -> (CGPoint, CGPoint)? {
        var maxDistance: CGFloat = 0
        var endA = points[0]
        var endB = points[0]
        for firstIndex in 0..<points.count {
            for secondIndex in (firstIndex + 1)..<points.count {
                let candidateDistance = distance(points[firstIndex], points[secondIndex])
                if candidateDistance > maxDistance {
                    maxDistance = candidateDistance
                    endA = points[firstIndex]
                    endB = points[secondIndex]
                }
            }
        }
        guard maxDistance > 0 else { return nil }
        return (endA, endB)
    }

    struct FlareCounts {
        var nearA = 0
        var nearB = 0
        var nearLine = 0
    }

    private static func flareCounts(points: [CGPoint], endA: CGPoint, endB: CGPoint) -> FlareCounts {
        let dx = endB.x - endA.x
        let dy = endB.y - endA.y
        let lengthSquared = dx * dx + dy * dy
        let deviationLimit = distance(endA, endB) * arrowFlareDeviationRatio
        var counts = FlareCounts()
        for point in points {
            let fraction = ((point.x - endA.x) * dx + (point.y - endA.y) * dy) / lengthSquared
            let projected = CGPoint(x: endA.x + fraction * dx, y: endA.y + fraction * dy)
            let deviation = distance(point, projected)
            if deviation <= deviationLimit {
                counts.nearLine += 1
            } else if fraction < 0.35 {
                counts.nearA += 1
            } else if fraction > 0.65 {
                counts.nearB += 1
            }
        }
        return counts
    }
}
