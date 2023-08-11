This project demonstrates an apparant memory leak that occurs when creating a `URLSessionStreamTask` from
a `URLSessionDataTask` without reading from the stream.

A `URLSessionDataTask` can be turned into a `URLSessionStreamTask` like this:

```swift
func urlSession(
  _ session: URLSession,
  dataTask: URLSessionDataTask,
  didReceive response: URLResponse,
  completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
) {
  completionHandler(.becomeStream)
}
```

That will cause the following delegate method to be invoked so you can obtain a
reference to the `URLSessionStreamTask`.

```swift
func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
  // Do something with `streamTask`
}
```

This means data will not be delivered via the `urlSession(:dataTask:didReceive:)` delegate function. Instead,
you need to read data from the stream task using `streamTask.readData(ofMinLength:maxLength:timeout:completionHandler:)`.

For large files, `URLSession` will download chunks of data from the server as necessary as data is consumed from the `URLSessionStreamTask`. In my testing, by the
time the stream task is available, 5-10MB of data has been loaded into private memory by `URLSession`. As you read from the stream task,
that memory gets released. If you read enough data, another chunk of data gets downloaded from the server into memory. So far so good.

Unfortunately, if the stream task is canceled or the session is invalidated prior, whatever data the `URLSession` was hanging onto gets leaked!
If you view the memory graph in Xcode at this point, the session, tasks, and configuration are still alive and have not been deallocated. This is despite
the delegate receiving all the expected calls for the cancelled stream task, the invalidated session, and deinitializing the session's delegate.

The same behavior is observed when reading directly from the `InputStream` that you can obtain by calling `captureStreams` on the `URLSessionStreamTask`.

The only way to avoid this seems to be to read from the stream until the entire file has been downloaded.

---

A `CFNetwork` implementation is included for comparison. This implementation works as expected, doesn't leak memory, and is much closer to a "only download what is necessary" implementation.

---

## To reproduce the issue

1. Click "Start" under "URLSession Streamer"
2. Observe the spike in memory in Xcode.
3. Observe the network graph in Xcode. You should see several MB of data having been downloaded.
4. Click "Read" a couple of times to see that data is read.
5. Click "Close Current Streamer"
6. Observe how the memory graph in Xcode doesn't drop significantly
7. Repeat this process, memory consumption continues to grow without relief.
