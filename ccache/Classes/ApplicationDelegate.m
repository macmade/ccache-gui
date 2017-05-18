/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www-xs-labs.com
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
 * @file        ApplicationDelegate.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com / www.imazing.com
 */

#import "ApplicationDelegate.h"
#import "MainViewController.h"
#import "AboutWindowController.h"
#import "NSApplication+LaunchServices.h"
#import "AppInstaller.h"

NS_ASSUME_NONNULL_BEGIN

@interface ApplicationDelegate() < NSPopoverDelegate, NSWindowDelegate >

@property( atomic, readwrite, strong           ) NSStatusItem          * statusItem;
@property( atomic, readwrite, strong           ) AboutWindowController * aboutWindowController;
@property( atomic, readwrite, strong           ) MainViewController    * mainViewController;
@property( atomic, readwrite, strong, nullable ) NSWindow              * popoverWindow;
@property( atomic, readwrite, strong, nullable ) NSPopover             * popover;
@property( atomic, readwrite, strong, nullable ) id                      popoverTranscientEvent;
@property( atomic, readwrite, assign           ) BOOL                    popoverIsOpen;
@property( atomic, readwrite, assign           ) BOOL                    didFinishLaunching;

- ( IBAction )togglePopover: ( nullable id )sender;

@end

NS_ASSUME_NONNULL_END

@implementation ApplicationDelegate

- ( void )applicationDidFinishLaunching: ( NSNotification * )notification
{
    ( void )notification;
    
    [ AppInstaller installIfNecessary ];
    
    self.startAtLogin       = [ NSApp isLoginItemEnabled ];
    self.statusItem         = [ [ NSStatusBar systemStatusBar ] statusItemWithLength: NSSquareStatusItemLength ];
    self.statusItem.image   = [ NSImage imageNamed: @"StatusIconTemplate" ];
    self.statusItem.target  = self;
    self.statusItem.action  = @selector( togglePopover: );
    self.mainViewController = [ MainViewController new ];
    
    [ self addObserver: self forKeyPath: NSStringFromSelector( @selector( startAtLogin ) ) options: 0 context: NULL ];
    
    self.didFinishLaunching = YES;
}

- ( void )applicationWillTerminate: ( NSNotification * )notification
{
    ( void )notification;
    
    if( self.didFinishLaunching )
    {
        [ [ NSNotificationCenter defaultCenter ] removeObserver: self ];
        [ self removeObserver: self forKeyPath: NSStringFromSelector( @selector( startAtLogin ) ) ];
        [ self.popoverWindow removeObserver: self forKeyPath: @"visible" ];
    }
}

- ( void )observeValueForKeyPath: ( NSString * )keyPath ofObject: ( id )object change: ( NSDictionary< NSKeyValueChangeKey, id > * )change context: ( void * )context
{
    if( object == self && [ keyPath isEqualToString: NSStringFromSelector( @selector( startAtLogin ) ) ] )
    {
        if( self.startAtLogin )
        {
            [ NSApp enableLoginItem ];
        }
        else
        {
            [ NSApp disableLoginItem ];
        }
    }
    else if( object == self.popoverWindow && [ keyPath isEqualToString: @"visible" ] )
    {
        if( self.popoverWindow.contentView != self.mainViewController.view )
        {
            self.popoverWindow.contentView = self.popover.contentViewController.view;
            self.popover                   = nil;
            self.popoverIsOpen             = NO;
        }
    }
    else
    {
        [ super observeValueForKeyPath: keyPath ofObject: object change: change context: context ];
    }
}

- ( IBAction )showAboutWindow: ( nullable id )sender
{
    if( self.aboutWindowController == nil )
    {
        self.aboutWindowController = [ AboutWindowController new ];
    }
    
    if( self.aboutWindowController.window.isVisible == NO )
    {
        [ self.aboutWindowController.window center ];
    }
    
    [ self closePopover: sender ];
    [ self.aboutWindowController.window makeKeyAndOrderFront: sender ];
}

- ( IBAction )openPopover: ( nullable id )sender
{
    if( self.popoverWindow != nil )
    {
        [ NSApp activateIgnoringOtherApps: YES ];
        [ self.popoverWindow makeKeyAndOrderFront: sender ];
    }
    else if( self.popover.isShown == NO )
    {
        [ self togglePopover: sender ];
    }
}

