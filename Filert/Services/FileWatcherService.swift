import Foundation
import CoreServices

class FileWatcherService {
    private var eventStream: FSEventStreamRef?
    var onChange: ((String, Date) -> Void)?

    func start(paths: [String]) {
        stop()
        guard !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            flags
        )

        guard let stream = eventStream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    deinit { stop() }
}

private let fsEventCallback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, _ in
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FileWatcherService>.fromOpaque(info).takeUnretainedValue()

    let paths = Unmanaged<NSArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
    let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))

    for (path, flag) in zip(paths, flags) {
        let modified = flag & UInt32(kFSEventStreamEventFlagItemModified) != 0
        let created  = flag & UInt32(kFSEventStreamEventFlagItemCreated)  != 0
        let renamed  = flag & UInt32(kFSEventStreamEventFlagItemRenamed)  != 0
        let isDir    = flag & UInt32(kFSEventStreamEventFlagItemIsDir)    != 0

        guard (modified || created || renamed) && !isDir else { continue }
        guard !path.hasSuffix(".DS_Store") && !path.contains("/.") else { continue }

        DispatchQueue.main.async {
            watcher.onChange?(path, Date())
        }
    }
}
