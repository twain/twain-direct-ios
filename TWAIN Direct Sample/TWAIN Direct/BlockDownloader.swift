//
//  BlockDownloader.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-27.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import Foundation

enum BlockDownloaderError : Error {
    case noResponseBody
    case unexpectedMimeType
    case missingMimeBoundary
    case downloadFailed
    case releaseImageBlocksFailed
    case missingMetadata
}

enum BlockStatus: String, Codable {
    // Ready to download
    case readyToDownload
    // Currently downloading
    case downloading
    // Downloaded, but waiting for more parts
    case waitingForMoreParts
    // Delivered to the client, and deleted
    case completed
}

struct ReadImageBlockRequest : Encodable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "readImageBlock"
    var params: ReadImageBlockParams
    
    init(sessionId: String, imageBlockNum: Int) {
        params = ReadImageBlockParams(sessionId: sessionId, imageBlockNum: imageBlockNum, withMetadata: true)
    }
    
    struct ReadImageBlockParams : Encodable {
        var sessionId: String
        var imageBlockNum: Int
        var withMetadata: Bool
    }
}

struct ReadImageBlockResponse : Codable {
    var commandId: String
    var kind: String
    var method: String
    var results: ReadImageBlockResults
    
    struct ReadImageBlockResults : Codable {
        var success: Bool
        var session: SessionResponse
        var metadata: ImageMetadata
    }
    
    struct SessionEvent : Codable {
        var event: String
        var session: SessionResponse
    }
    
    struct ImageMetadata: Codable {
        var image: ImageInfo?
        var address: ImageAddress
    }
    
    struct ImageInfo : Codable {
        var pixelOffsetX: Int
        var pixelOffsetY: Int
        var pixelFormat: String
        var pixelWidth: Int
        var pixelHeight: Int
        var compression: String
        var resolution: Int
    }
    
    enum MoreParts: String, Codable {
        case lastPartInFile
        case lastPartInFileMorePartsPending
        case morePartsPending
    }
    
    struct ImageAddress : Codable {
        var moreParts: MoreParts
        var sheetNumber: Int
        var imageNumber: Int
        var imagePart: Int
        var pixelFormatName: String
        var source: String
        var sourceName: String
        var streamName: String
    }
}

struct DownloadedBlockInfo {
    // Block number
    let blockNum: Int
    
    // JSON response as received
    let metadata: Data
    
    // Decoded JSON response
    let response: ReadImageBlockResponse
    
    // Where the PDF was saved
    let pdfPath: URL
}

/**
 Managed by a Session, the BlockDownloader keeps track of the blocks that are available,
 and manages downloading, re-assembling and delivering them to the client application.
 */
class BlockDownloader {
    let lock = NSRecursiveLock()
    
    // Block numbers < this value have been downloaded, assembled, and delivered
    // to the application.
    var highestBlockCompleted = 1

    // Maximum number of blocks we can be downloading at once
    var windowSize = 3

    // Blocks that the scanner has indicated are ready, and our current status.
    var blockStatus = [Int:BlockStatus]()

    // Blocks that we've downloaded but not yet delivered
    var downloadedBlocks = [Int:DownloadedBlockInfo]()
    
    // Updated as downloads are queued and complete
    var activeDownloadCount = 0
    
    // The session this downloader is working with
    weak var session: Session?

    var tempFolder: URL
    
