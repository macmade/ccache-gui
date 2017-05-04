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
 * @file        MainViewController.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com
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

- ( IBAction )cleanup:         ( nullable id )sender;
- ( IBAction )clear:           ( nullable id )sender;
- ( IBAction )resetStatistics: ( nullable id )sender;

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

@end
