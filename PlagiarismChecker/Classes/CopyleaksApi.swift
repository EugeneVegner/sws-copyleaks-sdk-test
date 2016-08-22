/*
 * The MIT License(MIT)
 *
 * Copyright(c) 2016 Copyleaks LTD (https://copyleaks.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

import Foundation
import MobileCoreServices

// MARK: - Convenience

/* Types adopting the URLStringConvertible protocol. */
public protocol URLStringConvertible { var URLString: String { get } }

/* Types adopting the URLRequestConvertible protocol. */
public protocol URLRequestConvertible { var URLRequest: NSMutableURLRequest { get } }

//func URLRequest(method: CopyleaksHTTPMethod, _ URLString: URLStringConvertible, headers: [String: String]? = nil, body: NSData? = nil) -> NSMutableURLRequest {
//    let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URLString.URLString)!)
//    mutableURLRequest.HTTPMethod = method.rawValue
//    
//    if let headers = headers {
//        for (headerField, headerValue) in headers {
//            mutableURLRequest.setValue(headerValue, forHTTPHeaderField: headerField)
//        }
//    }
//    
//    if let data = body {
//        mutableURLRequest.HTTPBody = data
//    }
//    
//    return mutableURLRequest
//}


public class CopyleaksApi {
    
    private var rout: URLStringConvertible = ""
    private var method: CopyleaksHTTPMethod = .GET
    private var parameters: [String: AnyObject]? = nil
    private var body: NSData? = nil
    
    
    let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)
    public let session: NSURLSession
    public let delegate: CopyleaksSessionDelegate

    
    
    //
    private var headers: [String: String]? = nil
    
    public var request: CopyleaksRequest?
    
    /* Init Api */
    
    public init (
        method: CopyleaksHTTPMethod,
        rout: String,
        parameters: [String: AnyObject]? = nil,
        headers: [String: String]? = nil,
        body: NSData? = nil)
    {
        
        self.method = method
        self.rout = rout
        self.parameters = parameters
        self.headers = headers
        self.body = body
        
    }

    // MARK: - Setup headers
    
    /* Creates default HTTP Headers */

    public static let defaultHTTPHeaders: [String: String] = {
        return [
            CopyleaksConst.cacheControlHeader: CopyleaksConst.cacheControlValue,
            CopyleaksConst.contentTypeHeader: CopyleaksHTTPContentType.JSON,
            CopyleaksConst.userAgentHeader: CopyleaksConst.userAgentValue,
            CopyleaksConst.acceptLanguageHeader: CopyleaksConst.defaultAcceptLanguage// acceptLanguage
        ]
    }()
    
    public static let authHTTPHeaders: [String: String] = {
        var headers:[String: String] = defaultHTTPHeaders
        headers["Authorization"] = CopyleaksToken.getAccessToken()!.generateAccessToken()
        return headers
    }()
    
    
    private func configureOptionalHeaders() -> [String: String] {
        var headers:[String: String] = CopyleaksCloud.authHTTPHeaders
        if Copyleaks.sharedSDK.sandboxMode {
            headers["copyleaks-sandbox-mode"] = "true"
        }
        if allowPartialScan {
            headers["copyleaks-allow-partial-scan"] = "true"
        }
        if let val = httpCallback {
            headers["copyleaks-http-callback"] = val
        }
        if let val = emailCallback {
            headers["copyleaks-email-callback"] = val
        }
        if let val = clientCustomMessage {
            headers["copyleaks-client-custom-Message"] = val
        }
        
        return headers
    }


    // MARK: - Request Methods
    
    /* Request constructor */
  
    private func configureRequest(
        method: CopyleaksHTTPMethod,
        _ URLString: URLStringConvertible,
          headers: [String: String]? = nil,
          body: NSData? = nil) -> NSMutableURLRequest
    {
        let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URLString.URLString)!)
        mutableURLRequest.HTTPMethod = method.rawValue
        
        if let headers = headers {
            for (headerField, headerValue) in headers {
                mutableURLRequest.setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
        
        if let data = body {
            mutableURLRequest.HTTPBody = data
        }
        
        return mutableURLRequest
    }

    
    
    /**
     Creates a request using the shared manager instance for the specified method, rout string, parameters, headers and body.
     
     - parameter method:     The HTTP method.
     - parameter rout:       The API rout.
     - parameter parameters: The parameters. `nil` by default.
     - parameter headers:    The HTTP headers. `nil` by default.
     - parameter body:       The HTTP body. `nil` by default.
     
     - returns: The created request.
     */
    
    public func request (
        method: CopyleaksHTTPMethod,
        _ rout: String,
          _ parameters: [String: AnyObject]? = nil,
            _ headers: [String: String]? = nil,
              _ body: NSData? = nil) -> CopyleaksRequest {
        
        let components = NSURLComponents()
        components.scheme = "https"
        components.host = CopyleaksConst.serviceHost
        components.path = "/" + CopyleaksConst.serviceVersion + "/" + rout
        
        var requestHeaders = headers
        if requestHeaders == nil {
            //requestHeaders = CopyleaksCloud.defaultHTTPHeaders
        }
        
        let mutableURLRequest = self.configureRequest(
            method,
            components.URL!,
            headers: requestHeaders,
            body: body)
        
        do {
            if parameters != nil {
                let options = NSJSONWritingOptions()
                let data = try NSJSONSerialization.dataWithJSONObject(parameters!, options: options)
                mutableURLRequest.HTTPBody = data
            }
        } catch {
            assert(true, "Incorrect encoding")
        }
        
        var dataTask: NSURLSessionDataTask!
        dispatch_sync(queue) { dataTask = self.session.dataTaskWithRequest(mutableURLRequest.URLRequest) }
        
        let request = CopyleaksRequest(session: session, task: dataTask)
        delegate[request.delegate.task] = request.delegate
        request.resume()
        
        return request
        
    }
    
    // MARK: - Upload Methods
    
    /**
     Creates a request for uploading File to the specified URL request.
     
     - parameter fileURL:   The File URL.
     - parameter rout:      The HTTP rout.
     - parameter language:  The Language Code that identifies the language of the content.
     - parameter headers:   The HTTP headers. `nil` by default.
     
     - returns: The created upload request.
     */
    
    public func uploadFile (
        _ fileURL : NSURL,
          rout: String,
          language: String,
          headers: [String: String]? = nil)
        -> CopyleaksRequest
    {
        let components = NSURLComponents()
        components.scheme = "https"
        components.host = CopyleaksConst.serviceHost
        components.path = "/" + CopyleaksConst.serviceVersion + "/" + rout
        components.query = "language=" + language
        
        let boundary = generateBoundary()
        var uploadData = NSMutableData()
        uploadData.appendData("--\(boundary)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        
        if let
            fileName = fileURL.lastPathComponent,
            pathExtension = fileURL.pathExtension,
            uploadFile: NSData = NSFileManager.defaultManager().contentsAtPath(fileURL.URLString)
        {
            let mimeType = mimeTypeForPathExtension(pathExtension)
            
            uploadData.appendData("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName).\(pathExtension)\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Type: \(mimeType)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            let strBase64:String = uploadFile.base64EncodedStringWithOptions(.Encoding64CharacterLineLength)
            uploadData.appendData("Content-Transfer-Encoding: binary\r\n\r\n\(strBase64)".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        }
        uploadData.appendData("--\(boundary)--\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        
        // Configure headers
        
        var uploadHeader = headers
        if uploadHeader == nil {
            uploadHeader = CopyleaksCloud.authHTTPHeaders
        }
        uploadHeader!["Accept"] = "application/json"
        uploadHeader![CopyleaksConst.contentTypeHeader] = "multipart/form-data;boundary="+boundary
        uploadHeader!["Content-Length"] = String(uploadData.length)
        
        let mutableURLRequest = self.configureRequest(
            .POST,
            components.URL!,
            headers: uploadHeader)
        
        mutableURLRequest.HTTPBody = uploadData
        
        var uploadTask: NSURLSessionUploadTask!
        dispatch_sync(queue) {
            uploadTask = self.session.uploadTaskWithRequest(mutableURLRequest, fromData: uploadData)
            //uploadTask = self.session.dataTaskWithRequest(mutableURLRequest)
        }
        
        let request = CopyleaksRequest(session: session, task: uploadTask)
        delegate[request.delegate.task] = request.delegate
        request.resume()
        return request
    }
    
    
    /* Configure MIME type from path */
    
    private func mimeTypeForPathExtension(pathExtension: String) -> String {
        if let
            id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, nil)?.takeRetainedValue(),
            contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return contentType as String
        }
        return "application/octet-stream"
    }
    
    
    /* Boundary generator */
    
    private func generateBoundary() -> String {
        return String(format: "copyleaks.boundary.%08x%08x", arc4random(), arc4random())
    }

}

public class CopyleaksHeaders: (String, String) {

    /**
     HTTP-Callbacks
     Add the Http request header copyleaks-http-callback with the URL of your endpoint.
     Tracking your processes is available by adding the token process ID {PID} as a parameter
     to your URL. This will allow you to follow each process individually.
     */
    
    public var httpCallback: String?
    
    
    /**
     Email-Callbacks
     Register a callback email to get informed when the request has been completed.
     When the API request status is complete, you will get an email to your inbox and
     the scan results will be available, using the result (Academic \ Businesses) method.
     */
    
    public var emailCallback: String?
    
    /**
     Custom Fields
     You can add custom payload to the request headers. The payload is stored in a
     'dictionary' representing a collection of string key and string value pairs.
     */
    
    public var clientCustomMessage: String?
    
    /**
     Allow Partial Scan
     If you don't have enough credits to scan the entire submitted text, part of the
     text will be scanned, according to the amount of credits you have left.
     
     For example, you have 5 credits and you would like to scan text that requires 10 credits.
     If you added the copyleaks-allow-partial-scanto your request only 5 pages out of 10 will
     be scanned. Otherwise, none of the pages will be scanned and you will get back an error
     messsage stating that you don't have enough credits to complete the scan.
     */
    
    public var allowPartialScan: Bool = false


    public init(
        httpCallback: String? = nil,
        emailCallback: String? = nil,
        clientCustomMessage: String? = nil,
        allowPartialScan: Bool = false)
    {
        self.httpCallback = httpCallback
        self.emailCallback = emailCallback
        self.clientCustomMessage = clientCustomMessage
        self.allowPartialScan = allowPartialScan
    }
    
    required convenience public init(dictionaryLiteral elements: (NSCopying, AnyObject)...) {
        fatalError("init(dictionaryLiteral:) has not been implemented")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


}
