/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www.xs-labs.com / www.imazing.com
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
 * @file        MainViewController.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com / www.imazing.com
 */

#import "MainViewController.h"
#import "CCache.h"
#import "StatisticItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController() < NSTableViewDelegate, NSTableViewDataSource >

@property( atomic, readwrite, assign           )          BOOL                         awake;
@property( atomic, readwrite, assign           )          BOOL                         running;
@property( atomic, readwrite, strong, nullable )          NSTimer                    * timer;
@property( atomic, readwrite, strong, nullable )          NSArray< StatisticItem * > * statistics;
@property( atomic, readwrite, strong, nullable ) IBOutlet NSArrayController          * statisticsController;

- ( IBAction )showOptionsMenu:       ( id )sender;
- ( IBAction )cleanup:               ( nullable id )sender;
- ( IBAction )clear:                 ( nullable id )sender;
- ( IBAction )resetStatistics:       ( nullable id )sender;
- ( IBAction )openManual:            ( nullable id )sender;
- ( IBAction )clearXcodeDerivedData: ( nullable id )sender;

- ( void )updateStatistics;

@end

NS_ASSUME_NONNULL_END

@implementation MainViewController

- ( instancetype )initWithNibName: ( NSString * )name bundle: ( NSBundle * )bundle
{
    if( ( self = [ super initWithNibName: name bundle: bundle ] ) )
    {
        self.statistics = @[];
    }
    
    return self;
}

- ( void )awakeFromNib
{
    if( self.awake )
    {
        return;
    }
    
    self.awake = YES;
    
    [ self updateStatistics ];
    
    self.statisticsController.sortDescriptors = @[ [ NSSortDescriptor sortDescriptorWithKey: NSStringFromSelector( @selector( label ) ) ascending: YES selector: @selector( localizedCaseInsensitiveCompare: ) ] ];
}

- ( void )viewDidAppear
{
    [ super viewDidAppear ];
    
    if( self.timer == nil )
    {
        self.timer = [ NSTimer scheduledTimerWithTimeInterval: 1 target: self selector: @selector( updateStatistics ) userInfo: nil repeats: YES ];
    }
}

- ( void )viewDidDisappear
{
    [ super viewDidDisappear ];
    
    [ self.timer invalidate ];
    
    self.timer = nil;
}

- ( IBAction )showOptionsMenu: ( id )sender
{
    NSButton * button;
    
    if( [ sender isKindOfClass: [ NSButton class ] ] == NO )
    {
        return;
    }
    
    button = sender;
    
    if( button.menu == nil || NSApp.currentEvent == nil )
    {
        return;
    }
    
    [ NSMenu popUpContextMenu: ( id )( button.menu ) withEvent: ( id )( NSApp.currentEvent ) forView: button ];
}

- ( IBAction )cleanup: ( nullable id )sender
{
    ( void )sender;
    
    self.running = YES;
    
    [ [ CCache sharedInstance ] cleanup: ^( BOOL success )
        {
            ( void )success;
            
            [ self updateStatistics ];
            
            self.running = NO;
        }
    ];
}

- ( IBAction )clear: ( nullable id )sender
{
    ( void )sender;
    
    self.running = YES;
    
    [ [ CCache sharedInstance ] clear: ^( BOOL success )
        {
            ( void )success;
            
            [ self updateStatistics ];
            
            self.running = NO;
        }
    ];
}

- ( IBAction )resetStatistics: ( nullable id )sender
{
    ( void )sender;
    
    self.running = YES;
    
    [ [ CCache sharedInstance ] clearStatistics: ^( BOOL success )
        {
            ( void )success;
            
            [ self updateStatistics ];
            
            self.running = NO;
        }
    ];
}

- ( void )updateStatistics
{
    [ [ CCache sharedInstance ] getStatistics: ^( BOOL success, NSString * statistics )
        {
            NSArray                           * lines;
            NSString                          * line;
            NSArray                           * parts;
            StatisticItem                     * item;
            NSMutableArray< StatisticItem * > * items;
            
            if( success == NO || statistics.length == 0 )
            {
                return;
            }
            
            lines = [ statistics componentsSeparatedByString: @"\n" ];
            items = [ NSMutableArray new ];
            
            for( line in lines )
            {
                parts = [ line componentsSeparatedByString: @"  " ];
                
                if( parts.count < 2 )
                {
                    continue;
                }
                
                item       = [ StatisticItem new ];
                item.label = [ parts.firstObject stringByTrimmingCharactersInSet: [ NSCharacterSet whitespaceCharacterSet ] ].capitalizedString;
                item.text  = [ parts.lastObject  stringByTrimmingCharactersInSet: [ NSCharacterSet whitespaceCharacterSet ] ];
                
                if( item.label.length && item.text.length )
                {
                    [ items addObject: item ];
                }
            }
            
            if( items.count )
            {
                [ self.statisticsController removeObjects: self.statistics ];
                [ self.statisticsController addObjects:    items ];
                [ self.statisticsController didChangeArrangementCriteria ];
            }
        }
    ];
}

- ( IBAction )openManual: ( nullable id )sender
{
    ( void )sender;
    
    [ [ NSWorkspace sharedWorkspace ] openURL: [ NSURL URLWithString: @"https://ccache.samba.org/manual.html" ] ];
}

- ( IBAction )clearXcodeDerivedData: ( nullable id )sender
{
    ( void )sender;
    
    self.running = YES;
    
    dispatch_async
    (
        dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ),
        ^( void )
        {
            NSString * library;
            NSString * path;
            NSString * sub;
            NSError  * error;
            BOOL       dir;
            
            library = NSSearchPathForDirectoriesInDomains( NSLibraryDirectory, NSUserDomainMask, YES ).firstObject;
            error   = nil;
            
            if( library.length && [ [ NSFileManager defaultManager ] fileExistsAtPath: library ] )
            {
                path = [ library stringByAppendingPathComponent: @"Developer" ];
                path = [ path    stringByAppendingPathComponent: @"Xcode" ];
                path = [ path    stringByAppendingPathComponent: @"DerivedData" ];
                
                if( path.length && [ [ NSFileManager defaultManager ] fileExistsAtPath: path isDirectory: &dir ] && dir )
                {
                    for( sub in [ [ NSFileManager defaultManager ] contentsOfDirectoryAtPath: path error: NULL ] )
                    {
                        [ [ NSFileManager defaultManager ] removeItemAtPath: [ path stringByAppendingPathComponent: sub ] error: &error ];
                        
                        if( error != nil )
                        {
                            break;
                        }
                    }
                }
            }
            
            dispatch_async
            (
                dispatch_get_main_queue(),
                ^( void )
                {
                    NSAlert * alert;
                    
                    if( error != nil )
                    {
                        alert = [ NSAlert alertWithError: error ];
                        
                        [ alert runModal ];
                    }
                    
                    self.running = NO;
                }
            );
        }
    );
}

@end
