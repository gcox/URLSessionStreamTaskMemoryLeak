///
///  Created by George Cox on 8/10/23.
///

import SwiftUI

struct ContentView: View {
  enum ActiveStreamer {
    case none
    case cfNetwork
    case urlSession
  }

  @State var activeStreamer: ActiveStreamer = .none
  let streamRunner = StreamRunner(readSize: 65536)

  var streamWithCFNetworkTitle: String {
    switch activeStreamer {
    case .cfNetwork:
      return "Restart"
    default:
      return "Start"
    }
  }

  var streamWithURLSessionTitle: String {
    switch activeStreamer {
    case .urlSession:
      return "Restart"
    default:
      return "Start"
    }
  }

  var body: some View {
    VStack(spacing: 50) {
      VStack {
        Text("CFNetwork Streamer")
        HStack {
          Button(streamWithCFNetworkTitle) {
            streamRunner.runCFNetworkStreamer()
            activeStreamer = .cfNetwork
          }
          Button("Read") {
            streamRunner.readBytes()
          }
          .disabled(activeStreamer != .cfNetwork)
        }
      }

      VStack {
        Text("URLSession Streamer")
        HStack {
          Button(streamWithURLSessionTitle) {
            streamRunner.runURLSessionStreamer()
            activeStreamer = .urlSession
          }
          Button("Read") {
            streamRunner.readBytes()
          }
          .disabled(activeStreamer != .urlSession)
        }
      }

      Divider()

      Button("Close Current Streamer") {
        streamRunner.closeCurrentStreamer()
        activeStreamer = .none
      }
      .disabled(activeStreamer == .none)
    }
    .padding()
  }
}

class StreamRunner {
  /// This URL points to an episode of the Apple Events (audio) podcast.
  static let url = URL(string: "https://rss.art19.com/episodes/24e71470-cdba-464c-863a-46e849a278ed.mp3?rss_browser=BAhJIgtSZXN0ZWQGOgZFVA%3D%3D--6aeae0cc246a2d8c58ecf7afa0b42ce9a2ee7ea7")!

  let url = StreamRunner.url
  let readSize: Int

  var cfNetworkStreamer: CFNetworkStreamer?
  var urlSessionStreamer: URLSessionStreamer?

  init(readSize: Int) {
    self.readSize = readSize
  }

  func closeCurrentStreamer() {
    cfNetworkStreamer?.stop()
    cfNetworkStreamer = nil

    urlSessionStreamer?.stop {
      self.urlSessionStreamer = nil
    }
  }

  func runCFNetworkStreamer() {
    closeCurrentStreamer()

    cfNetworkStreamer = .init(url: url, readSize: readSize)
    cfNetworkStreamer?.start()
  }

  func runURLSessionStreamer() {
    closeCurrentStreamer()

    urlSessionStreamer = .init(url: url, readSize: readSize)
    urlSessionStreamer?.start()
  }

  func readBytes() {
    cfNetworkStreamer?.readBytes()
    urlSessionStreamer?.readBytes()
  }
}

