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

import Foundation

class CCache: NSObject
{
    @objc public dynamic private( set ) var installed: Bool = false
    @objc public dynamic private( set ) var path:      String?
    
    static public let sharedInstance = CCache()
    
    private override init()
    {
        super.init()
        
        guard let shell = ProcessInfo.processInfo.environment[ "SHELL" ] as String?, shell.count > 0 else
        {
            return
        }
        
        let pipe            = Pipe()
        let task            = Process()
        task.launchPath     = shell
        task.arguments      = [ "-l", "-c", "which ccache" ]
        task.standardOutput = pipe;
        
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus == EXIT_SUCCESS
        {
            let data   = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String( data: data, encoding: String.Encoding.utf8 )?.trimmingCharacters( in: CharacterSet.whitespacesAndNewlines )
            
            if let output = output, output.isEmpty == false && FileManager.default.fileExists( atPath: output )
            {
                self.path      = output
                self.installed = true
            }
        }
        
        if self.installed == false
        {
            if FileManager.default.fileExists( atPath: "/opt/local/bin/ccache" )
            {
                self.path      = "/opt/local/bin/ccache"
                self.installed = true
            }
            else if FileManager.default.fileExists( atPath: "/opt/homebrew/bin/ccache" )
            {
                self.path      = "/opt/homebrew/bin/ccache"
                self.installed = true
            }
        }
    }
    
    private func execute( arguments: [ String ], completion: @escaping ( ( status: Int32, output: FileHandle?, error: FileHandle? ) ) -> Void )
    {
        if self.installed == false
        {
            completion( ( EXIT_FAILURE, nil, nil ) )
            
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
                completion( ( task.terminationStatus, p1.fileHandleForReading, p2.fileHandleForReading ) )
            }
        }
    }
    
    public func cleanup( completion: ( ( Bool ) -> Void )? )
    {
        self.execute( arguments: [ "-c" ] )
        {
            completion?( $0.status == 0 )
        }
    }
    
    public func clear( completion: ( ( Bool ) -> Void )? )
    {
        self.execute( arguments: [ "-C" ] )
        {
            completion?( $0.status == 0 )
        }
    }
    
    public func clearStatistics( completion: ( ( Bool ) -> Void )? )
    {
        self.execute( arguments: [ "-z" ] )
        {
            completion?( $0.status == 0 )
        }
    }
    
    public func getStatistics( completion: ( ( Bool, String ) -> Void )? )
    {
        self.execute( arguments: [ "-s" ] )
        {
            if $0.status == 0
            {
                let str = String( data: $0.output?.readDataToEndOfFile() ?? Data(), encoding: String.Encoding.utf8 )
                
                completion?( true, str ?? "" )
            }
            else
            {
                completion?( false, "" )
            }
        }
    }
}
