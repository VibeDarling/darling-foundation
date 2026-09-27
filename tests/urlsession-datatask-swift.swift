// Needs an HTTP server on the host serving a file with the exact body "urlsession-datatask-ok\n", e.g.
//   printf 'urlsession-datatask-ok\n' > dir/probe.txt && python3 -m http.server 8765 -b 127.0.0.1 -d dir
// and its URL as the first argument: urlsession-datatask-swift http://127.0.0.1:8765/probe.txt
import Foundation

var failures = 0
func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        failures += 1
    }
}

guard CommandLine.arguments.count == 2, let url = URL(string: CommandLine.arguments[1]) else {
    print("usage: urlsession-datatask-swift <url of a file containing \"urlsession-datatask-ok\\n\">")
    exit(2)
}

var request = URLRequest(url: url)
request.httpMethod = "GET"
request.timeoutInterval = 10

let done = DispatchSemaphore(value: 0)
var result: (Data?, URLResponse?, Error?)
let task: URLSessionDataTask = URLSession(configuration: .default).dataTask(with: request) { data, response, error in
    result = (data, response, error)
    done.signal()
}
expect(task.originalRequest?.url == url, "originalRequest bridges back to URLRequest with the same URL")
task.resume()

if done.wait(timeout: .now() + 20) == .timedOut {
    print("FAIL: no completion within 20 s")
    exit(1)
}
let (data, response, error) = result
expect(error == nil, "no error, got \(String(describing: error))")
expect(response != nil, "a response")
expect(data.map { String(decoding: $0, as: UTF8.self) } == "urlsession-datatask-ok\n",
       "body matches, got \(String(describing: data))")

if failures == 0 {
    print("PASS: URLSession.dataTask(with: URLRequest) completed a request")
}
exit(failures == 0 ? 0 : 1)
