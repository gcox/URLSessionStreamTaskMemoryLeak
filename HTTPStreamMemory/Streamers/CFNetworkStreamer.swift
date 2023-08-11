///
///  Created by George Cox on 8/10/23.
///

import Foundation

class CFNetworkStreamer {
  private let url: URL
  private let readSize: Int
  private var delegate: Delegate?

  init(url: URL, readSize: Int) {
    self.url = url
    self.readSize = readSize
  }

  deinit {
    print("CFNetworkStreamer: deinit")
  }

  func start() {
    delegate = .init(readSize: readSize)
    delegate?.start(url: url)
    print("CFNetworkStreamer: started")
  }

  func stop() {
    delegate?.stop()
    delegate = nil
    print("CFNetworkStreamer: stopped")
  }

  func readBytes() {
    delegate?.readBytes()
  }
}

extension CFNetworkStreamer {
  class Delegate: NSObject {
    var stream: CFReadStream?
    let readSize: Int

    init(readSize: Int) {
      self.readSize = readSize
      super.init()
    }

    func start(url: URL) {
      let message = CFHTTPMessageCreateRequest(nil, "GET" as CFString, url as CFURL, kCFHTTPVersion1_1).takeRetainedValue()
      self.stream = CFReadStreamCreateForHTTPRequest(nil, message).takeRetainedValue()
      if !CFReadStreamSetProperty(stream, .init(kCFStreamPropertyHTTPShouldAutoredirect), kCFBooleanTrue) {
        print("CFNetworkStreamer.Delegate: could not set kCFStreamPropertyHTTPShouldAutoredirect on stream")
        self.stream = nil
        return
      }

      let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
      CFReadStreamSetProperty(stream, .init(kCFStreamPropertyHTTPProxy), proxySettings)

      if url.scheme == "https" {
        let sslSettings = [
          kCFStreamSSLLevel: kCFStreamSocketSecurityLevelNegotiatedSSL as NSString,
          kCFStreamSSLValidatesCertificateChain: NSNumber(false)
        ] as NSDictionary

        CFReadStreamSetProperty(stream, .init(kCFStreamPropertySSLSettings), sslSettings)
      }

      guard let stream else {
        return
      }

      if !CFReadStreamOpen(stream) {
        self.stream = nil
        print("CFNetworkStreamer.Delegate: could not open stream")
      } else {
        var context = CFStreamClientContext(
          version: 0,
          info: Unmanaged.passUnretained(self).toOpaque(),
          retain: nil,
          release: nil,
          copyDescription: nil
        )

        CFReadStreamSetClient(
          stream,
          CFOptionFlags(
            CFStreamEventType.hasBytesAvailable.rawValue
              | CFStreamEventType.endEncountered.rawValue
              | CFStreamEventType.errorOccurred.rawValue
          ),
          handle,
          &context
        )
        CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), .commonModes)
      }
    }

    func stop() {
      if let stream {
        CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetMain(), .commonModes)
        CFReadStreamClose(stream)
        self.stream = nil
      }
    }

    func stream(_ aStream: CFReadStream, handle eventCode: Stream.Event) {
      switch eventCode {
      case .openCompleted:
        print("CFNetworkStreamer.Delegate: InputStream opened")
      case .endEncountered:
        print("CFNetworkStreamer.Delegate: InputStream end encountered")
      case .errorOccurred:
        print("CFNetworkStreamer.Delegate: InputStream error occurred")
      case .hasBytesAvailable:
        print("CFNetworkStreamer.Delegate: InputStream has bytes available")
      case .hasSpaceAvailable:
        print("CFNetworkStreamer.Delegate: InputStream has space available")
      default:
        print("CFNetworkStreamer.Delegate: InputStream undefined event: \(eventCode.rawValue)")
      }
    }

    func readBytes() {
      guard let stream else {
        return
      }

      let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: readSize)
      let result = CFReadStreamRead(stream, buffer, readSize)

      print("CFNetworkStreamer.Delegate: Bytes read: \(result)")
      buffer.deallocate()
    }
  }
}

private func handle(_ aStream: CFReadStream?, _ event: CFStreamEventType, _ context: UnsafeMutableRawPointer?) {
  guard let s = aStream else {
    return
  }
  let caller = unsafeBitCast(context, to: CFNetworkStreamer.Delegate.self)
  switch event {
  case .hasBytesAvailable:
    caller.stream(s, handle: .hasBytesAvailable)
  case .endEncountered:
    caller.stream(s, handle: .hasBytesAvailable)
  case .errorOccurred:
    caller.stream(s, handle: .hasBytesAvailable)
  default:
    break
  }
}
