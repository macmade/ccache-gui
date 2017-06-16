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
#import "ApplicationDelegate.h"
#import "CCache.h"
#import "StatisticItem.h"
#import "NSView+ccache.h"
#import <GitHubUpdates/GitHubUpdates.h>

static NSDictionary< NSString *, NSString * > * tooltips = nil;

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController() < NSTableViewDelegate, NSTableViewDataSource >

@property( atomic, readwrite, assign           )          BOOL                         awake;
@property( atomic, readwrite, assign           )          BOOL                         installed;
@property( atomic, readwrite, assign           )          BOOL                         running;
@property( atomic, readwrite, assign           )          CGFloat                      rowHeight;
@property( atomic, readwrite, assign           )          CGFloat                      tableViewHeight;
@property( atomic, readwrite, strong, nullable )          NSTimer                    * timer;
@property( atomic, readwrite, strong, nullable )          NSArray< StatisticItem * > * statistics;
@property( atomic, readonly,          nullable )          NSString                   * xcodeDerivedDataPath;
@property( atomic, readonly,          nullable )          NSURL                      * xcodeDerivedDataURL;
@property( atomic, readwrite, strong, nullable )          GitHubUpdater              * updater;
@property( atomic, readwrite, strong, nullable ) IBOutlet NSArrayController          * statisticsController;
@property( atomic, readwrite, strong, nullable ) IBOutlet NSTableView                * tableView;

- ( IBAction )showOptionsMenu:        ( id )sender;
- ( IBAction )cleanup:                ( nullable id )sender;
- ( IBAction )clear:                  ( nullable id )sender;
- ( IBAction )resetStatistics:        ( nullable id )sender;
- ( IBAction )openManual:             ( nullable id )sender;
- ( IBAction )install:                ( nullable id )sender;
- ( IBAction )clearXcodeDerivedData:  ( nullable id )sender;
- ( IBAction )revealXcodeDerivedData: ( nullable id )sender;
- ( IBAction )checkForUpdates:        ( nullable id )sender;

- ( void )updateStatistics;
- ( void )adjustTableViewHeight;
- ( void )alertForMissingXcodeDerivedDataDirectory;

@end

NS_ASSUME_NONNULL_END

@implementation MainViewController

+ ( void )initialize
{
    if( self != [ MainViewController self ] )
    {
        return;
    }
    
    tooltips =
    @{
        @"autoconf compile/link"            : @"Uncachable compilation or linking by an autoconf test.",
        @"bad compiler arguments"           : @"Malformed compiler argument, e.g. missing a value for an option that requires an argument or failure to read a file specified by an option argument.",
        @"cache file missing"               : @"A file was unexpectedly missing from the cache. This only happens in rare situations, e.g. if one ccache instance is about to get a file from the cache while another instance removed the file as part of cache cleanup.",
        @"cache hit (direct)"               : @"A result was successfully found using the direct mode.",
        @"cache hit (preprocessed)"         : @"A result was successfully found using the preprocessor mode.",
        @"cache miss"                       : @"No result was found.",
        @"cache size"                       : @"Current size of the cache.",
        @"called for link"                  : @"The compiler was called for linking, not compiling.",
        @"called for preprocessing"         : @"The compiler was called for preprocessing, not compiling.",
        @"can’t use precompiled header"     : @"Preconditions for using precompiled headers were not fulfilled.",
        @"ccache internal error"            : @"Unexpected failure, e.g. due to problems reading/writing the cache.",
        @"cleanups performed"               : @"Number of cleanups performed, either implicitly due to the cache size limit being reached or due to explicit ccache -c/--cleanup calls.",
        @"compile failed"                   : @"The compilation failed. No result stored in the cache.",
        @"compiler check failed"            : @"A compiler check program specified by compiler_check (CCACHE_COMPILERCHECK) failed.",
        @"compiler produced empty output"   : @"The compiler’s output file (typically an object file) was empty after compilation.",
        @"compiler produced no output"      : @"The compiler’s output file (typically an object file) was missing after compilation.",
        @"compiler produced stdout"         : @"The compiler wrote data to standard output. This is something that compilers normally never do, so ccache is not designed to store such output in the cache.",
        @"couldn’t find the compiler"       : @"The compiler to execute could not be found.",
        @"error hashing extra file"         : @"Failure reading a file specified by extra_files_to_hash (CCACHE_EXTRAFILES).",
        @"files in cache"                   : @"Current number of files in the cache.",
        @"multiple source files"            : @"The compiler was called to compile multiple source files in one go. This is not supported by ccache.",
        @"no input file"                    : @"No input file was specified to the compiler.",
        @"output to a non-regular file"     : @"The output path specified with -o is not a file (e.g. a directory or a device node).",
        @"output to stdout"                 : @"The compiler was instructed to write its output to standard output using -o -. This is not supported by ccache.",
        @"preprocessor error"               : @"Preprocessing the source code using the compiler’s -E option failed.",
        @"unsupported code directive"       : @"Code like the assembler “.incbin” directive was found. This is not supported by ccache.",
        @"unsupported compiler option"      : @"A compiler option not supported by ccache was found.",
        @"unsupported source language"      : @"A source language e.g. specified with -x was unsupported by ccache."
    };
}

