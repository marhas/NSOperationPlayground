/**
 NSOperations

 OperationQueue: a queue that executes the operations. Support for priority and serial/parallel execution.
 Selected interesting properties of a queue:
 isSuspended
 maxOperationCount (defaults to reasonable value for current device/hardware)

 Operation: a single shot operation that can be in any of the following state: ready, executing, finished, cancelled
 An operation can be set to depend on other operations, in which case they will start executing as soon as the other operation is finished.
 An operation can have a priority which determines the order of execution among tasks in an OperationQueue
 For serial tasks it's very simple, async tasks gets a little more complicated.
 An operation can be cancelled, which only sets the isCancelled flag on the operation. It is up to the implementation to check this flag and abort gracefully.


- Block Operations or adding a block directly to operationQueue.addOperation { ... }
- Create synchronous operation by subclassing - CalcOperation
- show waitUntilFinished
- Show priorities and maxConcurrentOperations
- Show dependencies
- Show completion blocks

- Creating async operations is harder and require emitting KVO notifications for isExecuting, isFinished
 */

import UIKit
import Foundation
import PlaygroundSupport

var str = "Hello, playground"

PlaygroundPage.current.needsIndefiniteExecution = true

let operationQueue = OperationQueue()
operationQueue.maxConcurrentOperationCount = 2

let calcOperation1 = CalcOperation1(startValue: 123)
let calcOperation2 = CalcOperation2(startValue: 123)
let calcOperation3 = CalcOperation3(startValue: 123)
let calcOperation4 = CalcOperation4(startValue: 123)
calcOperation3.queuePriority = .high
//calcOperation4.addDependency(calcOperation3)

operationQueue.addOperations([
    calcOperation1,
    calcOperation2,
    calcOperation3,
    calcOperation4,
    BlockOperation {
        Thread.sleep(forTimeInterval: 2)
        print("Block operation completed")
    }
    ], waitUntilFinished: false)
print("All operations finished.")



class CalcOperation: Operation {

    var result: Int?

    fileprivate let startValue: Int

    init(startValue: Int) {
        self.startValue = startValue
    }
}

class CalcOperation1: CalcOperation {
    override func main() {
        print("\(String(describing: type(of: self))) running")
        Thread.sleep(forTimeInterval: 4)
        result = startValue + 2
        print("\(String(describing: type(of: self))) finished with result: \(result!). Calculation completed \(Date())")
    }
}

class CalcOperation2: CalcOperation {
    override func main() {
        print("\(String(describing: type(of: self))) running")
        Thread.sleep(forTimeInterval: 6)
        result = startValue + 3
        print("\(String(describing: type(of: self))) finished with result: \(result!). Calculation completed \(Date())")
    }
}

class CalcOperation3: CalcOperation {
    override func main() {
        print("\(String(describing: type(of: self))) running")
        Thread.sleep(forTimeInterval: 8)
        result = startValue + 4
        print("\(String(describing: type(of: self))) finished with result: \(result!). Calculation completed \(Date())")
    }
}

class CalcOperation4: CalcOperation {
    override func main() {
        print("\(String(describing: type(of: self))) running")
        Thread.sleep(forTimeInterval: 8)
        result = startValue + 5
        print("\(String(describing: type(of: self))) finished with result: \(result!). Calculation completed \(Date())")
    }
}

/** Note how an operation that executes asynchronous code completes immediately, like this one for example */
class NetworkOperation: Operation {

    let url: URL
    var downloadTask: URLSessionDownloadTask?

    init(url: URL) {
        self.url = url
    }

    override func main() {
        print("\(String(describing: type(of: self))) running")
        let session = URLSession.shared
        downloadTask = session.downloadTask(with: url) { (url, response, error) in
            print("Download finished")
            if let error = error {
                print(" with error: \(error)")
            }
        }
        downloadTask?.resume()
        print("Network operation completes")
    }
}

let networkOperation1 = NetworkOperation(url: URL(string: "https://sample-videos.com/img/Sample-jpg-image-5mb.jpg")!)
let networkOperation2 = NetworkOperation(url: URL(string: "https://sample-videos.com/img/Sample-jpg-image-10mb.jpg")!)
let networkOperation3 = NetworkOperation(url: URL(string: "https://sample-videos.com/img/Sample-jpg-image-30mb.jpg")!)

//operationQueue.addOperations([
//    networkOperation1,
//    networkOperation2
//    ], waitUntilFinished: false)
//print("All operations finished.")


/** Supporting asynchronous operations is a bit trickier, but can be made a little easier by using a base class like this.  */
class AsyncOperation: Operation {

    var error: Error?
    private var cancellationObserver: NSKeyValueObservation?

    override init() {
        super.init()

        cancellationObserver = observe(\.isCancelled, options: [.initial, .new]) { [weak self] (kvo, change) in
            guard let self = self else { return }
            if change.newValue == true {
                self.handleCancellation()
                self._executing = false
                self._finished = true
            }
        }
    }

    private var _executing: Bool = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }

    override open var isExecuting: Bool {
        get {
            return _executing
        }
        set {
            _executing = newValue
        }
    }

    private var _finished: Bool = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
            if _finished {
                let errorString: String
                if let error = error {
                    errorString = " (with error: \(error.localizedDescription))"
                } else {
                    errorString = ""
                }
                print("Operation \(type(of: self)) finished" + errorString)
            }
        }
    }

    override open var isFinished: Bool {
        get {
            return _finished
        }
        set {
            _finished = newValue
        }
    }

    override open var isAsynchronous: Bool {
        return true
    }

    override func start() {
        _executing = true
        _finished = false
        run()
    }

    func run() {
        fatalError("You need to override the run method in a subclass")
    }

    func finish() {
        _executing = false
        _finished = true
    }

    private func _handleCancellation() {
        handleCancellation()
        finish()
    }

    func handleCancellation() {
        // Default implementation does nothing
    }
}

/** The same network request but with asynchronous support */
class AsyncNetworkOperation: AsyncOperation {
    let url: URL
    var downloadTask: URLSessionDownloadTask?

    init(url: URL) {
        self.url = url
    }

    override func run() {
        print("\(String(describing: type(of: self))) running asynchronously.")
        let session = URLSession.shared
        downloadTask = session.downloadTask(with: url) { (url, response, error) in
            print("Download finished")
            if let error = error {
                print(" with error: \(error)")
            }
            self.finish()
        }
        if !isCancelled {
            downloadTask?.resume()
        } else {
            print("Not starting download since task already cancelled.")
        }
        print("Network operation returns")
    }

    override func handleCancellation() {
        print("Cancelling AsyncNetworkOperation")
        downloadTask?.cancel()
    }
}

/** This demos dependencies for async operations and cancellation of long running tasks */
let asyncNetworkOperation1 = AsyncNetworkOperation(url: URL(string: "https://sample-videos.com/img/Sample-jpg-image-5mb.jpg")!)
let asyncNetworkOperation2 = AsyncNetworkOperation(url: URL(string: "https://sample-videos.com/img/Sample-jpg-image-10mb.jpg")!)
let allDownloadsFinishedOperation = BlockOperation {
    print("All downloads finished!")
}

allDownloadsFinishedOperation.addDependency(asyncNetworkOperation1)
allDownloadsFinishedOperation.addDependency(asyncNetworkOperation2)
operationQueue.addOperations([
    asyncNetworkOperation1,
    asyncNetworkOperation2,
    allDownloadsFinishedOperation
    ], waitUntilFinished: false)
Thread.sleep(forTimeInterval: 3)
asyncNetworkOperation2.cancel()
