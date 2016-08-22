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

//https://github.com/Copyleaks/Java-Plagiarism-Checker/blob/master/src/copyleaks/sdk/api/helpers/HttpURLConnection/CopyleaksClient.java

import Foundation

public class CopyleaksCloud {
    
    public typealias CopyleaksSuccessBlock = (result: CopyleaksResult<AnyObject, NSError>) -> Void
    public var successBlock: CopyleaksSuccessBlock?
    
    /**
     Callbacks
     Copyleaks API supports two types of completion callbacks that are invoked once the process has 
     been completed, with or without success.
     When using callbacks, there is no need to check the request's status manually. We will automatically 
     inform you when the process has completed running and the results are ready.
     */
    
    /* Copyleaks product type. Default is businesses */
    public var productType: CopyleaksProductType = .Businesses


    /* Generate current language */
    
    static let acceptLanguage: String = NSLocale.preferredLanguages().prefix(6).enumerate().map { index, languageCode in
        let quality = 1.0 - (Double(index) * 0.1)
        return "\(languageCode);q=\(quality)"
        }.joinWithSeparator(", ")
    
//    let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)
//    public let session: NSURLSession
//    public let delegate: CopyleaksSessionDelegate
    
    /**
     The background completion handler closure provided by the UIApplicationDelegate
     'application:handleEventsForBackgroundURLSession:completionHandler: method. By setting the background
     completion handler, the SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` closure implementation
     will automatically call the handler.
     
     If you need to handle your own events before the handler is called, then you need to override the
     SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` and manually call the handler when finished.
     
     `nil` by default.
     */
    public var backgroundCompletionHandler: (() -> Void)?
    

    /**
     Initializes the CopyleaksCloud instance with the specified configuration and delegate;
     - parameter product: The product type. Dafault value from Copyleaks
     - parameter httpCallback: HTTP-Callbacks. Dafault value is 'nil'.
     - parameter emailCallback: Email-Callbacks. Dafault value is 'nil'.
     - parameter clientCustomMessage: The custom payload message. Dafault value is 'nil'.
     - parameter allowPartialScan: Allow Partial Scan. Dafault value is 'nil'.
     - parameter configuration: The configuration used to construct the managed session.
     - parameter delegate:  The delegate used when initializing the session.
     */

    public init(
        _ product: CopyleaksProductType? = Copyleaks.sharedSDK.productType,
        httpCallback: String? = nil,
        emailCallback: String? = nil,
        clientCustomMessage: String? = nil,
        allowPartialScan: Bool = false,
        configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration(),
        delegate: CopyleaksSessionDelegate = CopyleaksSessionDelegate())
    {
        self.httpCallback = httpCallback
        self.emailCallback = emailCallback
        self.clientCustomMessage = clientCustomMessage
        self.allowPartialScan = allowPartialScan
        
        if product != nil {
            Copyleaks.setProduct(product!)
        }
        let config = configuration
        config.HTTPAdditionalHeaders = CopyleaksCloud.defaultHTTPHeaders
        self.delegate = delegate
        self.session = NSURLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        delegate.sessionDidFinishEventsForBackgroundURLSession = { [weak self] session in
            guard let strongSelf = self else { return }
            dispatch_async(dispatch_get_main_queue()) { strongSelf.backgroundCompletionHandler?() }
        }
    }
    //deinit { session.invalidateAndCancel() }

    
    // MARK: - Public Api methods
    
    /* Login to the Copyleaks API using your email and API key */
    
    public func login(
        email:String,
        apiKey: String,
        success: (result: CopyleaksResult<AnyObject, NSError>) -> Void)
    {
        var params:[String: AnyObject] = [String: AnyObject]()
        params["Email"] = email
        params["ApiKey"] = apiKey
        
        let api = CopyleaksApi(
            method: .POST,
            rout: "account/login-api",
            parameters: params,
            headers: nil,
            body: nil)
        
        api.request?.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            let token = CopyleaksToken(response: response)
            token.save()
            success(result: response.result)
        }
    }
    
    
    /* Starting a new process by providing a URL to scan. */
    
    public func createByUrl(url: NSURL, success: CopyleaksSuccessBlock?) {
        var params:[String: AnyObject] = [String: AnyObject]()
        params["Url"] = url.URLString
        let rout: String = productType.rawValue.lowercaseString + "/create-by-url"
        let request = self.request(.POST, rout, params, configureOptionalHeaders(), nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }
    
    /* Starting a new process by providing a file to scan. */

    public func createByFile(fileURL fileURL: NSURL, language: String, success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/create-by-file"
        let request = self.uploadFile(fileURL, rout: rout, language: language, headers: configureOptionalHeaders())
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }

    /* Starting a new process by providing a text to scan. */
    
    public func createByText(text: String, success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/create-by-text"
        let body = text.dataUsingEncoding(NSUTF8StringEncoding)
        let request = self.request(.POST, rout, nil, configureOptionalHeaders(), body)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }
    
    /* Starting a new process by providing a photo with text. */
    
    public func createByOCR(fileURL fileURL: NSURL, language: String, success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/create-by-file-ocr"
        let request = self.uploadFile(fileURL, rout: rout, language: language, headers: configureOptionalHeaders())
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }
    
    /* Get the scan progress details using the processId. */
    
    public func statusProcess(processId: String, success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/" + processId + "/status"
        let request = self.request(.GET, rout, nil, CopyleaksCloud.authHTTPHeaders, nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }
    
    /* Get the results using the processId. */
    
    public func resultProcess(processId: String, success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/" + processId + "/result"
        let request = self.request(.GET, rout, nil, CopyleaksCloud.authHTTPHeaders, nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }
    
    /* 
     * Delete the specific process from the server, after getting the scan results.
     * Only completed processes can be deleted.
     */
    
    public func deleteProcess(processId: String, success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/" + processId + "/delete"
        let request = self.request(.DELETE, rout, nil, CopyleaksCloud.authHTTPHeaders, nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }

    /* Receive a list of all your active processes. */
    
    public func processesList(success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/list"
        let request = self.request(.GET, rout, nil, CopyleaksCloud.authHTTPHeaders, nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }
    
    /* Get count of credits */
    
    public func countCredits(success: CopyleaksSuccessBlock?) {
        let rout: String = productType.rawValue.lowercaseString + "/count-credits"
        let request = self.request(.GET, rout, nil, CopyleaksCloud.authHTTPHeaders, nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }
    
    /* Get full list of the supported OCR languages. */
  
    public func languagesList(success: CopyleaksSuccessBlock?) {
        let rout: String = "/miscellaneous/ocr-languages-list"
        let request = self.request(.GET, rout, nil, CopyleaksCloud.defaultHTTPHeaders, nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }

    /* Get list of the supported file types . */
    
    public func supportedFileTypes(success: CopyleaksSuccessBlock?) {
        let rout: String = "/miscellaneous/supported-file-types"
        let request = self.request(.GET, rout, nil, CopyleaksCloud.defaultHTTPHeaders, nil)
        request.responseJSON { (response:CopyleaksResponse<AnyObject, NSError>) in
            success?(result: response.result)
        }
    }

}
