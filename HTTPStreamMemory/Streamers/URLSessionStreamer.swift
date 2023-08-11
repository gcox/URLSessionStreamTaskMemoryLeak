///
///  Created by George Cox on 8/10/23.
///

import Combine
import Foundation

class URLSessionStreamer {
  private let url: URL
  private let readSize: Int
  private lazy var sessionConfiguration: URLSessionConfiguration = {
    let config: URLSessionConfiguration = .ephemeral

    config.allowsCellularAccess = false
    config.allowsConstrainedNetworkAccess = false
    config.allowsExpensiveNetworkAccess = false

    config.timeoutIntervalForRequest = .infinity
    config.timeoutIntervalForResource = .infinity

    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    config.httpShouldSetCookies = false
    config.httpCookieAcceptPolicy = .never
    config.httpCookieStorage = nil
    config.httpShouldUsePipelining = true
    config.httpAdditionalHeaders = nil

    config.urlCache = nil
    config.urlCredentialStorage = nil

    config.networkServiceType = .avStreaming

    return config
  }()

  private lazy var session: URLSession = .init(
    configuration: sessionConfiguration,
    delegate: Delegate { [weak self] in
      self?.streamTask = $0
    },
    delegateQueue: nil
  )

  private var dataTask: URLSessionDataTask?
  private var streamTask: URLSessionStreamTask?

  init(url: URL, readSize: Int) {
    self.url = url
    self.readSize = readSize
  }

  deinit {
    print("URLSessionStreamer: deinit")
  }

  func start() {
    dataTask = session.dataTask(with: URLRequest(url: url))
    dataTask?.resume()
    print("URLSessionStreamer: started")
  }

  func stop(onCompleted: @escaping () -> Void) {
    streamTask?.closeRead()

    (session.delegate as? Delegate)?.onSessionInvalidated { [weak self] in
      self?.streamTask = nil
      self?.dataTask = nil
      onCompleted()
    }
    session.invalidateAndCancel()
  }

  func readBytes() {
    guard let streamTask else {
      return
    }
    streamTask.readData(ofMinLength: 1, maxLength: readSize, timeout: 30, completionHandler: { data, isAtEOS, error in
      if let error {
        print("URLSessionStreamer.Delegate: failed reading bytes: \(error)")
      } else {
        if let data {
          print("URLSessionStreamer.Delegate: read \(data.count) bytes")
        }
        if isAtEOS {
          print("URLSessionStreamer.Delegate: at EOS")
        }
        if data == nil, !isAtEOS {
          print("URLSessionStreamer.Delegate: naw")
        }
      }
    })
  }
}

extension URLSessionStreamer {
  class Delegate: NSObject, URLSessionDataDelegate, URLSessionStreamDelegate, StreamDelegate {
    private let onBecameStreamTask: (URLSessionStreamTask) -> Void

    private var isInvalidated = false
    private var onInvalidated: (() -> Void)?

    init(onBecameStreamTask: @escaping (URLSessionStreamTask) -> Void) {
      self.onBecameStreamTask = onBecameStreamTask
      super.init()
    }

    deinit {
      print("URLSessionStreamer.Delegate: deinit")
    }

    func onSessionInvalidated(_ closure: @escaping () -> Void) {
      if isInvalidated {
        closure()
      } else {
        onInvalidated = closure
      }
    }

    func urlSession(
      _ session: URLSession,
      dataTask: URLSessionDataTask,
      didReceive response: URLResponse,
      completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
      print("URLSessionStreamer.Delegate: Data task received initial response")
      completionHandler(.becomeStream)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
      print("URLSessionStreamer.Delegate: Data task became stream task")
      onBecameStreamTask(streamTask)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      if let error {
        print("URLSessionStreamer.Delegate: Stream task finished with error: \(error)")
      } else {
        print("URLSessionStreamer.Delegate: Stream task finished")
      }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
      if let error {
        print("URLSessionStreamer.Delegate: Session became invalid with error: \(error)")
      } else {
        print("URLSessionStreamer.Delegate: Session became invalid")
      }
      isInvalidated = true
      onInvalidated?()
      onInvalidated = nil
    }
  }
}