- ( instancetype )initWithNibName: ( NSString * )name bundle: ( NSBundle * )bundle
{
    if( ( self = [ super initWithNibName: name bundle: bundle ] ) )
    {
        self.statistics = @[];
        self.rowHeight  = 17.0;
        self.installed  = [ CCache sharedInstance ].installed;
    }
    
    return self;
}

- ( void )awakeFromNib
{
    if( self.awake )
    {
        return;
    }
    
    self.updater                              = [ GitHubUpdater new ];
    self.updater.user                         = @"macmade";
    self.updater.repository                   = @"ccache-gui";
    self.awake                                = YES;
    self.tableViewHeight                      = [ self.tableView.enclosingScrollView constantForAttribute: NSLayoutAttributeHeight ];
    self.statisticsController.sortDescriptors = @[ [ NSSortDescriptor sortDescriptorWithKey: NSStringFromSelector( @selector( label ) ) ascending: YES selector: @selector( localizedCaseInsensitiveCompare: ) ] ];
    
    [ self updateStatistics ];
    [ self.updater checkForUpdatesInBackground ];
    [ NSTimer scheduledTimerWithTimeInterval: 3600 target: self.updater selector: @selector( checkForUpdatesInBackground ) userInfo: nil repeats: YES ];
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
                
                item         = [ StatisticItem new ];
                item.label   = [ parts.firstObject stringByTrimmingCharactersInSet: [ NSCharacterSet whitespaceCharacterSet ] ].capitalizedString;
                item.text    = [ parts.lastObject  stringByTrimmingCharactersInSet: [ NSCharacterSet whitespaceCharacterSet ] ];
                item.tooltip = ( tooltips[ item.label.lowercaseString ] ) ? tooltips[ item.label.lowercaseString ] : @"";
                
                if( item.label.length && item.text.length )
                {
                    [ items addObject: item ];
                }
            }
            
            if( items.count && [ items isEqual: self.statistics ] == NO )
            {
                [ self.statisticsController removeObjects: self.statistics ];
                [ self.statisticsController addObjects:    items ];
                [ self.statisticsController didChangeArrangementCriteria ];
            }
            
            [ self adjustTableViewHeight ];
        }
    ];
}

- ( IBAction )openManual: ( nullable id )sender
{
    ( void )sender;
    
    [ [ NSWorkspace sharedWorkspace ] openURL: [ NSURL URLWithString: @"https://ccache.samba.org/manual.html" ] ];
}

