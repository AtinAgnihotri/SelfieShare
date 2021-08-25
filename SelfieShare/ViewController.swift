//
//  ViewController.swift
//  SelfieShare
//
//  Created by Atin Agnihotri on 25/08/21.
//

import UIKit
import MultipeerConnectivity

class ViewController: UICollectionViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, MCNearbyServiceAdvertiserDelegate {
    
    
    let SERVICE_TYPE = "atina-sfshare"
    var images = [UIImage]()
    var peerID = MCPeerID(displayName: UIDevice.current.name)
    var session: MCSession?
    var advertiserAssistent: MCNearbyServiceAdvertiser?
    var sentMessage = "" {
        didSet {
            print("Sent message: \(sentMessage)")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBar()
        setupSession()
    }
    
    func setupNavBar() {
        // Setup title
        title = "Selfie Share"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // Setup Camera Button
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importImage))
        
        // Setup Add Peer Button
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addConnectionPrompt))
        
    }
    
    func setupSession() {
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
    }
    
    @objc func importImage() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc func addConnectionPrompt() {
        let ac = UIAlertController(title: "Add Connection", message: nil, preferredStyle: .actionSheet)
        let hostASession = UIAlertAction(title: "Host a session", style: .default, handler: startHosting)
        let joinASession = UIAlertAction(title: "Join a session", style: .default, handler: joinSession)
        let listConnections = UIAlertAction(title: "List connections", style: .default, handler: listConnections)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        
        ac.addAction(hostASession)
        ac.addAction(joinASession)
        ac.addAction(listConnections)
        ac.addAction(cancel)
        
        present(ac, animated: true)
    }
    
    func listConnections(_ action: UIAlertAction) {
        guard let session = session else { return }
        var listOfPeers = ""
        let connectedPeers = session.connectedPeers
        for peer in connectedPeers {
            listOfPeers += peer.displayName + "\n"
        }
        listOfPeers = listOfPeers.trimmingCharacters(in: .whitespacesAndNewlines)
        showAlert(title: "List of connections", message: listOfPeers)
    }
    
    func startHosting(_ action: UIAlertAction) {
//        guard let session = session else { return }
//        advertiserAssistent = MCAdvertiserAssistant(serviceType: SERVICE_TYPE, discoveryInfo: nil, session: session)
//        advertiserAssistent?.start()
//        print("Started \(advertiserAssistent) for \(session)")
        advertiserAssistent = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: SERVICE_TYPE)
        advertiserAssistent?.delegate = self
        advertiserAssistent?.startAdvertisingPeer()
    }
    
    func joinSession(_ action: UIAlertAction) {
        guard let session = session else { return }
        let mcBrowser = MCBrowserViewController(serviceType: SERVICE_TYPE, session: session)
        mcBrowser.delegate = self
        present(mcBrowser, animated: true)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageView", for: indexPath)
        if let imageView = cell.viewWithTag(1000) as? UIImageView {
            imageView.image = images[indexPath.item]
        }
        return cell
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        dismiss(animated: true)
        
        images.insert(image, at: 0)
        collectionView.reloadData()
        
        sendImportedImageToPeers(image)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // empty
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // empty
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // empty
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected: \(peerID.displayName)")
        case .connecting:
            print("Connecting: \(peerID.displayName)")
        case .notConnected:
            DispatchQueue.main.async { [weak self] in
                self?.showError(title: "Peer Disconnected", message: "\(peerID.displayName) has dropped connection")
            }
            print("Disconnected: \(peerID.displayName)")
        @unknown default:
            print("Unknown Found: \(peerID.displayName)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            if let image = UIImage(data: data) {
                self?.images.insert(image, at: 0)
                self?.collectionView.reloadData()
            } else if let text = String(data: data, encoding: .utf8) {
                self?.sentMessage = text
            }
        }
    }
    
    func sendImportedImageToPeers(_ image: UIImage) {
        guard let session = session else { return }
        
        if !session.connectedPeers.isEmpty {
            if let imageData = image.pngData() {
                do {
                    try session.send(imageData, toPeers: session.connectedPeers, with: .reliable)
                    if let msg = "Sent from \(peerID.displayName)".data(using: .utf8) {
                        try session.send(msg, toPeers: session.connectedPeers, with: .reliable)
                    }
                    
                } catch {
                    showError(title: "Send Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {

        let ac = UIAlertController(title: title, message: "\(peerID.displayName) wants to connect", preferredStyle: .alert)

        ac.addAction(UIAlertAction(title: "Allow", style: .default, handler: { [weak self] _ in
            invitationHandler(true, self?.session)
        }))

        ac.addAction(UIAlertAction(title: "Decline", style: .cancel, handler: { _ in
            invitationHandler(false, nil)
        }))

        present(ac, animated: true)
    }
    
    func showAlert(title: String, message: String? = nil) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    func showError(title: String, message: String? = nil) {
        showAlert(title: "🚨 " + title, message: message)
    }
    
}

