//
//  SwiftUIView.swift
//  
//
//  Created by Mohit Kuldeep on 18/01/24.
//

import Foundation
import os

class LogM {
    static let TAG = "PALogs"
    private static var ENABLE_DEBUG = false
    private static var LOGGER_INITIALISED = false
    private static var customLogger: Any!
    private static let LOG_CATEGORY = "pushalert_logs"

    static func initLogger(){
        if(!LOGGER_INITIALISED){
            if #available(iOS 14.0, *) {
                LOGGER_INITIALISED = true
                LogM.customLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: LogM.LOG_CATEGORY)
            }
            else{
                LOGGER_INITIALISED = false
                LogM.customLogger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: LogM.LOG_CATEGORY)
            }
        }
    }
    
       
    static func enableDebug(enable:Bool){
        ENABLE_DEBUG = enable
    }

    static func error(message:String){
        if(ENABLE_DEBUG) {
            initLogger()
            if #available(iOS 14.0, *) {
                (LogM.customLogger as! Logger).error("\(message)")
            }
            else{
                os_log("%s", log: LogM.customLogger as! OSLog, type: .error, message)
            }
        }
    }
    
    
    
    static func debug(message:String){
        if(ENABLE_DEBUG) {
            initLogger()
            if #available(iOS 14.0, *) {
                (LogM.customLogger as! Logger).debug("\(message)")
            }
            else{
                os_log("%s", log: LogM.customLogger as! OSLog, type: .debug, message)
            }
        }
    }
    
    static func info(message:String){
        if(ENABLE_DEBUG) {
            initLogger()
            if #available(iOS 14.0, *) {
                (LogM.customLogger as! Logger).info("\(message)")
            }
            else{
                os_log("%s", log: LogM.customLogger as! OSLog, type: .info, message)
            }
        }
    }
    
    static func warning(message:String){
        if(ENABLE_DEBUG) {
            initLogger()
            if #available(iOS 14.0, *) {
                (LogM.customLogger as! Logger).warning("\(message)")
            }
        }
    }

    
}
