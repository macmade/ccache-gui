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

@NSApplicationMain class ApplicationDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate
{
    @objc private dynamic var statusItem:             NSStatusItem?
    @objc private dynamic var aboutWindowController:  AboutWindowController?
    @objc private dynamic var mainViewController:     MainViewController?
    @objc private dynamic var popover:                NSPopover?
    @objc private dynamic var popoverTranscientEvent: Any?
    @objc private dynamic var popoverIsOpen:          Bool = false
    @objc private dynamic var didFinishLaunching:     Bool = false
    
    @objc public dynamic var startAtLogin: Bool = false
    {
        didSet
        {
            if self.startAtLogin
            {
                NSApp.enableLoginItem()
            }
            else
            {
                NSApp.disableLoginItem()
            }
        }
    }
    
    @objc private dynamic var popoverWindow: NSWindow?
    {
        didSet
        {
            if let window = self.popoverWindow
            {
                self.popoverWindowVisibilityObserver = window.observe( \.isVisible )
                {
                    [ weak self ] _, _ in guard let self = self else { return }
                    
                    if window.contentView !== self.mainViewController?.view
                    {
                        self.popoverWindow?.contentView = self.popover?.contentViewController?.view
                        self.popover                    = nil
                        self.popoverIsOpen              = false
                    }
                }
            }
            else
            {
                self.popoverWindowVisibilityObserver = nil
            }
        }
    }
    
    private var popoverWindowVisibilityObserver: NSKeyValueObservation?
    
    @IBAction public func showAboutWindow( _ sender: Any? )
    {
        if self.aboutWindowController == nil
        {
            self.aboutWindowController = AboutWindowController()
            
            self.aboutWindowController?.window?.layoutIfNeeded()
        }
        
        if self.aboutWindowController?.window?.isVisible == false
        {
            self.aboutWindowController?.window?.center()
        }
        
        self.closePopover( sender )
        self.aboutWindowController?.window?.makeKeyAndOrderFront( sender )
    }
    
    @IBAction public func openPopover( _ sender: Any? )
    {
        if self.popoverWindow != nil && self.popoverWindow?.contentView !== self.mainViewController?.view
        {
            self.popoverWindow = nil
        }
        
        if let popoverWindow = self.popoverWindow
        {
            NSApp.activate( ignoringOtherApps: true )
            popoverWindow.makeKeyAndOrderFront( sender )
        }
        else if let popover = self.popover, popover.isShown
        {
            self.togglePopover( sender )
        }
    }
    
    @IBAction public func closePopover( _ sender: Any? )
    {
        if let popover = self.popover, popover.isShown
        {
            popover.close()
        }
    }
    
    @IBAction private func togglePopover( _ sender: Any? )
    {
        let view = self.statusItem?.button
        
        if self.popoverWindow != nil && self.popoverWindow?.contentView !== self.mainViewController?.view
        {
            self.popoverWindow = nil
        }
        
        if let popoverWindow = self.popoverWindow
        {
            NSApp.activate( ignoringOtherApps: true )
            popoverWindow.makeKeyAndOrderFront( sender )
        }
        else if let popover = self.popover, popover.isShown
        {
            popover.close()
        }
        else if view != nil
        {
            if self.popover == nil
            {
                self.popover                        = NSPopover()
                self.popover?.behavior              = .applicationDefined
                self.popover?.contentViewController = self.mainViewController
                self.popover?.delegate              = self
            }
            
            if self.statusItem != nil
            {
                self.popover?.show( relativeTo: self.statusItem!.button!.frame, of: view!, preferredEdge: .minY )
            }
        }
    }
    
    // MARK: NSApplicationDelegate
    
    func applicationDidFinishLaunching( _ notification: Notification )
    {
        AppInstaller.installIfNecessary()
        
        self.startAtLogin       = NSApp.isLoginItemEnabled()
        self.statusItem         = NSStatusBar.system.statusItem( withLength: NSStatusItem.squareLength )
        self.statusItem?.image  = NSImage( named: NSImage.Name( "StatusIconTemplate" ) )
        self.statusItem?.target = self
        self.statusItem?.action = #selector( togglePopover )
        self.mainViewController = MainViewController()
        self.didFinishLaunching = true;
    }
    
    func applicationWillTerminate( _ notification: Notification )
    {
        if self.didFinishLaunching
        {
            NotificationCenter.default.removeObserver( self )
        }
    }
    
    // MARK: NSWindowDelegate
    
    func windowWillClose( _ notification: Notification )
    {
        if let window = self.popoverWindow, notification.object as AnyObject === window
        {
            window.delegate    = nil
            self.popoverWindow = nil
        }
    }
    
    // MARK: NSPopoverDelegate
    
    func popoverShouldDetach( _ popover: NSPopover ) -> Bool
    {
        true
    }
    
    func detachableWindow( for popover: NSPopover ) -> NSWindow?
    {
        if popover.contentViewController == nil
        {
            return nil
        }
        
        if self.popoverWindow != nil
        {
            return self.popoverWindow
        }
        
        let mask: NSWindow.StyleMask = [ .titled, .closable, .miniaturizable, .fullSizeContentView ]
        let window                   = NSWindow( contentRect: popover.contentViewController!.view.bounds, styleMask: mask, backing: .buffered, defer: false )
        
        window.delegate                   = self
        window.isReleasedWhenClosed       = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility            = .hidden
        window.title                      = Bundle.main.object( forInfoDictionaryKey: "CFBundleName" ) as? String ?? ""
        
        NotificationCenter.default.removeObserver( self, name: NSPopover.willShowNotification,  object: self.popover )
        NotificationCenter.default.removeObserver( self, name: NSPopover.willCloseNotification, object: self.popover )
        
        self.popoverWindow = window
        
        return window
    }
    
    func popoverWillShow( _ notification: Notification )
    {
        self.popoverTranscientEvent = NSEvent.addGlobalMonitorForEvents( matching: .leftMouseUp )
        {
            _ in self.popover?.close()
        }
    }
    
    func popoverDidShow( _ notification: Notification )
    {
        self.popoverIsOpen = true
    }
    
    func popoverDidClose( _ notification: Notification )
    {
        if self.popoverTranscientEvent != nil
        {
            NSEvent.removeMonitor( self.popoverTranscientEvent! )
        }
        
        self.popoverIsOpen          = false
        self.popover                = nil
        self.popoverTranscientEvent = nil
    }
}