- ( IBAction )install: ( nullable id )sender
{
    ( void )sender;
    
    [ [ NSWorkspace sharedWorkspace ] openURL: [ NSURL URLWithString: @"https://brew.sh" ] ];
}

- ( nullable NSString * )xcodeDerivedDataPath
{
    NSString * library;
    NSString * path;
    BOOL       dir;
    
    library = NSSearchPathForDirectoriesInDomains( NSLibraryDirectory, NSUserDomainMask, YES ).firstObject;
    
    if( library.length && [ [ NSFileManager defaultManager ] fileExistsAtPath: library ] )
    {
        path = [ library stringByAppendingPathComponent: @"Developer" ];
        path = [ path    stringByAppendingPathComponent: @"Xcode" ];
        path = [ path    stringByAppendingPathComponent: @"DerivedData" ];
        
        if( path.length && [ [ NSFileManager defaultManager ] fileExistsAtPath: path isDirectory: &dir ] && dir )
        {
            return path;
        }
    }
    
    return nil;
}

- ( nullable NSURL * )xcodeDerivedDataURL
{
    NSString * path;
    
    path = self.xcodeDerivedDataPath;
    
    if( path != nil )
    {
        return [ NSURL fileURLWithPath: path ];
    }
    
    return nil;
}

- ( IBAction )clearXcodeDerivedData: ( nullable id )sender
{
    NSString * path;
    
    ( void )sender;
    
    path = self.xcodeDerivedDataPath;
    
    if( path == nil )
    {
        [ self alertForMissingXcodeDerivedDataDirectory ];
        
        return;
    }
    
    self.running = YES;
    
    dispatch_async
    (
        dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ),
        ^( void )
        {
            NSString * sub;
            NSError  * error;
            
            for( sub in [ [ NSFileManager defaultManager ] contentsOfDirectoryAtPath: path error: NULL ] )
            {
                [ [ NSFileManager defaultManager ] removeItemAtPath: [ path stringByAppendingPathComponent: sub ] error: &error ];
                
                if( error != nil )
                {
                    break;
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

- ( IBAction )revealXcodeDerivedData: ( nullable id )sender
{
    NSString * path;
    
    path = self.xcodeDerivedDataPath;
    
    if( path == nil )
    {
        [ self alertForMissingXcodeDerivedDataDirectory ];
        
        return;
    }
    
    [ ( ApplicationDelegate * )( NSApp.delegate ) closePopover: sender ];
    [ [ NSWorkspace sharedWorkspace ] selectFile: nil inFileViewerRootedAtPath: path ];
}

- ( IBAction )checkForUpdates: ( nullable id )sender
{
    [ ( ApplicationDelegate * )( NSApp.delegate ) closePopover: sender ];
    [ self.updater checkForUpdates: sender ];
}

- ( void )alertForMissingXcodeDerivedDataDirectory
{
    NSAlert * alert;
    
    alert                 = [ NSAlert new ];
    alert.messageText     = NSLocalizedString( @"No Derived Data", @"" );
    alert.informativeText = NSLocalizedString( @"The Xcode Derived Data directory does not exist.", @"" );
    
    [ alert addButtonWithTitle: NSLocalizedString( @"OK", @"" ) ];
    [ ( ApplicationDelegate * )( NSApp.delegate ) closePopover: nil ];
    [ alert runModal ];
}

- ( void )adjustTableViewHeight
{
    if( self.installed && self.statistics.count != 0 )
    {
        [ self.tableView.enclosingScrollView setConstant: self.statistics.count * self.rowHeight forAttribute: NSLayoutAttributeHeight ];
    }
    else
    {
        [ self.tableView.enclosingScrollView setConstant: self.tableViewHeight forAttribute: NSLayoutAttributeHeight ];
    }
}

#pragma mark - NSTableViewDelegate

- ( CGFloat )tableView: ( NSTableView * )tableView heightOfRow: ( NSInteger )row
{
    ( void )tableView;
    ( void )row;
    
    return self.rowHeight;
}

@end
