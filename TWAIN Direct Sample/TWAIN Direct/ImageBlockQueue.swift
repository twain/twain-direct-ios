//
//  ImageBlockQueue.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-26.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import Foundation

/**
 Images are delivered in blocks.
 
 Each block is either a complete image, or a part of an image. If an image is
 delivered in multiple parts, we have to assemble (concatenate) the parts once
 we have them all.
*/

struct ImageBlockInfo {
    
}

