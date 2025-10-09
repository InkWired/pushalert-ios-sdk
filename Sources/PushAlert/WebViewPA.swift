import UIKit
import WebKit

class WebViewPA: UIViewController,WKUIDelegate,WKNavigationDelegate {
    var window : UIWindow?
    var webView: WKWebView!
    static var url2Open : String?
    static var title : String?
    
    var activityIndicator: UIActivityIndicatorView!
    
    override func loadView() {
        super.loadView()
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.frame=self.view.bounds
        view.addSubview(webView)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setToolBar()
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.gray
        
        view.addSubview(activityIndicator)
        
        
        webView.scrollView.contentInset = UIEdgeInsets(top: 40,left: 0,bottom: 0,right: 0);
        if let url = URL(string: WebViewPA.url2Open!) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    private func setToolBar() {
        let screenWidth = self.view.bounds.width
        let backButton = UIBarButtonItem(title: "DONE", style: .plain, target: self, action: #selector(backAction))
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 30))
        toolBar.isTranslucent = true
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.items = [backButton]
        view.addSubview(toolBar)
        toolBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        toolBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        toolBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
    }
    
    @objc func backAction(){
        dismiss(animated: true, completion: nil)
    }
    
    func showActivityIndicator(show: Bool) {
        if show {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        showActivityIndicator(show: false)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showActivityIndicator(show: true)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showActivityIndicator(show: false)
    }
    
}
