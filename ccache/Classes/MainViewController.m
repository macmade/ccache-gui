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

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController()

@property( atomic, readwrite, assign           ) BOOL      running;
@property( atomic, readwrite, strong, nullable ) NSTimer * timer;

- ( IBAction )cleanup:         ( nullable id )sender;
- ( IBAction )clear:           ( nullable id )sender;
- ( IBAction )resetStatistics: ( nullable id )sender;

- ( void )updateStatistics;

@end

NS_ASSUME_NONNULL_END

@implementation MainViewController

- ( void )awakeFromNib
{
    [ self updateStatistics ];
}

- ( void )viewDidAppear
{
    [ super viewDidAppear ];
    
    self.timer = [ NSTimer scheduledTimerWithTimeInterval: 1 target: self selector: @selector( updateStatistics ) userInfo: nil repeats: YES ];
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
            if( success == NO )
            {
                return;
            }
            
            NSLog( @"%@", statistics );
        }
    ];
}

@end