    init(session: Session) {
        
        self.session = session
        
        tempFolder = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TDScans.xxx")!
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true, attributes: nil)
    }
    
    deinit {
        try? FileManager.default.removeItem(at: tempFolder)
    }
    
    func enqueueBlocks(_ blocks: [Int]) {
        lock.lock()
        defer { lock.unlock() }
        
        for block in blocks {
            if (blockStatus[block] == nil) {
                blockStatus[block] = .readyToDownload
                log.info("Enqueueing download of block \(block)")
            }
        }
        
        for _ in 0..<windowSize {
            download()
        }
    }
    
    // This function starts a download if we're not already at the configured maximum number
    // of concurrent downloads. It takes the next block that's in the readyToDownload state,
    // and starts downloading it.
    func download() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let session = session,
            let sessionID = session.sessionID else {
            // No session, can't download
            return
        }
        
        if (activeDownloadCount > windowSize) {
            // Can't start any more downloads right now
            return
        }
        
        // Find the lowest block number that's not already downloading
        var blockToDownload:Int?
        for blockNum in blockStatus.keys.sorted() {
            if blockStatus[blockNum] == .readyToDownload {
                // Found one
                blockToDownload = blockNum
                break
            }
        }
        
        guard let blockNum = blockToDownload else {            // Nothing ready to download
            return
        }
        
        var request: URLRequest
        do {
            request = try session.createURLRequest(method: "POST")
        } catch {
            return
        }
        
        func downloadError(_ error: Error) {
            lock.lock()
            blockStatus[blockNum] = .readyToDownload
            lock.unlock()
            session.delegate?.session(session, didEncounterError: error)
        }
        
        log.info("Starting download of block \(blockNum)")
        let body = ReadImageBlockRequest(sessionId: sessionID, imageBlockNum: blockNum)
        request.httpBody = try? JSONEncoder().encode(body)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, let urlResponse = response as? HTTPURLResponse else {
                downloadError(BlockDownloaderError.noResponseBody)
                return
            }
            
            // We have the HTTP response body, containing the MIME multipart/mixed body with
            // the metadata and the binary payload. Use MultipartExtractor to parse and separate.
            var json: Data
            var pdf: Data
            
            do {
                let r = try MultipartExtractor.extract(from: urlResponse, data: data)
                json = r.json
                pdf = r.pdf
            } catch {
                downloadError(error)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(ReadImageBlockResponse.self, from: json)
                if (!result.results.success) {
                    log.error("Failure downloading block: \(result)")
                    downloadError(BlockDownloaderError.downloadFailed)
                    return
                }
                
                let tempPDF = self.tempFolder.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
                log.info("Writing PDF for block \(blockNum) to \(tempPDF)")
                try? pdf.write(to: tempPDF)
                
                self.lock.lock()
                
                // There may not be more parts, but this signals to deliverCompletedBlocks that this
                // part is all here.
                self.blockStatus[blockNum] = .waitingForMoreParts
                
                // Release
                session.releaseImageBlocks(from: blockNum, to: blockNum, completion: { (result) in
                    switch (result) {
                    case .Success:
                        log.info("Released image block \(blockNum)")
                        break;
                    case .Failure(let error):
                        log.error("Error releasing block \(blockNum): \(String(describing:error))")
                        if let error = error {
                            downloadError(error);
                        } else {
                            downloadError(BlockDownloaderError.releaseImageBlocksFailed);
                        }
                    }
                })
                
                self.downloadedBlocks[blockNum] = DownloadedBlockInfo(blockNum: blockNum, metadata: json, response: result, pdfPath: tempPDF)
                
                self.activeDownloadCount = self.activeDownloadCount - 1
                
                self.lock.unlock()
                
                self.deliverCompletedBlocks()
                
                // Kick off the next one
                self.download()
            } catch {
                log.error("Error decoding response: \(error)")
                self.lock.lock()
                self.activeDownloadCount = self.activeDownloadCount - 1
                self.blockStatus[blockNum] = .readyToDownload
                self.lock.unlock()
                return
            }
        }

        task.resume()

        // Mark this block as downloading
        blockStatus[blockNum] = .downloading
        activeDownloadCount = activeDownloadCount + 1
    }

    // Check for images that we hae all the required parts of to delier
    // a file to the app. Assemble, if required, deliver, and delete the parts.
    func deliverCompletedBlocks() {
        lock.lock()
        defer { lock.unlock() }
        
        // First part,
        var partsToAssemble = 0
        var nextBlock = 0
        for blockNum in highestBlockCompleted... {
            guard let downloadedBlockInfo = downloadedBlocks[blockNum] else {
                // Missing piece, not ready to deliver
                return
            }
            
            partsToAssemble = partsToAssemble + 1
            
            let metadata = downloadedBlockInfo.response.results.metadata
            if metadata.address.moreParts != .morePartsPending {
                // This is the last piece of this PDF, although there may be
                // more PDFs in the entire image.  We can deliver this.
                nextBlock = blockNum + 1
                break
            }
        }

        // Use the metadata from the first part to build the filename
        guard let firstMeta = downloadedBlocks[highestBlockCompleted] else {
            session?.delegate?.session(session!, didEncounterError: BlockDownloaderError.missingMetadata)
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmSS"
        let address = firstMeta.response.results.metadata.address
        let fileName = "\(formatter.string(from: Date()))-\(address.sheetNumber)-\(address.imageNumber)-\(address.imagePart).pdf"
        
        // Rename the first part
        let fm = FileManager.default
        let destURL = tempFolder.appendingPathComponent(fileName)
        try! fm.moveItem(at:firstMeta.pdfPath, to: destURL)
        
        // Concatenate subsequent parts
        if (partsToAssemble > 1) {
            do {
                let chunkSize = 128*1024
                let outfh = try FileHandle(forUpdating: destURL)
                outfh.seekToEndOfFile()
                
                // We will be updating downloadedBlocks as we concatenate
                lock.lock()
                defer { lock.unlock() }
                
                for block in highestBlockCompleted + 1 ..< nextBlock {
                    if let blockInfo = downloadedBlocks[block] {
                        let infh = try FileHandle(forReadingFrom: blockInfo.pdfPath)
                        var data = infh.readData(ofLength: chunkSize)
                        while (data.count > 0) {
                            outfh.write(data)
                            data = infh.readData(ofLength: chunkSize)
                        }
                        infh.closeFile()
                        try FileManager.default.removeItem(at: blockInfo.pdfPath)
                    }
                    downloadedBlocks.removeValue(forKey: block)
                }
                outfh.closeFile()
            } catch {
                log.error("Error concatenating files: \(error)")
                if let session = session {
                    session.delegate?.session(session, didEncounterError: error)
                }
                highestBlockCompleted = nextBlock
                return
            }
        }
      
        // Deliver
        if let session = session {
            session.delegate?.session(session, didReceive: destURL, metadata: firstMeta.metadata)
        }
    }
}

