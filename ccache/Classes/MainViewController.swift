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
 * @file        MainViewController.swift
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com / www.imazing.com
 */

import Cocoa
import GitHubUpdates

class MainViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource
{
    @objc private dynamic var awake:           Bool              = false
    @objc private dynamic var installed:       Bool              = CCache.sharedInstance.installed
    @objc private dynamic var running:         Bool              = false
    @objc private dynamic var rowHeight:       CGFloat           = 17.0
    @objc private dynamic var tableViewHeight: CGFloat           = 0.0
    @objc private dynamic var statistics:      [ StatisticItem ] = []
    
    @objc private dynamic var timer:   Timer?
    @objc private dynamic var updater: GitHubUpdater?
    
    @IBOutlet @objc private dynamic var statisticsController: NSArrayController?
    @IBOutlet @objc private dynamic var tableView:            NSTableView?
    
    static private var tooltips: [ String : String ] =
    [
        "autoconf compile/link"            : "Uncachable compilation or linking by an autoconf test.",
        "bad compiler arguments"           : "Malformed compiler argument, e.g. missing a value for an option that requires an argument or failure to read a file specified by an option argument.",
        "cache file missing"               : "A file was unexpectedly missing from the cache. This only happens in rare situations, e.g. if one ccache instance is about to get a file from the cache while another instance removed the file as part of cache cleanup.",
        "cache hit (direct)"               : "A result was successfully found using the direct mode.",
        "cache hit (preprocessed)"         : "A result was successfully found using the preprocessor mode.",
        "cache miss"                       : "No result was found.",
        "cache size"                       : "Current size of the cache.",
        "called for link"                  : "The compiler was called for linking, not compiling.",
        "called for preprocessing"         : "The compiler was called for preprocessing, not compiling.",
        "can’t use precompiled header"     : "Preconditions for using precompiled headers were not fulfilled.",
        "ccache internal error"            : "Unexpected failure, e.g. due to problems reading/writing the cache.",
        "cleanups performed"               : "Number of cleanups performed, either implicitly due to the cache size limit being reached or due to explicit ccache -c/--cleanup calls.",
        "compile failed"                   : "The compilation failed. No result stored in the cache.",
        "compiler check failed"            : "A compiler check program specified by compiler_check (CCACHE_COMPILERCHECK) failed.",
        "compiler produced empty output"   : "The compiler’s output file (typically an object file) was empty after compilation.",
        "compiler produced no output"      : "The compiler’s output file (typically an object file) was missing after compilation.",
        "compiler produced stdout"         : "The compiler wrote data to standard output. This is something that compilers normally never do, so ccache is not designed to store such output in the cache.",
        "couldn’t find the compiler"       : "The compiler to execute could not be found.",
        "error hashing extra file"         : "Failure reading a file specified by extra_files_to_hash (CCACHE_EXTRAFILES).",
        "files in cache"                   : "Current number of files in the cache.",
        "multiple source files"            : "The compiler was called to compile multiple source files in one go. This is not supported by ccache.",
        "no input file"                    : "No input file was specified to the compiler.",
        "output to a non-regular file"     : "The output path specified with -o is not a file (e.g. a directory or a device node).",
        "output to stdout"                 : "The compiler was instructed to write its output to standard output using -o -. This is not supported by ccache.",
        "preprocessor error"               : "Preprocessing the source code using the compiler’s -E option failed.",
        "unsupported code directive"       : "Code like the assembler “.incbin” directive was found. This is not supported by ccache.",
        "unsupported compiler option"      : "A compiler option not supported by ccache was found.",
        "unsupported source language"      : "A source language e.g. specified with -x was unsupported by ccache."
    ];
    
    override func awakeFromNib()
    {
        if( self.awake )
        {
            return
        }
        
        self.awake                                 = true
        self.updater                               = GitHubUpdater()
        self.updater?.user                         = "macmade"
        self.updater?.repository                   = "ccache-gui"
        self.tableViewHeight                       = self.tableView?.enclosingScrollView?.constantForAttribute( .height ) ?? 0.0
        self.statisticsController?.sortDescriptors = [ NSSortDescriptor( key: "label", ascending: true ) ]
    
        self.updateStatistics()
        self.updater?.checkForUpdatesInBackground()
        
        Timer.scheduledTimer( withTimeInterval: 3600, repeats: true )
        {
            ( timer: Timer ) -> Void in
            
            self.updater?.checkForUpdatesInBackground()
        }
    }
    
    override func viewDidAppear()
    {
        super.viewDidAppear()
        
        if( self.timer == nil )
        {
            self.timer = Timer.scheduledTimer( withTimeInterval: 1, repeats: true )
            {
                ( timer: Timer ) -> Void in
                
                self.updateStatistics()
            }
        }
    }
    
    override func viewDidDisappear()
    {
        super.viewDidDisappear()
        
        self.timer?.invalidate()
        
        self.timer = nil
    }
    
    @IBAction private func showOptionsMenu( _ sender: Any? )
    {
        if let button = sender as? NSButton
        {
            if( button.menu == nil || NSApp.currentEvent == nil )
            {
                return;
            }
            
            NSMenu.popUpContextMenu( button.menu!, with: NSApp.currentEvent!, for: button )
        }
    }
    
    @IBAction private func cleanup( _ sender: Any? )
    {
        self.running = true
        
        CCache.sharedInstance.cleanup()
        {
            ( success: Bool ) -> Void in
            
            self.updateStatistics()
            
            self.running = false
        }
    }
    
    @IBAction private func clear( _ sender: Any? )
    {
        self.running = true
        
        CCache.sharedInstance.clear()
        {
            ( success: Bool ) -> Void in
            
            self.updateStatistics()
            
            self.running = false
        }
    }
    
