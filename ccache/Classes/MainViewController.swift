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

import Cocoa
import GitHubUpdates

class MainViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource
{
    @objc private dynamic var awake:           Bool              = false
    @objc private dynamic var installed:       Bool              = CCache.sharedInstance.installed
    @objc private dynamic var running:         Bool              = false
    @objc private dynamic var headerRowHeight: CGFloat           = 25.0
    @objc private dynamic var rowHeight:       CGFloat           = 17.0
    @objc private dynamic var tableViewHeight: CGFloat           = 0.0
    @objc private dynamic var statistics:      [ StatisticItem ] = []
    
    @objc private dynamic var timer:   Timer?
    @objc private dynamic var updater: GitHubUpdater?
    
    @IBOutlet @objc private dynamic var statisticsController: NSArrayController?
    @IBOutlet @objc private dynamic var tableView:            NSTableView?
    
    override func awakeFromNib()
    {
        if self.awake
        {
            return
        }
        
        self.awake               = true
        self.updater             = GitHubUpdater()
        self.updater?.user       = "macmade"
        self.updater?.repository = "ccache-gui"
        self.tableViewHeight     = self.tableView?.enclosingScrollView?.constantForAttribute( .height ) ?? 0.0
    
        self.updateStatistics()
        self.updater?.checkForUpdatesInBackground()
        
        Timer.scheduledTimer( withTimeInterval: 3600, repeats: true )
        {
            _ in self.updater?.checkForUpdatesInBackground()
        }
    }
    
    override func viewDidAppear()
    {
        super.viewDidAppear()
        
        if self.timer == nil
        {
            self.timer = Timer.scheduledTimer( withTimeInterval: 1, repeats: true )
            {
                _ in self.updateStatistics()
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
            if button.menu == nil || NSApp.currentEvent == nil
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
            _ in
            
            self.updateStatistics()
            
            self.running = false
        }
    }
    
    @IBAction private func clear( _ sender: Any? )
    {
        self.running = true
        
        CCache.sharedInstance.clear()
        {
            _ in
            
            self.updateStatistics()
            
            self.running = false
        }
    }
    
    @IBAction private func resetStatistics( _ sender: Any? )
    {
        self.running = true
        
        CCache.sharedInstance.clearStatistics()
        {
            _ in
            
            self.updateStatistics()
            
            self.running = false
        }
    }
    
    private func updateStatistics()
    {
        CCache.sharedInstance.getStatistics()
        {
            success, statistics in
            
            if success == false || statistics.count == 0
            {
                return
            }
            
            let lines = statistics.components( separatedBy: "\n" ).filter
            {
                $0.trimmingCharacters( in: .whitespaces ).isEmpty == false
            }
            
            let items: [ StatisticItem ] = lines.compactMap
            {
                if $0.contains( ":" ) == false
                {
                    return nil
                }
                
                let parts = $0.components( separatedBy: ":" )
                let label = parts.first ?? ""
                let text  = parts.count == 1 ? "" : parts.last ?? ""
                let item  = StatisticItem( label: label, text: text, tooltip: nil )
                
                return item
            }
            
            if items.count > 0 && items != self.statistics
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
        if let url = URL( string : "https://ccache.samba.org/manual.html" )
        {
            NSWorkspace.shared.open( url )
        }
    }
    
    @IBAction private func install( _ sender: Any? )
    {
        if let url = URL( string : "https://brew.sh" )
        {
            NSWorkspace.shared.open( url )
        }
    }
    
    @objc private dynamic var xcodeDerivedDataPath: String?
    {
        if let library = NSSearchPathForDirectoriesInDomains( .libraryDirectory, .userDomainMask, true ).first, FileManager.default.fileExists( atPath: library )
        {
            var path: NSString = library as NSString
            
            path = path.appendingPathComponent( "Developer"   ) as NSString
            path = path.appendingPathComponent( "Xcode"       ) as NSString
            path = path.appendingPathComponent( "DerivedData" ) as NSString
            
            var isDir: ObjCBool = false
            
            if path.length != 0 && FileManager.default.fileExists( atPath: path as String, isDirectory: &isDir ) && isDir.boolValue
            {
                return path as String
            }
        }
        
        return nil
    }
    
    @objc private dynamic var xcodeDerivedDataURL:  URL?
    {
        if let path = self.xcodeDerivedDataPath
        {
            return NSURL.fileURL( withPath: path )
        }
        
        return nil
    }
    
    @IBAction private func clearXcodeDerivedData( _ sender: Any? )
    {
        guard let path = self.xcodeDerivedDataPath else
        {
            self.alertForMissingXcodeDerivedDataDirectory()
            
            return
        }
        
        self.running = true
        
        DispatchQueue.global( qos: .userInitiated ).async
        {
            do
            {
                for sub in try FileManager.default.contentsOfDirectory( atPath: path )
                {
                    try FileManager.default.removeItem( atPath: ( path as NSString ).appendingPathComponent( sub ) )
                }
            }
            catch let error as NSError
            {
                DispatchQueue.main.async
                {
                    NSAlert( error: error ).runModal()
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
        guard let path = self.xcodeDerivedDataPath else
        {
            self.alertForMissingXcodeDerivedDataDirectory()
            
            return
        }
        
        ( NSApp.delegate as? ApplicationDelegate )?.closePopover( sender )
        NSWorkspace.shared.selectFile( nil, inFileViewerRootedAtPath: path )
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
        if self.installed && self.statistics.count != 0
        {
            guard let items = self.statisticsController?.arrangedObjects as? [ StatisticItem ] else
            {
                return
            }
            
            let headers = items.filter { $0.text.isEmpty }
            let stats   = items.filter { $0.text.isEmpty == false }
            let height  = CGFloat( headers.count ) * self.headerRowHeight + CGFloat( stats.count ) * self.rowHeight
            
            self.tableView?.enclosingScrollView?.setConstant( height, forAttribute: .height )
        }
        else
        {
            self.tableView?.enclosingScrollView?.setConstant( self.tableViewHeight, forAttribute: .height )
        }
    }
    
    // MARK: NSTableViewDelegate
    
    func tableView( _ tableView: NSTableView, heightOfRow row: Int ) -> CGFloat
    {
        guard let items = self.statisticsController?.arrangedObjects as? [ StatisticItem ] else
        {
            return self.rowHeight
        }
        
        if row >= items.count
        {
            return self.rowHeight
        }
        
        return items[ row ].text.isEmpty ? self.headerRowHeight : self.rowHeight
    }
    
    func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int ) -> NSView?
    {
        guard let items = self.statisticsController?.arrangedObjects as? [ StatisticItem ] else
        {
            return nil
        }
        
        if row >= items.count
        {
            return nil
        }
        
        if items[ row ].text.isEmpty
        {
            return tableView.makeView( withIdentifier: NSUserInterfaceItemIdentifier( "HeaderCell" ), owner: self )
        }
        
        return tableView.makeView( withIdentifier: NSUserInterfaceItemIdentifier( "DataCell" ), owner: self )
    }
}
