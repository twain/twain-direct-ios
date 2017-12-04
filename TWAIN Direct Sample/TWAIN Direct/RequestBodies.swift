//
//  RequestBodies.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-10-06.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import Foundation

// These are serializable structs that represent the JSON requests and
// responses for the TWAIN Direct commands we're using. Not every
// property is represented.

struct InfoExResponse : Decodable {
    enum CodingKeys: String, CodingKey {
        case type
        case version
        case description
        case api
        case manufacturer
        case model
        case privetToken = "x-privet-token"
    }
    var type: String
    var version: String?
    var description: String?
    var api: [String]?
    var manufacturer: String?
    var model: String?
    var privetToken: String
}

struct CloseSessionRequest : Codable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "closeSession"
    var params: CloseSessionParams
    
    init(sessionId: String) {
        params = CloseSessionParams(sessionId: sessionId)
    }
    
    struct CloseSessionParams : Codable {
        var sessionId: String
    }
}

struct CloseSessionResponse : Codable {
    var kind: String
    var commandId: String
    var method: String
    var results: CommandResult
}

struct ReleaseImageBlocksRequest : Codable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "releaseImageBlocks"
    var params: ReleaseImageBlocksParams
    
    init(sessionId: String, fromBlock: Int, toBlock: Int) {
        params = ReleaseImageBlocksParams(sessionId: sessionId, imageBlockNum:fromBlock, lastImageBlockNum:toBlock)
    }
    
    struct ReleaseImageBlocksParams : Codable {
        var sessionId: String
        var imageBlockNum: Int
        var lastImageBlockNum: Int
    }
}

struct ReleaseImageBlocksResponse : Codable {
    var kind: String
    var commandId: String
    var method: String
    var results: CommandResult
}

struct SendTaskRequest : Encodable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "sendTask"
    var params: SendTaskParams
    
    init(sessionId: String, task: [String:Any]) {
        params = SendTaskParams(sessionId: sessionId)
    }
    
    struct SendTaskParams : Encodable {
        var sessionId: String
        
        enum SendTaskParamsKeys: String, CodingKey {
            case sessionId
        }
    }
}

struct SendTaskResponse : Codable {
    var kind: String
    var commandId: String
    var method: String
    var results: CommandResult
}

struct WaitForEventsRequest : Encodable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "waitForEvents"
    var params: WaitForEventsParams
    
    init(sessionId: String, sessionRevision: Int) {
        params = WaitForEventsParams(sessionId: sessionId, sessionRevision: sessionRevision)
    }
    
    struct WaitForEventsParams : Encodable {
        var sessionId: String
        var sessionRevision: Int
    }
}

struct WaitForEventsResponse : Codable {
    var commandId: String
    var kind: String
    var method: String
    var results: WaitForEventsResults
    
    struct WaitForEventsResults : Codable {
        var success: Bool
        var events: [SessionEvent]?
    }
    
    struct SessionEvent : Codable {
        var event: String
        var session: SessionResponse
    }
}

struct CreateSessionRequest : Codable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "createSession"
}

struct CreateSessionResponse : Codable {
    var kind: String
    var commandId: String
    var method: String
    var results: CommandResult
}

struct SessionStatus : Codable, Equatable {
    static func ==(lhs: SessionStatus, rhs: SessionStatus) -> Bool {
        return lhs.success == rhs.success && lhs.detected == rhs.detected
    }
    
    var success: Bool
    var detected: Session.StatusDetected?
}

struct SessionResponse: Codable {
    var sessionId: String
    var revision: Int
    
    var doneCapturing: Bool?
    var imageBlocks: [Int]?
    var imageBlocksDrained: Bool?
    
    var state: Session.State
    var status: SessionStatus
}

struct CommandResult: Codable {
    var success: Bool
    var session: SessionResponse?
    var code: String?
}

struct StartCapturingRequest : Codable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "startCapturing"
    
    var params: StartCapturingParams
    
    init(sessionId: String) {
        params = StartCapturingParams(sessionId: sessionId)
    }
    
    struct StartCapturingParams : Codable {
        var sessionId: String
    }
}

struct StartCapturingResponse : Codable {
    var kind: String
    var commandId: String
    var method: String
    var results: CommandResult
}

struct StopCapturingRequest : Codable {
    var kind = "twainlocalscanner"
    var commandId = UUID().uuidString
    var method = "stopCapturing"
    
    var params: StopCapturingParams
    
    init(sessionId: String) {
        params = StopCapturingParams(sessionId: sessionId)
    }
    
    struct StopCapturingParams : Codable {
        var sessionId: String
    }
}

struct StopCapturingResponse : Codable {
    var kind: String
    var commandId: String
    var method: String
    var results: CommandResult
}
