# wkinterop
Swift plus JavaScript via WKWebView. You'll need the JS counterpart [wkinteropJS](https://github.com/randymarsh77/wkinteropJS), and can get that with `npm install wkinterop`.

[![license](https://img.shields.io/github/license/mashape/apistatus.svg)]()
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Build Status](https://api.travis-ci.org/randymarsh77/wkinterop.svg?branch=master)](https://travis-ci.org/randymarsh77/wkinterop)
[![codebeat badge](https://codebeat.co/badges/09a0ff65-91c9-48c7-be4a-a48ee1c9a269)](https://codebeat.co/projects/github-com-randymarsh77-wkinterop)

## Overview

`WKWebView` provides an api for executing JS code, and recieving messages from JS running in the view's execution environment. However, any nontrivial amount of communication requires boiler plate interop code. Then, there are other considerations like asynchronousity and cancellation.

`WKInterop` facilitates communication by providing an api to both Swift code, and JS code for publishing events and making asyncrhonous requests. Each execution environment can register to recieve events and process requests.

## Usage

Given that we have created a `WKWebView` and a `WKInterop` instance (see [Example](#example)), we can use the following apis...

From Swift,

- `public func request<T>(route: String, token: CancellationToken) -> Task<T>`
-	`public func request<S, T>(route: String, content: S, token: CancellationToken) -> Task<T>`
-	`public func publish(route: String) -> ()`
- `public func publish<T>(route: String, content: T) -> ()`
- `public func registerEventHandler(route: String, handler: @escaping () -> ()) -> Scope`
-	`public func registerEventHandler<T>(route: String, handler: @escaping (T) -> ()) -> Scope`
-	`public func registerRequestHandler<T>(route: String, handler: @escaping () -> (Task<T>)) -> Scope`
-	`public func registerRequestHandler<S, T>(route: String, handler: @escaping (S) -> (Task<T>)) -> Scope`

See the [JS Readme](https://github.com/randymarsh77/wkinteropJS) for a more detailed explanation of the JS portion.

## Notable Dependencies

`WKInterop` uses the following in it's public api:
- [CancellationToken](https://github.com/randymarsh77/cancellation), a .NET port for cancellation
- [Scope](https://github.com/randymarsh77/scope), an `IDisposable` object for managing multi-ownership concerns
- `Task` from [Async](https://github.com/randymarsh77/async), a version of `async/await` continuations for providing an asynchronous api

## Json

Communication with JS via `WKWebView` uses some standard `NS*` types for transferring object data. These types can be used directly, or you can tell `WKInterop` to use any Json serialization library you provide by implementing the `WebKitJObjectSerializer` protocol. I've implemented [GlossSerializer](https://github.com/randymarsh77/wkinterop-gloss) that uses [Gloss](https://github.com/hkellaway/Gloss) for this purpose.

## Example <a name="example"></a>

Import useful things:
```
import WebKit
import Async
import Cancellation
import Gloss
import GlossSerializer
import WKInterop
```

Then, create an instance of `WKInterop` and a `WKWebView` with something like:
```
let serializer = GlossSerializer()
let interop = WKInterop(serializer: serializer) { config in
  WKWebView(frame: self.view.bounds, configuration: config)
}
```
`WKInterop` provides a `WKUserContentController` and a `WKScriptMessageHandler` and therefore requires the `WKWebView` to be instantiated with it's `WKWebViewConfiguration`.

Then, carry on.
```
_ = interop.registerEventHandler(route: "example.route.js-published-event") {
  print("JS says hello to Swift")
}

_ = interop.registerEventHandler(route: "example.route.js-published-event") { (data: CustomObject) in
  print("We're overloading the event route, but this time using the provided argument: ", data)
}

interop.publish(route: "example.route.swift-initiated-event")
interop.publish(route: "example.route.swift-initiated-event", content: ...)

DispatchQueue.global(qos: .default).async {
  let jsResponse: CustomObject = await (interop.request(route: "swift.request", content: ..., token: CancellationTokenSource().token))
  print("JS responded to Swift with: ", jsResponse)
}

_ = interop.registerRequestHandler(route: "example.route.js-makes-request") { () -> Task<CustomObject> in
  return async {
    var myResponse = CustomObject()
    return myResponse
  }
}
```

## Why?

JS is the most cross platform accessible language. However, you might not want to write important business logic in it. You might not be able to. But, you can still ship a consistent UI to any desktop or mobile platform, and even all of the above together with maximal code sharing. If that's what you want to do, then a good framework for communication interop is a must. `WKInterop` is still in it's early stages, but it aims to be good for this use case.

Ok, so... cross platform, but... `WKWebView` and Swift? Alright, you got me. Platforms besides macOS and iOS would need a compatible reciever, and the JS library would need some additional abstraction and environment detection. The potential is there, but I'm starting out with some platform contraints.

## Roadmap

These are a few items I imagine I'll need to address in the near future.

- CancellationTokens are completely ignored
- Serialization for `Array<T>` or `Dictionary<S, T>` where `S` and `T` are custom types probably isn't going to work out so hot right now
- Support for items listed in the [JS Roadmap](https://github.com/randymarsh77/wkinteropJS#roadmap)
