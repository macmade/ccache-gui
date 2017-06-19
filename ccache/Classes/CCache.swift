/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www.xs-labs.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

/*!
 * @file        CCache.swift
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com / www.imazing.com
 */

import Foundation

class CCache: NSObject
{
    @objc public dynamic private( set ) var installed: Bool = false
    @objc public dynamic private( set ) var path:      String?
    
    static public let sharedInstance = CCache()
    
    override init()
    {
        super.init()
        
        if let shell = ProcessInfo.processInfo.environment[ "SHELL" ] as String?
        {
            if( shell.count == 0 )
            {
                return
            }
            
            let pipe = Pipe()
            let task = Process()
            
            task.launchPath     = shell
            task.arguments      = [ "-l", "-c", "which ccache" ]
            task.standardOutput = pipe;
            
            task.launch()
            task.waitUntilExit()
            
            if( task.terminationStatus == EXIT_SUCCESS )
            {
                var output = String( data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: String.Encoding.utf8 )
                    output = output?.trimmingCharacters( in: CharacterSet.whitespacesAndNewlines )
                
                if( output?.count != 0 && FileManager.default.fileExists( atPath: output! ) )
                {
                    self.path      = output
                    self.installed = true
                }
            }
        }
    }
    
    private func execute( arguments: [ String ], completion: @escaping ( Int32, FileHandle?, FileHandle? ) -> Void )
    {
        if( self.installed == false )
        {
            completion( EXIT_FAILURE, nil, nil )
            
            return
        }
        
        DispatchQueue.global( qos: .userInitiated ).async
        {
            let task = Process()
            let p1   = Pipe()
            let p2   = Pipe()
            
            task.launchPath     = self.path
            task.arguments      = arguments
            task.standardOutput = p1
            task.standardError  = p2
            
            task.launch()
            task.waitUntilExit()
            
            DispatchQueue.main.async
            {
                completion( task.terminationStatus, p1.fileHandleForReading, p2.fileHandleForReading )
            }
        }
    }
    
    public func cleanup( completion: ( ( Bool ) -> Void )? )
    {
        self.execute( arguments: [ "-c" ] )
        {
            ( status: Int32, output: FileHandle?, error: FileHandle? ) -> Void in
            
            completion?( status == 0 )
        }
    }
    
    public func clear( completion: ( ( Bool ) -> Void )? )
    {
        self.execute( arguments: [ "-C" ] )
        {
            ( status: Int32, output: FileHandle?, error: FileHandle? ) -> Void in
            
            completion?( status == 0 )
        }
    }
    
    public func clearStatistics( completion: ( ( Bool ) -> Void )? )
    {
        self.execute( arguments: [ "-z" ] )
        {
            ( status: Int32, output: FileHandle?, error: FileHandle? ) -> Void in
            
            completion?( status == 0 )
        }
    }
    
    public func getStatistics( completion: ( ( Bool, String ) -> Void )? )
    {
        self.execute( arguments: [ "-s" ] )
        {
            ( status: Int32, output: FileHandle?, error: FileHandle? ) -> Void in
            
            if( status == 0 )
            {
                let str = String( data: output?.readDataToEndOfFile() ?? Data(), encoding: String.Encoding.utf8 )
                
                completion?( true, str ?? "" )
            }
            else
            {
                completion?( false, "" )
            }
        }
    }
}
