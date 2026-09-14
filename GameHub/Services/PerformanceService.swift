import Foundation
import QuartzCore
import Darwin

struct PerformanceSample: Identifiable, Sendable {
    let id: UUID = UUID()
    let timestamp: Date
    let fps: Double
    let frameTimeMS: Double
    let cpuUsage: Double
    let memoryUsageMB: Double
}

enum PerformanceMetric: String, CaseIterable, Sendable {
    case fps
    case frameTime
    case cpuUsage
    case memoryUsage
    case runtimeStatus
}

@MainActor
final class PerformanceMonitor: ObservableObject {
    @Published private(set) var currentFPS: Double = 0
    @Published private(set) var currentFrameTimeMS: Double = 0
    @Published private(set) var cpuUsagePercent: Double = 0
    @Published private(set) var memoryUsageMB: Double = 0
    @Published private(set) var isRunning = false

    private var lastFrameTime: CFTimeInterval?
    private var frameCount: Int = 0
    private var lastReportingTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink?

    private let sampleInterval: CFTimeInterval = 0.5

    func start() {
        guard displayLink == nil else { return }
        lastFrameTime = nil
        frameCount = 0
        isRunning = true

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    func snapshot() -> PerformanceSample {
        PerformanceSample(
            timestamp: Date(),
            fps: currentFPS,
            frameTimeMS: currentFrameTimeMS,
            cpuUsage: cpuUsagePercent,
            memoryUsageMB: memoryUsageMB
        )
    }

    @objc private func tick(link: CADisplayLink) {
        guard lastFrameTime != nil else {
            lastFrameTime = link.targetTimestamp
            lastReportingTime = link.timestamp
            return
        }

        let now = link.timestamp
        frameCount += 1

        if now - lastReportingTime >= sampleInterval {
            let elapsed = now - lastReportingTime
            let fps = Double(frameCount) / elapsed
            let frameTime = (elapsed / Double(max(frameCount, 1))) * 1000.0

            currentFPS = fps
            currentFrameTimeMS = frameTime
            cpuUsagePercent = hostCPUUsage()
            memoryUsageMB = currentMemoryUsageMB()

            frameCount = 0
            lastReportingTime = now
        }

        lastFrameTime = link.targetTimestamp
    }

    private func hostCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000
        let system = Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000
        return user + system
    }

    private func currentMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }
}
