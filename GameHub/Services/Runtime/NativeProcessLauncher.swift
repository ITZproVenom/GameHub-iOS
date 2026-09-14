import Foundation
import Darwin

enum NativeProcessLauncher {
    struct Result {
        let status: Int32
        let pid: pid_t
    }

    enum LaunchError: Error, LocalizedError {
        case executableMissing(String)
        case spawnFailed(Int32)
        case waitFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .executableMissing(let path):
                return "Executable not found: \(path)"
            case .spawnFailed(let code):
                return "posix_spawn failed with errno \(code)"
            case .waitFailed(let code):
                return "waitpid failed with errno \(code)"
            }
        }
    }

    @discardableResult
    static func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL?
    ) throws -> Result {
        guard FileManager.default.isExecutableFile(atPath: executable.path)
                || FileManager.default.fileExists(atPath: executable.path) else {
            throw LaunchError.executableMissing(executable.path)
        }

        var argv: [UnsafeMutablePointer<CChar>?] = []
        argv.append(strdup(executable.path))
        for argument in arguments {
            argv.append(strdup(argument))
        }
        argv.append(nil)

        var envp: [UnsafeMutablePointer<CChar>?] = []
        var merged = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            merged[key] = value
        }
        if let workingDirectory {
            merged["PWD"] = workingDirectory.path
        }
        for (key, value) in merged {
            envp.append(strdup("\(key)=\(value)"))
        }
        envp.append(nil)

        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var pid: pid_t = 0
        let spawnResult = argv.withUnsafeMutableBufferPointer { argvBuf in
            envp.withUnsafeMutableBufferPointer { envBuf in
                posix_spawn(
                    &pid,
                    executable.path,
                    nil,
                    nil,
                    argvBuf.baseAddress,
                    envBuf.baseAddress
                )
            }
        }

        guard spawnResult == 0 else {
            throw LaunchError.spawnFailed(spawnResult)
        }

        var status: Int32 = 0
        let waited = waitpid(pid, &status, 0)
        guard waited == pid else {
            throw LaunchError.waitFailed(errno)
        }

        let exitStatus: Int32
        if (status & 0x7f) == 0 {
            exitStatus = (status >> 8) & 0xff
        } else {
            exitStatus = status
        }
        return Result(status: exitStatus, pid: pid)
    }

    static func terminate(names: [String]) {
        for name in names {
            var argv: [UnsafeMutablePointer<CChar>?] = [
                strdup("/usr/bin/killall"),
                strdup(name),
                nil
            ]
            defer { argv.forEach { free($0) } }
            var pid: pid_t = 0
            _ = argv.withUnsafeMutableBufferPointer { buf in
                posix_spawn(&pid, "/usr/bin/killall", nil, nil, buf.baseAddress, nil)
            }
            if pid > 0 {
                var status: Int32 = 0
                _ = waitpid(pid, &status, 0)
            }
        }
    }
}
