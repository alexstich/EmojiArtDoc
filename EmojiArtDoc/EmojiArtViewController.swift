//
//  EmojiArtViewController.swift
//  EmojiArt
//
//  Created by Алексей Гребенкин on 11.09.2020.
//  Copyright © 2020 Alex Grebenkin. All rights reserved.
//

import UIKit
import MobileCoreServices

extension EmojiArt.EmojiInfo
{
    init?(label: UILabel) {
        if let attributedText = label.attributedText, let font = attributedText.font {
            x = Int(label.center.x)
            y = Int(label.center.y)
            text = attributedText.string
            size = Int(font.pointSize)
        } else {
            return nil
        }
    }
}


class EmojiArtViewController: UIViewController, UIDropInteractionDelegate, UIScrollViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    
    // MARK: Camera
    
    @IBOutlet weak var cameraButton: UIBarButtonItem! {
        didSet {
            cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }
    
    @IBAction func takeBackgroundPhoto(_ sender: UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [kUTTypeImage as String]
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = ((info[UIImagePickerController.InfoKey.editedImage] ?? info[UIImagePickerController.InfoKey.originalImage]) as? UIImage)?.scaled(by: 0.25) {
//            let url = image.storeLocallyAsJPEG(named: String(Date.timeIntervalSinceReferenceDate))
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                emojiArtBackgroundImage = .local(imageData, image)
                documentChanged()
            } else {
                // TODO: alert user of bad camera input
            }
        }
        picker.presentingViewController?.dismiss(animated: true)
        
    }
    
    // MARK: NAvigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Document Info" {
            if let destination = segue.destination.contents as? DocumentInfoViewController {
                document?.thumbnail = emojiArtView.snapshot
                destination.document = document
                if let ppc = destination.popoverPresentationController {
                    ppc.delegate = self
                }
            }
        } else if segue.identifier == "Embed Document Info" {
            embededdDocInfo = segue.destination.contents as? DocumentInfoViewController
        }
    }
    
    private var embededdDocInfo: DocumentInfoViewController?
    
    @IBOutlet weak var EmbeddedDocInfoHeight: NSLayoutConstraint!
    @IBOutlet weak var EmbeddedDocInfoWidth: NSLayoutConstraint!
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    @IBAction func close(bySegue: UIStoryboardSegue) {
        close()
    }
  
    // MARK: Model
    
    var emojiArt:  EmojiArt? {
        get {
            if let imageSource = emojiArtBackgroundImage {
                let emojis = emojiArtView.subviews.compactMap { $0 as? UILabel }.compactMap { EmojiArt.EmojiInfo(label: $0) }
                switch imageSource {
                case .remote(let url, _): return EmojiArt(url: url, emojis: emojis)
                case .local(let imageData, _): return EmojiArt(imageData: imageData, emojis: emojis)
                }
            }
            return nil
        }
        set {
            emojiArtBackgroundImage = nil
            emojiArtView.subviews.compactMap { $0 as? UILabel }.forEach { $0.removeFromSuperview() }
            let imageData = newValue?.imageData
            let image = (imageData != nil) ? UIImage(data: imageData!) : nil
            if let url = newValue?.url {
                imageFetcher = ImageFetcher() { (url, image) in
                    DispatchQueue.main.async {
                        if let image = self.imageFetcher.backup {
                            self.emojiArtBackgroundImage = .local(imageData!, image)
                        } else {
                            self.emojiArtBackgroundImage = .remote(url, image)
                        }
                        newValue?.emojis.forEach {
                            let attributedText = $0.text.attributedString(withTextStyle: .body, ofSize: CGFloat($0.size))
                            self.emojiArtView.addLabel(with: attributedText, centeredAt: CGPoint(x: $0.x, y: $0.y))
                        }
                    }
                }
                imageFetcher.backup = image
                imageFetcher.fetch(url)
            } else if image != nil {
                emojiArtBackgroundImage = .local(imageData!, image!)
                newValue?.emojis.forEach{
                    let attributedText = $0.text.attributedString(withTextStyle: .body, ofSize: CGFloat($0.size))
                    self.emojiArtView.addLabel(with: attributedText, centeredAt: CGPoint(x: $0.x, y: $0.y))
                }
            }
        }
    }
    
    var document: EmojiArtDocument?
    
    func documentChanged(_ sender: UIBarButtonItem? = nil) {
        document?.emojiArt = emojiArt
        if document?.emojiArt != nil {
            document?.updateChangeCount(.done)
        }
    }
    
    @IBAction func close(_ sender: UIBarButtonItem? = nil) {
        if let observer = emojiViewObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        documentChanged()
        if document?.emojiArt != nil {
            document?.thumbnail = emojiArtView.snapshot
        }
        presentingViewController?.dismiss(animated: true) {
            self.document?.close { success in
                if let observer = self.documentObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
        document?.close()
    }
    
    private var documentObserver: NSObjectProtocol?
    private var emojiViewObserver: NSObjectProtocol?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if document?.documentState != .normal {
            documentObserver = NotificationCenter.default.addObserver(
                forName: UIDocument.stateChangedNotification,
                object: document,
                queue: OperationQueue.main,
                using: { (notification) in
                    print("documentState changed to \(self.document!.documentState)")
                    if self.document!.documentState == .normal, let docInfoVC = self.embededdDocInfo {
                        docInfoVC.document = self.document
                        self.EmbeddedDocInfoHeight.constant = docInfoVC.preferredContentSize.width
                        self.EmbeddedDocInfoHeight.constant = docInfoVC.preferredContentSize.height
                    }
            })
            document?.open { success in
                if success {
                    self.title = self.document?.localizedName
                    self.emojiArt = self.document?.emojiArt
                    self.emojiViewObserver = NotificationCenter.default.addObserver(
                        forName: .EmojiArtViewDidChange,
                        object: self.emojiArtView,
                        queue: OperationQueue.main,
                        using: { notification in
                            self.documentChanged()
                    })
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = try? FileManager.default.url (for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Untitled.json") {
            document = EmojiArtDocument(fileURL: url)
        }
    }

    @IBOutlet weak var dropZone: UIView! {
        didSet {
            dropZone.addInteraction(UIDropInteraction(delegate: self))
        }
    }
    
    lazy var emojiArtView = EmojiArtView()
   
    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            scrollView.minimumZoomScale = 0.1
            scrollView.maximumZoomScale = 5.0
            scrollView.delegate = self
            scrollView.addSubview(emojiArtView)
        }
    }
    @IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollViewHeight.constant = scrollView.contentSize.height
        scrollViewWidth.constant = scrollView.contentSize.width
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return emojiArtView
    }
    
    private var _emojiArtBackgroundImageURL: URL?
    
    enum ImageSource {
        case remote(URL, UIImage)
        case local(Data, UIImage)
        
        var image: UIImage {
            switch self {
            case .remote(_, let image): return image
            case .local(_, let image): return image
            }
        }
    }
    
    var emojiArtBackgroundImage: ImageSource? {
        didSet {
            scrollView?.zoomScale = 1.0
            emojiArtView.backgroundImage = emojiArtBackgroundImage?.image
            let size = emojiArtBackgroundImage?.image.size ?? CGSize.zero
            emojiArtView.frame = CGRect(origin: CGPoint.zero, size: size)
            scrollView?.contentSize = size
            scrollViewHeight?.constant = size.height
            scrollViewWidth?.constant = size.width
            if let dropZone = self.dropZone, size.width > 0, size.height > 0 {
                scrollView?.zoomScale = max(dropZone.bounds.size.width / size.width, dropZone.bounds.size.height / size.height)
            }
        }
    }
    
    var emojis = "🥶👿🎃🦊🐧🐞🦞🦩🐿🌴🌹🌗🌏🌈❄️🍎🍔🚌".map{ String($0) }
    
    @IBOutlet weak var emojiCollectionView: UICollectionView! {
        didSet {
            emojiCollectionView.dataSource = self
            emojiCollectionView.delegate = self
            emojiCollectionView.dragDelegate = self
            emojiCollectionView.dropDelegate = self
            emojiCollectionView.dragInteractionEnabled = true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis.count
    }
    
    private var font: UIFont {
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.preferredFont(forTextStyle: .body).withSize(48.0))
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath)
        if let emojiCell = cell as? EmojiCollectionViewCell {
            let text = NSAttributedString(string: emojis[indexPath.item], attributes: [.font: font])
            emojiCell.label.attributedText = text
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }
    
    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        if let attributeString = (emojiCollectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell)?.label.attributedText {
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: attributeString))
            dragItem.localObject = attributeString
            return [dragItem]
        } else {
            return []
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        let isSelf = (session.localDragSession?.localContext as? UICollectionView) == collectionView
        return UICollectionViewDropProposal(operation: isSelf ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                if let attributedString = item.dragItem.localObject as? NSAttributedString {
                    collectionView.performBatchUpdates({
                        emojis.remove(at: sourceIndexPath.item)
                        emojis.insert(attributedString.string, at: destinationIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        collectionView.insertItems(at: [destinationIndexPath])
                    })
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                }
            } else {
                let placeholderContext = coordinator.drop(item.dragItem, to: UICollectionViewDropPlaceholder(insertionIndexPath: destinationIndexPath, reuseIdentifier: "DropPlaceholderCell"))
                item.dragItem.itemProvider.loadObject(ofClass: NSAttributedString.self) { (provider, error) in
                    DispatchQueue.main.async {
                        if let attributedString = provider as? NSAttributedString {
                            placeholderContext.commitInsertion { (insertionIndexPath) in
                                self.emojis.insert(attributedString.string, at: insertionIndexPath.item)
                            }
                        } else {
                            placeholderContext.deletePlaceholder()
                        }
                    }
                }
            }
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSURL.self) &&
        session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    var imageFetcher: ImageFetcher!
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        
        imageFetcher = ImageFetcher() {
            (url, image) in
            DispatchQueue.main.async {
                if image == self.imageFetcher.backup {
                    if let imageData = image.jpegData(compressionQuality: 1.0) {
                        self.emojiArtBackgroundImage = .local(imageData, image)
                        self.documentChanged()
                    } else {
                        self.presentBadURLWarning(for: url)
                    }
                } else {
                    self.emojiArtBackgroundImage = .remote(url, image)
                    self.documentChanged()
                }
                
            }
        }
        session.loadObjects(ofClass: NSURL.self) { nsurls in
            if let url = nsurls.first as? URL {
                self.imageFetcher.fetch(url)
            }
        }
        session.loadObjects(ofClass: UIImage.self) {
            image in
            if let image = image.first as? UIImage {
                self.imageFetcher.backup = image
            }
        }
    }
    
    private var suppressBadURLWarnings = false
    
    private func presentBadURLWarning(for url: URL?) {
        if !suppressBadURLWarnings {
            let alert = UIAlertController(
                title: "Image Transfer Failed",
                message: "Couldn't transfer the dropped image from its source.\nShow this warning in the future?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: "Keep Warning",
                style: .default
            ))
            alert.addAction(UIAlertAction(
                title: "Stop Warning",
                style: .destructive,
                handler: { action in
                    self.suppressBadURLWarnings = true
            }
            ))
            present(alert, animated: true)
        }
    }
}
