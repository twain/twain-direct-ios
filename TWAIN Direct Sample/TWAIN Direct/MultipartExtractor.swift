//
//  MultipartExtractor.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-10-12.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import Foundation

/**
 * MIME multipart extractor, which returns the JSON metadata and PDF data from a MIME multipart body.
 * Uses the C based multipart parser (in ThirdParty/multipart) to do the parsing.
 */
class MultipartExtractor {
    fileprivate class Context {
        var fieldName: String?
        var headers = [String:String]()
        var contentType = ""
        
        var json: Data?
        var pdf: Data?
        var current = Data()
        
        func partDataEnd() {
            log.info("part data end, \(current.count) bytes");
            
            // Figure out where the body part should go
            if let contentType = headers["content-type"] {
                if contentType.starts(with: "application/json") {
                    json = current
                } else if contentType.starts(with: "application/pdf") {
                    pdf = current
                }
            }
            
            current = Data()
        }
    }

    // Extract metadata and body from MIME multipart/mixed response body.
    class func extract(from response: HTTPURLResponse, data: Data) throws -> (json: Data, pdf: Data) {
        if response.mimeType != "multipart/mixed" {
            throw BlockDownloaderError.unexpectedMimeType
        }
        
        guard let contentTypeHeader = response.allHeaderFields["Content-Type"] as? String else {
            throw BlockDownloaderError.missingMimeBoundary
        }
        
        guard let range = contentTypeHeader.range(of: "boundary=") else {
            throw BlockDownloaderError.missingMimeBoundary
        }
        
        let quotedBoundary = String(contentTypeHeader[range.upperBound...])
        let boundary = "--" + (quotedBoundary as NSString).trimmingCharacters(in: CharacterSet(charactersIn:"\"'"))
        
        var callbacks = multipart_parser_settings()
        let parser = multipart_parser_init(boundary, &callbacks)
        
        var context = Context()
        
        callbacks.on_header_field = { parser, ptr, count in
            let context = multipart_parser_get_data(parser)?.assumingMemoryBound(to: Context.self)
            let data = Data.init(bytes: ptr!, count: count)
            context?.pointee.fieldName = String(data:data, encoding: .utf8)
            return 0
        }
        
        callbacks.on_header_value = { parser, ptr, count in
            if let context = multipart_parser_get_data(parser)?.assumingMemoryBound(to: Context.self) {
                if let fieldName = context.pointee.fieldName {
                    let data = Data.init(bytes: ptr!, count: count)
                    if let fieldValue = String(data:data, encoding: .utf8) {
                        context.pointee.headers[fieldName.lowercased()] = fieldValue
                    }
                }
            }
            return 0
        }
        
        callbacks.on_part_data_begin = { parser in
            let context = multipart_parser_get_data(parser)?.assumingMemoryBound(to: Context.self)
            context?.pointee.headers.removeAll()
            return 0
        }
        
        callbacks.on_headers_complete = { parser in
            if let context = multipart_parser_get_data(parser)?.assumingMemoryBound(to: Context.self) {
                context.pointee.current = Data()
            }
            
            return 0
        }
        
        callbacks.on_part_data_end = { parser in
            if let context = multipart_parser_get_data(parser)?.assumingMemoryBound(to: Context.self).pointee {
                context.partDataEnd()
            }
            return 0
        }
        
        withUnsafeMutablePointer(to: &context, { (dataPtr) -> Void in
            multipart_parser_set_data(parser, dataPtr)
        })
        
        callbacks.on_part_data = { parser, ptr, count in
            let context = multipart_parser_get_data(parser)?.assumingMemoryBound(to: Context.self)
            ptr?.withMemoryRebound(to: UInt8.self, capacity: count, { (p) -> Void in
                context?.pointee.current.append(p, count: count)
            })
            return 0
        }
        
        let _ = data.withUnsafeBytes {
            multipart_parser_execute(parser, UnsafePointer($0), data.count)
        }
        
        if (context.current.count > 0) {
            context.partDataEnd()
        }
        multipart_parser_free(parser)
        
        // Remove the trailing crlf that ends the body part
        context.pdf?.removeLast(2)
        
        return (context.json!, context.pdf!)
    }
}
