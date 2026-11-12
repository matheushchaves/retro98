import Foundation

/// Copies one item (file, folder or package) with copyfile(3): clones on APFS, keeps links,
/// extended attributes and permissions, and never writes over anything (COPYFILE_EXCL).
enum FileCopy {
    enum Result: Equatable {
        case done, cancelled, failed(String)
    }

    static let flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_CLONE | COPYFILE_EXCL | COPYFILE_NOFOLLOW_SRC)

    /// `onBytes` gets each increment of copied bytes (a cloned file counts whole when it finishes).
    /// A failed or cancelled copy leaves a partial destination; the caller removes it.
    static func copy(_ source: URL, to destination: URL, control: OperationControl, onBytes: @escaping (Int64) -> Void) -> Result {
        let context = Context(control: control, onBytes: onBytes)
        guard let state = copyfile_state_alloc() else { return .failed(reason(errno: ENOMEM)) }
        defer { copyfile_state_free(state) }
        let callback: copyfile_callback_t = { what, stage, state, source, _, context in
            guard let context else { return COPYFILE_CONTINUE }
            return Unmanaged<Context>.fromOpaque(context).takeUnretainedValue().handle(what: what, stage: stage, state: state, source: source)
        }
        copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CB), unsafeBitCast(callback, to: UnsafeRawPointer.self))
        copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CTX), Unmanaged.passUnretained(context).toOpaque())
        let result = withExtendedLifetime(context) { copyfile(source.path, destination.path, state, flags) }
        if result == 0 { return .done }
        if control.isCancelled { return .cancelled }
        return .failed(reason(errno: context.error ?? errno))
    }

    static func reason(errno code: Int32) -> String {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code)).localizedDescription
    }

    /// Size of one item as lstat sees it (links are not followed); folders count as 0.
    static func size(ofPath path: String) -> Int64 {
        var info = stat()
        guard lstat(path, &info) == 0, (info.st_mode & S_IFMT) != S_IFDIR else { return 0 }
        return Int64(info.st_size)
    }

    /// Total bytes of everything inside `item` (the item itself when it is a file).
    static func totalSize(of item: URL, control: OperationControl) -> Int64 {
        var total = size(ofPath: item.path)
        guard let enumerator = FileManager.default.enumerator(atPath: item.path) else { return total }
        while let relative = enumerator.nextObject() as? String, !control.isCancelled {
            total += size(ofPath: item.path + "/" + relative)
        }
        return total
    }

    private final class Context {
        let control: OperationControl
        let onBytes: (Int64) -> Void
        var reportedForFile: Int64 = 0
        var error: Int32?

        init(control: OperationControl, onBytes: @escaping (Int64) -> Void) {
            self.control = control
            self.onBytes = onBytes
        }

        func handle(what: Int32, stage: Int32, state: copyfile_state_t?, source: UnsafePointer<CChar>?) -> Int32 {
            if stage == COPYFILE_ERR {
                error = errno
                return COPYFILE_QUIT
            }
            if control.isCancelled { return COPYFILE_QUIT }
            switch (what, stage) {
            case (COPYFILE_RECURSE_FILE, COPYFILE_START):
                reportedForFile = 0
            case (COPYFILE_COPY_DATA, COPYFILE_PROGRESS):
                var copied: off_t = 0
                if let state, copyfile_state_get(state, UInt32(COPYFILE_STATE_COPIED), &copied) == 0, copied > reportedForFile {
                    onBytes(Int64(copied) - reportedForFile)
                    reportedForFile = Int64(copied)
                }
            case (COPYFILE_RECURSE_FILE, COPYFILE_FINISH):
                let size = source.map { FileCopy.size(ofPath: String(cString: $0)) } ?? 0
                if size > reportedForFile { onBytes(size - reportedForFile) }
                reportedForFile = 0
            default:
                break
            }
            return COPYFILE_CONTINUE
        }
    }
}
