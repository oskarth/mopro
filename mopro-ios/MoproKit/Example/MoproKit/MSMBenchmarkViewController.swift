//
//  MSMBenchmarkViewController.swift
//  MoproKit_Example
//
//  Created by Fuchuan Chung on 2024/2/6.
//  Copyright © 2024 CocoaPods. All rights reserved.
//x

//import UIKit
//import WebKit
//import MoproKit

//class MSMBenchmarkViewController: UITableViewController, WKScriptMessageHandler, WKNavigationDelegate {

//    let webView = WKWebView()
//    let moproCircom = MoproKit.MoproCircom()
//    //var setupResult: SetupResult?
//    var generatedProof: Data?
//    var publicInputs: Data?
//    let containerView = UIView()
//    var textView = UITextView()
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//            runInitAction()
//            setupUI()
//            
//            let contentController = WKUserContentController()
//            contentController.add(self, name: "startProvingHandler")
//            contentController.add(self, name: "messageHandler")
//            
//            let configuration = WKWebViewConfiguration()
//            configuration.userContentController = contentController
//            configuration.preferences.javaScriptEnabled = true
//            
//            // Assign the configuration to the WKWebView
//            let webView = WKWebView(frame: view.bounds, configuration: configuration)
//            webView.navigationDelegate = self
//                
//            view.addSubview(webView)
//            view.addSubview(textView)
//            
//            guard let url = URL(string: "https://webview-anon-adhaar.vercel.app/") else { return }
//            webView.load(URLRequest(url: url))
//    }
//    
//    func setupUI() {
//         textView.isEditable = false
//
//        textView.translatesAutoresizingMaskIntoConstraints = false
//         view.addSubview(textView)
//
//         // Make text view visible
//         textView.heightAnchor.constraint(equalToConstant: 200).isActive = true
//
//         NSLayoutConstraint.activate([
//            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//                    textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//                    textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
//         ])
//     }
//    
//    
//    
//    @objc func runInitAction() {
//        // Update the textView on the main thread
//        DispatchQueue.main.async {
//            self.textView.text += "Initializing library\n"
//        }
//
//        // Execute long-running tasks in the background
//        DispatchQueue.global(qos: .userInitiated).async {
//            // Record start time
//            let start = CFAbsoluteTimeGetCurrent()
//
//            do {
//                try initializeMopro()
//
//                // Record end time and compute duration
//                let end = CFAbsoluteTimeGetCurrent()
//                let timeTaken = end - start
//
//                // Again, update the UI on the main thread
//                DispatchQueue.main.async {
//                    self.textView.text += "Initializing arkzkey took \(timeTaken) seconds.\n"
//                }
//            } catch {
//                // Handle errors - update UI on main thread
//                DispatchQueue.main.async {
//                    self.textView.text += "An error occurred during initialization: \(error)\n"
//                }
//            }
//        }
//    }
//    
//    @objc func runProveAction(inputs: [String: [String]]) {
//        // Logic for prove (generate_proof2)
//        do {
//            textView.text += "Starts proving...\n"
//            // Record start time
//            let start = CFAbsoluteTimeGetCurrent()
//            
//            // Generate Proof
//            let generateProofResult = try generateProof2(circuitInputs: inputs)
//            assert(!generateProofResult.proof.isEmpty, "Proof should not be empty")
//            //assert(Data(expectedOutput) == generateProofResult.inputs, "Circuit outputs mismatch the expected outputs")
//            
//            // Record end time and compute duration
//            let end = CFAbsoluteTimeGetCurrent()
//            let timeTaken = end - start
//            
//            // Store the generated proof and public inputs for later verification
//            generatedProof = generateProofResult.proof
//            publicInputs = generateProofResult.inputs
//            
//            print("Proof generation took \(timeTaken) seconds.\n")
//            
//            textView.text += "Proof generated!!! \n"
//            textView.text += "Proof generation took \(timeTaken) seconds.\n"
//            textView.text += "---\n"
//            runVerifyAction()
//        } catch let error as MoproError {
//            print("MoproError: \(error)")
//        } catch {
//            print("Unexpected error: \(error)")
//        }
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        webView.frame = view.bounds
//    }
//    
//    struct Witness {
//        let signature: [String]
//        let modulus: [String]
//        let base_message: [String]
//    }
//    
//    // Implement WKScriptMessageHandler method
//        func provingContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//            if message.name == "messageHandler" {
//                // Handle messages for "messageHandler"
//                print("Received message from JavaScript:", message.body)
//            }
//        }
//
//    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//        if message.name == "startProvingHandler", let data = message.body as? [String: Any] {
//            // Check for the "witness" key in the received data
//            if let witnessData = data["witness"] as? [String: [String]] {
//                if let signature = witnessData["signature"],
//                   let modulus = witnessData["modulus"],
//                   let baseMessage = witnessData["base_message"] {
//                    
//                    let inputs: [String: [String]] = [
//                        "signature": signature,
//                        "modulus": modulus,
//                        "base_message": baseMessage
//                    ]
//                    
//                    // Call your Swift function with the received witness data
//                    runProveAction(inputs: inputs)
//                }
//            } else if let error = data["error"] as? String {
//                // Handle error data
//                print("Received error value from JavaScript:", error)
//            } else {
//                print("No valid data keys found in the message data.")
//            }
//        }
//    }
//    
//    @objc func runVerifyAction() {
//        // Logic for verify
//        guard let proof = generatedProof,
//            let publicInputs = publicInputs else {
//            print("Proof has not been generated yet.")
//            return
//        }
//        do {
//            // Verify Proof
//            let isValid = try verifyProof2(proof: proof, publicInput: publicInputs)
//            assert(isValid, "Proof verification should succeed")
//
//            textView.text += "Proof verification succeeded.\n"
//        } catch let error as MoproError {
//            print("MoproError: \(error)")
//        } catch {
//            print("Unexpected error: \(error)")
//        }
//    }
//}


import UIKit

class MSMBenchmarkViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableView: UITableView!
    var submitButton: UIButton!
    let items = ["Option 1", "Option 2", "Option 3"]
    var selectedItems: Set<Int> = [] // Set to keep track of selected items
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupBenchmarkButton()
    }
    
    func setupTableView() {
        tableView = UITableView(frame: view.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.allowsMultipleSelection = true // Enable multiple selection
        view.addSubview(tableView)
    }
    
    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        
        // Configure the cell for selected state
        if selectedItems.contains(indexPath.row) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    // UITableViewDelegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedItems.insert(indexPath.row)
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark
        }
        print("Selected: \(items[indexPath.row])")
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        selectedItems.remove(indexPath.row)
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .none
        }
        print("Deselected: \(items[indexPath.row])")
    }
    
    func setupBenchmarkButton() {
        submitButton = UIButton(type: .system)
        submitButton.frame = CGRect(x: 20, y: view.bounds.height - 80, width: view.bounds.width - 60, height: 50)
        submitButton.setTitle("Benchmark", for: .normal)
        submitButton.addTarget(self, action: #selector(submitAction), for: .touchUpInside)
        submitButton.backgroundColor = .systemBlue
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = 10
        view.addSubview(submitButton)
    }
    
    @objc func submitAction() {
        // Action for the submit button
        print("Selected Items: \(selectedItems.map { items[$0] })")
        // Here you can add further actions, like navigating to another view controller
    }
}

// Don't forget to set this view controller as the root view controller in your AppDelegate or SceneDelegate