- ( IBAction )closePopover: ( nullable id )sender
{
    ( void )sender;
    
    if( self.popover.isShown )
    {
        [ self.popover close ];
    }
}

- ( IBAction )togglePopover: ( nullable id )sender
{
    NSView * view;
    
    view = self.statusItem.view;
    
    if( view == nil && [ self.statusItem respondsToSelector: @selector( button ) ] )
    {
        view = [ self.statusItem performSelector: @selector( button ) ];
    }
    
    if( self.popoverWindow != nil )
    {
        [ NSApp activateIgnoringOtherApps: YES ];
        [ self.popoverWindow makeKeyAndOrderFront: sender ];
    }
    else if( self.popover.isShown )
    {
        [ self.popover close ];
    }
    else if( view )
    {
        if( self.popover == nil )
        {
            self.popover                        = [ NSPopover new ];
            self.popover.behavior               = NSPopoverBehaviorApplicationDefined;
            self.popover.contentViewController  = self.mainViewController;
            self.popover.delegate               = self;
            
            [ [ NSNotificationCenter defaultCenter ] addObserver: self selector: @selector( popoverNotification: ) name: NSPopoverWillShowNotification  object: self.popover ];
            [ [ NSNotificationCenter defaultCenter ] addObserver: self selector: @selector( popoverNotification: ) name: NSPopoverWillCloseNotification object: self.popover ];
        }
        
        [ self.popover showRelativeToRect: self.statusItem.view.frame ofView: view preferredEdge: NSRectEdgeMinY ];
    }
}

- ( void )popoverNotification: ( NSNotification * )notification
{
    if( [ notification.name isEqualToString: NSPopoverWillShowNotification ] || [ notification.name isEqualToString: NSPopoverWillCloseNotification ] )
    {
        self.popoverIsOpen = !( self.popoverIsOpen );
    }
}

#pragma mark - NSWindowDelegate

- ( void )windowWillClose: ( NSNotification * )notification
{
    if( notification.object == self.popoverWindow )
    {
        [ self.popoverWindow removeObserver: self forKeyPath: @"visible" ];
        
        self.popoverWindow.delegate = nil;
        self.popoverWindow          = nil;
    }
}

#pragma mark - NSPopoverDelegate

- ( BOOL )popoverShouldDetach: ( NSPopover * )popover
{
    ( void )popover;
    
    return YES;
}

- ( NSWindow * )detachableWindowForPopover: ( NSPopover * )popover
{
    NSWindow * window;
    NSUInteger mask;
    
    if( self.popoverWindow )
    {
        [ self.popoverWindow removeObserver: self forKeyPath: @"visible" ];
        
        self.popoverWindow = nil;
    }
    
    mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskFullSizeContentView;
    
    window                            = [ [ NSWindow alloc ] initWithContentRect: popover.contentViewController.view.bounds styleMask: mask backing: NSBackingStoreBuffered defer: NO ];
    window.delegate                   = self;
    window.releasedWhenClosed         = NO;
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility            = NSWindowTitleHidden;
    window.title                      = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleName" ];
    
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self name: NSPopoverWillShowNotification  object: self.popover ];
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self name: NSPopoverWillCloseNotification object: self.popover ];
    
    self.popoverWindow = window;
    
    [ self.popoverWindow addObserver: self forKeyPath: @"visible" options: 0 context: NULL ];
    
    return window;
}

- ( void )popoverWillShow: ( NSNotification * )notification
{
    ( void )notification;
    
    self.popoverTranscientEvent = [ NSEvent addGlobalMonitorForEventsMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp handler:
        ^( NSEvent * e )
        {
            ( void )e;
            
            [ self.popover close ];
        }
    ];
}

- ( void )popoverDidClose: ( NSNotification * )notification
{
    ( void )notification;
    
    if( self.popoverTranscientEvent )
    {
        [ NSEvent removeMonitor: ( id )( self.popoverTranscientEvent ) ];
    }
    
    self.popover                = nil;
    self.popoverTranscientEvent = nil;
}

@end
