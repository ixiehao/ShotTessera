import Foundation

enum FrameSelection {
    static func histogramDistance(_ lhs: [Float], _ rhs: [Float]) -> Float {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 1 }
        return zip(lhs, rhs).reduce(0) { $0 + abs($1.0 - $1.1) } / 2
    }

    static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    static func sceneRanges(in frames: [FrameDescriptor], threshold: Float = 0.22) -> [Range<Int>] {
        guard !frames.isEmpty else { return [] }
        var ranges: [Range<Int>] = []
        var start = 0

        for index in 1..<frames.count {
            let previous = frames[index - 1]
            let current = frames[index]
            let changedEnough = histogramDistance(previous.histogram, current.histogram) >= threshold
            let hasRoom = current.time - frames[start].time >= 0.7
            if changedEnough && hasRoom {
                ranges.append(start..<index)
                start = index
            }
        }
        ranges.append(start..<frames.count)
        return ranges
    }

    static func chooseFrames(from frames: [FrameDescriptor], count: Int) -> [FrameDescriptor] {
        guard count > 0, !frames.isEmpty else { return [] }
        let pool = frames.filter(\.isUsable)
        // A grid of black or excessively blurry cards is not a useful storyboard.
        // The analyzer turns this empty result into a clear user-facing error.
        guard !pool.isEmpty else { return [] }
        let ranges = sceneRanges(in: pool)
        var sceneWinners = ranges.compactMap { range in
            pool[range].max { $0.qualityScore < $1.qualityScore }
        }

        // A short video may have fewer cuts than requested grid cells. Add the best
        // candidate from each time bucket so that the output still tells its story.
        if sceneWinners.count < count {
            let start = pool.first?.time ?? 0
            let end = pool.last?.time ?? start
            let span = max(0.001, end - start)
            for bucket in 0..<count {
                let lower = start + span * Double(bucket) / Double(count)
                let upper = start + span * Double(bucket + 1) / Double(count)
                if let candidate = pool
                    .filter({ $0.time >= lower && ($0.time < upper || bucket == count - 1) })
                    .max(by: { $0.qualityScore < $1.qualityScore }) {
                    sceneWinners.append(candidate)
                }
            }
        }

        var unique: [FrameDescriptor] = []
        for candidate in sceneWinners.sorted(by: { $0.time < $1.time }) {
            let isDuplicate = unique.contains {
                isVisualDuplicate($0, candidate, strict: true)
            }
            if !isDuplicate { unique.append(candidate) }
        }

        if unique.count < count {
            let orderedExtras = pool.sorted { $0.qualityScore > $1.qualityScore }
            for candidate in orderedExtras where unique.count < count {
            let isDuplicate = unique.contains {
                    isVisualDuplicate($0, candidate, strict: true)
                }
                if !isDuplicate { unique.append(candidate) }
            }
        }

        // A requested sheet must never render empty cells just because a video
        // contains a single long shot. Fill remaining slots from evenly distributed
        // time buckets, relaxing only visual-duplication rules—not black/blur checks.
        if unique.count < count {
            unique.append(contentsOf: relaxedBucketFill(from: pool, current: unique, count: count))
        }

        guard unique.count > count else { return unique.sorted { $0.time < $1.time } }
        return evenlySpaced(unique.sorted { $0.time < $1.time }, count: count)
    }

    static func evenlySpaced(_ frames: [FrameDescriptor], count: Int) -> [FrameDescriptor] {
        guard count > 0, frames.count > count else { return frames }
        if count == 1 {
            return [frames[frames.count / 2]]
        }
        return (0..<count).map { slot in
            let position = Double(slot) * Double(frames.count - 1) / Double(count - 1)
            return frames[Int(position.rounded())]
        }
    }

    private static func isVisualDuplicate(_ lhs: FrameDescriptor, _ rhs: FrameDescriptor, strict: Bool) -> Bool {
        if abs(lhs.time - rhs.time) < (strict ? 0.35 : 0.08) { return true }
        let hamming = hammingDistance(lhs.fingerprint, rhs.fingerprint)
        let histDistance = histogramDistance(lhs.histogram, rhs.histogram)
        if hamming < (strict ? 7 : 3) { return true }
        // Average hashes alone can miss same-stage frames with small motion. Combine
        // them with histogram distance for a less brittle near-duplicate signal.
        return hamming < (strict ? 18 : 8) && histDistance < (strict ? 0.035 : 0.012)
    }

    private static func relaxedBucketFill(
        from pool: [FrameDescriptor],
        current: [FrameDescriptor],
        count: Int
    ) -> [FrameDescriptor] {
        guard let first = pool.first, let last = pool.last else { return [] }
        let span = max(0.001, last.time - first.time)
        var output: [FrameDescriptor] = []
        var occupied = current

        for bucket in 0..<count where occupied.count < count {
            let lower = first.time + span * Double(bucket) / Double(count)
            let upper = first.time + span * Double(bucket + 1) / Double(count)
            let candidates = pool
                .filter { $0.time >= lower && ($0.time < upper || bucket == count - 1) }
                .sorted { $0.qualityScore > $1.qualityScore }
            if let choice = candidates.first(where: { candidate in
                !occupied.contains(where: { isVisualDuplicate($0, candidate, strict: false) })
            }) ?? candidates.first {
                if !occupied.contains(where: { $0.id == choice.id }) {
                    output.append(choice)
                    occupied.append(choice)
                }
            }
        }

        // In extremely short clips several buckets may map to the same sample. Use
        // the remaining usable timestamps before accepting any repeat.
        for candidate in pool.sorted(by: { $0.qualityScore > $1.qualityScore }) where occupied.count < count {
            if !occupied.contains(where: { $0.id == candidate.id }) {
                output.append(candidate)
                occupied.append(candidate)
            }
        }
        return output
    }
}
