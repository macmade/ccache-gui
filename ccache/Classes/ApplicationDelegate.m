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
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com
 */

#import "ApplicationDelegate.h"
#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ApplicationDelegate() < NSPopoverDelegate, NSWindowDelegate >

@property( atomic, readwrite, strong           ) NSStatusItem       * statusItem;
@property( atomic, readwrite, strong           ) MainViewController * mainViewController;
@property( atomic, readwrite, strong, nullable ) NSWindow           * popoverWindow;
@property( atomic, readwrite, strong, nullable ) NSPopover          * popover;
@property( atomic, readwrite, strong, nullable ) id                   popoverTranscientEvent;
@property( atomic, readwrite, assign           ) BOOL                 popoverIsOpen;

- ( IBAction )togglePopover: ( nullable id )sender;

@end

NS_ASSUME_NONNULL_END

@implementation ApplicationDelegate

- ( void )applicationDidFinishLaunching: ( NSNotification * )notification
{
    ( void )notification;
    
    self.statusItem         = [ [ NSStatusBar systemStatusBar ] statusItemWithLength: NSSquareStatusItemLength ];
    self.statusItem.image   = [ NSImage imageNamed: @"StatusIconTemplate" ];
    self.statusItem.target  = self;
    self.statusItem.action  = @selector( togglePopover: );
    self.mainViewController = [ MainViewController new ];
}

- ( void )applicationWillTerminate: ( NSNotification * )notification
{
    ( void )notification;
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
    
    mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskFullSizeContentView;
    
    window                            = [ [ NSWindow alloc ] initWithContentRect: popover.contentViewController.view.bounds styleMask: mask backing: NSBackingStoreBuffered defer: NO ];
    window.contentView                = popover.contentViewController.view;
    window.delegate                   = self;
    window.releasedWhenClosed         = NO;
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility            = NSWindowTitleHidden;
    window.title                      = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleName" ];
    
    [ window center ];
    [ window makeKeyAndOrderFront: nil ];
    
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self name: NSPopoverWillShowNotification  object: self.popover ];
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self name: NSPopoverWillCloseNotification object: self.popover ];
    
    [ self.popover close ];
    
    self.popover       = nil;
    self.popoverWindow = window;
    self.popoverIsOpen = NO;
    
    return window;
}

- ( void )popoverWillShow: ( NSNotification * )notification
{
    ( void )notification;
    
    self.popoverTranscientEvent = [ NSEvent addGlobalMonitorForEventsMatchingMask: ( NSEventMask )( NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp ) handler:
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
