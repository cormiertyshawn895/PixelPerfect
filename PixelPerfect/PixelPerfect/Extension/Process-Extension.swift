import Foundation

extension Process {
    static func runNonAdminTaskWait(toolPath: String, arguments: [String]) {
        let task = Process()
        task.launchPath = toolPath
        task.arguments = arguments
        task.launch()
        task.waitUntilExit()
    }

    static func runNonAdminTask(toolPath: String, arguments: [String], attemptInteractive: String? = nil) -> String {
        let task = Process()
        task.launchPath = toolPath
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        var stdIn: Pipe?
        if (attemptInteractive != nil) {
            stdIn = Pipe()
            task.standardInput = stdIn
        }
        task.launch()
        if let attempt = attemptInteractive {
            let response = attempt as NSString
            if let encodedResponse = response.data(using: String.Encoding.utf8.rawValue) {
                stdIn?.fileHandleForWriting.write(encodedResponse)
            }
        }
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? {
            print(output)
            return output
        }
        return ""
    }
}

extension NSObject {
    func syncMainQueue(closure: (() -> ())) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                closure()
            }
        } else {
            closure()
        }
    }
}