    @IBAction private func resetStatistics( _ sender: Any? )
    {
        self.running = true
        
        CCache.sharedInstance.clearStatistics()
        {
            ( success: Bool ) -> Void in
            
            self.updateStatistics()
            
            self.running = false
        }
    }
    
    private func updateStatistics()
    {
        CCache.sharedInstance.getStatistics()
        {
            ( success: Bool, statistics: String ) -> Void in
            
            if( success == false || statistics.count == 0 )
            {
                return
            }
            
            let lines = statistics.components( separatedBy: "\n" )
            var items = [ StatisticItem ]()
            
            for line in lines
            {
                let parts = line.components( separatedBy: "  " )
                
                if( parts.count < 2 )
                {
                    continue
                }
                
                let item     = StatisticItem()
                item.label   = parts.first?.trimmingCharacters( in: CharacterSet.whitespaces ).capitalized ?? ""
                item.text    = parts.last?.trimmingCharacters(  in: CharacterSet.whitespaces )             ?? ""
                item.tooltip = MainViewController.tooltips[ item.label.lowercased() ] ?? ""
                
                if( item.label.count != 0 && item.text.count != 0 )
                {
                    items.append( item )
                }
            }
            
            if( items.count > 0 && items != self.statistics )
            {
                self.statisticsController?.remove( contentsOf: self.statistics )
                self.statisticsController?.add( contentsOf: items )
                self.statisticsController?.didChangeArrangementCriteria()
            }
            
            self.adjustTableViewHeight()
        }
    }
    
    @IBAction private func openManual( _ sender: Any? )
    {
        let url = URL( string : "https://ccache.samba.org/manual.html" )
        
        if( url != nil )
        {
            NSWorkspace.shared.open( url! )
        }
    }
    
    @IBAction private func install( _ sender: Any? )
    {
        let url = URL( string : "https://brew.sh" )
        
        if( url != nil )
        {
            NSWorkspace.shared.open( url! )
        }
    }
    
    @objc private dynamic var xcodeDerivedDataPath: String?
    {
        let library = NSSearchPathForDirectoriesInDomains( .libraryDirectory, .userDomainMask, true ).first
        
        if( library?.count != 0 && FileManager.default.fileExists( atPath: library! ) )
        {
            var path: NSString = library! as NSString
            
            path = path.appendingPathComponent( "Developer"   ) as NSString
            path = path.appendingPathComponent( "Xcode"       ) as NSString
            path = path.appendingPathComponent( "DerivedData" ) as NSString
            
            var isDir: ObjCBool = false
            
            if( path.length != 0 && FileManager.default.fileExists( atPath: path as String, isDirectory: &isDir ) && isDir.boolValue )
            {
                return path as String
            }
        }
        
        return nil
    }
    
    @objc private dynamic var xcodeDerivedDataURL:  URL?
    {
        let path = self.xcodeDerivedDataPath
        
        return ( path != nil ) ? NSURL.fileURL( withPath: path! ) : nil
    }
    
    @IBAction private func clearXcodeDerivedData( _ sender: Any? )
    {
        let path = self.xcodeDerivedDataPath
        
        if( path == nil )
        {
            self.alertForMissingXcodeDerivedDataDirectory()
            
            return;
        }
        
        self.running = true
        
        DispatchQueue.global( qos: .userInitiated ).async
        {
            do
            {
                for sub in try FileManager.default.contentsOfDirectory( atPath: path! )
                {
                    try FileManager.default.removeItem( atPath: ( path! as NSString ).appendingPathComponent( sub ) )
                }
            }
            catch let error as NSError
            {
                DispatchQueue.main.async
                {
                    let alert = NSAlert( error: error )
                    
                    alert.runModal()
                }
            }
            
            DispatchQueue.main.async
            {
                self.running = false
            }
        }
    }
    
    @IBAction private func revealXcodeDerivedData( _ sender: Any? )
    {
        let path = self.xcodeDerivedDataPath
        
        if( path == nil )
        {
            self.alertForMissingXcodeDerivedDataDirectory()
            
            return
        }
        
        ( NSApp.delegate as? ApplicationDelegate )?.closePopover( sender )
        NSWorkspace.shared.selectFile( nil, inFileViewerRootedAtPath: path! )
    }
    
    @IBAction private func checkForUpdates( _ sender: Any? )
    {
        ( NSApp.delegate as? ApplicationDelegate )?.closePopover( sender )
        self.updater?.checkForUpdates( sender )
    }
    
    private func alertForMissingXcodeDerivedDataDirectory()
    {
        let alert             = NSAlert()
        alert.messageText     = NSLocalizedString( "No Derived Data", comment: "" )
        alert.informativeText = NSLocalizedString( "The Xcode Derived Data directory does not exist.", comment: "" )
    
        alert.addButton( withTitle: NSLocalizedString( "OK", comment: "" ) )
        ( NSApp.delegate as? ApplicationDelegate )?.closePopover( nil )
        alert.runModal()
    }
    
    private func adjustTableViewHeight()
    {
        if( self.installed && self.statistics.count != 0 )
        {
            self.tableView?.enclosingScrollView?.setConstant( ( CGFloat )( self.statistics.count ) * self.rowHeight, forAttribute: .height )
        }
        else
        {
            self.tableView?.enclosingScrollView?.setConstant( self.tableViewHeight, forAttribute: .height )
        }
    }
    
    // MARK: NSTableViewDelegate
    
    func tableView( _ tableView: NSTableView, heightOfRow row: Int ) -> CGFloat
    {
        return self.rowHeight
    }
}
